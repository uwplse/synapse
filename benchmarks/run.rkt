#lang s-exp rosette

(require "../opsyn/engine/search.rkt"
         ;"../opsyn/engine/search-old.rkt"
         "../opsyn/metasketches/cost.rkt" "../opsyn/metasketches/iterator.rkt"
         "hd/reference.rkt"
         "sygus/qm/reference.rkt"
         rosette/solver/smt/z3 rosette/solver/kodkod/kodkod)

(define (cmd-parse [args (current-command-line-arguments)])
  (current-log-handler (log-handler #:info none/c))
  (define verbosity 0)
  (define bw 32)
  (define e 1)
  (define threads 1)
  (define structure #t)
  (define exchange-cex #t)
  (define exchange-costs #t)
  (define incremental #t)
  (define timeout 900)
  (define order #f)
  (define widening #f)
  (define solver-synth 'kodkod-incremental%)
  (define solver-verify 'kodkod%)
  
  (define ms
    (command-line
     #:argv args
     #:usage-help
     "<benchmark> specifies a benchmark to run as follows:"
     " * Array Search benchmarks:"
     "   - \"(array-search n)\" runs the n'th array search benchmark"
     " * Conditional Integer Arithmetic benchmarks:"
     "   - \"(qm x)\" runs the CIA benchmark named x (e.g. \"(qm qm_max2)\")"
     " * Hacker's Delight benchmarks:"
     "   - \"(hd-d0 n)\" runs the n'th Hacker's Delight benchmark at difficulty 0."
     "   - \"(hd-d5 n)\" runs the n'th Hacker's Delight benchmark at difficulty 5."
     " * Parrot benchmarks:"
     "   - \"(sobel-x)\" runs the sobel-x benchmark."
     "   - \"(sobel-y)\" runs the sobel-y benchmark."
     "   - \"(kmeans)\" runs the kmeans benchmark."
     "   - \"(fft-sin)\" runs the fft-sin benchmark."
     "   - \"(fft-cos)\" runs the fft-cos benchmark."
     "   - \"(inversek2j-theta1)\" runs the inversek2j-theta1 benchmark."
     "   - \"(inversek2j-theta2)\" runs the inversek2j-theta2 benchmark."
     
     #:multi
     [("-v" "--verbose")
      "Execute with verbose search messages."
      (begin
        (set! verbosity (add1 verbosity)))]

     #:once-each
     [("-b" "--bitwidth")
      bits
      ("Limit arithmetic precision to the given number of bits during synthesis."
       "This parameter must be in range [1..32].")
      (begin
        (set! bw (string->number bits))
        (unless (and (integer? bw) (<= 1 bw))
          (error 'bits "expected an integer >= 1, given ~a" bits)))]
     
     [("-e" "--error")
      err
      ("For Parrot benchmarks, specifies the accuracy of the synthesized"
       "program P with respect to the spec S:"
       "| P(x) - S(x) | <= (| S(x) | >> err)."
       "This parameter must be in range [0..32].")
      (begin
        (set! e (string->number err))
        (unless (and (integer? e) (<= 0 e) (<= e 32))
          (error 'err "expected an integer in [0..32], given ~a" err)))]
     
     [("-u" "--unbuffered")
      "Use unbuffed stdout and stderr."
      (file-stream-buffer-mode (current-output-port) 'none)
      (file-stream-buffer-mode (current-error-port) 'none)]
     
     [("-n" "--threads")
      thds
      "Use the specified number of threads for the search. Must be >= 1."
      (begin
        (set! threads (string->number thds))
        (unless (and (integer? threads) (>= threads 1))
          (error 'threads "exepcted an integer >= 1, given ~a" threads)))]
     
     [("-t" "--timeout")
      tout
      "Timeout for individual sketches, in seconds. Must be > 0."
      (begin
        (set! timeout (string->number tout))
        (unless (and (integer? timeout) (> timeout 0))
          (error 'timeout "expected an integer > 0, given ~a" timeout)))]
     
     [("-s" "--no-structure")
      "Do not use structure constraints."
      (set! structure #f)]
     
     [("-c" "--no-exchange-cex")
      "Do not exchange counterexamples between solvers."
      (set! exchange-cex #f)]

     [("-x" "--no-exchange-cost")
      "Do not exchange costs between solvers."
      (set! exchange-costs #f)]

     [("-i" "--no-incremental")
      "Do no use incremental CEGIS."
      (set! incremental #f)]
     
     [("-o" "--order")
      ordr
      "Order to use for enumerating sketches."
      (match ordr
        ["sum" (set! order 'enumerate-cross-product/sum)]
        [_     void])]
     
     [("-w" "--widening")
      "Perform bitwidth widening."
      (set! widening #t)]

     [("-r" "--solver")
      slvr
      "Solver to use."
      (match slvr
        ["z3" (set! solver-synth 'z3%)
              (set! solver-verify 'z3%)]
        ["kodkod" (set! solver-synth 'kodkod-incremental%)
                  (set! solver-verify 'kodkod%)]
        [else (error 'solver "unrecognized solver ~a" slvr)])]
     
     #:args (benchmark)
     (cmd->metasketch benchmark e order)))
  
  (set! verbosity
    (match verbosity
      [0 #f]
      [1 #t]
      [v v]))
  (values verbosity ms bw threads timeout
          structure exchange-cex exchange-costs incremental
          widening solver-synth solver-verify))
     

(define (cmd->metasketch cmd e order)
  (define (make-hd-metasketch ms i)
    (unless (and (>= i 1) (<= i 20))
      (error 'cmd->metasketch "there are only ~a HD programs" (length all-hd-programs)))
    `(,ms (list-ref all-hd-programs (- ,i 1))
        #:finite? #f
        #:cost-model constant-cost-model))

  (match (read (open-input-string cmd))
    [`(hd-d0 ,i) (make-hd-metasketch 'hd-d0 i)]
    [`(hd-d5 ,i) (make-hd-metasketch 'hd-d5 i)]
    [`(sobel-x)  `(sobel-metasketch #:reference sobel-x
                                    #:quality (relaxed ,e)
                                    #:order ,order)]
    [`(sobel-y)  `(sobel-metasketch #:reference sobel-y
                                    #:quality (relaxed ,e)
                                    #:order ,order)]
    [`(kmeans)   `(dist3-bdf #:quality (relaxed ,e))]
    [`(fft-sin)  `(fft-sin-metasketch ,e ,order)]
    [`(fft-cos)  `(fft-cos-metasketch ,e ,order)]
    [`(inversek2j-theta1) `(inversek2j-theta1-metasketch ,e ,order)]
    [`(inversek2j-theta2) `(inversek2j-theta2-metasketch ,e ,order)]
    [`(array-search ,n) `(array-search ,n #:order ,order)]
    [`(qm ,q) `(,q #:order ,order)]
    [`(,x) `(,x)]
    [_           (error 'cmd->metasketch "invalid benchmark: ~a" cmd)]))

(define (run)
  (define-values (verbose ms bw threads timeout
                          structure exchange-cex exchange-costs incremental
                          widening solver-synth solver-verify) (cmd-parse))
  (define P (search #:metasketch ms
                    #:threads threads
                    #:timeout timeout
                    #:bitwidth bw
                    #:exchange-samples exchange-cex
                    #:exchange-costs exchange-costs
                    #:use-structure structure
                    #:incremental incremental
                    #:widening (if widening (list 1) #f)
                    #:synthesizer solver-synth
                    #:verifier solver-verify
                    #:verbose verbose))
  (error-print-width 100000)  ; don't truncate the output program
  P)

(run)