### Benchee Jiffy Benchmark

This is clone of the Jason bench https://github.com/michalmuskala/jason with a
bunch more data sets from various other json benchmarks I found. The primary
use it to benchmark Jiffy against itself (release 1.1.3 vs release 2.0.0, etc),
but it can also test Jiffy against the built-in OTP `json` module and a few
other Erlang libraries.

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

Example run with Jiffy 2.0.0

```shell
./bench_scheduling.sh
...
scheduler responsiveness check
  input:       citm-catalog.json duration: 2000
  schedulers:  12 online
  impls:       json, jiffy, simdjsone, jsone, jsx

[json]
  1x encdec                    n=84 p50=135.0ms p95=182.9ms p99=191.9ms max=196.7ms
  12x encdec                   n=86 p50=129.7ms p95=189.9ms p99=203.0ms max=206.2ms
  24x encdec                   n=87 p50=263.0ms p95=461.2ms p99=506.1ms max=527.1ms

[jiffy]
  1x encdec                    n=309 p50=38.3ms p95=51.9ms p99=57.4ms max=66.5ms
  12x encdec                   n=300 p50=41.2ms p95=52.5ms p99=59.7ms max=66.2ms
  24x encdec                   n=306 p50=80.2ms p95=111.8ms p99=118.8ms max=140.1ms

[simdjsone]
  1x encdec                    n=20 p50=690.1ms p95=784.6ms p99=784.6ms max=784.8ms
  12x encdec                   n=16 p50=790.9ms p95=887.5ms p99=887.5ms max=899.9ms
  24x encdec                   n=24 p50=1448.4ms p95=1876.7ms p99=1879.5ms max=1882.7ms

[jsone]
  1x encdec                    n=60 p50=213.1ms p95=261.8ms p99=263.9ms max=264.8ms
  12x encdec                   n=60 p50=204.9ms p95=329.8ms p99=345.0ms max=350.9ms
  24x encdec                   n=52 p50=440.1ms p95=700.3ms p99=773.3ms max=817.3ms

[jsx]
  1x encdec                    n=24 p50=398.8ms p95=539.0ms p99=544.1ms max=548.3ms
  12x encdec                   n=24 p50=391.5ms p95=684.9ms p99=687.0ms max=689.6ms
  24x encdec                   n=24 p50=1181.3ms p95=1479.0ms p99=1558.1ms max=1654.7ms
```
