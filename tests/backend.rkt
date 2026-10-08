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

(write-frame (frame message:shutdown 0 #"") client-out)
(thread-wait server-thread)
