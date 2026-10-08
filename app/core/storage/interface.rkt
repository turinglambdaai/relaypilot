#lang racket/base

(provide (struct-out storage-provider))

;; Sync implementations exchange canonical profile bytes and revisions. They do
;; not leak provider-specific identifiers into the Relay Profile.
(struct storage-provider (id read write list watch capabilities) #:transparent)
