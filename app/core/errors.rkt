#lang racket/base

(provide (struct-out exn:fail:relaypilot)
         raise-relaypilot
         relaypilot-error?)

;; kind is one of 'validation, 'usage, 'engine. exit-code mirrors
;; docs/CLI-SPEC.md so the CLI and native adapters do not re-invent error
;; classification on each platform.
(struct exn:fail:relaypilot exn:fail (kind exit-code) #:transparent)

(define (raise-relaypilot kind exit-code message)
  (raise (exn:fail:relaypilot message (current-continuation-marks) kind exit-code)))

(define relaypilot-error? exn:fail:relaypilot?)
