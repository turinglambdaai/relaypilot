#lang racket/base

(require racket/file
         racket/path
         "../json.rkt"
         "../profile/json.rkt"
         "interface.rkt")

(provide make-local-folder-storage
         read-profile-file
         write-profile-file!)

(define (profile-path root id)
  (build-path root (string-append id ".relayprofile.json")))

(define (read-profile-file path)
  (call-with-input-file path read-relay-profile))

(define (write-profile-file! path profile)
  (define parent (or (path-only path) (current-directory)))
  (make-directory* parent)
  (define temporary (make-temporary-file "relaypilot-~a.tmp" #f parent))
  (dynamic-wind void
                (lambda ()
                  (call-with-output-file
                   temporary
                   (lambda (out)
                     (write-bytes (jsexpr->canonical-bytes (relay-profile->jsexpr profile)) out))
                   #:exists 'truncate/replace)
                  (rename-file-or-directory temporary path #t))
                (lambda ()
                  (when (file-exists? temporary)
                    (delete-file temporary)))))

(define (make-local-folder-storage root)
  (storage-provider 'local-folder
                    (lambda (id) (read-profile-file (profile-path root id)))
                    (lambda (id profile) (write-profile-file! (profile-path root id) profile))
                    (lambda ()
                      (for/list ([path (in-directory root)]
                                 #:when (regexp-match? #rx"[.]relayprofile[.]json$"
                                                       (path->string path)))
                        path))
                    #f
                    '(atomic-write user-owned-folder no-account)))
