#lang racket/base

(require racket/string
         "../diagnostics/bundle.rkt")

(provide redact-diagnostic-bundle)

(define (redact-value value secrets)
  (cond
    [(string? value)
     (for/fold ([result value])
               ([secret (in-list secrets)]
                #:when (and (string? secret) (positive? (string-length secret))))
       (string-replace result secret "[REDACTED]"))]
    [(hash? value)
     (for/hasheq ([(key nested) (in-hash value)])
       (values key (redact-value nested secrets)))]
    [(list? value) (map (lambda (nested) (redact-value nested secrets)) value)]
    [else value]))

(define (redact-diagnostic-bundle bundle secrets)
  (diagnostic-bundle (diagnostic-bundle-schema-version bundle)
                     (diagnostic-bundle-trace-id bundle)
                     (diagnostic-bundle-profile-id bundle)
                     (redact-value (diagnostic-bundle-connection bundle) secrets)
                     (redact-value (diagnostic-bundle-decision bundle) secrets)
                     (redact-value (diagnostic-bundle-engine-events bundle) secrets)
                     (redact-value (diagnostic-bundle-comparable-failures bundle) secrets)))
