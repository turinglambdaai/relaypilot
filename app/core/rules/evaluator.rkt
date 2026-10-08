#lang racket/base

(require racket/list
         racket/match
         racket/string
         "../model.rkt")

(provide evaluate-rules)

(define (normalize-domain domain)
  (and domain
       (let ([lower (string-downcase (string-trim domain))])
         (if (string-suffix? lower ".")
             (substring lower 0 (sub1 (string-length lower)))
             lower))))

(define (domain-suffix-match? domain suffix)
  (define clean-domain (normalize-domain domain))
  (define clean-suffix (normalize-domain suffix))
  (and clean-domain
       clean-suffix
       (or (string=? clean-domain clean-suffix)
           (string-suffix? clean-domain (string-append "." clean-suffix)))))

(define (ipv4->integer value)
  (define parts (string-split value "."))
  (and (= (length parts) 4)
       (for/and ([part (in-list parts)])
         (define number (string->number part))
         (and (exact-integer? number) (<= 0 number 255)))
       (for/fold ([result 0]) ([part (in-list parts)])
         (+ (arithmetic-shift result 8) (string->number part)))))

(define (ipv4-cidr-match? ip cidr)
  (match (string-split cidr "/")
    [(list network prefix-text)
     (define ip-number (ipv4->integer ip))
     (define network-number (ipv4->integer network))
     (define prefix (string->number prefix-text))
     (and ip-number
          network-number
          (exact-integer? prefix)
          (<= 0 prefix 32)
          (let ([mask (if (zero? prefix)
                          0
                          (bitwise-and #xffffffff (arithmetic-shift #xffffffff (- 32 prefix))))])
            (= (bitwise-and ip-number mask) (bitwise-and network-number mask))))]
    [_ #f]))

(define (rule-match-result rule flow)
  (case (relay-rule-kind rule)
    [(domain)
     (values (and (connection-flow-domain flow)
                  (string-ci=? (normalize-domain (connection-flow-domain flow))
                               (normalize-domain (relay-rule-value rule))))
             "exact domain")]
    [(domain-suffix)
     (values (domain-suffix-match? (connection-flow-domain flow) (relay-rule-value rule))
             "domain suffix")]
    [(ip-cidr)
     (values (and (connection-flow-ip flow)
                  (ipv4-cidr-match? (connection-flow-ip flow) (relay-rule-value rule)))
             "IPv4 CIDR")]
    [(match) (values #t "final fallback")]
    [(ip-cidr6) (values #f "IPv6 CIDR deferred to engine capability")]
    [(geoip) (values #f "GeoIP database lookup not installed")]
    [else (values #f "unsupported rule")]))

(define (evaluate-rules rules flow)
  (let loop ([remaining rules]
             [attempts '()])
    (cond
      [(null? remaining) (values #f (reverse attempts))]
      [else
       (define rule (car remaining))
       (define-values (matched? reason) (rule-match-result rule flow))
       (define attempt
         (hasheq 'rule-index
                 (relay-rule-index rule)
                 'kind
                 (symbol->string (relay-rule-kind rule))
                 'value
                 (relay-rule-value rule)
                 'matched
                 matched?
                 'reason
                 reason))
       (if matched?
           (values rule (reverse (cons attempt attempts)))
           (loop (cdr remaining) (cons attempt attempts)))])))
