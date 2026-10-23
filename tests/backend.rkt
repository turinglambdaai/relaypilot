#lang racket/base

(require rackunit
         rivet/backend
         rivet/protocol
         "../app/backend.rkt"
         "support.rkt")

(define-values (server-in client-out) (make-pipe))
(define-values (client-in server-out) (make-pipe))
(define server-thread (thread (lambda () (serve server-in server-out))))

(define hello (read-frame client-in))
(check-equal? (frame-type hello) message:hello)

(define next-id 1)
(define (call name . arguments)
  (define id next-id)
  (set! next-id (add1 next-id))
  (write-frame (frame message:request id (encode-value (cons name arguments))) client-out)
  (let loop ()
    (define response (read-frame client-in))
    (cond
      [(= (frame-type response) message:event) (loop)]
      [(not (= (frame-id response) id)) (error 'call "unexpected response id")]
      [(= (frame-type response) message:error)
       (error 'call "~a" (decode-value (frame-payload response)))]
      [else (decode-value (frame-payload response))])))

(define decision (call "explain-route" sample-profile-json "api.openai.com" "" 443 "tcp"))
(check-equal? (list-ref decision 1) 1)
(check-equal? (list-ref decision 2) "AI")
(check-equal? (list-ref decision 3) "us-reality-01")

(define compiled (call "compile-engine-config" sample-profile-json))
(check-equal? (list-ref compiled 0) "xray")
(check-equal? (string-length (list-ref compiled 2)) 64)
(check-regexp-match #rx"\"ruleTag\":\"relaypilot:1\"" (list-ref compiled 3))

;; Engine RPCs need the pinned binary; they are exercised when one is
;; configured and skipped with the reason otherwise.
(define engine-binary
  (let ([from-env (getenv "RELAYPILOT_XRAY_BIN")])
    (and from-env (not (string=? from-env "")) (file-exists? from-env) from-env)))

(when engine-binary
  (define loopback-json
    "{\"schemaVersion\":1,\"id\":\"loopback\",\"name\":\"Loopback\",\"nodes\":[],\"policies\":[],\"rules\":[\"FINAL,DIRECT\"],\"dns\":{}}")
  (define dry-run (call "engine-dry-run" sample-profile-json 1080))
  (check-equal? (list-ref dry-run 0) "xray")
  (check-equal? (list-ref dry-run 3) #t)
  (check-equal? (list-ref dry-run 4) #t)
  (check-regexp-match #rx"^26[.]" (list-ref dry-run 5))

  (define handle (call "engine-session-start" loopback-json 0))
  (check-regexp-match #rx"^xray-" (list-ref handle 0))
  (check-true (exact-positive-integer? (list-ref handle 1)))
  (check-regexp-match #rx"^26[.]" (list-ref handle 2))
  (define events (call "engine-session-events" (list-ref handle 0)))
  (check-true (list? events))
  (define stopped (call "engine-session-stop" (list-ref handle 0)))
  (check-equal? (list-ref stopped 0) #t)
  (check-equal? (list-ref stopped 1) "0")
  (check-true (positive? (length (list-ref stopped 2))))
  (define unknown (call "engine-session-stop" "xray-nope"))
  (check-equal? (list-ref unknown 0) #f))

(write-frame (frame message:shutdown 0 #"") client-out)
(thread-wait server-thread)
