#lang racket/base

(require racket/list
         racket/string
         "../model.rkt")

(provide parse-surge-rule
         parse-surge-rules)

(define supported-kinds
  (hash "DOMAIN"
        'domain
        "DOMAIN-SUFFIX"
        'domain-suffix
        "IP-CIDR"
        'ip-cidr
        "IP-CIDR6"
        'ip-cidr6
        "GEOIP"
        'geoip
        "FINAL"
        'match
        "MATCH"
        'match))

(define (comment-or-empty? line)
  (define clean (string-trim line))
  (or (string=? clean "")
      (string-prefix? clean "#")
      (string-prefix? clean ";")
      (string-prefix? clean "//")))

(define (parse-surge-rule line index [source "inline"])
  (cond
    [(comment-or-empty? line) #f]
    [else
     (define parts (map string-trim (string-split line ",")))
     (when (< (length parts) 2)
       (raise-arguments-error 'parse-surge-rule
                              "rule needs at least a kind and policy"
                              "source"
                              source
                              "line"
                              index
                              "text"
                              line))
     (define external-kind (string-upcase (car parts)))
     (define kind
       (hash-ref supported-kinds
                 external-kind
                 (lambda ()
                   (raise-arguments-error 'parse-surge-rule
                                          "unsupported Surge rule kind"
                                          "source"
                                          source
                                          "line"
                                          index
                                          "kind"
                                          external-kind))))
     (define match-rule? (eq? kind 'match))
     (define minimum-length (if match-rule? 2 3))
     (when (< (length parts) minimum-length)
       (raise-arguments-error 'parse-surge-rule
                              "rule has too few fields"
                              "source"
                              source
                              "line"
                              index
                              "text"
                              line))
     (define value
       (if match-rule?
           "*"
           (list-ref parts 1)))
     (define policy
       (if match-rule?
           (list-ref parts 1)
           (list-ref parts 2)))
     (define options (drop parts minimum-length))
     (relay-rule index kind value policy options source)]))

(define (parse-surge-rules value [source "inline"])
  (define lines
    (cond
      [(string? value) (string-split value "\n")]
      [(list? value) value]
      [else (raise-argument-error 'parse-surge-rules "(or/c string? (listof string?))" value)]))
  (filter values
          (for/list ([line (in-list lines)]
                     [index (in-naturals 1)])
            (parse-surge-rule line index source))))
