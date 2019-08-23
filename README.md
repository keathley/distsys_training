# Distributed Systems Training in Elixir

This training is divided into 4 parts. Each part is designed to teach you
concepts about distributed systems, the ways that they fail, and how to utilize
some of the tools available in erlang and elixir to help mitigate those failures.

## Requirements

You'll need these things installed or available in order to go through
this training.

* Elixir >= 1.9.1
* Erlang >= 22.0.7
* Redis

## Initial Setup

Run through these steps before starting on the examples. These should help
ensure that your system is set up correctly.

### Check VPNs or Firewall rules

In other trainings we've seen issues with corporate vpns or firewalls. These
issues typically cause connections to be very slow or not connect at all.
You may need to temporarily disable these or add rules to allow epmd and
erlang to open ports on your local machine.

If you're on macos then the first time you start a node with distribution
turned on then you may see a prompt to allow epmd open network
connections. You want to allow this.

### Ensure you can connect nodes

You'll find it useful to run multiple nodes simultaneously for debugging
and testing. There are many ways to do this such as tmux, emacs buffers,
split terminal windows, or whatever other method works for you. We want to
ensure that you can connect nodes together before we move on.

* Open up two terminal windows using whatever method you like.
* In window 1: run `iex --name gold@127.0.0.1`
* In window 2: run `iex --name silver@127.0.0.1`
* In window 1: run `Node.connect(:"silver@127.0.0.1")`
* In window 2: run `Node.list()`. The output should be
  `[:"gold@127.0.0.1"]`

If you have an error during any of these steps please ask Chris or Ben for
help.

## Part 1 - Ping Pong - ping_pong

Part 1 provides a rough overview of connecting erlang nodes. We will see
how to start processes on specific nodes, some of the failure scenarios
when BEAMs disconnect, sending RPCs and other fundamental concepts.

## Part 2 - Map Reduce

Part 2 starts with a local only implementation of map reduce. Your task
will be to make this map reduce implementation more robust against worker
failure. It'll also explain message delivery guarantees and demonstrate
the benefit of idempotent messages.

## Part 3 - Link Shortener (Margarine)

In Part 3 we start with a simple link shortener and make it more reliable
and decrease its overall latency by replicating our state across
a cluster. We'll learn about the distributed process registries available
in erlang and elixir and how we can utilize them.

## Part 4 - Improving our Link Shortener

Part 4 builds on the latency improvements we made to our link shortener in part 3. In this section we will look at more efficient ways of replicating our state across the cluster and add aggregates for how often people view our links.

## Why do this use Distributed Erlang?

This training uses standard, distributed erlang. While there are many limitations
and issues with dist-erl the goal of this training is not to promote a specific
tool but instead to teach the underlying concepts that are universal to
all distributed systems. Dist-erl provides the lowest barier for doing
that. We make no attempt to hide the issues with dist-erl. If you need
a more robust solution you should look at Partisan.
