#lang s-exp rosette

(require
  "../opsyn/metasketches/imetasketch.rkt" "../opsyn/metasketches/ris.rkt"
  "../opsyn/metasketches/cost.rkt" "../opsyn/metasketches/iterator.rkt"
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt" 
  "util.rkt"
  rackunit "test-runner.rkt")

(current-bitwidth 5)

; A metasketch with 1 input, 4 instructions, and programs of size up to 3.
(define core (list bv))
(define extension (list bvadd bvshl bvmul))
(define M0
  (ris #:arity 1
       #:maxlength 3
       #:core core
       #:extension extension
       #:post (lambda (p inputs) 
                (assert (= (interpret p inputs) (* 4 (car inputs)))))
       #:cost-model sample-cost-model))

; A metasketch with 1 input and 4 instructions, with extension instructions
; not provided in cost order.
(define M1
  (ris #:arity 1
       #:maxlength +inf.0
       #:core (list bvsqrt)
       #:extension (list bvmul bvadd bvsub)
       #:cost-model sample-cost-model))

; M0 but with sum order
(define M0/sum
  (ris #:arity 1
       #:maxlength 3
       #:core core
       #:extension extension
       #:post (lambda (p inputs) 
                (assert (= (interpret p inputs) (* 4 (car inputs)))))
       #:cost-model sample-cost-model
       #:order enumerate-cross-product/sum))

; M1 but with sum order
(define M1/sum
  (ris #:arity 1
       #:maxlength +inf.0
       #:core (list bvsqrt)
       #:extension (list bvmul bvadd bvsub)
       #:cost-model sample-cost-model
       #:order enumerate-cross-product/sum))


; Tests the interface of M0.
(define (test0 M0)
 (test-case "M0 interface"
  (check equal? (length (inputs M0)) 1)
  (check equal? (set-count (sketches M0)) 12)
  (check equal? (set-count (sketches M0 +inf.0)) 12)
  (check equal? (set-count (sketches M0 400)) 12)
  (check equal? (set-count (sketches M0 -100)) 0)
  (check equal? (set-count (sketches M0 0)) 0)
  (check equal? (set-count (sketches M0 1)) 0)
  (check equal? (set-count (sketches M0 2)) 3)
  (check equal? (set-count (sketches M0 3)) 6)
  (check equal? (set-count (sketches M0 4)) 9)
  (check equal? (set-count (sketches M0 5)) 10)
  (check equal? (set-count (sketches M0 6)) 11)
  (check equal? (set-count (sketches M0 7)) 12)
  (define family (sketches M0))
  (printf "  order: ")
  (for ([S family])
    (printf "~a " (isketch-index S))
    (check-true (set-member? family S))
    (check-equal? (pre S) null)
    (define P (programs S))
    (match-define (list len prefix) (isketch-index S))
    (check equal? (length (program-instructions P)) len)
    (define ris (map object-name (append core (take extension prefix))))
    (for ([inst (program-instructions P)])
      (if (union? inst) 
          (check-true (for/and ([i (union-values inst)]) 
                        (for/or ([r ris]) (equal? r (object-name i)))))
          (check-true (bv? inst)))))
  (printf "\n")
  (define family* (sequence->list (sketches M0)))
  (check equal? (length family*) 12)))
        
; Tests the correctness of (1 *) sketches in M0.
(define (test1 M0)
 (test-case "M0 correctness (1 *)"
  ; no single instruction solution
  (define family (sequence->list (sketches M0)))
  (for ([S family] #:when (= (car (isketch-index S)) 1))
    (check-true (unsat? (synth M0 S)))
    (check-true (unsat? (synth2 M0 S))))))


; Tests the correctness of (2 *) sketches in M0.
(define (test2 M0)
 (test-case "M0 correctness (2 *)"
  (define family (sequence->list (sketches M0)))
  ; there are 3 solutions of length 2 (all prefixes except bv alone produce a solution)
  (define S2* (filter (lambda (S) (= (car (isketch-index S)) 2)) family))
  (check = (length S2*) 4)
  (check equal? (for/sum ([S S2*] #:when (sat? (synth M0 S))) 1) 3)
  (check equal? (for/sum ([S S2*] #:when (sat? (synth2 M0 S))) 1) 3)))

; Tests the correctness of (3 *) sketches in M0.
(define (test3 M0)
 (test-case "M0 correctness (3 *)"
  (define family (sequence->list (sketches M0)))
  ; there are 3 solutions of length 3 (all prefixes except bv alone produce a solution)
  (define S3* (filter (lambda (S) (= (car (isketch-index S)) 3)) family))
  (check = (length S3*) 4)
  (check equal? (for/sum ([S S3*] #:when (sat? (synth M0 S))) 1) 3)  
  (check equal? (for/sum ([S S3*] #:when (sat? (synth2 M0 S))) 1) 3)))

(define (sketches->indices sk)
  (for/list ([S sk]) (isketch-index S)))
(define (sketches->indexset sk)
  (for/set ([S sk]) (isketch-index S)))


; Tests the interface of a metasketch with core / extension instructions that are 
; not given in the increasing order of cost.
(define (test-out-of-order-instructions M1)
 (test-case "out-of-order instructions"
  (check equal? (set-count (sketches M1)) +inf.0)
  (check equal? (set-count (sketches M1 +inf.0)) +inf.0)
  (check equal? (set-count (sketches M1 -100)) 0)
  (check equal? (set-count (sketches M1 0)) 0)
  (check equal? (set-count (sketches M1 1)) 0)
  (check equal? (sketches->indexset (sketches M1 2)) (list->set '((1 2)(1 3))))
  (check equal? (sketches->indexset (sketches M1 3)) (list->set '((1 2)(1 3)(2 2)(2 3))))
  (check equal? (sketches->indexset (sketches M1 4)) (list->set '((1 2)(1 3)(2 2)(2 3)(3 2)(3 3))))
  (check equal? (sketches->indexset (sketches M1 5)) (list->set '((1 1)(1 2)(1 3)(2 2)(2 3)(3 2)(3 3)(4 2)(4 3))))
  (for ([c (in-range 6 17)])
    (check-false (ormap (compose1 zero? second) (sketches->indices (sketches M1 c)))))
  (check equal? (count (compose1 zero? second) (sketches->indices (sketches M1 17))) 1)
  ))


(define/provide-test-suite ris-tests
  (test0 M0)
  (test1 M0)
  (test2 M0)
  (test3 M0)
  (test-out-of-order-instructions M1)
  )

(define/provide-test-suite ris-tests/sum
  (test0 M0/sum)
  (test1 M0/sum)
  (test2 M0/sum)
  (test3 M0/sum)
  (test-out-of-order-instructions M1/sum)
  )

(run-tests-quiet ris-tests)
(run-tests-quiet ris-tests/sum)
