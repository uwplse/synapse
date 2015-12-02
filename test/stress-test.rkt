#lang s-exp rosette

(require "../opsyn/metasketches/stress-test.rkt" "../opsyn/engine/search.rkt"
         "../opsyn/engine/metasketch.rkt"
        "util.rkt"
         rackunit "test-runner.rkt")

(current-bitwidth 16)
(current-subprocess-custodian-mode 'kill)

(define (test-search [thds 1] [order #f])
 (set! order (or order (tm-shuffled-order 10)))
 (test-case (format "stress ~a ~a" thds order)
  (printf "  ~s\n" order)
  (define cust (make-custodian))
  (parameterize ([current-custodian cust])
    (define T
      (let ([me (current-thread)])
        (thread (thunk
                 (thread-send me
                              (search #:metasketch `(test-metasketch #:length 10 #:order ',order)
                                      #:threads thds
                                      #:verbose #t))))))
    (define alm (alarm-evt (+ (current-inexact-milliseconds) (* 1000 30))))
    (match (sync (thread-receive-evt) alm)
      [(== alm) (fail "timed out -- deadlock?")]
      [tre (let ([P (thread-receive)])
             (check-false (false? P))
             (define M (test-metasketch #:length 10 #:order order))
             (define C (cost M P))
             (check-false (term? C))
             (check-equal? C 1))]))
  (custodian-shutdown-all cust)))
    

(define/provide-test-suite race-tests
  (for ([thds (in-range 1 4)])
    (let ([thds (expt 2 thds)])
      (for ([perm 10])
        (test-search thds)))))

(run-tests-quiet race-tests)
