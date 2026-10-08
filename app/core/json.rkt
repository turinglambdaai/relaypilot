#lang racket/base

(require json
         racket/list
         racket/port
         racket/string)

(provide jsexpr->canonical-bytes)

(define (key->string key)
  (cond
    [(symbol? key) (symbol->string key)]
    [(string? key) key]
    [else (error 'jsexpr->canonical-bytes "invalid JSON object key: ~e" key)]))

(define (write-canonical value out)
  (cond
    [(hash? value)
     (display "{" out)
     (define entries
       (sort (hash->list value) string<? #:key (lambda (entry) (key->string (car entry)))))
     (for ([entry (in-list entries)]
           [index (in-naturals)])
       (unless (zero? index)
         (display "," out))
       (write-json (key->string (car entry)) out)
       (display ":" out)
       (write-canonical (cdr entry) out))
     (display "}" out)]
    [(list? value)
     (display "[" out)
     (for ([item (in-list value)]
           [index (in-naturals)])
       (unless (zero? index)
         (display "," out))
       (write-canonical item out))
     (display "]" out)]
    [else (write-json value out)]))

(define (jsexpr->canonical-bytes value)
  (call-with-output-bytes (lambda (out) (write-canonical value out))))
