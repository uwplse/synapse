#lang s-exp rosette

(require
  "../opsyn/metasketches/superoptimization.rkt" "../opsyn/metasketches/cost.rkt"
  "../opsyn/engine/search.rkt" "../opsyn/engine/verifier.rkt" "../opsyn/engine/metasketch.rkt"
  "../opsyn/bv/lang.rkt" 
  "../benchmarks/hd/reference.rkt" "../benchmarks/hd/d0.rkt" "../benchmarks/hd/d5.rkt"
  "../benchmarks/all.rkt"
  rackunit "test-runner.rkt")

(current-bitwidth 32)
;(current-log-handler (log-handler #:info (lambda (s) (eq? s 'search))))

(define bench (list hd01 hd02 hd03 hd04 hd05 hd06 hd07 hd08 hd09 hd10
                    hd11 hd12 hd13 hd14 hd15 hd16 hd17 hd18 hd19 hd20))

(define (verify32 x P1 P2)
  (parameterize ([current-bitwidth 32])
    (check equal? (program-inputs P1) (program-inputs P2))
    (check-true
     (unsat? (verify #:post (list (= (interpret P1 x) (interpret P2 x))))))))

; Test the correctness of the search over a HD benchmark metasketch.
(define (test-hd ms hd i [widening #f] [threads 1])
 (test-case (format "hd~a" i)
  (clear-terms!)
  (define M-spec `(,ms (list-ref all-hd-programs ,i)))
  (define prog (search #:metasketch M-spec
                       #:threads threads
                       #:timeout 60
                       #:widening widening
                       #:bitwidth (current-bitwidth)))
  (check-false (false? prog))
  (define M (eval-metasketch M-spec))
  (verify32 (inputs M) hd prog)))


(define/provide-test-suite search-tests/d0
  (for ([hd bench] [i (in-range 10)])
    (test-hd 'hd-d0 hd i)))

(define/provide-test-suite search-tests/d0-widening
  (for ([hd bench] [i (in-range 10)])
    (test-hd 'hd-d0 hd i '(-1))))

(define/provide-test-suite search-tests/d5
  (for ([hd bench] [i (in-range 10)])
    (test-hd 'hd-d5 hd i)))

(run-tests-quiet search-tests/d0)
(run-tests-quiet search-tests/d0-widening)
(run-tests-quiet search-tests/d5)
