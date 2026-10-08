#lang racket/base

(require racket/match)

(provide (struct-out config-patch)
         (struct-out patch-operation)
         validate-config-patch)

(struct config-patch (schema-version rationale operations) #:transparent)
(struct patch-operation (kind target expected replacement) #:transparent)

(define allowed-kinds '(set-policy-selection add-rule remove-rule replace-rule))

(define (validate-config-patch patch)
  (unless (config-patch? patch)
    (raise-argument-error 'validate-config-patch "config-patch?" patch))
  (unless (= (config-patch-schema-version patch) 1)
    (raise-arguments-error 'validate-config-patch
                           "unsupported patch schema"
                           "schema-version"
                           (config-patch-schema-version patch)))
  (for ([operation (in-list (config-patch-operations patch))])
    (unless (patch-operation? operation)
      (raise-argument-error 'validate-config-patch "patch-operation?" operation))
    (unless (memq (patch-operation-kind operation) allowed-kinds)
      (raise-arguments-error 'validate-config-patch
                             "unsupported operation"
                             "kind"
                             (patch-operation-kind operation)))
    (unless (patch-operation-expected operation)
      (raise-arguments-error 'validate-config-patch
                             "every AI patch needs an optimistic-concurrency precondition"
                             "target"
                             (patch-operation-target operation))))
  patch)
