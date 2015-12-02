#lang s-exp rosette

(require
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt" "../benchmarks/hd/reference.rkt" "../benchmarks/hd/d5.rkt" 
  "../benchmarks/hd/d0.rkt" "../opsyn/engine/solver+.rkt" 
  rosette/solver/smt/z3
  rackunit "test-runner.rkt")

(current-bitwidth 32)

(define bench (list hd01 hd02 hd03 hd04 hd05 hd06 hd07 hd08 hd09 hd10
                    hd11 hd12 hd13 hd14 hd15 hd16 hd17 hd18 hd19 hd20))

(current-subprocess-custodian-mode 'kill)

(define (synth M S)
  (parameterize ([current-custodian (make-custodian)])
    (with-handlers ([exn? (lambda (e) (custodian-shutdown-all (current-custodian)) (raise e))])
      (∃∀solver #:forall (inputs M) 
                #:pre (pre S) 
                #:post (append (post S (programs S)) (structure M S))
                #:samples (list (sat (for/hash ([x (inputs M)]) (values x 1)))))
      (begin0
        (second (thread-receive))  
        (custodian-shutdown-all (current-custodian))))))

(define (test-hd M i)
 (test-case (format "HD ~a ~a" M i)
  (unsafe-clear-terms!)
  (check-true
   (sat?
    (let loop ([sketches (sequence->list (sketches M))][i 1])
      (cond [(empty? sketches) (unsat)]
            [else 
             (define S (car sketches))
             (printf "~a: " i)
             (define sol (synth M S))
             (cond [(sat? sol)
                    (printf "~s\n"  (programs S sol))
                    sol]
                   [else 
                    (printf "unsat\n")
                    (loop (cdr sketches) (add1 i))])]))))))

(define (test-hds hds meta)
  (for ([hd hds][i (in-naturals 1)]) 
     (test-hd (meta hd) i)))


(define/provide-test-suite hd-d0-tests
  (test-hds (take bench 19) hd-d0))

(define/provide-test-suite hd-d5-tests
  (test-hds (take bench 10) hd-d5))

(run-tests-quiet hd-d0-tests)
(run-tests-quiet hd-d5-tests)
