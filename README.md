# Synapse

Synapse is a framework for program synthesis with cost functions, as described in our POPL'16 paper [*Optimizing Synthesis with Metasketches*](http://synapse.uwplse.org/synapse-popl16.pdf).

## Requirements

Synapse is built in the [Rosette](http://homes.cs.washington.edu/~emina/rosette/) solver-aided language, which extends [Racket](http://racket-lang.org). Install the following requirements:

* Racket v6.2.1 ([download](http://download.racket-lang.org/racket-v6.2.1.html); v6.3 has not yet been tested)
* Java v1.7 or above ([download](http://www.oracle.com/technetwork/java/javase/downloads/index.html))
* Rosette ([instructions on GitHub](https://github.com/emina/rosette))

## Getting started

Existing benchmarks can be run from the command line using the `benchmarks/run.rkt` script. Be sure to compile this script first. For example:

	$ raco make benchmarks/run.rkt
	$ racket benchmarks/run.rkt "(hd-d0 1)"
	(program 1 (list (bv 1) (bvsub 0 1) (bvand 0 2)))
	
The expression `(hd-d0 1)` specifies the benchmark to execute. To see a list of available benchmarks, and the other options this script accepts, run:

	$ racket benchmarks/run.rkt -h

### More experiments

Instructions for running more experiments with Synapse's existing benchmarks accompany our [POPL'16 artifact](http://synapse.uwplse.org/popl16-aec/).

## Using metasketches

A *metasketch* is an ordered set of *sketches* together with a cost function and gradient function. Together, these elements define an optimal synthesis problem: the set of sketches defines the search space, and the solution is the program in that search space that minimizes the cost function.

### Standard metasketches

Synapse includes several standard metasketches for a variety of synthesis problems. These implementations all reside in the `opsyn/metasketches` directory:

* `superoptimization.rkt` implements a superoptimization metasketch for bitvector programs in SSA form
* `piecewise.rkt` implements a metasketch for a piecewise polynomial program
* `ris.rkt` and `bdf.rkt` implement metasketches for approximate computing:
	* `ris.rkt` extracts a "reduced instruction set" of operations from a reference implementation and uses them to guide synthesis of an optimal approximate implementation
	* `bdf.rkt` extracts the data-flow graph from a reference implementation and uses it as the basis for synthesis of an optimal approximate implementation
* `neural.rkt` implements a metasketch for training a neural network on a set of input-output examples

### Using a standard metasketch

The file `benchmarks/demo/example.rkt` contains simple examples of how to use the built-in superoptimization metasketch. Here we'll walk through this example to demonstrate the key parts of Synapse.

#### Programs

This metasketch operates over programs in SSA form, represented with a `program` structure (in `opsyn/bv/lang.rkt`):

```racket
(struct program (inputs instructions))
```

For example, this program:

```racket
(program 2 (list (bvslt 0 1) (ite 2 1 0)))
```

implements the `max` function. The program takes two inputs. The operands to instructions refer to SSA registers; the first 2 of these registers (0 and 1) are the two inputs to the program, and the remaining are the outputs of previous instructions. Therefore, this program first stores `x < y` in register 2, and then stores `if (r2) then y else x` in register 3 (where `r2` is the value of register 2). Programs implicitly return the value of the last assigned register (in this case, register 3).

#### Postconditions

`example.rkt` starts by defining a postcondition:

```racket
(define (max-post P inputs)
  (match-define (list x y) inputs)
  (define out (interpret P inputs))
  (assert (>= out x))
  (assert (>= out y))
  (assert (or (= out x) (= out y))))
```

The postcondition function takes as input a program P (which is an instance of the `program` struct above) and symbolic inputs to that program. The function should assert (using Rosette's `assert` operation) the desired postconditions for functional correctness. 

Here, the assertions say that the output of P should be greater than or eqaul to both of the arguments, and should be equal to one of the arguments.

#### Metasketches

The `example` procedure defines a simple metasketch based on the provided superoptimization metaskecth:

```racket
(define (example)
  (superopt∑ #:arity 2
             #:instructions (list bvslt ite)
             #:post max-post
             #:cost-model constant-cost-model))
```

The `superopt∑` procedure takes the number of inputs to the synthesized program, the instructions it is allowed to use, the postcondition, and a *cost model*. The cost model attaches a static cost to each type of instruction, and Synapse will minimize the sum of these costs for the synthesized program. Here, we have specified the constant cost model, that attaches the same cost to every instruction. Synapse will therefore return the *shortest* program that satisfies the postcondition.

#### Running the example

To run Synapse on the example metasketch, execute:

```bash
$ racket benchmarks/run.rkt "(example)"
```

This will return the same program as above:
```racket
(program 2 (list (bvslt 0 1) (ite 2 1 0)))
```

You can also pass the `-v` flag to `run.rkt` to see verbose output about the programm of Synapse's search algorithms.

#### More examples

`example.rkt` contains three more examples -- `(example2)`, `(example3)`, and `(example4)` -- which can be executed in the same fashion as `(example)`.

* `(example2)` prevents the synthesized program from using `ite` instructions, which forces it to instead generate bitwise manipulations to compute the maximum:

    ```racket
    (define (example2)
      (superopt∑ #:arity 2
                 #:instructions (list bvand bvor bvxor bvnot bvneg bvadd bvsub bvslt)
                 #:post max-post
                 #:cost-model constant-cost-model))
    ```

* `(example3)` allows the synthesized program to use both bitwise manipulations and `ite` instructions. It also uses a different cost model that attaches different costs to each operations; for example, `bvxor` costs 1 while `ite` costs 8:

    ```racket 
    (define c (static-cost-model (hash-set sample-costs ite 8)))
    (define (example3)
      (superopt∑ #:arity 2
                 #:instructions (list bvand bvor bvxor bvnot bvneg bvadd bvsub bvslt ite)
                 #:post max-post
                 #:cost-model c))
    ```

    The result is that a longer program is "cheaper" than a shorter one. Executing this metasketch with the `-v` flag will show that Synapse finds the shorter program first, but realizes from the metasketch's gradient function that it must consider longer programs, and eventually finds the cheaper, longer solution.

* `(example4)` demonstrates *pre*conditions:

    ```racket
    (define (max-pre inputs)
      (match-define (list x y) inputs)
      (assert (< x y)))
    (define (example4)
      (superopt∑ #:arity 2
                 #:instructions (list bvor)
                 #:pre max-pre
                 #:post max-post
                 #:cost-model constant-cost-model))
    ```

    Here the precondition asserts that `x < y`, which makes computing the maximum of `x` and `y` much simpler. The synthesized program is:

    ```racket
    (program 2 (list (bvor 1 1)))
    ```

    which simply returns `y | y`, or just `y`.

## Developing metasketches

The metasketch interface is defined as a Racket generic interface in `opsyn/metasketches/metasketch.rkt`. However, Synapse supports only *indexed* metasketches, which are simply metasketches that attach a unique *index* to each sketch in the set of sketches. The indexing helps Synapse to track progress and parallelize execution. The indexed metaaketch interface is defined and documented in `opsyn/metasketches/imetasketch.rkt`.

To be able to run a metasketch using `benchmarks/run.rkt`, it must be `provide`d by a file that is then added to the `require` spec of `benchmarks/all.rkt`. For example, the example metasketch defined above is provided in the `benchmarks/demos/example.rkt` file, which is required by `benchmarks/all.rkt`.

The command line for `benchmarks/run.rkt` accepts an s-expression corresponding to an invocation of a metasketch function. For example, if we had defined a metasketch that took an argument:

```racket
(define (example do-stuff?)
  (if do-stuff? ... ...))
```

then we could invoke this metasketch from the command line, passing in a value for the argument:

```bash
$ racket benchmarks/run.rkt "(example #t)"
```