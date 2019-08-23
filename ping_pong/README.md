# PingPong

## Goal

The goal of this exercise is to connect Nodes together, send some messages
across them, and see what happens when those messages fail.

Each node starts a producer and a consumer. The Producer's job is to send
pings to Consumer's. It will do this by broadcasting them to all
consumer's on all connected nodes. Producers keep track of the number of
pings that they've sent. Consumer's keep a count of pings they've seen
from a each producer on each node.

## Helpful functions

In order to solve each of these problems it'll help to know about a few important OTP functions.

* `Node.list/0` - Lists all currently connected nodes.
* `GenServer.abcast/2` - Casts a message to a genserver with the name on all connected nodes.
* `GenServer.multi_call/2` - Calls a genserver with a given name on all connected nodes.
* `net_kernel.monitor_nodes/1` - Allows any process to monitor node up and node down events. Node events can be handled in the `handle_info` callback.


## Problem 1

In this problem you need to cast pings to all consumers.

## Problem 2

Now that we can broadcast pings to all consumers we need to check each
consumer to see what their current ping counts are.

## Problem 3

If our consumer crashes our states will get out of sync. In this exercise your
job is to recover gracefully from a crash. In this case we're going to do this
by having the consumer request the current ping count from each producer
when the consumer starts. To make this work you'll need to modify both the
consumer and the producer code.

We could have chosen to solve this problem with monitors. But monitors
have an inherent race condition where the producer could cast to
a consumer that isn't currently started yet. Using this demand driven
approach helps us to eliminate that race condition and is generally more
reliable.

## Problem 4

In our last exercise we're going to see how things fail when network
partitions occur. In order to create partitions between nodes we're using
a tool called Schism. By calling `Schism.partition/1` we can cause
a partition between nodes. When we want to heal the partition we can call
`Schism.heal/1`.

After a node is split from the network - or if a new node joins the
cluster - we need to catch them up on our latest status. In order to
accomplish we need our producer to monitor node events. When the producer
sees a new node join the cluster it should send a ping to the consumer
with its current ping count.

## Problem 4

In our last exercise we're going to see how things fail when network partitions occur. In order to create partitions between nodes we're using a tool called Schism. By calling `Schism.partition/1` we can cause a partition between nodes.
When we want to heal the partition we can call `Schism.heal/1`.

After a node is split from the network - or if a new node joins the cluster - we need to catch them up on our latest status. In order to accomplish we need our producer to monitor node events. When the producer sees a new node join the cluster it should send a ping to the consumer with its current ping count.

## Additional exercises

* In these exercises we only tested independent failures. What would happen if a consumer crashed during a partition? Would we be able to recover from this?
* Our Consumer's manage their own state. Which means if they crash this state is lost. Is there a way to pull apart the updating of the state and the storage of the state so we don't have to worry about crashes?
* We didn't test producer crashes. If we wanted to ensure that we didn't lose any data how could we protect ourselves against a producer crashing? What would happen if the producer crashed during a netsplit?
* Currently if anyone queries the consumer during a partition we have a high probability of returning incorrect data. If we wanted to always return the "correct" data what tradeoffs would we need to make?
