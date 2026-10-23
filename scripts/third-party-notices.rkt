#lang racket/base

;; Emits the third-party NOTICE text an application bundle must ship when it
;; redistributes the pinned engine binary (docs/third-party.md). The pin is
;; duplicated here on purpose: this file is the source-offer artifact that
;; travels with a bundle, so it stays readable without the repo.

(require racket/cmdline
         racket/file
         racket/list
         racket/runtime-path
         racket/string)

(define-runtime-path third-party-doc "../docs/third-party.md")

(struct pin (project version license source-url offer) #:transparent)

(define xray-pin
  (pin "Xray-core"
       "v26.3.27"
       "MPL-2.0"
       "https://github.com/XTLS/Xray-core"
       (string-append
        "This application bundles an unmodified Xray binary, version v26.3.27.\n"
        "Xray is Copyright (c) The XTLS authors and licensed under the Mozilla\n"
        "Public License 2.0. The source is available at\n"
        "https://github.com/XTLS/Xray-core ; you may obtain a copy of the license\n"
        "at https://www.mozilla.org/MPL/2.0/ . This distribution does not modify\n"
        "Xray source; the exact upstream release archive and its SHA-256 digest\n"
        "are recorded in docs/third-party.md of the application's source offer.\n")))

(define (notice-text pins)
  (string-join
   (append
    (list "THIRD-PARTY NOTICES\n===================\n")
    (append*
     (for/list ([p (in-list pins)])
       (list (format "~a ~a (~a)\n" (pin-project p) (pin-version p) (pin-license p))
             (format "Source: ~a\n" (pin-source-url p))
             (pin-offer p)))))
   ""))

(module+ main
  (define check-mode #f)
  (command-line
   #:program "third-party-notices.rkt"
   #:once-each
   [("--check") "Verify docs/third-party.md still carries the pinned notice facts"
    (set! check-mode #t)]
   #:args ()
   (if check-mode
       (let ([doc (file->string third-party-doc)])
         (unless (and (string-contains? doc (pin-version xray-pin))
                      (string-contains? doc (pin-license xray-pin)))
           (raise-user-error 'third-party-notices
                             "docs/third-party.md drifted from the notice pin (~a ~a)"
                             (pin-project xray-pin)
                             (pin-version xray-pin)))
         (printf "notice pin aligned: ~a ~a\n" (pin-project xray-pin) (pin-version xray-pin)))
       (display (notice-text (list xray-pin))))))
