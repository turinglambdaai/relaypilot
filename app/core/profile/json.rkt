#lang racket/base

(require json
         racket/list
         racket/string
         "../model.rkt"
         "../rules/surge.rkt")

(provide read-relay-profile
         parse-relay-profile
         relay-profile->jsexpr)

(define missing (gensym 'missing))

(define (hget table key [default missing])
  (define value
    (cond
      [(hash-has-key? table key) (hash-ref table key)]
      [(and (symbol? key) (hash-has-key? table (symbol->string key)))
       (hash-ref table (symbol->string key))]
      [else missing]))
  (cond
    [(not (eq? value missing)) value]
    [(not (eq? default missing)) default]
    [else (raise-arguments-error 'parse-relay-profile "missing required field" "field" key)]))

(define (->symbol value who)
  (cond
    [(symbol? value) value]
    [(string? value) (string->symbol (string-downcase value))]
    [else (raise-argument-error who "(or/c symbol? string?)" value)]))

(define (parse-node value)
  (unless (hash? value)
    (raise-argument-error 'parse-node "hash?" value))
  (proxy-node (hget value 'id)
              (hget value 'name (hget value 'id))
              (->symbol (hget value 'protocol) 'parse-node)
              (hget value 'address)
              (hget value 'port)
              (hget value 'credentials (hasheq))
              (hget value 'transport (hasheq))
              (hget value 'tls (hasheq))))

(define (parse-policy value)
  (unless (hash? value)
    (raise-argument-error 'parse-policy "hash?" value))
  (define selected (hget value 'selected #f))
  (policy-group (hget value 'id)
                (hget value 'name (hget value 'id))
                (->symbol (hget value 'kind "select") 'parse-policy)
                (hget value 'members)
                (if (eq? selected 'null) #f selected)))

(define (parse-relay-profile value)
  (unless (hash? value)
    (raise-argument-error 'parse-relay-profile "hash?" value))
  (define profile-id (hget value 'id))
  (validate-profile (relay-profile (hget value 'schemaVersion 1)
                                   profile-id
                                   (hget value 'name profile-id)
                                   (map parse-node (hget value 'nodes '()))
                                   (map parse-policy (hget value 'policies '()))
                                   (parse-surge-rules (hget value 'rules '())
                                                      (string-append "profile:" profile-id))
                                   (hget value 'dns (hasheq)))))

(define (read-relay-profile source)
  (define value
    (cond
      [(input-port? source) (read-json source)]
      [(bytes? source) (bytes->jsexpr source)]
      [(path? source) (call-with-input-file source read-json)]
      [(string? source) (string->jsexpr source)]
      [else
       (raise-argument-error 'read-relay-profile "(or/c input-port? bytes? path? string?)" source)]))
  (parse-relay-profile value))

(define (node->jsexpr node)
  (hasheq 'id
          (proxy-node-id node)
          'name
          (proxy-node-name node)
          'protocol
          (symbol->string (proxy-node-protocol node))
          'address
          (proxy-node-address node)
          'port
          (proxy-node-port node)
          'credentials
          (proxy-node-credentials node)
          'transport
          (proxy-node-transport node)
          'tls
          (proxy-node-tls node)))

(define (policy->jsexpr policy)
  (hasheq 'id
          (policy-group-id policy)
          'name
          (policy-group-name policy)
          'kind
          (symbol->string (policy-group-kind policy))
          'members
          (policy-group-members policy)
          'selected
          (or (policy-group-selected policy) 'null)))

(define (rule->string rule)
  (define external-kind
    (case (relay-rule-kind rule)
      [(domain) "DOMAIN"]
      [(domain-suffix) "DOMAIN-SUFFIX"]
      [(ip-cidr) "IP-CIDR"]
      [(ip-cidr6) "IP-CIDR6"]
      [(geoip) "GEOIP"]
      [(match) "FINAL"]
      [else (string-upcase (symbol->string (relay-rule-kind rule)))]))
  (string-join (append (if (eq? (relay-rule-kind rule) 'match)
                           (list external-kind (relay-rule-policy rule))
                           (list external-kind (relay-rule-value rule) (relay-rule-policy rule)))
                       (relay-rule-options rule))
               ","))

(define (relay-profile->jsexpr profile)
  (hasheq 'schemaVersion
          (relay-profile-schema-version profile)
          'id
          (relay-profile-id profile)
          'name
          (relay-profile-name profile)
          'nodes
          (map node->jsexpr (relay-profile-nodes profile))
          'policies
          (map policy->jsexpr (relay-profile-policies profile))
          'rules
          (map rule->string (relay-profile-rules profile))
          'dns
          (relay-profile-dns profile)))
