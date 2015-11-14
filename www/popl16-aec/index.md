---
title: Optimizing Synthesis with Metasketches
---

<img class="aec" src="/img/popl-aec.png" />

# Optimizing Synthesis with Metasketches
{:.no_toc}

<p class="authors" markdown="1">
[James Bornholt](http://homes.cs.washington.edu/~bornholt/), 
[Emina Torlak](http://homes.cs.washington.edu/~emina/),
[Dan Grossman](http://homes.cs.washington.edu/~djg/), 
[Luis Ceze](http://homes.cs.washington.edu/~luisceze/)
<br>
[POPL 2016](http://conf.researchr.org/home/POPL-2016)
</p>

This page hosts the accepted artifact for our POPL 2016 paper, [*Optimizing Synthesis with Metasketches*](http://synapse.uwplse.org/).

## Contents 
{:.no_toc}

* Contents
{:toc}

### Materials

* [Paper](paper.pdf) (PDF, 333 kB)
* [VirtualBox image](synapse.ova?md5=f3d1f2b9d05a60440955130cfbda0259) (OVA, 1.9 GB)
  * MD5: `f3d1f2b9d05a60440955130cfbda0259`
  * Username: `synapse`
  * Password: `synapse` (has passwordless sudo access)

### Overview

We have provided a [VirtualBox](https://www.virtualbox.org/wiki/Downloads) image containing the implementation of Synapse,
our framework for optimal synthesis with metasketches.
The image also contains the benchmarks used in our evalation,
and a test suite for Synapse. 

Both Synapse and the benchmarks are implemented in [Rosette](http://homes.cs.washington.edu/~emina/rosette/), an extension of [Racket](http://racket-lang.org/), and both languages are installed in the virtual machine.

#### Claims

The artifact addresses all the research questions in the "Evaluation" section of the paper:

1. Is Synapse a practical approach to solving different kinds of synthesis problems?
	* [Figure 6 experiment](#paper-experiments)
2. Does the fragmentatation of the search space by a metasketch translate into parallel speedup?
	* [Figure 7 experiment](#paper-experiments)
3. Is online completeness empirically useful?
	* [Figure 8 experiment](#paper-experiments)
4. How beneficial are our metasketch and implementation optimizations?
	* [Figure 9 experiment](#paper-experiments)
5. Can Synapse reason about dynamic cost functions?
   * [Demonstrations](#demonstrations)

#### Getting Started

Install [VirtualBox 5.0.6](https://www.virtualbox.org/wiki/Downloads) and the VirtualBox extension pack.
Import the VirtualBox image (open VirtualBox, then File > Import Appliance).
Boot the resulting virtual machine.
It will log in be automatically as the `synapse` user,
and open a terminal in the `~/opsyn` directory.
There is also a desktop shortcut to re-open this terminal.

### Running an Experiment

The `~/opsyn` directory contains a script `run.py` to run experiments.
Experiments are defined in JSON files in the `experiments` directory.
An *experiment* is a collection of *jobs*,
where each job is a single invocation of Synapse (i.e., on a single benchmark with a single configuration).

To run a basic test experiment, execute this command:

```
python run.py -f -n 2 experiments/test.json
```

(The `-f` flag overrides the cache, [explained below](#cache),
and the `-n 2` flag controls the maximum number of parallel cores used).
This should take approximately 1 minute, and produce output similar to the following:

```
compiling benchmark runner...
starting: /home/synapse/opsyn/benchmarks/run -t 900 -n 2 -u -v -w (hd-d0 1)
  --> /tmp/tmpX2QpSC
  [4 jobs: 0 complete, 1 running, 3 remaining]
finished: /home/synapse/opsyn/benchmarks/run -t 900 -n 2 -u -v -w (hd-d0 1)
  [4 jobs: 1 complete, 0 running, 3 remaining]
starting: /home/synapse/opsyn/benchmarks/run -t 900 -n 1 -u -v -w (hd-d0 1)
  --> /tmp/mpocrjp1
  [4 jobs: 1 complete, 2 running, 1 remaining]
starting: /home/synapse/opsyn/benchmarks/run -t 900 -n 1 -u -v -w (hd-d0 2)
  --> /tmp/mpWrCYJ8
  [4 jobs: 1 complete, 2 running, 1 remaining]
finished: /home/synapse/opsyn/benchmarks/run -t 900 -n 1 -u -v -w (hd-d0 1)
  [4 jobs: 2 complete, 1 running, 1 remaining]
finished: /home/synapse/opsyn/benchmarks/run -t 900 -n 1 -u -v -w (hd-d0 2)
  [4 jobs: 3 complete, 1 running, 0 remaining]
starting: /home/synapse/opsyn/benchmarks/run -t 900 -n 1 -u -v -w (hd-d0 3)
  --> /tmp/mpShesLL
  [4 jobs: 3 complete, 1 running, 0 remaining]
finished: /home/synapse/opsyn/benchmarks/run -t 900 -n 1 -u -v -w (hd-d0 3)
  [4 jobs: 4 complete, 0 running, 0 remaining]
```

The exact order of the output and the temporary files names may differ.
This output says that four *jobs* were run
(i.e., Synapse was invoked four times).
When a job starts, the experiment runner outputs the name of a temporary file to which that job's output is being redirected.

Running this command also produces two **output files** in the `data` directory:

* `test.csv` is a summary of the results of each job in the experiment
* `test.out.txt` contains the complete output of each job in the experiment

### Paper Experiments

The virtual machine contains everything necessary to reproduce all results in the "Evaluation" section of the paper.
Because many of these experiments take considerable computing resources to run, 
the results are [cached](#caching) by default,
and we have also provided [smaller versions](#smaller-experiments) of experiments (where appropriate) that can be run in reasonable time.

To run an experiment corresponding to Figure 6 in the paper,
execute the command:

```
python run.py experiments/all-benchmarks.json
```

When this command finishes,
it will open a graph with results similar to the paper's Figure 6.
Just as with the test experiment, 
this command also produces two output files in the `data` directory:
`all-benchmarks.csv` and `all-benchmarks.out.txt`.
The produced graph is also in the `data` directory as `all-benchmarks.pdf`.

Each figure in the paper corresponds to an experiment,
and the experiments can be run (and so their corresponding figures redrawn) by running the appropriate command:

Figure   | Command
---------|--------
Figure 6 (sequential performance) | `python run.py experiments/all-benchmarks.json`
Figure 7 (parallel speedup) | `python run.py experiments/parallel-speedup.json`
Figure 8 (search progress) | `python run.py experiments/search-progress.json`
Figure 9 (optimizations) | `python run.py experiments/optimizations.json`

Each of these experiments will produce output files—including a PDF graph—in the `data` folder, with the same name as the experiment.

#### Caching

The above experiments complete quickly because they are not doing any actual work.
Because the experiments take considerable time,
and many jobs within an experiment are reused across experiments,
the experiment runner *caches* results of each job to be reused.
We have pre-seeded the cache with results for every job necessary to reproduce the experiments above.

To ignore the cache, pass the `-f` flag to `run.py`.
For example:

```
python run.py -f experiments/all-benchmarks.json
```

This command will re-run all jobs necessary for Figure 6. **This will take several hours!**

The rough time required to run the experiments from scratch is as follows:

Figure | Command | Time
-------|---------|-----
Figure 6 (sequential performance) | `python run.py -f experiments/all-benchmarks.json` | 12&nbsp;hours
Figure 7 (parallel speedup) | `python run.py -n 8 experiments/parallel-speedup.json` | 24 hours
Figure 8 (search progress) | `python run.py -f experiments/search-progress.json` | 15 mins
Figure 9 (optimizations) | `python run.py -f experiments/optimizations.json` | 48 hours

#### Parallel Resources

Running the experiments above can be greatly accelerated by using parallelism.
The `-n` flag to `run.py` controls the number of cores it can use.
For example, running this command:

```
python run.py -f -n 2 experiments/all-benchmarks.json
```

will schedule the jobs for this experiment across two cores,
so the experiment will complete in about half the time.

The experiment runner will not respect a value for `-n` that is higher than the available CPUs.
The virtual machine is configured to use two cores,
so `-n 2` is the maximum.

Note that the `parallel-speedup` experiment requires at least 8 cores
because it will be using up to 8 threads for a single job.
This means that the parallel speedup experiment cannot be reproduced without reconfiguring the virtual machine (or using EC2, [as described below](#running-on-ec2-with-docker)).

### Smaller Experiments

We have provided smaller versions of some experiments,
which should complete in short enough time to be executed inside the virtual machine.
These experiments produce output in the same way as the full experiments:
three output files—including a PDF graph—in the `data` folder, with the same name as the experiment. 

Figure | Command | Time
-------|---------|-----
Figure 6 (sequential performance) | `python run.py -f experiments/small/all-benchmarks.json` | 5 mins
Figure 7 (parallel speedup) | `python run.py -f -n 8 experiments/small/parallel-speedup.json` | 15&nbsp;mins
Figure 9 (optimizations) | `python run.py -f experiments/small/optimizations.json` | 7 mins

**Because the larger benchmarks are excluded,
the aggregate results for Figures 7 and 9 will not be a fair representation of the results.**

Note that the `parallel-speedup` experiment still requires at least 8 cores—the experiment will not run with less than 8 cores,
and so cannot be run on the virtual machine unless its settings are changed.
We have also supplied a special small version of `parallel-speedup` that will run on the two cores the virtual machine is configured with:

```
python run.py -f -n 2 experiments/small/parallel-speedup-2cores.json
```

This experiment will complete in approximately 15 minutes.

### Demonstrations

The virtual machine also includes demonstrations for the claims in the paper about dynamic cost functions (Section 5.6).
They are separate from the experiment runner.
They can be run as follows (from the `~/opsyn` directory):

Demonstration | Command
--------------|--------
Least-squares regression | `racket benchmarks/demos/least-squares.rkt`
Worst-case execution time | `racket benchmarks/demos/wcet.rkt`
Neural network (not in paper) | `racket benchmarks/demos/neural.rkt`

These scripts also accept a `-v` flag to turn on Synapse's verbose output 
(equivalent to the `.out.txt` files from experiments above).

### Additional Resources

#### Running Synapse Manually

You can also run benchmarks individually, without going through the experiment runner.
The executable to do so is `benchmarks/run`
(which is a compiled version of the Racket program `benchmarks/run.rkt`).
To see the available options, run:

```
benchmarks/run -h
```

There are many command-line options to the benchmark runner.
To get an idea of which to use, consult the output of an experiment (an `.out.txt` file),
which contains the command used to run each benchmark.

#### Running on EC2 with Docker

To help reproduce the experiments at their full scale,
we are also providing a [Docker](http://www.docker.com) image that can be run on [Amazon EC2](https://aws.amazon.com/ec2/) (or some other machine).
This is the same setup we used for the paper.

We ran our experiments on a [c4.8xlarge](https://aws.amazon.com/ec2/pricing/) EC2 instance running the standard Ubuntu 14.04 AMI.
Docker is installed and set up in [the usual way](https://docs.docker.com/linux/started/).

Pull our Docker image:

```
sudo docker pull opsyn/synapse
```

and run it:

```
sudo docker run -ti -v ~:/host/home --name synapse opsyn/synapse bash
```

The Docker environment is the same as the VirtualBox virtual machine: the code resides in `~/opsyn` (which is `/root/opsyn` since the Docker user is root).
The c4.8xlarge instance has 36 cores, all of which will be available to the running Docker container.
We ran experiments using 31 cores to allow for some scheduling overhead; for example:

```
python run.py -f -n 31 experiments/parallel-speedup.json
```

This command completes in about 7 hours.
The `docker run` command above mounted the EC2 user's home directory at `/host/home` in the Docker container,
so to download data files from the experiment,
copy them into that directory from inside the Docker container, and then `scp` them from the EC2 instance.

### Source Code

All source code resides in the `~/opsyn` directory of the `synapse` user.
The source is arranged as follows:

* `benchmarks`: implementations of benchmarks used in the paper
* `opsyn`: core implementation of Synapse
* `test`: tests for Synapse and benchmarks

The core implementation of Synapse consists of:

* The global search implementation `opsyn/engine/search.rkt`
* The local search implementation `opsyn/engine/search-place.rkt`
* The incremental CEGIS implementation `opsyn/engine/solver+.rkt`

Metasketch implementations are in the `opsyn/metasketches` directory.