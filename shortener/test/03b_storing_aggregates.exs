defmodule Shortener.StoringAggregatesTest do
  use ExUnit.Case, async: false

  import Shortener.TestUtils

  alias Shortener.{
    Aggregates,
    GCounter,
  }

  setup_all do
    Application.ensure_all_started(:shortener)

    :ok
  end

  setup do
    Aggregates.flush()

    :ok
  end

  describe "Aggregates" do
    test "creates a counter for a short code" do
      current_state = :sys.get_state(Aggregates)
      assert %{} == current_state.counters
      Aggregates.increment("chris")
      assert match?(%{"chris" => _}, :sys.get_state(Aggregates).counters)
    end

    test "turns counters into a representation for quick lookups" do
      Aggregates.increment("chris")
      Aggregates.increment("alice")
      Aggregates.increment("andra")

      eventually(fn ->
        assert Aggregates.count_for("chris") == 1
        assert Aggregates.count_for("alice") == 1
        assert Aggregates.count_for("andra") == 1
      end)
    end

    test "counters can be merged" do
      chris_counter =
        GCounter.new()
        |> GCounter.increment(:other)
        |> GCounter.increment(:other)
        |> GCounter.increment(:other)

      alice_counter =
        GCounter.new()
        |> GCounter.increment(:other)
        |> GCounter.increment(:other)

      andra_counter =
        GCounter.new()
        |> GCounter.increment(:other)

      Aggregates.increment("chris")
      Aggregates.increment("alice")
      Aggregates.increment("alice")
      Aggregates.increment("alice")

      Aggregates.merge("chris", chris_counter)
      Aggregates.merge("alice", alice_counter)
      Aggregates.merge("andra", andra_counter)

      eventually(fn ->
        assert Aggregates.count_for("chris") == 4
        assert Aggregates.count_for("alice") == 5
        assert Aggregates.count_for("andra") == 1
      end)
    end
  end
end

