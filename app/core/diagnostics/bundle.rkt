#lang racket/base

(require "../model.rkt")

(provide (struct-out diagnostic-bundle)
         trace->diagnostic-bundle)

(struct diagnostic-bundle
        (schema-version trace-id profile-id connection decision engine-events comparable-failures)
  #:transparent)

(define (trace->diagnostic-bundle trace
                                  #:engine-events [events '()]
                                  #:comparable-failures [failures '()])
  (diagnostic-bundle 1
                     (decision-trace-trace-id trace)
                     (decision-trace-profile-id trace)
                     (hasheq 'domain
                             (connection-flow-domain (decision-trace-flow trace))
                             'ip
                             (connection-flow-ip (decision-trace-flow trace))
                             'port
                             (connection-flow-port (decision-trace-flow trace))
                             'network
                             (connection-flow-network (decision-trace-flow trace))
                             'source-app
                             (connection-flow-source-app (decision-trace-flow trace)))
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
