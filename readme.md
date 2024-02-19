# CPU Determinism: How deterministic is your CPU?

CPU Determinism is an attempt to measure and quantify how deterministic your CPU is. It currently works on a natively installed Ubuntu and has been tested on two CPUs so far; Intel and AMD.

How it works TLDR: The shell script pins the CPU scaling frequency to either high or low, and runs n iterations of a supposedly deterministic sequence of loops, first without other CPUs active, and second with all other CPUs active. The individual runs are timed in 4 different ways; `clock_gettime(CLOCK_MONOTONIC)`, `gettimeofday()`, `rdtsc` CPU instruction, and with no timing. Each loop is timed 200 times to hopefully measure a loop without kernel interrupts. The loop code is pinned to a particular CPU, and runs at the highest priority. While the loops are running, various monitoring is also happening; top CPU, CPU temparature, CPU scaling frequency, and ntp clock drift. All findings are logged to single folder, so it's hopefully easy to push the results of many unique CPU determinism tests to this repo.

## How to run `test-cpu-determinism`

```
$ git clone https://github.com/simonhf/cpu-determinism.git
$ cd cpu-determinism
$ export USE_ITERATIONS="100" USE_SCALING_FREQ="scaling_max_freq" ; ./test-cpu-determinism.sh
$ export USE_ITERATIONS="100" USE_SCALING_FREQ="scaling_min_freq" ; ./test-cpu-determinism.sh
```
## How to read `test-cpu-determinism` run logs

TODO

## Examine variance anomalies and try to explain them

TODO

## Quantifying a particular `test-cpu-determinism` run

TODO

## FAQ

### What are the known causes of variance while running benchmarks?

Some of the reasons are listed in this Google Benchmark project [1], e.g.:
* Different CPU cores can run at different speeds.
* The CPU might use a scaling frequency to dynamically change speed.
* Process context switching between CPUs is not free.
* Intel hyper threads or AMD SMT can slow down its neighboring cores.
* CPU memory cache effects.
* Non-uniform memory architectures, e.g. NUMA.

Other reasons:
* Interrupts from the OS.
* The timer itself may drift or not be accurate enough.
* The `rdtsc` instruction can on some CPUs vary depending upon the core.
* The `rdtsc` instruction can on some CPUs vary depending upon the CPU scaling frequency.
* Other reasons yet to be determined but visible via `test-cpu-determinism`.

[1] https://github.com/google/benchmark/blob/main/docs/reducing_variance.md

### How does `test-cpu-determinism` attempt to work-around benchmark variance?

In theory all known causes of variance are mitigated as follows:
* By re-running benchmarks repeatedly, some runs should run without interrupts.
* Pin process to a single core to avoid CPU memory cache effects.
* Pin process to a single core to avoid context switching overhead.
* Pin process to a single core to avoid context switching to a faster / slower core.
* Pin process to a single core to avoid `rdtsc` core variance.
* Pin CPU scaling frequency either high or low to avoid CPU scaling frequency variance.
* Pin CPU scaling frequency either high or low to avoid `rdtsc` variance bugs.
* Set benchmark to highest priority AKA niceness to avoid context switch overhead.
* Run benchmark with and without noisy neighbor cores.
* Benchmark is a simple loop to avoid use of CPU memory cache.
* Monitor any timer drift via ntp logs during benchmark.

### Will `test-cpu-determinism` run in the cloud, e.g. on AWS, GCP, etc

Unlikely to give accurate results, because most cloud instances do not allow pinning the CPU scaling frequency. Why? Likely because the cloud provider wants to be in control of this themselves, and therefore in control of how hot their racks get?

An exception maybe e.g. AWS arm64 platforms which have neither hyper threading nor CPU frequency scaling, and therefore run cooler and in theory more deterministically anyway?

Therefore, to run `test-cpu-determinism` with accurate results, ideally Ubuntu should be installed natively, and not in a cloud environment.

### Will `test-cpu-determinism` run in a Ubuntu guest in a virtual environment?

Unlikely to give accurate results, because virtual environments:
* Do not allow proper pinning of processes to cores (on host as well as guest).
* Suffer from even more interrupts from both the guest and host OSs.

### Why use different mechanisms to time the benchmark loops?

One word: Paranoia :-)

TODO

### What was the motivation for creating CPU Determinism?

TODO
