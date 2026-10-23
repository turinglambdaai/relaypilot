#lang racket/base

(require "../model.rkt")

(provide (struct-out diagnostic-bundle)
         trace->diagnostic-bundle)

(struct diagnostic-bundle
        (schema-version trace-id profile-id connection decision engine-events comparable-failures)
  #:transparent)

;; Absent facts are JSON null, never inferred stand-ins (ARCHITECTURE.md).
(define (absent value)
  (or value 'null))

(define (trace->diagnostic-bundle trace
                                  #:engine-events [events '()]
                                  #:comparable-failures [failures '()])
  (define flow (decision-trace-flow trace))
  (diagnostic-bundle 1
                     (decision-trace-trace-id trace)
                     (decision-trace-profile-id trace)
                     (hasheq 'domain
                             (absent (connection-flow-domain flow))
                             'ip
                             (absent (connection-flow-ip flow))
                             'port
                             (connection-flow-port flow)
                             'network
                             (and (connection-flow-network flow)
                                  (symbol->string (connection-flow-network flow)))
                             'source-app
                             (absent (connection-flow-source-app flow)))
                     (hasheq 'rule-index
                             (decision-trace-rule-index trace)
                             'rule-source
                             (decision-trace-rule-source trace)
                             'policy
                             (decision-trace-requested-policy trace)
                             'outbound
                             (decision-trace-selected-outbound trace)
                             'steps
                             (decision-trace-steps trace)
                             'warnings
                             (decision-trace-warnings trace))
                     events
                     failures))
