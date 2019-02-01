defmodule SoupexTest do
  use ExUnit.Case
  doctest Soupex

  test "greets the world" do
    assert Soupex.hello() == :world
  end
end
