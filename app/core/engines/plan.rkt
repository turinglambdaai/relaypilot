#lang racket/base

(require racket/list
         "../model.rkt"
         "../policy/resolve.rkt")

(provide profile->engine-plan)

(define (profile->engine-plan profile)
  (validate-profile profile)
  (define routing
    (for/list ([rule (in-list (relay-profile-rules profile))])
      (define-values (outbound steps) (resolve-policy profile (relay-rule-policy rule)))
      (hasheq 'rule rule 'outbound outbound 'resolution-steps steps)))
  (define source-map
    (for/hasheq ([entry (in-list routing)])
      (define rule (hash-ref entry 'rule))
      (values (format "relaypilot:~a" (relay-rule-index rule))
              (hasheq 'source
                      (relay-rule-source rule)
                      'line
                      (relay-rule-index rule)
                      'kind
                      (symbol->string (relay-rule-kind rule))
                      'value
                      (relay-rule-value rule)
                      'policy
                      (relay-rule-policy rule)))))
  (engine-plan (relay-profile-id profile) (relay-profile-nodes profile) routing source-map))
