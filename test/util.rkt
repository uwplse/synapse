#lang s-exp rosette

(require "../opsyn/engine/metasketch.rkt" "../opsyn/engine/solver+.rkt")
  
(provide (all-defined-out))

(define (solution=? s1 s2)
  (and (solution? s1)
       (solution? s2)
       (or (and (sat? s1)
                (sat? s2)
                (equal? (model s1) (model s2)))
           (and (unsat? s1)
                (unsat? s2)))))

(define (synth M S)
  (current-solution (empty-solution))
  (with-handlers ([exn:fail? (lambda (e) (unsat))])
    (synthesize #:forall    (inputs M)
                #:assume    (for ([a (pre S)]) (assert a))
                #:guarantee (for ([a (post S (programs S))]) (assert a)))))

(define (synth2 M S)
  (current-solution (empty-solution))
  (with-handlers ([exn:fail? (lambda (e) (unsat))])
    (synthesize #:forall    
                (inputs M)
                #:assume    
                (for ([a (pre S)]) (assert a))
                #:guarantee 
                (for ([a (in-sequences (post S (programs S)) (structure M S))])
                  (assert a)))))

(define (∃∀synth M S [c +inf.0])
  (parameterize ([current-custodian (make-custodian)])
    (with-handlers ([exn? (lambda (e) (custodian-shutdown-all (current-custodian)) (raise e))])
      (let ([P (programs S)])
        (∃∀solver #:forall (inputs M) 
                  #:pre (pre S) 
                  #:post (append (post S P)
                                 (structure M S)
                                 (if (infinite? c) '() (list (< (cost M P) c))))))
      (begin0
        (second (thread-receive))  
        (custodian-shutdown-all (current-custodian))))))