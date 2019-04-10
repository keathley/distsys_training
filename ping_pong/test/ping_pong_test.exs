defmodule PingPongTest do
  use ExUnit.Case
  doctest PingPong

  alias PingPong.{
    Consumer,
    Producer
  }

  setup do
    on_exit(fn ->
      try do
        Process.unregister(:consumer)
      rescue
        _ -> :ok
      end

      try do
        Process.unregister(:producer)
      rescue
        _ -> :ok
      end
    end)
  end

  test "consumers can subscribe to a producer" do
    producer = self()
    consumer = Consumer.start(producer)

    assert_receive {:hello, ^consumer}

    send(consumer, {:ping, 0})
    send(consumer, {:check, 1, self()})
    assert_receive :expected

    send(consumer, {:ping, 1})
    send(consumer, {:check, 2, self()})
    assert_receive :expected

    send(consumer, {:ping, 2})
    send(consumer, {:check, 3, self()})
    assert_receive :expected

    send(consumer, {:ping, 4})
    send(consumer, {:check, 5, self()})
    assert_receive {:unexpected, 3}

    send(consumer, {:ping, 3})
    send(consumer, {:check, 4, self()})
    assert_receive :expected
  end

  test "works when the producer fails" do
    producer = Producer.start(self())
    consumer = Consumer.start(producer)

    Producer.produce(producer)
    send(consumer, {:check, 1, self()})
    assert_receive :expected

    Producer.produce(producer)
    send(consumer, {:check, 2, self()})
    assert_receive :expected

    Producer.crash()
    :timer.sleep(100)
    send(consumer, {:check, 0, self()})
    assert_receive :expected
  end

  test "Works across a cluster" do
    nodes = LocalCluster.start_nodes("ping-pong-cluster", 2)
    [n1, n2] = nodes

    producer = :rpc.call(n1, Producer, :start, [self()])
    consumer = :rpc.call(n2, Consumer, :start, [producer])

    assert_receive {:starting, ^producer}

    send(consumer, {:check, 0, self()})
    assert_receive :expected

    :ok = Producer.produce(producer)
    send(consumer, {:check, 1, self()})
    assert_receive :expected

    :ok = Producer.produce(producer)
    send(consumer, {:check, 2, self()})
    assert_receive :expected

    # Split the consumer from the producer
    Schism.partition([n2])
    Schism.partition([n1])

    # Producing won't work now
    :ok = Producer.produce(producer)
    :ok = Producer.produce(producer)
    :ok = Producer.produce(producer)
    :ok = Producer.produce(producer)
    send(consumer, {:check, 2, self()})
    assert_receive :expected

    # Heal partition so that the consumer now sees the producer
    Schism.heal([n1, n2])

    # See if producing works now
    :ok = Producer.produce(producer)
    send(consumer, {:check, 7, self()})
    assert_receive :expected
  end
end
