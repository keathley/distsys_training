defmodule MapReduceTest do
  use ExUnit.Case
  doctest MapReduce

  alias MapReduce.Storage

  setup do
    Storage.flush()

    :ok
  end

  test "can count words" do
    foo = Stream.repeatedly(fn -> "foo" end) |> Enum.take(10)
    bar = Stream.repeatedly(fn -> "bar" end) |> Enum.take(20)
    baz = Stream.repeatedly(fn -> "baz" end) |> Enum.take(30)

    content =
      (foo ++ bar ++ baz)
      |> Enum.shuffle
      |> Enum.join(" ")

    file_name =
      System.tmp_dir!
      |> Path.join("test_file")

    File.write!(file_name, content)

    assert results = MapReduce.start_job("test_job", file_name)

    assert results["foo"] == 10
    assert results["bar"] == 20
    assert results["baz"] == 30
  end
end

