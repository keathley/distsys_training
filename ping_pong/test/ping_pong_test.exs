defmodule PingPongTest do
  use ExUnit.Case

  alias PingPong.{
    Consumer,
    Producer
  }

  setup_all do
    Application.ensure_all_started(:ping_pong)

    :ok
  end

  setup do
    nodes = LocalCluster.start_nodes("ping-pong", 2)
    GenServer.multi_call(Consumer, :flush)
    GenServer.multi_call(Producer, :flush)

    on_exit fn ->
      LocalCluster.stop_nodes(nodes)
    end

    {:ok, nodes: nodes}
  end

  test "producer sends pings to each connected nodes consumer", %{nodes: nodes} do
    [n1, n2] = nodes
    assert :ok == Producer.send_ping()
    assert :ok == Producer.send_ping({Producer, n2})
    assert :ok == Producer.send_ping({Producer, n1})

    for n <- nodes do
      assert Consumer.total_pings({Consumer, n}) == 3
    end
  end

  test "producer can check the state of each connected consumer", %{nodes: nodes} do
    [n1, n2] = nodes

    assert :ok = Producer.send_ping()
    assert :ok = Producer.send_ping({Producer, n1})
    assert :ok = Producer.send_ping({Producer, n2})

    eventually(fn ->
      assert Producer.get_counts() == %{
        n1 => 3,
        n2 => 3,
        Node.self() => 3,
      }
    end)
  end

  test "producer can catch up crashed consumers", %{nodes: nodes} do
    [n1, _n2] = nodes

    assert :ok = Producer.send_ping()
    assert :ok = Producer.send_ping()

    for n <- nodes do
      eventually(fn ->
        assert Consumer.count_for_node({Consumer, n}, Node.self()) == 2
      end)
    end

    # Crash the consumer in a process so we don't need to catch exceptions
    spawn(fn ->
      GenServer.call({Consumer, n1}, :crash)
    end)

    for n <- nodes do
      eventually(fn ->
        assert Consumer.count_for_node({Consumer, n}, Node.self()) == 2
      end)
    end
  end

  test "producer can catch up nodes after a netsplit", %{nodes: nodes} do
    [n1, n2] = nodes

    assert :ok = GenServer.call({Producer, n2}, :send_ping)
    assert :ok = GenServer.call({Producer, n1}, :send_ping)

    eventually(fn ->
      assert Consumer.total_pings({Consumer, n1}) == 2
      assert Consumer.total_pings({Consumer, n2}) == 2
    end)

    # Split n1 away from n2
    Schism.partition([n1])

    # Sending pings from n2 should not reach n1 and vice versa
    assert :ok = GenServer.call({Producer, n2}, :send_ping)
    assert :ok = GenServer.call({Producer, n1}, :send_ping)

    eventually(fn ->
      assert Consumer.total_pings({Consumer, n1}) == 3
      assert Consumer.total_pings({Consumer, n2}) == 3
    end)

    Schism.heal([n1, n2])

    eventually(fn ->
      assert Consumer.total_pings({Consumer, n1}) == 4
      assert Consumer.total_pings({Consumer, n2}) == 4
    end)
  end

  def eventually(f, retries \\ 0) do
    f.()
  rescue
    err ->
      if retries >= 10 do
        reraise err, __STACKTRACE__
      else
        :timer.sleep(500)
        eventually(f, retries + 1)
      end
  catch
    _exit, _term ->
      :timer.sleep(500)
      eventually(f, retries + 1)
  end
end
