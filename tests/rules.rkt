#lang racket/base

(require rackunit
         "../app/core/model.rkt"
         "../app/core/rules/evaluator.rkt"
         "../app/core/rules/surge.rkt")

(define rules
  (parse-surge-rules '("# comment" "DOMAIN,api.openai.com,AI"
                                   "DOMAIN-SUFFIX,example.com,Proxy"
                                   "IP-CIDR,10.0.0.0/8,DIRECT,no-resolve"
                                   "FINAL,REJECT")
                     "test.list"))

(check-equal? (length rules) 4)
(check-equal? (relay-rule-index (car rules)) 2)

(define-values (domain-match domain-attempts)
  (evaluate-rules rules (connection-flow "api.openai.com" #f 443 'tcp "browser")))
(check-equal? (relay-rule-policy domain-match) "AI")
(check-equal? (length domain-attempts) 1)

(define-values (suffix-match suffix-attempts)
  (evaluate-rules rules (connection-flow "cdn.example.com" #f 443 'tcp #f)))
(check-equal? (relay-rule-policy suffix-match) "Proxy")

(define-values (cidr-match cidr-attempts)
  (evaluate-rules rules (connection-flow #f "10.42.0.7" 53 'udp #f)))
(check-equal? (relay-rule-policy cidr-match) "DIRECT")

(define-values (final-match final-attempts)
  (evaluate-rules rules (connection-flow "elsewhere.invalid" #f 443 'tcp #f)))
(check-equal? (relay-rule-policy final-match) "REJECT")
