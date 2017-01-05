#lang s-exp rosette

(require
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt" "../opsyn/metasketches/imetasketch.rkt"
  "../benchmarks/parrot/inversek2j.rkt" "../opsyn/engine/solver+.rkt"
  rackunit "test-runner.rkt")

(current-bitwidth 32)
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

(define (test-with-search M)
  (unsafe-clear-terms!)
  (define best-cost +inf.0)
  (define-values (more-sketches? next-sketch)
    (sequence-generate (sketches M best-cost)))
  (define done (make-hash))
  (let loop ([n 50])
    (when (= n 0) (error "maximum depth for search exceeded"))
    (when (more-sketches?)
      (define S (next-sketch))
      (cond [(hash-has-key? done S) (loop n)]
            [else (printf "~a: " S)
                  (define sol (synth M S))
                  (hash-set! done S (sat? sol))
                  (when (sat? sol)
                    (printf "~s\n" (programs S sol))
                    (define P (evaluate (programs S) sol))
                    (set! best-cost (cost M P))
                    (set!-values (more-sketches? next-sketch)
                                 (sequence-generate (sketches M best-cost))))
                  (when (unsat? sol)
                    (printf "unsat\n"))
                  (loop (- n 1))])))
  (check-false (infinite? best-cost)))

(define (test-no-search M name idx)
 (test-case (format "~a ~a" name idx)
  (define S (isketch M idx))
  (define sol (synth M S))
  (check-true (sat? sol))))


(define/provide-test-suite inversek2j-tests
  (time (test-no-search (inversek2j-theta1-metasketch) 'theta1 '(3 1)))
  (time (test-no-search (inversek2j-theta2-metasketch) 'theta2 '(2 1))))

(run-tests-quiet inversek2j-tests)
