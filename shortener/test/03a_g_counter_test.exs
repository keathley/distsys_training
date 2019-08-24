defmodule Shortener.GCounterTest do
  use ExUnit.Case, async: true

  alias Shortener.GCounter

  describe "new/0" do
    test "returns a blank g counter" do
      assert GCounter.new() == %{}
    end
  end

  describe "increment/3" do
    test "defaults to the existing node name" do
      assert GCounter.new()
      |> GCounter.increment() == %{Node.self() => 1}

      assert GCounter.new()
      |> GCounter.increment()
      |> GCounter.increment()
      |> GCounter.increment() == %{Node.self() => 3}
    end
  end

  describe "merging/2" do
    test "takes the max value for each node" do
      c1 =
        GCounter.new()
        |> GCounter.increment(:foo)
        |> GCounter.increment(:bar)
        |> GCounter.increment(:bar)

      c2 =
        GCounter.new()
        |> GCounter.increment(:bar)
        |> GCounter.increment(:baz)

      c3 = GCounter.new()

      merged =
        c1
        |> GCounter.merge(c2)
        |> GCounter.merge(c3)
        |> GCounter.merge(c2)
        |> GCounter.merge(c1)

      merged =
        merged
        |> GCounter.merge(merged)
        |> GCounter.merge(c3)
        |> GCounter.merge(c2)

      assert GCounter.to_i(merged) == 4
    end
  end

  describe "to_i/1" do
    test "converts a counter to an integer" do
      assert GCounter.new()
      |> GCounter.increment(:foo)
      |> GCounter.increment(:foo)
      |> GCounter.increment(:bar)
      |> GCounter.increment(:baz)
      |> GCounter.increment(:baz)
      |> GCounter.to_i() == 5
    end
  end
end

