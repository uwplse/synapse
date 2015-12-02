#lang racket

(require (only-in rosette/solver/solution sat))
(provide inflate-sample deflate-sample)

; Convert a serialized sample into a solution?, given a list of
; variables and another list of their values
(define (inflate-sample inputs vals)
  (sat (for/hash ([in inputs][v vals])
         (values in v))))

; Convert a solution? into a serialized list of values
(define (deflate-sample inputs m)
  (for/list ([in inputs])
    (m in)))
