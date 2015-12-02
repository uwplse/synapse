#lang s-exp rosette

(require
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt" "../opsyn/engine/solver+.rkt" "../opsyn/metasketches/iterator.rkt"
  "../benchmarks/sygus/qm/reference.rkt"
  rackunit "test-runner.rkt")

(current-subprocess-custodian-mode 'kill)

(current-bitwidth 6)

(define (synth M S)
  (parameterize ([current-custodian (make-custodian)])
    (with-handlers ([exn? (lambda (e) (custodian-shutdown-all (current-custodian)) (raise e))])
      (∃∀solver #:forall (inputs M) 
                #:pre (pre S) 
                #:post (append (post S (programs S)) (structure M S)))
      (begin0
        (second (thread-receive))  
        (custodian-shutdown-all (current-custodian))))))

(define (test-qm M s)
 (test-case (format "~a" s)
  (unsafe-clear-terms!)
  (check-true
   (sat?
    (let loop ([sketches (sequence->stream (sketches M))])
      (define S (stream-first sketches))
      (printf "~a: " S)
      (define sol (synth M S))
      (cond [(sat? sol)
             (printf "~v\n"  (programs S sol))
             sol]
            [else 
             (printf "unsat\n")
             (loop (stream-rest sketches))]))))))

(define/provide-test-suite qm-tests
  (test-qm (qm_choose_01) 'qm_choose_01)
  (test-qm (qm_loop_1) 'qm_loop_1)
  (test-qm (qm_max2) 'qm_max2)
  (test-qm (qm_neg_1) 'qm_neg_1)
  (test-qm (qm_neg_eq_1) 'qm_neg_eq_1))

(run-tests-quiet qm-tests)
