#lang racket/base

(require racket/file
         racket/runtime-path
         "../app/core/profile/json.rkt")

(provide sample-profile
         sample-profile-json)

(define-runtime-path sample-path "../examples/relay-profile.json")

(define sample-profile-json (file->string sample-path))
(define sample-profile (read-relay-profile (string->path (path->string sample-path))))
