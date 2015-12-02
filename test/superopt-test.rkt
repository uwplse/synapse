#lang s-exp rosette

(require
  "../opsyn/metasketches/imetasketch.rkt" "../opsyn/metasketches/superoptimization.rkt"
   "../opsyn/metasketches/cost.rkt"
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt" 
  "util.rkt"
  rackunit "test-runner.rkt")

(current-bitwidth 4)

; A metasketch with 1 input, 1 instruction, and programs of size up to 3.
(define M0
  (superopt∑ #:arity 1
             #:maxlength 3
             #:instructions (list bvadd)
             #:post (lambda (p inputs) 
                      (assert (= (interpret p inputs) (* 3 (car inputs)))))
             #:cost-model sample-cost-model))

; A metasketch with 2 inputs (second of which is fixed to a constant), 
; 3 instructions, and programs of unbounded size.
(define M1
  (superopt∑ #:arity 2
             #:maxlength +inf.0
             #:instructions (list bv bvadd bvmul)
             #:pre (lambda (inputs)
                     (assert (= 3 (second inputs))))
             #:post (lambda (p inputs) 
                      (assert (= (interpret p inputs) (- (first inputs) (second inputs)))))
             #:cost-model sample-cost-model))

; Tests the interface of M0.
(define (test0)
 (test-case "M0 interface"
  (check equal? (length (inputs M0)) 1)
  (check equal? (set-count (sketches M0)) 3)
  (check equal? (set-count (sketches M0 +inf.0)) 3)
  (check equal? (set-count (sketches M0 400)) 3)
  (check equal? (set-count (sketches M0 -100)) 0)
  (check equal? (set-count (sketches M0 0)) 0)
  (check equal? (set-count (sketches M0 1)) 0)
  (check equal? (set-count (sketches M0 2)) 1)
  (check equal? (set-count (sketches M0 3)) 2)
  (check equal? (set-count (sketches M0 4)) 3)
  (for ([S (sketches M0)])
    (check equal? (pre S) null)
    (define P (programs S))
    (match-define (list i) (isketch-index S))
    (check equal? (length (program-instructions P)) i)
    (for ([inst (program-instructions P)])
        (check-true (bvadd? inst)))
    (check equal? (cost M0 P) i)
    (check-false (null? (post S P))))
  (match-define (list S1 S2 S3) (set->list (sketches M0)))
  (check equal? (min-bitwidth M0 S1) 6)
  (check equal? (min-bitwidth M0 S2) 6)
  (check equal? (min-bitwidth M0 S3) 6)))


; Tests the correctness of M0.
(define (test1)
 (test-case "M0 correctness"
  (match-define (list S1 S2 S3) (set->list (sketches M0)))
  (check-true (unsat? (synth M0 S1)))
  (check-true (sat? (synth M0 S2)))
  (check-true (sat? (synth M0 S3)))
  (check-true (sat? (synth2 M0 S2)))
  (check-true (unsat? (synth2 M0 S3))))) ; there is no solution with >2 instructions


; Tests the interface of M1.
(define (test2)
 (test-case "M1 interface"
  (check equal? (length (inputs M1)) 2)
  (check equal? (set-count (sketches M1)) +inf.0)
  (check equal? (set-count (sketches M1 +inf.0)) +inf.0)
  (check equal? (set-count (sketches M1 -100)) 0)
  (check equal? (set-count (sketches M1 0)) 0)
  (for ([i (in-range 1 10)]) 
    (check equal? (set-count (sketches M1 i)) (sub1 i)))
  (for ([S (sketches M1 5)])
    (check-false (null? (pre S)))
    (define P (programs S))
    (match-define (list i) (isketch-index S))
    (check equal? (length (program-instructions P)) i)
    (check-true (term? (cost M1 P)))
    (check-false (null? (post S P))))
  (match-define (list S1 S2 S3 S4) (set->list (sketches M1 5)))
  (check equal? (min-bitwidth M1 S1) 6)
  (check equal? (min-bitwidth M1 S2) 6)
  (check equal? (min-bitwidth M1 S3) 6)
  (check equal? (min-bitwidth M1 S4) 6)))


; Tests the correctness of M1.
(define (test3)
 (test-case "M1 correctness"
  (match-define (list S1 S2 S3 S4) (set->list (sketches M1 5)))
  (check-true (unsat? (synth M1 S1)))
  (check-true (sat? (synth M1 S2)))
  (check-true (sat? (synth M1 S3)))
  (check-true (sat? (synth M1 S4)))
  (check-true (sat? (synth2 M1 S2)))
  (check-true (sat? (synth2 M1 S3)))
  (check-true (sat? (synth2 M1 S4)))))


(define/provide-test-suite superopt-tests
  (test0)
  (test1)
  (test2)
  (test3)
  )

(run-tests-quiet superopt-tests)
