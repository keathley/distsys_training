# Map Reduce

## Goal

In this exercise we're going to build our own version of a distributed map reduce.

## Part 1

The first step is to update the code found in `MapReduce.WordCount`. Your task
is to fill implement the map function and the reduce function. You can run
`mix test test/map_reduce_local_test.exs` to help you with this.

After you have a working version of word count you can run with a larger data
set. Running the following code should give you the answer listed below:

```
MapReduce.start_job("test", "priv/input.txt")
|> Enum.sort_by(fn {_, v} -> v end, &>=/2)
|> Enum.take(10)

# =>
[
  {"the", 62075},
  {"and", 38850},
  {"of", 34434},
  {"to", 13384},
  {"And", 12846},
  {"that", 12577},
  {"in", 12334},
  {"shall", 9760},
  {"he", 9666},
  {"unto", 8940}
]
```

## Part 2

Now that we have a working Map Reduce job we can focus on distributing the work
across multiple clusters.

You should feel free to change any of the existing code for
the master process in `MapReduce` in order to accomodate provide fault tolerance.
You're also welcome to look at the implementation of the workers or storage engine.
But you should not change this code.

You can run `mix test test/map_reduce_dist_test.exs` to test your implementation
across a local cluster. This test will inject faults into your network and
processes while it runs in order to ensure that you're handling different types of network and
node failures. While running these tests you might find it helpful to enable logging
in the `config.exs` file.

## Additional exercises

* Convert our simple processes to OTP compliant processes
* Intelligently re-distribute work across the cluster
* Think about ways that we could make our system perform better. Is it possible
  to start running reduce jobs earlier? Benchmark the system and see what
  improvements we can gain.

