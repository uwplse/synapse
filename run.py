#!/usr/bin/env python
import argparse
import collections
from cpuinfo import cpuinfo
import datetime
import hashlib
import json
import multiprocessing
import os
import psutil
import signal
import subprocess32 as subprocess
import sys
import tempfile
import time


# default arguments that experiments can override
DEFAULT_ARGUMENTS = {
    "verbose": True,
    "unbuffered": True,
    "threads": 1,
}


# benchmarks groups that can be used as shorthand
BENCHMARK_GROUPS = {
    'hd-d0': [('(hd-d0 %d)' % (i+1)) for i in xrange(20)],
    'hd-d5': [('(hd-d5 %d)' % (i+1)) for i in xrange(20)],
    'parrot': ['(fft-sin)', '(fft-cos)', 
               '(inversek2j-theta1)', '(inversek2j-theta2)', 
               '(sobel-x)', '(sobel-y)', '(kmeans)'],
    'arraysearch': ['(array-search %d)' % i for i in xrange(2, 16)],
    'max': ['(max %d)' % i for i in xrange(2, 10)],
    'qm': ['(qm qm_choose_01)', '(qm qm_choose_yz)'] + 
          ['(qm qm_loop_%d)' % i for i in xrange(1,4)] + 
          ['(qm qm_max%d)' % i for i in xrange(2,4)] +
          ['(qm qm_neg_%d)' % i for i in xrange(1,5)] + 
          ['(qm qm_neg_eq_%d)' % i for i in xrange(1,3)]
}
BENCHMARK_TO_GROUP = {
    bm: grp for grp in BENCHMARK_GROUPS for bm in BENCHMARK_GROUPS[grp]
}


# a job is a single execution of racket
Job = collections.namedtuple("Job", ["id", "command", "threads", "timeout", "ident"])

## experiment configuration parsing ############################################

# input: a list of benchmarks, possibly including shorthand
# output: a list of (benchmark, group) tuples, where each benchmark is singular
def expand_benchmarks(benchmarks):
    ret = []
    seen = set()
    for bm in benchmarks:
        if bm in BENCHMARK_GROUPS:
            for b in BENCHMARK_GROUPS[bm]:
                if (b, bm) not in seen:
                    ret.append((b, bm))
                    seen.add((b, bm))
        else:
            grp = BENCHMARK_TO_GROUP.get(bm, bm)
            if (bm, grp) not in seen:
                ret.append((bm, grp))
                seen.add((bm, grp))
    return ret


# input: a dictionary of arguments
# output: a list of command-line arguments
def arguments_to_command_line(args):
    cmd = []
    # canonicalize arguments by sorting keys
    for k in sorted(args):
        v = args[k]
        if k == "timeout":
            pass  # used only by this running script, not racket
        elif k == "solver_timeout":
            cmd.extend(["-t", str(v)])
        elif k == "verbose":
            if v: cmd.extend(["-v"])
        elif k == "debug":
            if v: cmd.extend(["-vv"])
        elif k == "bitwidth":
            cmd.extend(["-b", str(v)])
        elif k == "error":
            cmd.extend(["-e", str(v)])
        elif k == "unbuffered":
            if v: cmd.extend(["-u"])
        elif k == "threads":
            cmd.extend(["-n", str(v)])
        elif k == "use_structure_constraints":
            if not v: cmd.extend(["-s"])
        elif k == "exchange_cex":
            if not v: cmd.extend(["-c"])
        elif k == "exchange_costs":
            if not v: cmd.extend(["-x"])
        elif k == "incremental_cegis":
            if not v: cmd.extend(["-i"])
        elif k == "order":
            cmd.extend(["-o", str(v)])
        elif k == "widening":
            if v: cmd.extend(["-w"])
        elif k == "solver":
            cmd.extend(["-r", str(v)])
        else:
            raise Exception("unrecognized argument '%s'" % k)
    return cmd


# input: an id number, a dictionary of arguments, a benchmark name, 
#        and an identifier dict
# output: an instance of Job
def create_job(num, args, bm, ident):
    assert "threads" in args
    assert "timeout" in args
    # where is benchmarks/run.rkt?
    cwd = os.path.dirname(os.path.realpath(__file__))
    run_path = os.path.join(cwd, "benchmarks/run.rkt")

    cmd = ["racket", run_path] + arguments_to_command_line(args) + [bm]
    threads = args["threads"]
    timeout = args["timeout"]

    return Job(num, cmd, threads, timeout, ident)


# expand an experiment definition into a set of jobs
def generate_jobs(exp, only=None):
    # predicate to subset benchmarks according to `only`
    if only:
        include_bm = lambda bm, grp: bm in only or grp in only
    else:
        include_bm = lambda bm, grp: True

    # overlay the experiment's global arguments on the defaults
    default_args = DEFAULT_ARGUMENTS.copy()
    default_args.update(exp.get("arguments", {}))
    default_benchmarks = exp.get("benchmarks", [])

    # if there are no configurations, the configuration is the global arguments
    configs = exp.get("configurations", [exp])

    # build up jobs
    jobs = []
    for config in configs:
        args = default_args.copy()
        args.update(config.get("arguments", {}))
        benchmarks = default_benchmarks + config.get("benchmarks", [])
        benchmarks = expand_benchmarks(benchmarks)
        for bm, grp in benchmarks:
            if include_bm(bm, grp):
                ident = config.get("id", {}).copy()
                ident["group"] = grp
                ident["benchmark"] = bm
                job = create_job(len(jobs), args, bm, ident)
                jobs.append(job)

    return jobs


## job running #################################################################

# compile benchmarks/run.rkt into an executable
def compile_runner():
    # where is it?
    cwd = os.path.dirname(os.path.realpath(__file__))
    run_path = os.path.join(cwd, "benchmarks/run.rkt")

    # compile it
    print "compiling benchmark runner..."
    subprocess.check_call(["raco", "make", run_path])


# execute a single job and send it back on the queue
def run_job(queue, job):
    # multiprocessing: don't capture ctrl+c
    signal.signal(signal.SIGINT, signal.SIG_IGN)

    output_file = tempfile.NamedTemporaryFile(bufsize=8, delete=False)
    output_file.write("experiment: %s\n" % " ".join(sys.argv))
    output_file.write("start: %s\n" % datetime.datetime.now())
    output_file.write("cpu: %s\n" % cpuinfo.get_cpu_info()['brand'])
    if sys.platform.startswith("linux"):
        output_file.write("affinity: %s\n" % psutil.Process().cpu_affinity())
    output_file.write("\n")
    output_file.write("cmd: %s\n" % " ".join(job.command))
    output_file.write("\n")
    output_file.flush()

    queue.put(("start", job, output_file.name))

    t = time.time()
    proc = subprocess.Popen(job.command, stderr=subprocess.STDOUT,
                              stdout=output_file)
    timed_out = False

    try:
        out, err = proc.communicate(timeout=job.timeout)
        t = time.time() - t
    except subprocess.TimeoutExpired:
        parent = psutil.Process(proc.pid)
        for c in parent.children(recursive=True):
            try:
                c.kill()
            except:
                pass
        try:
            proc.kill()
        except:
            pass
        out, err = proc.communicate()
        t = job.timeout
        timed_out = True

    f = open(output_file.name)
    out = f.read()
    f.close()
    output_file.close()

    queue.put(("end", job, t, timed_out, out))


# return the cache key for a given job
def cache_key(job):
    m = hashlib.sha1()
    m.update(" ".join(job.command[2:]))  # ignore executable
    return m.hexdigest()


def execute_jobs(jobs, threads, job_name, output_dir, plot_file, args):
    # set up the cache
    cache_dir = os.path.join(output_dir, "cache")
    if not os.path.exists(cache_dir):
        os.mkdir(cache_dir)
    # find things in the cache if we're allowed
    cached = []
    if not args.force:
        for job in jobs[:]:
            key = cache_key(job)
            path = os.path.join(cache_dir, key + ".json")
            if os.path.exists(path):
                cached.append((job, path))
                jobs.remove(job)

    if args.dry_run:
        if cached:
            print "in cache:"
            for i, (job, path) in enumerate(cached):
                print "  %d: %s (%s)" % (i, " ".join(job.command),
                                         cache_key(job))
            if jobs:
                print ""
        if jobs:
            print "to run:"
            for i, job in enumerate(jobs):
                print "  %d: %s" % (i, " ".join(job.command))
        sys.exit(0)

    # do we have enough actual threads to run every remaining job?
    if threads == -1:
        threads = psutil.cpu_count()
    else:
        threads = min(psutil.cpu_count(), threads)
    needed_threads = max([0] + [job.threads for job in jobs])
    if needed_threads > threads:
        raise Exception("not enough threads: need %d, have %d" % (
                          needed_threads, threads))

    # compile benchmark runner if necessary
    if jobs:
        compile_runner()

    # output files
    data_file = open(os.path.join(output_dir, "%s.out.csv" % job_name), "w")
    output_file = open(os.path.join(output_dir, "%s.out.txt" % job_name), "w")
    output_file.write("experiment: %s\n" % " ".join(sys.argv))
    output_file.write("start: %s\n" % datetime.datetime.now())
    output_file.write("cpu: %s\n" % cpuinfo.get_cpu_info()['brand'])
    header_printed = False

    def on_job_complete(job, t, timed_out, out):
        # write to data file
        if not header_printed:
            keys = sorted(job.ident) + ["time", "timeout"]
            data_file.write(",".join("\"%s\"" % k for k in keys) + "\n")
        for k in sorted(job.ident):
            data_file.write("\"%s\"," % job.ident[k])
        data_file.write("%.3f,%s\n" % (t, timed_out))
        data_file.flush()

        # write to output file
        output_file.write("*** %s\n" % job.ident)
        output_file.write(out.encode('utf8', 'replace'))
        output_file.write("*** %s\n" % (
                            "timeout (%s)" % t if timed_out else t))
        output_file.flush()

    # first process all results that are cached
    for job, path in cached:
        with open(path) as f:
            data = json.load(f)
        cmd = " ".join(job.command)
        print "cached: %s\n  (%s)" % (cmd, cache_key(job))
        on_job_complete(job, data["time"], data["timed_out"], data["out"])
        header_printed = True

    total_jobs = len(jobs)

    running_jobs = {}
    threads_used = 0
    cpus = range(psutil.cpu_count())
    queue = multiprocessing.Queue()

    # schedule jobs in descending order of threads so we can use smaller jobs to
    # fill gaps
    jobs = sorted(jobs, key=lambda j: j.threads, reverse=True)

    # spawn jobs that use at most a given number of threads on the given cpus
    def launch_more_jobs(threads, cpus):
        threads_used = 0
        cpus_available = cpus
        for job in jobs[:]:
            if threads_used + job.threads <= threads:
                my_cpus = cpus_available[:job.threads]
                cpus_available = cpus_available[job.threads:]
                p = multiprocessing.Process(target=run_job, args=(queue, job))
                p.start()
                if sys.platform.startswith("linux"):
                    pp = psutil.Process(p.pid)
                    pp.cpu_affinity(my_cpus)
                running_jobs[job.id] = (p, my_cpus)
                threads_used += job.threads
                jobs.remove(job)
                if args.sequential:
                    break
        return threads_used, cpus_available

    # spawn initial threads
    threads_used, cpus = launch_more_jobs(threads, cpus)

    while running_jobs:
        evt = queue.get()
        if evt[0] == "start":
            start, job, output_name = evt
            cmd = " ".join(job.command)
            status = "[%d jobs: %d complete, %d running, %d remaining]" % (
                        total_jobs, total_jobs - len(running_jobs) - len(jobs),
                        len(running_jobs), len(jobs))
            print "starting: %s\n  --> %s\n  %s" % (cmd, output_name, status)
        elif evt[0] == "end":
            end, job, t, timed_out, out = evt

            # write to data file
            on_job_complete(job, t, timed_out, out)
            header_printed = True

            # write to cache
            key = cache_key(job)
            path = os.path.join(cache_dir, key + ".json")
            with open(path, "w") as f:
                json.dump({"command": job.command, "time": t, 
                           "timed_out": timed_out, "out": out}, 
                           f, indent=2)

            p, c = running_jobs[job.id]
            p.join()
            del running_jobs[job.id]
            threads_used -= job.threads
            cpus = sorted(cpus + c)

            status = "[%d jobs: %d complete, %d running, %d remaining]" % (
                        total_jobs, total_jobs - len(running_jobs) - len(jobs),
                        len(running_jobs), len(jobs))
            print "finished: %s\n  %s" % (" ".join(job.command), status)

            t, c = launch_more_jobs(threads - threads_used, cpus)
            threads_used += t
            cpus = c

    output_file.close()
    data_file.close()

    if plot_file and not args.no_post_process:
        path = os.path.join(os.getcwd(), "experiments/plots/" + plot_file)
        if not os.path.exists(path):
            print "plot file not found: %s" % plot_file
        else:
            print "running post-process file %s..." % plot_file
            subprocess.check_call(["python", path, job_name], cwd=output_dir,
                                      stderr=subprocess.STDOUT)


## main ########################################################################

if __name__ == "__main__":
    p = argparse.ArgumentParser(description='Synapse experiment runner')
    p.add_argument("file", help="experiment file to run")
    p.add_argument("--dry-run", action="store_true", 
                     help="only list the jobs to execute")
    p.add_argument("-n", "--threads", type=int, default=1, 
                     help="total number of threads to run in parallel")
    p.add_argument("--output-dir", help="directory to output to")
    p.add_argument("-f", "--force", action="store_true",
                     help="ignore cached results")
    p.add_argument("-np", "--no-post-process", action="store_true",
                     help="do not run post-process file")
    p.add_argument("-s", "--sequential", action="store_true",
                     help="run one job at a time regardless of threads")
    p.add_argument("--only", help="only run specified benchmarks (useful for"
                                  "partitioning across nodes")
    args = p.parse_args()

    with open(args.file) as f:
        experiment = json.load(f)

    only = args.only.split(",") if args.only is not None else None
    jobs = generate_jobs(experiment, only)

    job_name = os.path.splitext(os.path.basename(args.file))[0]
    if not job_name:
        job_name = "experiment"

    output_dir = args.output_dir
    if not output_dir:
        output_dir = os.path.join(
                       os.path.dirname(os.path.realpath(__file__)), 
                       "experiments/data")
    if not os.path.exists(output_dir):
        os.mkdir(output_dir)

    plot = experiment.get("plot", None)

    execute_jobs(jobs, args.threads, job_name, output_dir, plot, args)

