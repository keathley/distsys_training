defmodule PingPongTest do
  use ExUnit.Case
  doctest PingPong

  test "greets the world" do
    assert PingPong.hello() == :world
  end
end
