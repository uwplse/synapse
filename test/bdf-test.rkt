#lang s-exp rosette

(require
  "../opsyn/metasketches/imetasketch.rkt" "../opsyn/metasketches/bdf.rkt"
   "../opsyn/metasketches/cost.rkt"
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt" 
  "util.rkt"
  rackunit "test-runner.rkt")

(current-bitwidth 5)

; Test the trivial corner case where the reference program is just a constant.
(define (test0)
 (test-case "constant reference program"
  (define P0 (program 0 (list (bv 1))))
  (define M0 (bdf #:reference P0
                  #:core (list bvadd)
                  #:extension (list bvsub)
                  #:post (lambda (P inputs) (assert (= (interpret P0 inputs) (interpret P inputs))))))
  (check equal? (set-count (sketches M0)) 1)
  (check equal? (set-count (sketches M0 +inf.0)) 1)
  (check equal? (set-count (sketches M0 -100)) 0)
  (check equal? (set-count (sketches M0 0)) 0)
  (check equal? (set-count (sketches M0 1)) 0)
  (check equal? (set-count (sketches M0 2)) 1)
  (define S (for/first ([S (sketches M0)]) S))
  (check-true (set-member? (sketches M0) S))
  (define P (programs S))
  (check equal? (length (program-instructions P)) (length (program-instructions P0)) )
  (check-true (andmap bv? (program-instructions P)))
  (check-true (sat? (synth M0 S)))
  (check-true (sat? (synth2 M0 S)))))

(define P1 (program 1 (list (bv 4) (bvmul 0 1))))
(define core (list bvsqrt))
(define extension (list bvmul ite bvshl))
(define M1 (bdf #:reference P1
                #:core core
                #:extension extension
                #:post (lambda (P inputs) (assert (= (interpret P1 inputs) (interpret P inputs))))))

; Tests the M1 interface.
(define (test1)
 (test-case "M1 interface"
  (check equal? (set-count (sketches M1)) 4)
  (check equal? (set-count (sketches M1 +inf.0)) 4)
  (check equal? (set-count (sketches M1 -100)) 0)
  (check equal? (set-count (sketches M1 0)) 0)
  (check equal? (set-count (sketches M1 1)) 0)
  (check equal? (set-count (sketches M1 2)) 0)
  (check equal? (set-count (sketches M1 3)) 1)
  (check equal? (set-count (sketches M1 4)) 1)
  (check equal? (set-count (sketches M1 5)) 1)
  (check equal? (set-count (sketches M1 6)) 3)
  (for ([i (in-range 7 18)])
     (check equal? (set-count (sketches M1 6)) 3))
  (check equal? (set-count (sketches M1 18)) 4)
  (define family (sketches M1))
  (define len (length (program-instructions P1)))
  (for ([S family])
    (check-true (set-member? family S))
    (define P (programs S))
    (match-define (list prefix) (isketch-index S))
    (check equal? (length (program-instructions P)) len)
    (define bdf (map object-name (append core (take extension prefix))))
    (for ([inst (program-instructions P)])
      (if (union? inst) 
          (check-true (for/and ([i (union-values inst)]) 
                        (for/or ([r bdf]) (equal? r (object-name i)))))
          (check-true (or (bv? inst) (bvsqrt? inst))))))))

; Tests M1 correctness.
(define (test2)
 (test-case "M1 correctness"
  (match-define (list S0 S1 S2 S3) (set->list (sketches M1)))
  (check-true (unsat? (synth M1 S0)))
  (check-true (unsat? (synth2 M1 S0)))
  (check-true (sat? (synth M1 S1)))
  (check-true (sat? (synth2 M1 S1)))
  (check-true (sat? (synth M1 S2)))
  (check-true (unsat? (synth2 M1 S2)))
  (check-true (sat? (synth M1 S3)))
  (check-true (sat? (synth2 M1 S3)))))


(define/provide-test-suite bdf-tests
  (test0)
  (test1)
  (test2)
  )

(run-tests-quiet bdf-tests)
