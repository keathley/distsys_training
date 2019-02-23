defmodule PingPongTest do
  use ExUnit.Case
  doctest PingPong

  import ExUnit.CaptureLog

  alias PingPong.{
    Consumer,
    Producer,
  }

  test "consumers can subscribe to a producer" do
    producer = self()
    consumer = Consumer.start(producer)

    assert_receive {:hello, ^consumer}

    assert capture_log(fn ->
      send(consumer, {:ping, 0})
    end) =~ "Received expected value: 0"

    assert capture_log(fn ->
      send(consumer, {:ping, 1})
    end) =~ "Received expected value: 1"

    assert capture_log(fn ->
      send(consumer, {:ping, 2})
    end) =~ "Received expected value: 2"

    assert capture_log(fn ->
      send(consumer, {:ping, 4})
    end) =~ "Received unexpected value: 4"

    assert capture_log(fn ->
      send(consumer, {:ping, 5})
    end) =~ "Received expected value: 5"
  end

  test "Works across a cluster" do
    nodes = LocalCluster.start_nodes("ping-pong-cluster", 2)
    [n1, n2] = nodes

    producer = :rpc.call(n1, Producer, :start, [self()])
    consumer = :rpc.call(n2, Consumer, :start, [producer])

    assert_receive {:starting, ^producer}

    send(consumer, {:expected_value, self()})
    assert_receive {:value, 0}

    :ok = Producer.produce(producer)
    send(consumer, {:expected_value, self()})
    assert_receive {:value, 1}

    :ok = Producer.produce(producer)
    send(consumer, {:expected_value, self()})
    assert_receive {:value, 2}

    # Split the consumer from the producer
    Schism.partition([n2])
    Schism.partition([n1])

    # Producing won't work now
    :ok = Producer.produce(producer)
    :ok = Producer.produce(producer)
    :ok = Producer.produce(producer)
    :ok = Producer.produce(producer)
    send(consumer, {:expected_value, self()})
    assert_receive {:value, 2}

    # Heal partition so that the consumer now sees the producer
    Schism.heal([n1, n2])

    # See if producing works now
    :ok = Producer.produce(producer)
    send(consumer, {:expected_value, self()})
    assert_receive {:value, 7}
  end
end

