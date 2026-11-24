### Benchee Jiffy Benchmark

This is clone of the Jason bench https://github.com/michalmuskala/jason with a
bunch more data sets from various other json benchmarks I found. The primary
use it to benchmark Jiffy against itself (release 1.1.3 vs release 2.0.0, etc),
but it can also test Jiffy against the built-in OTP `json` module and a few
other Erlang libraries (`glazer`, `jsone`, etc).

##### Pointing at a jiffy checkout

The scripts locate the jiffy checkout to benchmark:

 * `JIFFY_ROOT` environment variable:
   ```shell
   JIFFY_ROOT=~/src/jiffy ./bench.sh
   ```
 * Symlink:
   ```shell
   ln -s ~/src/jiffy jiffy
   ./bench.sh
   ```

##### Examples on how to run it:

Benchmark jiffy `master` branch against the current branch:
```shell
./bench.sh
```

Benchmark jiffy release `1.1.3` against the current branch:
```shell
./bench.sh 1.1.3
```

Benchmark jiffy release `1.1.3`, `jsone` and built-in `json` library against current branch:
```shell

./bench.sh --compare jsone,json 1.1.3
```

### Scheduler Responsiveness Test

One of the most important thing for Jiffy is to behave "well" in a busy Erlang
VM, which means not blocking schedulers, yielding properly, and not hogging
dirty schedulers (which is a rather limited resource). To test this behavior
there is separate `bench_scheduling` benchmark. This benchmark spawns parallel
pairs of proceses which encode, decode and then ping-pong a term back and forth
between them, while measuring both latency and throughput.

Example run with Jiffy 2.1.0. As concurrency increases there is more
pressure on GC and contention on dirty CPU scheduler. Jiffy's yielding
architecture proves its worth. The built-in json module does fairly well and
degrades predictably, too:

```shell
./bench_scheduling.sh
...
scheduler responsiveness check
  input:       citm-catalog.json duration: 2000
  schedulers:  12 online
  impls:       json, jiffy, glazer, jsone, jsx

[json]
  1x encdec                    n=20 p50=48.1ms p95=54.0ms p99=54.0ms max=80.1ms
  12x encdec                   n=108 p50=109.0ms p95=148.1ms p99=153.1ms max=168.5ms
  24x encdec                   n=99 p50=214.4ms p95=389.1ms p99=479.6ms max=525.5ms

[jiffy]
  1x encdec                    n=74 p50=13.0ms p95=16.8ms p99=29.7ms max=44.8ms
  12x encdec                   n=424 p50=28.2ms p95=35.5ms p99=40.6ms max=45.0ms
  24x encdec                   n=404 p50=59.2ms p95=98.0ms p99=122.1ms max=146.6ms

[glazer]
  1x encdec                    n=182 p50=5.2ms p95=7.2ms p99=10.4ms max=31.8ms
  12x encdec                   n=202 p50=62.9ms p95=114.9ms p99=120.6ms max=121.8ms
  24x encdec                   n=166 p50=141.7ms p95=203.7ms p99=305.7ms max=305.7ms

[jsone]
  1x encdec                    n=12 p50=77.5ms p95=99.3ms p99=99.3ms max=115.9ms
  12x encdec                   n=60 p50=182.6ms p95=225.0ms p99=232.2ms max=234.7ms
  24x encdec                   n=68 p50=353.8ms p95=525.3ms p99=588.4ms max=598.5ms

[jsx]
  1x encdec                    n=6 p50=150.0ms p95=166.2ms p99=166.2ms max=259.1ms
  12x encdec                   n=36 p50=309.7ms p95=615.9ms p99=619.6ms max=636.0ms
  24x encdec                   n=24 p50=1086.7ms p95=1263.9ms p99=1355.0ms max=1405.5ms
```
