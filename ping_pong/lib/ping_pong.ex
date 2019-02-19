defmodule PingPong do
  require Logger

  defmodule Producer do
    def start(delay) do
      producer = spawn(fn -> init(delay) end)
      Process.register(producer, :producer)
    end

    def stop do
      send(:producer, :stop)
    end

    def crash do
      send(:producer, :crash)
    end

    def init(delay) do
      receive do
        {:hello, consumer} ->
          producer(consumer, 0, delay)

        :stop ->
          :ok
      end
    end

    def producer(consumer, n, delay) do
      receive do
        :stop ->
          send(consumer, :bye)

        :crash ->
          raise "Boom!!!"

      after delay ->
        send(consumer, {:ping, n})
        producer(consumer, n+1, delay)
      end
    end
  end

  defmodule Consumer do
    def start(producer) do
      consumer = spawn(fn -> init(producer) end)
      Process.register(consumer, :consumer)
    end

    def stop, do: send(:consumer, :stop)

    def init(producer) do
      send(producer, {:hello, self()})
    end

    def consume(expected) do
      receive do
        {:ping, ^expected} ->
          Logger.info("Received expected value: #{expected}")
          consume(expected+1)

        {:ping, other_value} ->
          Logger.error("Received unexpected value: #{other_value}")
          consume(other_value+1)

        :bye ->
          :ok

        :stop ->
          :ok
      end
    end
  end
end
