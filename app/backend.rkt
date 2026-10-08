#lang racket/base

(require rivet/backend
         (prefix-in core: "core/model.rkt")
         "core/decision.rkt"
         "core/engines/interface.rkt"
         "core/engines/xray.rkt"
         "core/profile/json.rkt")

(provide start)

(define-record RouteDecision
               ([traceId : String] [ruleIndex : Int64]
                                   [policy : String]
                                   [outbound : String]
                                   [steps : (List String)]
                                   [warnings : (List String)]))

(define-record CompiledEngineConfig
               ([adapter : String] [adapterVersion : String] [sha256 : String] [json : String]))

(define-rpc (explain-route [profileJson : String]
                           [domain : String]
                           [ip : String]
                           [port : Int64]
                           [network : String]
                           :
                           RouteDecision)
            (define profile (read-relay-profile profileJson))
            (define trace
              (decide-flow profile
                           (core:connection-flow (if (string=? domain "") #f domain)
                                                 (if (string=? ip "") #f ip)
                                                 port
                                                 (string->symbol network)
                                                 #f)))
            (RouteDecision (core:decision-trace-trace-id trace)
                           (core:decision-trace-rule-index trace)
                           (core:decision-trace-requested-policy trace)
                           (core:decision-trace-selected-outbound trace)
                           (core:decision-trace-steps trace)
                           (core:decision-trace-warnings trace)))

(define-rpc (compile-engine-config [profileJson : String] : CompiledEngineConfig)
            (define compiled (engine-compile xray-engine-adapter (read-relay-profile profileJson)))
            (CompiledEngineConfig (symbol->string (core:compiled-engine-config-adapter compiled))
                                  (core:compiled-engine-config-adapter-version compiled)
                                  (core:compiled-engine-config-digest compiled)
                                  (bytes->string/utf-8 (core:compiled-engine-config-bytes compiled))))

(define (start in-fd out-fd)
  (serve-fds in-fd out-fd))

(module+ test-support
  (provide RouteDecision
           CompiledEngineConfig
           explain-route
           compile-engine-config))
