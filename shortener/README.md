# Shortener

## Goal

Our goals to build a link shortener utilizing distributed erlang.

## Problem 1

In this first example were going to take a full url and convert it to a short code,
cache that short code in an in-memory cache, store that short code in a database,
and finally broadcast the short codes across the cluster.

## Problem 2

Now that we have our nodes connected and sharing links we want to make our distribution,
more efficient. Currently we're doing full replication of all of our links. This
is pretty inefficient. In this exercise we're going to update our replication
strategy to send specific links to specific nodes. We'll do this using a technique
known as Consistent Hashing. We're going to use the ExHashRing library to accomplish this.
You will need to implement a function to rebuild the hash ring on demand. In our
tests we'll store the known set of nodes in the cluster. You will need to implement
a function to read the cluster from Redis and use it to rebuild the hash ring.

Once the hash ring has been built you can change the replication logic to send
creates to a specific node in the cluster. You will also need to change the
lookup logic to do lookups from a remote node.

Because our cache is based on ets you won't be able to get cache results from ets
directly. You'll need to build a way to call a remote function on a node and
send yourself the results from the lookup back. You may find `Task.Supervisor`
and the docs for `Task.async` when used with remote nodes to be helpful here.

## Problem 3

In the final exercise we're going to keep track of how many times a short code
has been redirected to. We're going to do this by first building a Grow Only Counter CRDT
(GCounter). Once this is done we're going to store each gcounter in a genserver,
increment each gcounter locally, and then broadcast it to all other nodes. Finally
we're going to support node disconnects and re-connects by catching up any
missed messages during a netsplit.

### GCounter
