#lang racket/base

(require racket/list
         rivet/backend
         (prefix-in core: "core/model.rkt")
         "core/decision.rkt"
         "core/engines/interface.rkt"
         "core/engines/runtime.rkt"
         "core/engines/xray.rkt"
         "core/errors.rkt"
         "core/json.rkt"
         "core/profile/json.rkt")

(provide start)

(define-record RouteDecision
               ([traceId : String] [ruleIndex : Int64]
                                   [policy : String]
                                   [outbound : String]
                                   [steps : (List String)]
                                   [warnings : (List String)]))

(define-record CompiledEngineConfig
               ([adapter : String] [adapterVersion : String] [sha256 : String] [json : String]))

(define-record EngineDryRun
               ([adapter : String] [adapterVersion : String] [sha256 : String]
                                   [available : Bool] [validated : Bool]
                                   [engineVersion : String] [engineOutput : (List String)]))

(define-record EngineSessionHandle ([sessionId : String] [inboundPort : Int64] [engineVersion : String]))

(define-record EngineSessionStop ([stopped : Bool] [exitStatus : String] [events : (List String)]))

(define-rpc (explain-route [profileJson : String]
                           [domain : String]
                           [ip : String]
                           [port : Int64]
                           [network : String]
                           :
                           RouteDecision)
            (define profile (read-relay-profile profileJson))
            (define trace
              (decide-flow profile
                           (core:connection-flow (if (string=? domain "") #f domain)
                                                 (if (string=? ip "") #f ip)
                                                 port
                                                 (string->symbol network)
                                                 #f)))
            (RouteDecision (core:decision-trace-trace-id trace)
                           (core:decision-trace-rule-index trace)
                           (core:decision-trace-requested-policy trace)
                           (core:decision-trace-selected-outbound trace)
                           (core:decision-trace-steps trace)
                           (core:decision-trace-warnings trace)))

(define-rpc (compile-engine-config [profileJson : String] : CompiledEngineConfig)
            (define compiled (engine-compile xray-engine-adapter (read-relay-profile profileJson)))
            (CompiledEngineConfig (symbol->string (core:compiled-engine-config-adapter compiled))
                                  (core:compiled-engine-config-adapter-version compiled)
                                  (core:compiled-engine-config-digest compiled)
                                  (bytes->string/utf-8 (core:compiled-engine-config-bytes compiled))))

(define-rpc (engine-dry-run [profileJson : String] [socksPort : Int64] : EngineDryRun)
            (define profile (read-relay-profile profileJson))
            (define compiled
              (compile-xray-config profile (if (zero? socksPort) 1080 socksPort)))
            (define binary (resolve-engine-binary))
            (define version
              (if binary (hash-ref (engine-query-version! binary) 'version) ""))
            (define validation
              (if binary
                  (engine-validate-config (core:compiled-engine-config-bytes compiled) binary)
                  (hasheq 'available #f 'validated #f 'output (list engine-not-configured-reason))))
            (EngineDryRun "xray"
                          (core:compiled-engine-config-adapter-version compiled)
                          (core:compiled-engine-config-digest compiled)
                          (hash-ref validation 'available)
                          (hash-ref validation 'validated)
                          version
                          (hash-ref validation 'output)))

;; Live sessions live only inside this backend process; the id is opaque to
;; hosts. Events cross the wire as canonical JSON strings.
(define sessions (make-hash))
(define sessions-lock (make-semaphore 1))

(define (with-session-lock thunk)
  (call-with-semaphore sessions-lock thunk))

(define (event->string event)
  (bytes->string/utf-8 (jsexpr->canonical-bytes event)))

(define-rpc (engine-session-start [profileJson : String] [socksPort : Int64]
                                  :
                                  EngineSessionHandle)
            (define profile (read-relay-profile profileJson))
            (define binary (resolve-engine-binary))
            (unless binary
              (raise-relaypilot 'engine 3 engine-not-configured-reason))
            ;; Port 0 means "pick a free loopback port"; the compile and the
            ;; spawned engine must agree on the same concrete port.
            (define port (if (zero? socksPort) (free-loopback-port!) socksPort))
            (define compiled (compile-xray-config profile port))
            (define version (hash-ref (engine-query-version! binary) 'version))
            (define session
              (engine-session-start! (core:compiled-engine-config-bytes compiled)
                                     binary
                                     #:socks-port port))
            (with-session-lock
             (lambda () (hash-set! sessions (engine-session-id session) session)))
            (EngineSessionHandle (engine-session-id session)
                                 (engine-session-inbound-port session)
                                 version))

(define-rpc (engine-session-stop [sessionId : String] : EngineSessionStop)
            (define session
              (with-session-lock (lambda () (hash-ref sessions sessionId #f))))
            (cond
              [(not session) (EngineSessionStop #f "unknown-session" '())]
              [else
               (define result (engine-session-stop! session))
               (with-session-lock (lambda () (hash-remove! sessions sessionId)))
               (EngineSessionStop #t
                                  (format "~a" (hash-ref result 'exit-code))
                                  (map event->string (hash-ref result 'events)))]))

(define-rpc (engine-session-events [sessionId : String] : (List String))
            (define session
              (with-session-lock (lambda () (hash-ref sessions sessionId #f))))
            (if session
                (map event->string (engine-session-events session))
                '()))

(define (start in-fd out-fd)
  (serve-fds in-fd out-fd))

(module+ test-support
  (provide RouteDecision
           CompiledEngineConfig
           EngineDryRun
           EngineSessionHandle
           EngineSessionStop
           explain-route
           compile-engine-config
           engine-dry-run
           engine-session-start
           engine-session-stop
           engine-session-events))
