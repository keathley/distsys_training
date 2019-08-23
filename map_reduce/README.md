# Map Reduce

## Goal

In this exercise we're going to build our own version of a distributed map reduce.


## Problem 1

In order to distribute work across our cluster we need to have a way of starting
workers on other nodes.

## Problem 2




## Map Reduce Overview & Architecture

A Map Reduce takes the problem of processing large data sets and breaks it into
two stages that can be scaled independently. The stages are, unsurprisingly, the
map stage and the reduce stage.

A master process is started with a given input file, a name for the job,
and a user defined map and reduce function. The master process then splits
this input file into a set of chunks and writes each chunk to storage with
a key derived from its job id. The master then waits for available
workers. In our examples and tests these worker processes are started
manually (although we will make updates to this as we go forward). Once
workers have connected the master process sends out "map" jobs to all of
them until all of the map jobs have been completed.

During the map stage workers are given a specific job id (in our example
these ids are just integers). The worker pulls the chunk for that map job
out of storage and hands the chunk to the user defined `map` function. The
user `map` function can then break that chunk into a list of key-value
maps like: `%{key: term(), value: term()}`. This worker uses the result of
the user's `map` function and groups the values by hashing the key and
taking the mod of the number of reduce jobs. The purpose of this hashing
is to ensure that a single reduce job processes all occurences of a given
key even across multiple map jobs.

Once the map stage has been finished the master process then begins
sending workers "reduce" jobs. During the reduce stage the workers are
again given an job id. They look up any output from any of the map jobs
for that id. The worker then sorts and groups all of the stored values by
key and passes both the key and list of grouped values to the users
`reduce/2` function. The users `reduce/2` function is responsible for
outputting a final value for the given key. The worker takes the output
from the users `reduce` function and stores the output as a list of
`%{key: key, value: output_from_user_reduce()}`.


Once both of these stages have been finished the master process pulls all
of the reduce job results from storage and merges them all together. The
master process then sends a message back to the calling process.

## Questions to consider

Here are a few things to think about as you're going through this
exercise:

* Why do the workers write values to intermediate storage instead of
  sending the results back to the master process?
* What about the map reduce design makes it easier to handle faults
  in the system?

## Part 1

The first step is to update the code found in `MapReduce.WordCount`. Your task
is to implement a map reduce job for counting words. You can run
`mix test test/map_reduce_local_test.exs` to check your implementation.

After you have a working version of word count you can test your implementation with a larger data
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
across multiple nodes and handling failures.

In this step you will need to update the code found in the `MapReduce` module.
Specifically you'll want to update and change the code for controlling the "master"
process. You're welcome to look at how `MapReduce.Worker`, `MapReduce.Storage`
and `MapReduce.FileUtil` are implemented but you should not change any of this
code.

Running `mix test test/map_reduce_dist_test.exs` will run the master process
and inject failures into both the local network and the worker processes.

It may be helpful to output more verbose logging and sasl reports while you're
debugging your solution. You can do this by updating your logger configuration
in `config.exs` with the settings below:

```elixir
config :logger,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  level: :debug
```

## Additional exercises

If you get through these exercises then here are some ideas for further improvements:

* Currently our system can only run 1 job at a time. How could we extend this
system to support multiple concurrent jobs?
* Our manager is currently a single point of failure. If the manager dies
our workers will be orphaned. How can we provide more faul-tolerance here?
What would happen if we separated the work of managing workers from managing
the jobs themselves.




* Convert our simple processes to OTP compliant processes
* Intelligently re-distribute work across the cluster. Is there a more "fair"
  way to distribute work across our nodes? How can we avoid a situation where
  one node ends up with more work then the rest?
* There are practical limits for monitors across nodes. Is there a way we could
  determine if our workers have crashed without the use of monitors? Is there
  a way to determine our workers have finished without needing the worker to
  tell us they're finished?
* Think about ways that we could make our system perform better. Is it possible
  to start running reduce jobs earlier? Benchmark the system and see what
  improvements we can gain.
