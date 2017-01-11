#lang s-exp rosette

(require
  "../opsyn/engine/metasketch.rkt" "../opsyn/engine/eval.rkt" "../opsyn/engine/util.rkt"
  "../opsyn/bv/lang.rkt" "../opsyn/metasketches/imetasketch.rkt" 
  "../benchmarks/parrot/specs.rkt" "../benchmarks/parrot/sobel.rkt" "../opsyn/engine/solver+.rkt" 
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

(define (test-with-search sobel-ref)
  (define M (sobel-metasketch #:reference sobel-ref #:quality (relaxed 1)))
  (define ref-cost (cost M sobel-ref))
  (printf "~a cost: ~a\n" (object-name sobel-ref) ref-cost)
  (define Ss (sketches M (cost M sobel-ref)))
  (printf "sketches to try: ~a\n" (set-count Ss))
  (check-true
   (sat?
    (let loop ([sketches (set->stream Ss)])
      (clear-terms!)
      (cond [(stream-empty? sketches) (unsat)]
            [else 
             (define S (stream-first sketches))
             (printf "~a: " S)
             (define sol (synth M S))
             (cond [(sat? sol)  (printf "~s\n"  (programs S sol)) sol]
                   [else 
                    (printf "unsat\n")
                    (loop (stream-rest sketches))])])))))

(define (test-no-search sobel-ref name idx)
 (test-case (format "~a ~a" name idx)
  (clear-terms!)
  (define M (sobel-metasketch #:reference sobel-ref #:quality (relaxed 1)))
  (define ref-cost (cost M sobel-ref))
  (printf "~a cost: ~a\n" (object-name sobel-ref) ref-cost)
  (define Ss (sketches M (cost M sobel-ref)))
  (printf "sketches to try: ~a\n" (set-count Ss))
  (define S (isketch M idx))
  (printf "trying: ~a\n" S)
  (define sol (synth M S))
  (cond [(sat? sol)  (printf "~s\n"  (programs S sol)) sol]
        [else 
         (printf "unsat\n")])
  (check-true (sat? sol))))


(define/provide-test-suite sobel-tests
  (time (test-no-search sobel-x 'sobel-x '(7 1)))
  (time (test-no-search sobel-y 'sobel-y '(7 1))))

(run-tests-quiet sobel-tests)

