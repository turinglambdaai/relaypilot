#lang racket/base

(require racket/string
         "model.rkt"
         "policy/resolve.rkt"
         "rules/evaluator.rkt")

(provide decide-flow)

(define hex-digits "0123456789abcdef")

(define (bytes->hex value)
  (define out (open-output-string))
  (for ([byte (in-bytes value)])
    (write-char (string-ref hex-digits (arithmetic-shift byte -4)) out)
    (write-char (string-ref hex-digits (bitwise-and byte #x0f)) out))
  (get-output-string out))

(define (trace-id profile flow rule outbound)
  (substring (bytes->hex (sha256-bytes (string->bytes/utf-8 (format "~s"
                                                                    (list (relay-profile-id profile)
                                                                          flow
                                                                          (relay-rule-index rule)
                                                                          outbound)))))
             0
             16))

(define (deferred-rule-warnings attempts)
  (for/list ([attempt (in-list attempts)]
             #:when (member (hash-ref attempt 'kind) '("geoip" "ip-cidr6")))
    (format "Rule ~a was not evaluated: ~a"
            (hash-ref attempt 'rule-index)
            (hash-ref attempt 'reason))))

(define (decide-flow profile flow)
  (validate-profile profile)
  (define-values (matched attempts) (evaluate-rules (relay-profile-rules profile) flow))
  (unless matched
    (raise-arguments-error 'decide-flow
                           "no rule matched; add FINAL or MATCH"
                           "profile"
                           (relay-profile-id profile)
                           "flow"
                           flow))
  (define-values (outbound policy-steps) (resolve-policy profile (relay-rule-policy matched)))
  (decision-trace (trace-id profile flow matched outbound)
                  (relay-profile-id profile)
                  flow
                  (relay-rule-index matched)
                  (relay-rule-source matched)
                  (relay-rule-kind matched)
                  (relay-rule-value matched)
                  (relay-rule-policy matched)
                  outbound
                  (append (list (format "rule ~a matched ~a ~a"
                                        (relay-rule-index matched)
                                        (relay-rule-kind matched)
                                        (relay-rule-value matched)))
                          policy-steps)
                  (deferred-rule-warnings attempts)))
