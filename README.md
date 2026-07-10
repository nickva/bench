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

Example run with Jiffy 2.0.2. As concurrency increases there is more
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
  1x encdec                    n=108 p50=109.5ms p95=166.3ms p99=170.2ms max=172.2ms
  12x encdec                   n=108 p50=110.2ms p95=162.2ms p99=169.1ms max=170.7ms
  24x encdec                   n=97 p50=221.7ms p95=366.6ms p99=404.3ms max=425.7ms

[jiffy]
  1x encdec                    n=364 p50=32.4ms p95=41.3ms p99=46.3ms max=49.8ms
  12x encdec                   n=382 p50=31.2ms p95=38.5ms p99=43.6ms max=48.1ms
  24x encdec                   n=373 p50=65.4ms p95=97.7ms p99=118.8ms max=146.6ms

[glazer]
  1x encdec                    n=24 p50=242.6ms p95=712.4ms p99=712.4ms max=713.2ms
  12x encdec                   n=24 p50=245.7ms p95=844.2ms p99=849.1ms max=855.6ms
  24x encdec                   n=24 p50=1398.2ms p95=1628.4ms p99=1632.5ms max=1639.5ms

[jsone]
  1x encdec                    n=60 p50=188.6ms p95=234.8ms p99=237.0ms max=237.2ms
  12x encdec                   n=60 p50=187.4ms p95=331.4ms p99=338.5ms max=351.5ms
  24x encdec                   n=62 p50=359.2ms p95=570.7ms p99=601.3ms max=687.6ms

[jsx]
  1x encdec                    n=36 p50=305.1ms p95=449.3ms p99=455.5ms max=458.5ms
  12x encdec                   n=36 p50=310.3ms p95=657.2ms p99=666.8ms max=674.6ms
  24x encdec                   n=24 p50=1068.3ms p95=1203.0ms p99=1368.8ms max=1387.9ms
```
