#lang racket/base

(provide (struct-out relay-profile)
         (struct-out proxy-node)
         (struct-out policy-group)
         (struct-out relay-rule)
         (struct-out connection-flow)
         (struct-out decision-trace)
         (struct-out engine-plan)
         (struct-out compiled-engine-config)
         validate-profile)

(struct relay-profile (schema-version id name nodes policies rules dns) #:transparent)
(struct proxy-node (id name protocol address port credentials transport tls) #:transparent)
(struct policy-group (id name kind members selected) #:transparent)
(struct relay-rule (index kind value policy options source) #:transparent)
(struct connection-flow (domain ip port network source-app) #:transparent)
(struct decision-trace
        (trace-id profile-id
                  flow
                  rule-index
                  rule-source
                  matched-kind
                  matched-value
                  requested-policy
                  selected-outbound
                  steps
                  warnings)
  #:transparent)
(struct engine-plan (profile-id outbounds routing source-map) #:transparent)
(struct compiled-engine-config (adapter adapter-version bytes digest metadata) #:transparent)

(define (non-empty-string? value)
  (and (string? value) (positive? (string-length value))))

(define (duplicates items)
  (for/fold ([seen '()]
             [dupes '()]
             #:result (reverse dupes))
            ([value (in-list items)])
    (if (member value seen)
        (values seen
                (if (member value dupes)
                    dupes
                    (cons value dupes)))
        (values (cons value seen) dupes))))

(define (validate-profile profile)
  (unless (relay-profile? profile)
    (raise-argument-error 'validate-profile "relay-profile?" profile))
  (unless (= (relay-profile-schema-version profile) 1)
    (raise-arguments-error 'validate-profile
                           "unsupported Relay Profile schema"
                           "schema-version"
                           (relay-profile-schema-version profile)))
  (unless (non-empty-string? (relay-profile-id profile))
    (raise-arguments-error 'validate-profile "profile id must not be empty"))
  (define node-ids (map proxy-node-id (relay-profile-nodes profile)))
  (define policy-ids (map policy-group-id (relay-profile-policies profile)))
  (define duplicate-node-ids (duplicates node-ids))
  (define duplicate-policy-ids (duplicates policy-ids))
  (unless (null? duplicate-node-ids)
    (raise-arguments-error 'validate-profile "duplicate node ids" "ids" duplicate-node-ids))
  (unless (null? duplicate-policy-ids)
    (raise-arguments-error 'validate-profile "duplicate policy ids" "ids" duplicate-policy-ids))
  (for ([node (in-list (relay-profile-nodes profile))])
    (unless (and (non-empty-string? (proxy-node-id node))
                 (non-empty-string? (proxy-node-address node))
                 (exact-integer? (proxy-node-port node))
                 (<= 1 (proxy-node-port node) 65535))
      (raise-arguments-error 'validate-profile "invalid proxy node" "node" node)))
  (define known-targets (append node-ids policy-ids '("DIRECT" "REJECT")))
  (for ([group (in-list (relay-profile-policies profile))])
    (unless (memq (policy-group-kind group) '(select fallback))
      (raise-arguments-error 'validate-profile
                             "unsupported policy group kind"
                             "group"
                             (policy-group-id group)
                             "kind"
                             (policy-group-kind group)))
    (when (null? (policy-group-members group))
      (raise-arguments-error 'validate-profile
                             "policy group must have members"
                             "group"
                             (policy-group-id group)))
    (for ([member-id (in-list (policy-group-members group))])
      (unless (member member-id known-targets)
        (raise-arguments-error 'validate-profile
                               "unknown policy member"
                               "group"
                               (policy-group-id group)
                               "member"
                               member-id)))
    (when (and (policy-group-selected group)
               (not (member (policy-group-selected group) (policy-group-members group))))
      (raise-arguments-error 'validate-profile
                             "selected member is not in group"
                             "group"
                             (policy-group-id group)
                             "selected"
                             (policy-group-selected group))))
  (for ([rule (in-list (relay-profile-rules profile))])
    (unless (member (relay-rule-policy rule) known-targets)
      (raise-arguments-error 'validate-profile
                             "rule references unknown policy"
                             "rule"
                             (relay-rule-index rule)
                             "policy"
                             (relay-rule-policy rule))))
  profile)
