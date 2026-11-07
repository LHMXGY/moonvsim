# Simulator throughput

Design: `examples/bench.v` (`bench_tb`), 200,000 simulated ns = 20,000 clock cycles.
Best of 3 runs, wall clock, process start included.

| simulator | wall time | cycles / s | final state |
| --- | --- | --- | --- |
| moonvsim | 531 ms | 37,662 | `bench done sum=26dfe118 prod=4c9b18d7` |
| iverilog | 74 ms | 269,438 | `bench done sum=26dfe118 prod=4c9b18d7` |

Both simulators report the same final state.

