#lang racket/base

;; Supervised Xray process runtime: binary discovery, config validation
;; (`run -test`), session lifecycle, and a bounded structured event bridge.
;;
;; The runtime owns execution evidence only. It never rewrites the compiled
;; artifact, never logs config bytes or credentials, and reports facts it
;; cannot observe as explicitly unavailable instead of inferring them
;; (ARCHITECTURE.md).

(require racket/file
         racket/list
         racket/path
         racket/port
         racket/string
         racket/tcp
         "../errors.rkt")

(provide (struct-out engine-session)
         engine-binary-env-var
         engine-not-configured-reason
         resolve-engine-binary
         engine-query-version!
         engine-validate-config
         engine-session-start!
         engine-session-stop!
         engine-session-events
         free-loopback-port!
         event-limit
         line-limit)

;; ---- bounded evidence ------------------------------------------------------

(define event-limit (make-parameter 200))
(define line-limit (make-parameter 2000))

(define (bounded-line raw)
  (define text (string-trim (if (string? raw) raw (format "~a" raw))))
  (define cap (line-limit))
  (if (> (string-length text) cap)
      (string-append (substring text 0 cap) "...[truncated]")
      text))

;; The event box always holds a bounded list in emission order. Oldest events
;; are kept (bounded head), so startup evidence survives a chatty session.
(define (make-event-log)
  (box '()))

(define (log-event! log stream-name line)
  (define current (unbox log))
  (unless (>= (length current) (event-limit))
    (set-box! log
              (append current
                      (list (hasheq 'stream stream-name 'line (bounded-line line)))))))

(define engine-binary-env-var "RELAYPILOT_XRAY_BIN")

(define engine-not-configured-reason
  (format "engine binary not configured; set ~a or put xray on PATH"
          engine-binary-env-var))

;; ---- binary discovery ------------------------------------------------------

;; An explicit binary must exist (the caller asked for that exact file);
;; env/PATH discovery reports unavailability as #f instead.
(define (resolve-engine-binary [explicit #f])
  (cond
    [(and explicit (not (string=? explicit "")))
     (define candidate
       (if (regexp-match? #rx"[/\\]" explicit)
           (simple-form-path (path->complete-path (string->path explicit)))
           explicit))
     (cond
       [(and (path? candidate) (file-exists? candidate))
        (path->string candidate)]
       [(and (path? candidate) (not (file-exists? candidate)))
        (raise-relaypilot 'engine 3 (format "engine binary not found: ~a" explicit))]
       [(and (string? candidate) (find-executable-path candidate))
        => path->string]
       [else
        (raise-relaypilot 'engine
                          3
                          (format "engine binary not found on PATH: ~a" explicit))])]
    [else
     (define from-env (getenv engine-binary-env-var))
     (with-handlers ([exn:fail:filesystem? (lambda (_) #f)])
       (define found
         (cond
           [(and from-env (not (string=? from-env ""))) (find-executable-path from-env)]
           [else (find-executable-path "xray")]))
       (and found (path->string found)))]))

;; ---- process helpers ---------------------------------------------------------

(define (run-capture! binary args timeout-ms)
  ;; subprocess returns (values proc child-stdout child-stdin child-stderr):
  ;; the first port is what the parent reads, the second what it writes.
  (define-values (proc child-out child-in child-err)
    (apply subprocess #f #f #f binary args))
  (close-output-port child-in)
  (define out-lines (open-output-string))
  (define err-lines (open-output-string))
  (define readers
    (list (thread (lambda () (copy-port child-out out-lines)))
          (thread (lambda () (copy-port child-err err-lines)))))
  (define deadline (+ (current-inexact-milliseconds) timeout-ms))
  (let loop ()
    (cond
      [(not (eq? (subprocess-status proc) 'running))
       (subprocess-wait proc)
       (for ([reader (in-list readers)])
         (sync/timeout 1 (thread-dead-evt reader)))
       (close-input-port child-out)
       (close-input-port child-err)
       (hasheq 'exit-code
               (subprocess-status proc)
               'output
               (append (string-split (get-output-string out-lines) "\n")
                       (string-split (get-output-string err-lines) "\n")))]
      [(> (current-inexact-milliseconds) deadline)
       (subprocess-kill proc #t)
       (hasheq 'exit-code 'timeout 'output (list "relaypilot: engine call timed out"))]
      [else (sleep 0.02) (loop)])))

;; ---- version ------------------------------------------------------------------

(define (engine-query-version! binary)
  (define result (run-capture! binary (list "version") 15000))
  (define first-line
    (for/first ([line (in-list (hash-ref result 'output))]
                #:when (non-empty-string? (string-trim line)))
      (string-trim line)))
  (unless (and first-line (equal? 0 (hash-ref result 'exit-code)))
    (raise-relaypilot 'engine
                      3
                      (format "engine binary did not report a version (exit ~a)"
                              (hash-ref result 'exit-code))))
  (define tokens (string-split first-line))
  (hasheq 'full
          first-line
          'version
          (if (>= (length tokens) 2) (list-ref tokens 1) first-line)))

;; ---- config validation (dry-run) -----------------------------------------------

(define (private-config-dir!)
  (define dir (make-temporary-file "relaypilot-engine-~a" 'directory))
  (with-handlers ([exn:fail:filesystem? void])
    (file-or-directory-permissions dir #o700))
  dir)

(define (write-config-file! config-bytes)
  (define dir (private-config-dir!))
  (define path (build-path dir "config.json"))
  (call-with-output-file path
                         (lambda (out) (write-bytes config-bytes out))
                         #:exists 'truncate/replace)
  (values dir path))

(define (engine-validate-config config-bytes binary [timeout-ms 60000])
  (define-values (config-dir config-path) (write-config-file! config-bytes))
  (dynamic-wind
    void
    (lambda ()
      (define result
        (run-capture! binary
                      (list "run" "-test" "-config" (path->string config-path))
                      timeout-ms))
      (define output
        (filter non-empty-string? (map string-trim (hash-ref result 'output))))
      (hasheq 'available
              #t
              'validated
              (equal? 0 (hash-ref result 'exit-code))
              'exit-code
              (hash-ref result 'exit-code)
              'output
              (take output (min (length output) (event-limit)))))
    (lambda ()
      (delete-directory/files config-dir))))

;; ---- sessions -------------------------------------------------------------------

(struct engine-session (id process stdin stdout stderr config-dir inbound-port event-log pumps)
        #:transparent)

(define (free-loopback-port!)
  (let loop ([port 39217] [attempts 32])
    (cond
      [(negative? attempts)
       (raise-relaypilot 'engine 3 "no free loopback port for engine session")]
      [else
       (define listener
         (with-handlers ([exn:fail:network? (lambda (_) #f)])
           (tcp-listen port 1 #t "127.0.0.1")))
       (cond
         [listener (tcp-close listener) port]
         [else (loop (+ port 1) (sub1 attempts))])])))

(define (validate-socks-port port who)
  (unless (and (exact-integer? port) (<= 1 port 65535))
    (raise-relaypilot 'validation 1 (format "socks port must be an integer in [1, 65535], got ~a" port)))
  port)

(define (pump-port! port stream-name log)
  (thread
   (lambda ()
     (with-handlers ([exn:fail? void])
       (let loop ()
         (define line (read-line port 'any))
         (unless (eof-object? line)
           (log-event! log stream-name line)
           (loop)))))))

(define (session-recent-events session)
  (define events (unbox (engine-session-event-log session)))
  (define recent (take-right events (min 5 (length events))))
  (string-join
   (for/list ([event (in-list recent)])
     (format "[~a] ~a" (hash-ref event 'stream) (hash-ref event 'line)))
   " | "))

(define (wait-for-inbound! session ready-timeout-ms)
  (define deadline (+ (current-inexact-milliseconds) ready-timeout-ms))
  (let loop ()
    (define proc (engine-session-process session))
    (cond
      [(not (eq? (subprocess-status proc) 'running))
       (raise-relaypilot
        'engine
        3
        (format "engine exited before the inbound became reachable (exit ~a); recent events: ~a"
                (subprocess-status proc)
                (session-recent-events session)))]
      [else
       (define connected
         (with-handlers ([exn:fail:network? (lambda (_) #f)])
           (define-values (in out)
             (tcp-connect "127.0.0.1" (engine-session-inbound-port session)))
           (close-input-port in)
           (close-output-port out)
           #t))
       (cond
         [connected (void)]
         [(> (current-inexact-milliseconds) deadline)
          (raise-relaypilot 'engine 3 "engine inbound did not become ready within the deadline")]
         [else (sleep 0.05) (loop)])])))

(define (engine-session-start! config-bytes binary
                               #:socks-port [socks-port #f]
                               #:ready-timeout-ms [ready-timeout-ms 15000])
  (unless binary
    (raise-relaypilot 'engine 3 engine-not-configured-reason))
  (define port
    (validate-socks-port (or socks-port (free-loopback-port!)) 'engine-session-start!))
  (define-values (config-dir config-path) (write-config-file! config-bytes))
  (define log (make-event-log))
  (define-values (proc child-out child-in child-err)
    (subprocess #f #f #f binary "-config" (path->string config-path)))
  (define pumps
    (list (pump-port! child-out "stdout" log)
          (pump-port! child-err "stderr" log)))
  (define session
    (engine-session (format "xray-~a" (subprocess-pid proc))
                    proc
                    child-in
                    child-out
                    child-err
                    config-dir
                    port
                    log
                    pumps))
  (dynamic-wind
    void
    (lambda () (wait-for-inbound! session ready-timeout-ms))
    (lambda ()
      ;; A failed start must never leak the process or its private config.
      (unless (session-live? session)
        (engine-session-stop! session))))
  session)

(define (session-live? session)
  (eq? (subprocess-status (engine-session-process session)) 'running))

(define (engine-session-stop! session [grace-ms 2000])
  (define proc (engine-session-process session))
  (when (session-live? session)
    (subprocess-kill proc #f)
    (define deadline (+ (current-inexact-milliseconds) grace-ms))
    (let loop ()
      (when (and (session-live? session) (< (current-inexact-milliseconds) deadline))
        (sleep 0.05)
        (loop))))
  (when (session-live? session) (subprocess-kill proc #t))
  (subprocess-wait proc)
  (with-handlers ([exn:fail:filesystem? void])
    (close-output-port (engine-session-stdin session)))
  (for ([thread* (in-list (engine-session-pumps session))])
    (sync/timeout 1 (thread-dead-evt thread*)))
  (with-handlers ([exn:fail:filesystem? void])
    (close-input-port (engine-session-stdout session))
    (close-input-port (engine-session-stderr session)))
  (with-handlers ([exn:fail:filesystem? void])
    (delete-directory/files (engine-session-config-dir session)))
  (hasheq 'stopped
          #t
          'exit-code
          (subprocess-status proc)
          'events
          (engine-session-events session)))

(define (engine-session-events session)
  (unbox (engine-session-event-log session)))
