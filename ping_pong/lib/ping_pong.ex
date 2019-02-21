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
      consumer
    end

    def stop, do: send(:consumer, :stop)

    def init(producer) do
      # Your code goes here!!!
    end

    def consume(expected) do
      # Your code goes here!!!
    end
  end
end
