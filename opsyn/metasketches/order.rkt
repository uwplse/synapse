#lang racket

(require racket/generic racket/generator "iterator.rkt")

(provide ordered-space)

(struct ordered-space (space order)
  #:transparent
  #:property prop:sequence
  (lambda (self) (in-set self))
  #:methods gen:set
  [(define/generic space-set-count set-count)
   (define/generic space-set-member? set-member?)
   (define/generic space-in-set in-set)
   
   (define (set-count self) (space-set-count (ordered-space-space self)))
   
   (define (set-member? self S)
     (space-set-member? (ordered-space-space self) S))
   
   (define (in-set self)
     (define total (set-count self))
     (define seen 0)
     (in-generator
      (for ([idx (ordered-space-order self)]
            #:break (= seen total))
        (when (set-member? self idx)
          (set! seen (add1 seen))
          (yield idx)))))])
