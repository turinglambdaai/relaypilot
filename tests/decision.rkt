#lang racket/base

(require rackunit
         racket/string
         "../app/core/decision.rkt"
         "../app/core/model.rkt"
         "support.rkt")

(define flow (connection-flow "api.openai.com" #f 443 'tcp "browser"))
(define first (decide-flow sample-profile flow))
(define second (decide-flow sample-profile flow))

(check-equal? (decision-trace-trace-id first) (decision-trace-trace-id second))
(check-equal? (decision-trace-rule-index first) 1)
(check-equal? (decision-trace-requested-policy first) "AI")
(check-equal? (decision-trace-selected-outbound first) "us-reality-01")
(check-regexp-match #rx"group AI selected us-reality-01"
                    (string-join (decision-trace-steps first) "\n"))
