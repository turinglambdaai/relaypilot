#lang racket/base

(provide (struct-out engine-adapter)
         engine-compile)

;; An adapter owns translation and lifecycle boundaries. It never becomes the
;; canonical Relay Profile or the source of routing explanations.
(struct engine-adapter (id version compile capabilities) #:transparent)

(define (engine-compile adapter profile)
  ((engine-adapter-compile adapter) profile))
