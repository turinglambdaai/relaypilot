#lang racket/base

;; RelayPilot agent-facing CLI (docs/CLI-SPEC.md). One canonical JSON envelope
;; per invocation on stdout (sorted keys, no whitespace), errors as canonical
;; JSON on stderr, exit codes that never lie: 0 ok, 1 invalid input,
;; 2 usage, 3 engine failure.

(require json
         racket/file
         racket/format
         racket/list
         racket/path
         racket/port
         racket/string
         "core/ai/redact.rkt"
         "core/decision.rkt"
         "core/diagnostics/bundle.rkt"
         "core/errors.rkt"
         "core/engines/runtime.rkt"
         "core/engines/xray.rkt"
         "core/json.rkt"
         "core/model.rkt"
         "core/profile/json.rkt"
         "core/rules/surge.rkt"
         "core/version.rkt")

(provide run-cli)

;; ---- emission ----------------------------------------------------------------

(define (emit jsexpr)
  (write-bytes (jsexpr->canonical-bytes jsexpr))
  (newline))

(define (emit-error kind exit-code message)
  (define error-port (current-error-port))
  (write-bytes
   (jsexpr->canonical-bytes (hasheq 'ok
                                    #f
                                    'error
                                    message
                                    'kind
                                    (symbol->string kind)
                                    'exitCode
                                    exit-code))
   error-port)
  (newline error-port)
  (flush-output error-port))

(define (fail kind exit-code message)
  (raise (exn:fail:relaypilot message (current-continuation-marks) kind exit-code)))

;; ---- input -------------------------------------------------------------------

(define (load-profile source)
  (cond
    [(string=? source "-") (read-relay-profile (current-input-port))]
    [else (read-relay-profile (string->path source))]))

(define (flag flags key)
  (hash-ref flags key #f))

(define (flag->number flags key who)
  (define raw (flag flags key))
  (and raw
       (let ([number (string->number raw)])
         (unless (and (exact-integer? number) (<= 1 number 65535))
           (fail 'validation 1 (format "~a must be an integer in [1, 65535], got ~a" key raw)))
         number)))

(define (require-positional positionals command)
  (unless (= (length positionals) 1)
    (fail 'usage 2 (format "~a expects exactly one profile path" command)))
  (car positionals))

(define (flow-from-flags flags)
  (define domain (flag flags "domain"))
  (define ip (flag flags "ip"))
  (unless (or domain ip)
    (fail 'usage 2 "provide at least one of --domain or --ip"))
  (define port (let ([raw (flag flags "port")])
                 (if raw
                     (let ([number (string->number raw)])
                       (unless (and (exact-integer? number) (<= 0 number 65535))
                         (fail 'validation 1 (format "--port must be an integer in [0, 65535], got ~a" raw)))
                       number)
                     0)))
  (define network (let ([raw (or (flag flags "network") "tcp")])
                    (unless (member raw (list "tcp" "udp"))
                      (fail 'validation 1 (format "--network must be tcp or udp, got ~a" raw)))
                    (string->symbol raw)))
  (connection-flow domain ip port network (flag flags "source-app")))

;; ---- flow helpers -------------------------------------------------------------

(define (decide-trace profile flags)
  (decide-flow profile (flow-from-flags flags)))

(define (trace->jsexpr trace)
  (hasheq 'traceId
          (decision-trace-trace-id trace)
          'profileId
          (decision-trace-profile-id trace)
          'ruleIndex
          (decision-trace-rule-index trace)
          'ruleSource
          (decision-trace-rule-source trace)
          'matchedKind
          (symbol->string (decision-trace-matched-kind trace))
          'matchedValue
          (decision-trace-matched-value trace)
          'policy
          (decision-trace-requested-policy trace)
          'outbound
          (decision-trace-selected-outbound trace)
          'steps
          (decision-trace-steps trace)
          'warnings
          (decision-trace-warnings trace)))

(define (absent value)
  (or value 'null))

(define (flow->jsexpr flow)
  (hasheq 'domain
          (absent (connection-flow-domain flow))
          'ip
          (absent (connection-flow-ip flow))
          'port
          (connection-flow-port flow)
          'network
          (symbol->string (connection-flow-network flow))
          'sourceApp
          (absent (connection-flow-source-app flow))))

;; Profile secret material that must not leak into diagnostics. Values shorter
;; than 8 characters are structural ("none", "chrome") rather than secrets.
(define (profile-secrets profile)
  (remove-duplicates
   (for*/list ([node (in-list (relay-profile-nodes profile))]
               [table (in-list (list (proxy-node-credentials node) (proxy-node-tls node)))]
               [value (in-hash-values table)]
               #:when (and (string? value) (>= (string-length value) 8)))
     value)))

;; ---- commands ------------------------------------------------------------------

(define (cmd-version)
  (emit (hasheq 'ok
                #t
                'name
                app-display-name
                'version
                app-version
                'build
                app-build
                'identifier
                app-identifier
                'channel
                (symbol->string app-channel)))
  0)

(define (cmd-validate positionals)
  (define profile (load-profile (require-positional positionals "validate")))
  (emit (hasheq 'ok
                #t
                'profileId
                (relay-profile-id profile)
                'schemaVersion
                (relay-profile-schema-version profile)
                'nodes
                (length (relay-profile-nodes profile))
                'policies
                (length (relay-profile-policies profile))
                'rules
                (length (relay-profile-rules profile))))
  0)

(define (cmd-decide positionals flags)
  (define profile (load-profile (require-positional positionals "decide")))
  (define trace (decide-trace profile flags))
  (emit (hasheq 'ok
                #t
                'flow
                (flow->jsexpr (decision-trace-flow trace))
                'trace
                (trace->jsexpr trace)))
  0)

(define (compile-envelope profile socks-port out-path)
  (define compiled (compile-xray-config profile socks-port))
  (define base
    (hasheq 'ok
            #t
            'adapter
            (symbol->string (compiled-engine-config-adapter compiled))
            'adapterVersion
            (compiled-engine-config-adapter-version compiled)
            'sha256
            (compiled-engine-config-digest compiled)
            'profileId
            (relay-profile-id profile)
            'ruleCount
            (length (relay-profile-rules profile))
            'inbound
            (hash-ref (compiled-engine-config-metadata compiled) 'inbound)))
  (cond
    [out-path
     (define parent (or (path-only out-path) (current-directory)))
     (make-directory* parent)
     (define temporary (make-temporary-file "relaypilot-config-~a.tmp" #f parent))
     (dynamic-wind
       void
       (lambda ()
         (call-with-output-file
          temporary
          (lambda (out) (write-bytes (compiled-engine-config-bytes compiled) out))
          #:exists 'truncate/replace)
         (rename-file-or-directory temporary out-path #t))
       (lambda ()
         (when (file-exists? temporary) (delete-file temporary))))
     (hash-set base 'writtenTo (path->string out-path))]
    [else
     (hash-set base 'config (bytes->jsexpr (compiled-engine-config-bytes compiled)))]))

(define (cmd-compile positionals flags)
  (define profile (load-profile (require-positional positionals "compile")))
  (define socks-port (or (flag->number flags "socks-port" 'compile) 1080))
  (emit (compile-envelope profile socks-port (flag flags "out")))
  0)

(define (cmd-dry-run positionals flags)
  (define profile (load-profile (require-positional positionals "dry-run")))
  (define socks-port (or (flag->number flags "socks-port" 'dry-run) 1080))
  (define compiled (compile-xray-config profile socks-port))
  (define binary
    (resolve-engine-binary (flag flags "binary")))
  (define engine
    (if binary
        (let ([result (engine-validate-config (compiled-engine-config-bytes compiled) binary)])
          (hasheq 'available
                  #t
                  'validated
                  (hash-ref result 'validated)
                  'exitCode
                  (hash-ref result 'exit-code)
                  'binary
                  binary
                  'output
                  (hash-ref result 'output)))
        (hasheq 'available #f 'validated #f 'reason engine-not-configured-reason)))
  (when (and (hash-ref engine 'available #f) (not (hash-ref engine 'validated #f)))
    (fail 'engine
          3
          (format "engine rejected the compiled configuration (exit ~a): ~a"
                  (hash-ref engine 'exitCode)
                  (string-join (hash-ref engine 'output) " | "))))
  (emit (hasheq 'ok
                #t
                'adapter
                "xray"
                'adapterVersion
                (compiled-engine-config-adapter-version compiled)
                'sha256
                (compiled-engine-config-digest compiled)
                'profileId
                (relay-profile-id profile)
                'ruleCount
                (length (relay-profile-rules profile))
                'inbound
                (hash-ref (compiled-engine-config-metadata compiled) 'inbound)
                'engine
                engine))
  0)

(define (cmd-import-surge positionals flags)
  (unless (= (length positionals) 1)
    (fail 'usage 2 "import-surge expects exactly one rules file path"))
  (define profile-id (flag flags "id"))
  (unless profile-id (fail 'usage 2 "import-surge requires --id"))
  (define source (car positionals))
  (define rules-text
    (if (string=? source "-")
        (port->string (current-input-port))
        (file->string (string->path source))))
  (define rules
    (parse-surge-rules rules-text (if (string=? source "-") "stdin" source)))
  (define profile
    (relay-profile 1 profile-id (or (flag flags "name") profile-id) '() '() rules (hasheq)))
  (define unresolved
    (remove-duplicates
     (for/list ([rule (in-list rules)]
                #:unless (or (string-ci=? (relay-rule-policy rule) "DIRECT")
                             (string-ci=? (relay-rule-policy rule) "REJECT")))
       (relay-rule-policy rule))))
  (emit (hasheq 'ok
                #t
                'unresolvedPolicies
                unresolved
                'ruleCount
                (length rules)
                'profile
                (relay-profile->jsexpr profile)))
  0)

(define (cmd-diagnose positionals flags)
  (define profile (load-profile (require-positional positionals "diagnose")))
  (define trace (decide-trace profile flags))
  (define bundle (trace->diagnostic-bundle trace))
  (define secrets (profile-secrets profile))
  (define redacted (redact-diagnostic-bundle bundle secrets))
  (define decision (diagnostic-bundle-decision redacted))
  (emit (hasheq 'ok
                #t
                'redacted
                #t
                'bundle
                (hasheq 'schemaVersion
                        (diagnostic-bundle-schema-version redacted)
                        'traceId
                        (diagnostic-bundle-trace-id redacted)
                        'profileId
                        (diagnostic-bundle-profile-id redacted)
                        'connection
                        (diagnostic-bundle-connection redacted)
                        'decision
                        decision
                        'engineEvents
                        (diagnostic-bundle-engine-events redacted)
                        'comparableFailures
                        (diagnostic-bundle-comparable-failures redacted))))
  0)

;; ---- dispatch -------------------------------------------------------------------

(define usage-text
  (string-append
   "RelayPilot — deterministic relay profile control plane\n"
   "\n"
   "Usage: relaypilot <command> [arguments]\n"
   "\n"
   "Commands:\n"
   "  version                              Print release identity as JSON\n"
   "  validate <profile.json>              Validate a Relay Profile (\"-\" reads stdin)\n"
   "  decide <profile.json> [flow]         Explain one connection as a DecisionTrace\n"
   "  compile <profile.json> [flags]       Compile the engine artifact\n"
   "  dry-run <profile.json> [flags]       Compile and validate with the engine binary\n"
   "  import-surge <rules.list> [flags]    Import Surge rule lines into a profile skeleton\n"
   "  diagnose <profile.json> [flow]       Emit a redacted DiagnosticBundle\n"
   "\n"
   "Flow flags: --domain D --ip I --port P --network tcp|udp --source-app S\n"
   "Other flags: --out PATH --socks-port N --binary PATH --id ID --name NAME\n"
   "\n"
   "Exit codes: 0 ok | 1 invalid input | 2 usage | 3 engine failure\n"
   "Contract: docs/CLI-SPEC.md\n"))

(define known-commands
  '("version" "validate" "decide" "compile" "dry-run" "import-surge" "diagnose"))

(define (parse-args argv)
  (let loop ([rest argv] [flags (hash)] [positionals '()] [sub #f])
    (cond
      [(null? rest) (values sub flags (reverse positionals))]
      [else
       (define arg (car rest))
       (cond
         [(and (string-prefix? arg "--") (string-contains? arg "="))
          (define split (string-split arg "=" #:trim? #f))
          (loop (cdr rest)
                (hash-set flags (substring (car split) 2) (string-join (cdr split) "="))
                positionals
                sub)]
         [(string-prefix? arg "--")
          (if (null? (cdr rest))
              (fail 'usage 2 (format "flag ~a needs a value" arg))
              (loop (cddr rest)
                    (hash-set flags (substring arg 2) (cadr rest))
                    positionals
                    sub))]
         [(not sub) (loop (cdr rest) flags positionals arg)]
         [else (loop (cdr rest) flags (cons arg positionals) sub)])])))

(define (dispatch argv)
  (define-values (sub flags positionals) (parse-args argv))
  (cond
    [(or (not sub) (member sub (list "help" "--help" "-h")))
     (display usage-text (current-error-port))
     2]
    [(not (member sub known-commands))
     (fail 'usage 2 (format "unknown command: ~a" sub))]
    [else
     (case sub
       [("version") (cmd-version)]
       [("validate") (cmd-validate positionals)]
       [("decide") (cmd-decide positionals flags)]
       [("compile") (cmd-compile positionals flags)]
       [("dry-run") (cmd-dry-run positionals flags)]
       [("import-surge") (cmd-import-surge positionals flags)]
       [("diagnose") (cmd-diagnose positionals flags)]
       [else (fail 'usage 2 (format "unknown command: ~a" sub))])]))

(define (run-cli argv)
  (with-handlers
    ([exn:fail:relaypilot?
      (lambda (e)
        (emit-error (exn:fail:relaypilot-kind e)
                    (exn:fail:relaypilot-exit-code e)
                    (exn-message e))
        (exn:fail:relaypilot-exit-code e))]
     [exn:fail:filesystem?
      (lambda (e)
        (emit-error 'validation 1 (format "cannot read input: ~a" (exn-message e)))
        1)]
     [exn:fail?
      (lambda (e)
        (emit-error 'validation 1 (exn-message e))
        1)])
    (with-handlers ([exn:break? (lambda (_) 130)])
      (dispatch argv))))

(module+ main
  (exit (run-cli (vector->list (current-command-line-arguments)))))
