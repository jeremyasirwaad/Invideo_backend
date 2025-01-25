defmodule InvideoBackendTest do
  use ExUnit.Case
  doctest InvideoBackend

  test "greets the world" do
    assert InvideoBackend.hello() == :world
  end
end
