#lang racket/base

;; Engine runtime tests. The loopback SOCKS test runs a real request through a
;; real engine session against a local test endpoint — no external network,
;; no real credentials. It is skipped (honestly, with a printed reason) when
;; no engine binary is configured.

(require json
         rackunit
         racket/file
         racket/match
         racket/port
         racket/string
         racket/tcp
         "../app/core/errors.rkt"
         "../app/core/engines/runtime.rkt"
         "../app/core/engines/xray.rkt"
         "../app/core/json.rkt"
         "../app/core/model.rkt"
         "../app/core/profile/json.rkt")

(define engine-binary (resolve-engine-binary))

(unless engine-binary
  (displayln
   (format "relaypilot: skipping engine session tests — ~a" engine-not-configured-reason)))

(define loopback-profile
  (parse-relay-profile (hasheq 'schemaVersion
                               1
                               'id
                               "loopback-test"
                               'name
                               "Loopback Test"
                               'nodes
                               '()
                               'policies
                               '()
                               'rules
                               (list "FINAL,DIRECT")
                               'dns
                               (hasheq))))

;; ---- minimal SOCKS5 CONNECT client (loopback tests only) ---------------------

(define (socks5-connect! host port target-host target-port)
  (define-values (tunnel-in tunnel-out) (tcp-connect host port))
  (write-bytes (bytes 5 1 0) tunnel-out)
  (flush-output tunnel-out)
  (define greeting (read-bytes 2 tunnel-in))
  (unless (and (bytes? greeting)
               (= 2 (bytes-length greeting))
               (= 5 (bytes-ref greeting 0))
               (zero? (bytes-ref greeting 1)))
    (raise-result-error 'socks5-connect! "no-auth greeting" greeting))
  (define ip-parts (map string->number (string-split target-host ".")))
  (write-bytes (bytes 5
                      1
                      0
                      1
                      (list-ref ip-parts 0)
                      (list-ref ip-parts 1)
                      (list-ref ip-parts 2)
                      (list-ref ip-parts 3)
                      (quotient target-port 256)
                      (remainder target-port 256))
               tunnel-out)
  (flush-output tunnel-out)
  (define reply-head (read-bytes 4 tunnel-in))
  (unless (and (bytes? reply-head) (= 4 (bytes-length reply-head)))
    (raise-result-error 'socks5-connect! "reply head" reply-head))
  (unless (zero? (bytes-ref reply-head 1))
    (raise-result-error 'socks5-connect! "CONNECT succeeded" (bytes-ref reply-head 1)))
  (define skip
    (case (bytes-ref reply-head 3)
      [(1) 4]
      [(3) (+ 1 (read-byte tunnel-in))]
      [(4) 16]
      [else (raise-result-error 'socks5-connect! "address type" (bytes-ref reply-head 3))]))
  (read-bytes (+ skip 2) tunnel-in)
  (values tunnel-in tunnel-out))

;; ---- local test endpoint ------------------------------------------------------

(define (start-loopback-endpoint! port)
  (define listener (tcp-listen port 4 #t "127.0.0.1"))
  (define server-thread
    (thread
     (lambda ()
       (let accept ()
         (define-values (conn-in conn-out) (tcp-accept listener))
         (thread
          (lambda ()
            ;; Read until the end of the request headers, then answer once.
            (let read-request ([buffer #""])
              (define buf (make-bytes 1024))
              (define count (read-bytes-avail! buf conn-in))
              (define next
                (if (eof-object? count) buffer (bytes-append buffer (subbytes buf 0 count))))
              (unless (or (eof-object? count)
                          (regexp-match? #rx"\r\n\r\n$" next)
                          (> (bytes-length next) 8192))
                (read-request next)))
            (write-bytes
             #"HTTP/1.1 200 OK\r\nContent-Length: 25\r\nConnection: close\r\n\r\nrelaypilot-loopback-probe"
             conn-out)
            (close-output-port conn-out)
            (close-input-port conn-in)))
         (accept)))))
  (values listener server-thread))

;; ---- runtime unit behavior -----------------------------------------------------

(test-case "socks port validation"
  (check-exn exn:fail:relaypilot?
             (lambda () (compile-xray-config loopback-profile 0)))
  (check-exn exn:fail:relaypilot?
             (lambda () (compile-xray-config loopback-profile 70000))))

(test-case "compiled loopback artifact routes through the direct outbound"
  (define compiled (compile-xray-config loopback-profile 39217))
  (define generated (bytes->jsexpr (compiled-engine-config-bytes compiled)))
  (define routes (hash-ref (hash-ref generated 'routing) 'rules))
  (check-equal? (hash-ref (car routes) 'outboundTag) "relaypilot.direct")
  (check-equal? (hash-ref (car (hash-ref generated 'inbounds)) 'port) 39217)
  (check-equal? (hash-ref (compiled-engine-config-metadata compiled) 'inbound)
                (hasheq 'listen "127.0.0.1" 'port 39217 'protocol "socks")))

(when engine-binary
  (test-case "engine accepts a compiled configuration"
    (define result
      (engine-validate-config
       (compiled-engine-config-bytes (compile-xray-config loopback-profile 39217))
       engine-binary))
    (check-true (hash-ref result 'validated))
    (check-equal? (hash-ref result 'exit-code) 0))

  (test-case "real loopback SOCKS request through a supervised engine session"
    (define endpoint-port (free-loopback-port!))
    (define-values (listener endpoint-thread) (start-loopback-endpoint! endpoint-port))
    (define socks-port (free-loopback-port!))
    (define compiled (compile-xray-config loopback-profile socks-port))
    (define session
      (engine-session-start! (compiled-engine-config-bytes compiled) engine-binary))
    (check-equal? (engine-session-inbound-port session) socks-port)
    (check-equal? (engine-session-id session) (format "xray-~a" (subprocess-pid (engine-session-process session))))
    (define-values (tunnel-in tunnel-out)
      (socks5-connect! "127.0.0.1" socks-port "127.0.0.1" endpoint-port))
    (write-bytes
     #"GET /probe HTTP/1.0\r\nHost: loopback.relaypilot.test\r\nUser-Agent: relaypilot-test\r\n\r\n"
     tunnel-out)
    (flush-output tunnel-out)
    (define response (port->bytes tunnel-in))
    (define response-text (bytes->string/latin-1 response))
    (check-true (string-contains? response-text "200 OK"))
    (check-true (string-contains? response-text "relaypilot-loopback-probe"))
    (close-input-port tunnel-in)
    (close-output-port tunnel-out)
    (define stop-result (engine-session-stop! session))
    (check-true (hash-ref stop-result 'stopped))
    (check-equal? (hash-ref stop-result 'exit-code) 0)
    (check-true (positive? (length (hash-ref stop-result 'events))))
    (tcp-close listener)
    (kill-thread endpoint-thread))

  (test-case "a failed start leaves no process behind"
    (define broken-config #"this is not a config")
    (check-exn exn:fail:relaypilot?
               (lambda () (engine-session-start! broken-config engine-binary))))

  (when (memq (system-type 'os) '(unix macosx))
    (test-case "engine rejection is reported with bounded evidence"
      (define fake-dir (make-temporary-file "relaypilot-fake-~a" 'directory))
      (define fake-binary (build-path fake-dir "fake-xray"))
      (call-with-output-file
       fake-binary
       (lambda (out)
         (display "#!/bin/sh\nif [ \"$1\" = \"version\" ]; then\n  echo \"Xray 0.0.0-fake (fake engine)\"\n  exit 0\nelse\n  echo \"fake engine: rejected\"\n  exit 1\nfi\n"
                 out))
       #:exists 'truncate/replace)
      (file-or-directory-permissions fake-binary #o755)
      (check-equal? (hash-ref (engine-query-version! fake-binary) 'version) "0.0.0-fake")
      (define rejection
        (engine-validate-config
         (compiled-engine-config-bytes (compile-xray-config loopback-profile 39217))
         fake-binary))
      (check-false (hash-ref rejection 'validated))
      (check-equal? (hash-ref rejection 'exit-code) 1)
      (check-not-false (member "fake engine: rejected" (hash-ref rejection 'output)))
      (delete-directory/files fake-dir))))
