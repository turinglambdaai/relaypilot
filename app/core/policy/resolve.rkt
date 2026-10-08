#lang racket/base

(require racket/list
         "../model.rkt")

(provide resolve-policy)

(define (find-group profile id)
  (findf (lambda (group) (string=? (policy-group-id group) id)) (relay-profile-policies profile)))

(define (find-node profile id)
  (findf (lambda (node) (string=? (proxy-node-id node) id)) (relay-profile-nodes profile)))

(define (resolve-policy profile id [visited '()])
  (when (member id visited)
    (raise-arguments-error 'resolve-policy "policy group cycle" "path" (reverse (cons id visited))))
  (cond
    [(string-ci=? id "DIRECT")
     (values "relaypilot.direct" (list "DIRECT resolves to RelayPilot direct outbound"))]
    [(string-ci=? id "REJECT")
     (values "relaypilot.block" (list "REJECT resolves to RelayPilot block outbound"))]
    [(find-node profile id) (values id (list (format "node ~a selected directly" id)))]
    [(find-group profile id)
     =>
     (lambda (group)
       (define member (or (policy-group-selected group) (car (policy-group-members group))))
       (define-values (outbound nested-steps) (resolve-policy profile member (cons id visited)))
       (values outbound (cons (format "group ~a selected ~a" id member) nested-steps)))]
    [else (raise-arguments-error 'resolve-policy "unknown policy or node" "id" id)]))
