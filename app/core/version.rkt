#lang racket/base

;; Release identity for RelayPilot, duplicated from rivet.rktd — the packaged
;; app and the CLI cannot reliably read the project file at runtime.
;; scripts/check-release-version.sh re-checks the values against rivet.rktd.
;;
;; This is a leaf module on purpose: the CLI's `version` command reports
;; identity without loading the engine or runtime machinery.

(provide app-version
         app-build
         app-identifier
         app-channel
         app-display-name)

(define app-version "0.1.0")
(define app-build 1)
(define app-identifier "ai.turinglambda.relaypilot")
(define app-channel 'alpha)
(define app-display-name "RelayPilot")
