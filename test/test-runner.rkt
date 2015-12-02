#lang racket

(require rackunit)
; (require rackunit/text-ui)  ; hack, see below

(provide run-tests-quiet)

(define delimiter "********************\n")

(define (run-tests-quiet test)
  (unless (test-suite? test)
    (raise-argument-error 'run-tests-quiet "expected a test-suite?" test))
  (define stdout (open-output-string))
  (parameterize ([current-output-port stdout])
    (let*-values ([(out cpu real gc) (time-apply run-tests (list test))]
                  [(result) (values (first out))])
      (when (> result 0)
        (fprintf (current-error-port) delimiter)
        (fprintf (current-error-port) "test output:\n~a" (get-output-string stdout))
        (fprintf (current-error-port) delimiter))
      (fprintf (current-error-port) 
                "~a: cpu = ~a, real = ~a, gc = ~a\n"
                (rackunit-test-suite-name test) cpu real gc))))

;; everything below is a hack to fix rackunit/text-ui's output:
;; when running a test, stdout should work as normal, and test failures go to
;; stderr. this is fixed upstream but not in the current racket (6.2.1).
;; when fixed, we should remove all this, and run-tests-quiet should just invoke
;; rackunit/text-ui's run-tests.
;; this bug was fixed by
;;   https://github.com/racket/rackunit/commit/a0118d6ccf2aa45b74331dd0aba1ae04901e1a69
;; here we pull in enough of rackunit's internals to replicate that fix

; expose the parts of rackunit we need
(require/expose rackunit/private/monad (monad-value compose sequence* sequence))
(require/expose rackunit/private/counter (update-counter! counter->vector put-initial-counter))
(require/expose rackunit/private/hash-monad (make-empty-hash return-hash))
(require/expose rackunit/private/name-collector (put-initial-name push-suite-name! pop-suite-name!))
(require/expose rackunit/text-ui (display-counter*
                                  display-context
                                  display-test-preamble
                                  display-test-case-name
                                  display-result
                                  display-test-postamble))

;; run-tests : test [(U 'quiet 'normal 'verbose)] -> integer
(define (run-tests test [mode 'normal])
  (unless (or (test-case? test) (test-suite? test))
    (raise-argument-error 'run-tests "(or/c test-case? test-suite?)" test))
  (unless (memq mode '(quiet normal verbose))
    (raise-argument-error 'run-tests "(or/c 'quiet 'normal 'verbose)" mode))
  (parameterize ((current-custodian (make-custodian)))
    (monad-value
     ((compose
       (sequence*
        (case mode
          [(normal verbose)
           (display-counter*)]
          [(quiet)
           (lambda (a) a)])
        (counter->vector))
       (match-lambda
        ((vector s f e)
         (return-hash (+ f e)))))
      (case mode
        ((quiet)
         (fold-test-results
          (lambda (result seed)
            ((update-counter! result) seed))
          ((put-initial-counter)
           (make-empty-hash))
          test))
        ((normal) (std-test/text-ui display-context test))
        ((verbose) (std-test/text-ui
                    (lambda (x) (display-context x #t))
                    test)))))))

(define (std-test/text-ui display-context test)
  (fold-test-results
   (lambda (result seed)
     (parameterize ([current-output-port (current-error-port)])
       ((sequence* (update-counter! result)
                   (display-test-preamble result)
                   (display-test-case-name result)
                   (lambda (hash)
                     (display-result result)
                     (display-context result)
                     hash)
                   (display-test-postamble result))
        seed)))
   ((sequence
     (put-initial-counter)
     (put-initial-name))
    (make-empty-hash))
   test
   #:fdown (lambda (name seed) ((push-suite-name! name) seed))
   #:fup (lambda (name kid-seed) ((pop-suite-name!) kid-seed))))
