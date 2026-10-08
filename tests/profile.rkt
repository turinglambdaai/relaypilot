#lang racket/base

(require rackunit
         "../app/core/model.rkt"
         "../app/core/profile/json.rkt"
         "support.rkt")

(check-equal? (relay-profile-schema-version sample-profile) 1)
(check-equal? (relay-profile-id sample-profile) "daily-network")
(check-equal? (length (relay-profile-nodes sample-profile)) 1)
(check-equal? (length (relay-profile-rules sample-profile)) 4)
(check-equal? (relay-profile-id (parse-relay-profile (relay-profile->jsexpr sample-profile)))
              "daily-network")

(check-exn
 exn:fail?
 (lambda ()
   (read-relay-profile
    "{\"schemaVersion\":1,\"id\":\"bad\",\"nodes\":[],\"policies\":[],\"rules\":[\"FINAL,MISSING\"]}")))
