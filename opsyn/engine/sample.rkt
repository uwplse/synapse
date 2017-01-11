#lang racket

(require (only-in rosette/solver/solution sat)
         (only-in rosette/base/core/bitvector bitvector [bv rosette-bv]))
(provide inflate-sample deflate-sample)

(struct prefab-bv (val bitwidth) #:prefab)

; Convert a serialized sample into a solution?, given a list of
; variables and another list of their values
(define (inflate-sample inputs vals)
  (sat (for/hash ([in inputs][v vals])
         (match v
           [(prefab-bv val bw)
            (values in (rosette-bv val (bitvector bw)))]
           [val (values in val)]))))

; Convert a solution? into a serialized list of values
(define (deflate-sample inputs m)
  (for/list ([in inputs])
    (match (m in)
      [(rosette-bv val (bitvector bw))
       (prefab-bv val bw)]
      [val val])))
