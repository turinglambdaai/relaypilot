#lang racket/base

(require rackunit
         "../app/core/ai/patch.rkt"
         "../app/core/ai/redact.rkt"
         "../app/core/decision.rkt"
         "../app/core/diagnostics/bundle.rkt"
         "../app/core/model.rkt"
         "support.rkt")

(define trace
  (decide-flow sample-profile (connection-flow "private.example.com" "203.0.113.9" 443 'tcp #f)))
(define bundle (trace->diagnostic-bundle trace))
(define redacted (redact-diagnostic-bundle bundle '("private.example.com" "203.0.113.9")))
(check-equal? (hash-ref (diagnostic-bundle-connection redacted) 'domain) "[REDACTED]")
(check-equal? (hash-ref (diagnostic-bundle-connection redacted) 'ip) "[REDACTED]")

(check-not-exn
 (lambda ()
   (validate-config-patch
    (config-patch 1
                  "Prefer the healthy node"
                  (list (patch-operation 'set-policy-selection "AI" "us-reality-01" "DIRECT"))))))

(check-exn exn:fail?
           (lambda ()
             (validate-config-patch
              (config-patch 1
                            "Unsafe blind write"
                            (list (patch-operation 'set-policy-selection "AI" #f "DIRECT"))))))
