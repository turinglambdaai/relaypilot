#lang racket/base

(require racket/cmdline
         "../app/core/engines/xray.rkt"
         "../app/core/model.rkt"
         "../app/core/profile/json.rkt")

(define input-path #f)
(define output-path #f)

(command-line #:program "compile-profile.rkt"
              #:args (input output)
              (set! input-path input)
              (set! output-path output))

(define compiled (compile-xray-config (read-relay-profile (string->path input-path))))

(call-with-output-file output-path
                       (lambda (out) (void (write-bytes (compiled-engine-config-bytes compiled) out)))
                       #:exists 'truncate/replace)

(displayln (compiled-engine-config-digest compiled))
