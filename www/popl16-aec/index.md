---
title: Optimizing Synthesis with Metasketches
---

# Optimizing Synthesis with Metasketches

## POPL'16 Artifact Evaluation

This page hosts the artifact for our paper, *Optimizing Synthesis with Metasketches*, to appear at POPL 2016.

### Materials

* [Accepted paper](paper.pdf) (PDF, 403 kB)
* [VirtualBox image](synapse.ova) (OVA, 1.95 GB)
  * MD5: XXXXXXXX
  * Username: `synapse`
  * Password: `synapse`

### Overview

We have provided a [VirtualBox](https://www.virtualbox.org/wiki/Downloads) image containing the implementation of Synapse,
our framework for optimal synthesis with metasketches.
The image also contains the benchmarks used in our evalation,
and a test suite for Synapse. 

Both Synapse and the benchmarks are implemented in [Rosette](http://homes.cs.washington.edu/~emina/rosette/), an extension of [Racket](http://racket-lang.org/), and both languages are installed in the virtual machine.

All source code resides in the `~/opsyn` directory of the `synapse` user.
That directory is arranged as follows:

* `benchmarks`: implementations of benchmarks used in the paper
* `data`: outputs from experiments (described below)
* `experiments`: specifications of experiments in the paper (described below)
* `opsyn`: core implementation of Synapse
* `run.py`: experiment runner (described below)
* `test`: tests for Synapse and benchmarks

### Experiments

The virtual machine contains everything necessary to reproduce all results in the "Evaluation" section of the paper.
Because many of these experiments take considerable computing resources to run, we have also provided smaller versions of experiments (where appropriate) that can be run in reasonable time.

To run an experiment, execute the command:

```bash
python run.py experiments/all-benchmarks.json
```

The output of this command reports on which *jobs* have been run
(a job is a single invocation of Synapse)
and whether they came from the *cache* (see below)
or were run from scratch.

This command also produces three **output files** in the `data` folder:

* `all-benchmarks.csv` contains a summary of the experiment
* `all-benchmarks.out.txt` contains the standard output of each job in the experiment
* `all-benchmarks.pdf` is a graph of the experiment results

Each figure in the paper corresponds to an experiment,
and the figures can be re-drawn by running the appropriate experiment:

Figure   | Command
---------|--------
Figure 6 (sequential performance) | `python run.py experiments/all-benchmarks.json`
Figure 7 (parallel speedup) | `python run.py experiments/parallel-speedup.json`
Figure 8 (search progress) | `python run.py experiments/search-progress.json`
Figure 9 (optimizations) | `python run.py experiments/optimizations.json`

Each of these experiments will produce output files in the `data` folder with the same name as the experiment.

### Caching

The above commands return quickly because they are not doing any actual work.
Because the experiments take considerable time,
and many jobs within an experiment are reused across experiments,
the experiment runner *caches* results of each job to be reused.
We have pre-seeded the cache with results for every job necessary to reproduce the experiments above.

To ignore the cache, pass the `-f` flag to `run.py`.
For example:

```bash
python run.py -f experiments/all-benchmarks.json
```

This command will re-run all jobs necessary for Figure 6. **This will take several hours!**

The rough time required to run the experiments from scratch is as follows:

Figure | Command | Time
-------|---------|-----
Figure 6 (sequential performance) | `python run.py -f experiments/all-benchmarks.json` | 12 hours
Figure 7 (parallel speedup) | `python run.py -n 8 experiments/parallel-speedup.json` | 24 hours
Figure 8 (search progress) | `python run.py -f experiments/search-progress.json` | 15 minutes
Figure 9 (optimizations) | `python run.py -f experiments/optimizations.json` | 48 hours

### Parallel Resources

Running the experiments above can be greatly accelerated by using parallelism.
The `-n` flag to `run.py` controls the number of cores it can use.
For example, running this command:

```bash
python run.py -f -n 2 experiments/all-benchmarks.json
```

will schedule the jobs for this experiment across two cores,
so the experiment will complete in about half the time.
Note that the `parallel-speedup` experiment requires at least 8 cores
because it will be using up to 8 threads for a single job.

### Smaller Experiments

TODO





