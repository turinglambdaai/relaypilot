#lang racket/base

(require racket/list
         racket/string
         "../json.rkt"
         "../model.rkt"
         "interface.rkt"
         "plan.rkt")

(provide xray-engine-adapter
         compile-xray-config
         xray-config-jsexpr)

(define adapter-version "xray-json-v1")
(define hex-digits "0123456789abcdef")

(define (bytes->hex value)
  (define out (open-output-string))
  (for ([byte (in-bytes value)])
    (write-char (string-ref hex-digits (arithmetic-shift byte -4)) out)
    (write-char (string-ref hex-digits (bitwise-and byte #x0f)) out))
  (get-output-string out))

(define missing (gensym 'missing))

(define (hget table key [default missing])
  (define alt (and (symbol? key) (symbol->string key)))
  (cond
    [(hash-has-key? table key) (hash-ref table key)]
    [(and alt (hash-has-key? table alt)) (hash-ref table alt)]
    [(not (eq? default missing)) default]
    [else (raise-arguments-error 'compile-xray-config "missing node field" "field" key)]))

(define (non-empty value)
  (and (string? value) (not (string=? value ""))))

(define (compact-hash entries)
  (for/hasheq ([entry (in-list entries)]
               #:when (cdr entry))
    (values (car entry) (cdr entry))))

(define (stream-settings node)
  (define transport (proxy-node-transport node))
  (define tls (proxy-node-tls node))
  (define requested-network (string-downcase (hget transport 'network "raw")))
  (define network (if (string=? requested-network "tcp") "raw" requested-network))
  (define security (string-downcase (hget tls 'security "none")))
  (define base (hasheq 'network network 'security security))
  (cond
    [(string=? security "reality")
     (hash-set base
               'realitySettings
               (compact-hash (list (cons 'serverName (hget tls 'serverName))
                                   (cons 'fingerprint (hget tls 'fingerprint "chrome"))
                                   (cons 'password
                                         (or (hget tls 'password #f) (hget tls 'publicKey #f)))
                                   (cons 'shortId (hget tls 'shortId ""))
                                   (cons 'spiderX (hget tls 'spiderX "/")))))]
    [(string=? security "tls")
     (hash-set base
               'tlsSettings
               (compact-hash (list (cons 'serverName (hget tls 'serverName #f))
                                   (cons 'fingerprint (hget tls 'fingerprint #f)))))]
    [(string=? security "none") base]
    [else
     (raise-arguments-error 'compile-xray-config
                            "unsupported transport security"
                            "node"
                            (proxy-node-id node)
                            "security"
                            security)]))

(define (vless-outbound node)
  (define credentials (proxy-node-credentials node))
  (hasheq 'tag
          (proxy-node-id node)
          'protocol
          "vless"
          'settings
          (compact-hash (list (cons 'address (proxy-node-address node))
                              (cons 'port (proxy-node-port node))
                              (cons 'id (hget credentials 'id))
                              (cons 'encryption (hget credentials 'encryption "none"))
                              (cons 'flow (hget credentials 'flow #f))))
          'streamSettings
          (stream-settings node)))

(define (node->outbound node)
  (case (proxy-node-protocol node)
    [(vless) (vless-outbound node)]
    [else
     (raise-arguments-error 'compile-xray-config
                            "protocol is not implemented by the first Xray adapter slice"
                            "node"
                            (proxy-node-id node)
                            "protocol"
                            (proxy-node-protocol node))]))

(define (routing-condition rule)
  (case (relay-rule-kind rule)
    [(domain) (hasheq 'domain (list (string-append "full:" (relay-rule-value rule))))]
    [(domain-suffix) (hasheq 'domain (list (string-append "domain:" (relay-rule-value rule))))]
    [(ip-cidr) (hasheq 'ip (list (relay-rule-value rule)))]
    [(match) (hasheq 'network "tcp,udp")]
    [else
     (raise-arguments-error 'compile-xray-config
                            "rule parses but cannot yet be executed with deterministic local parity"
                            "rule"
                            (relay-rule-index rule)
                            "kind"
                            (relay-rule-kind rule))]))

(define (route-entry->xray entry)
  (define rule (hash-ref entry 'rule))
  (hash-set* (routing-condition rule)
             'type
             "field"
             'ruleTag
             (format "relaypilot:~a" (relay-rule-index rule))
             'outboundTag
             (hash-ref entry 'outbound)))

(define (xray-config-jsexpr profile)
  (define plan (profile->engine-plan profile))
  (hasheq 'log
          (hasheq 'loglevel "warning")
          'inbounds
          (list (hasheq 'tag
                        "relaypilot.local"
                        'listen
                        "127.0.0.1"
                        'port
                        1080
                        'protocol
                        "socks"
                        'settings
                        (hasheq 'auth "noauth" 'udp #t)
                        'sniffing
                        (hasheq 'enabled #t 'destOverride (list "http" "tls" "quic") 'routeOnly #t)))
          'outbounds
          (append (map node->outbound (engine-plan-outbounds plan))
                  (list (hasheq 'tag "relaypilot.direct" 'protocol "freedom")
                        (hasheq 'tag "relaypilot.block" 'protocol "blackhole")))
          'routing
          (hasheq 'domainStrategy "AsIs" 'rules (map route-entry->xray (engine-plan-routing plan)))))

(define (compile-xray-config profile)
  (define plan (profile->engine-plan profile))
  (define bytes (jsexpr->canonical-bytes (xray-config-jsexpr profile)))
  (compiled-engine-config 'xray
                          adapter-version
                          bytes
                          (bytes->hex (sha256-bytes bytes))
                          (hasheq 'profile-id
                                  (relay-profile-id profile)
                                  'source-map
                                  (engine-plan-source-map plan)
                                  'execution-boundary
                                  "not-started"
                                  'xray-config-contract
                                  "official docs snapshot 2026-10-08")))

(define xray-engine-adapter
  (engine-adapter 'xray
                  adapter-version
                  compile-xray-config
                  '(vless reality socks-inbound deterministic-source-map)))
