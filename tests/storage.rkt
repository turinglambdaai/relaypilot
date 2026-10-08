#lang racket/base

(require rackunit
         racket/file
         "../app/core/model.rkt"
         "../app/core/storage/local-file.rkt"
         "support.rkt")

(define root (make-temporary-file "relaypilot-storage-~a" 'directory))
(dynamic-wind void
              (lambda ()
                (define target (build-path root "profile.json"))
                (write-profile-file! target sample-profile)
                (define loaded (read-profile-file target))
                (check-equal? (relay-profile-id loaded) (relay-profile-id sample-profile))
                (check-false (file-exists? (build-path root "relaypilot.tmp"))))
              (lambda () (delete-directory/files root)))
