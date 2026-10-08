#lang racket/base

(require json
         rackunit
         "../app/core/engines/interface.rkt"
         "../app/core/engines/xray.rkt"
         "../app/core/model.rkt"
         "support.rkt")

(define first (engine-compile xray-engine-adapter sample-profile))
(define second (engine-compile xray-engine-adapter sample-profile))
(check-equal? (compiled-engine-config-bytes first) (compiled-engine-config-bytes second))
(check-equal? (compiled-engine-config-digest first) (compiled-engine-config-digest second))
(check-equal? (string-length (compiled-engine-config-digest first)) 64)

(define generated (bytes->jsexpr (compiled-engine-config-bytes first)))
(check-equal? (hash-ref (hash-ref generated 'routing) 'domainStrategy) "AsIs")
(define routes (hash-ref (hash-ref generated 'routing) 'rules))
(check-equal? (hash-ref (car routes) 'ruleTag) "relaypilot:1")
(check-equal? (hash-ref (car routes) 'outboundTag) "us-reality-01")
(define vless (car (hash-ref generated 'outbounds)))
(check-equal? (hash-ref vless 'protocol) "vless")
(check-equal? (hash-ref (hash-ref vless 'settings) 'address) "proxy.example.invalid")
(check-equal? (hash-ref (hash-ref vless 'streamSettings) 'security) "reality")
