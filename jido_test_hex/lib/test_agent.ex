defmodule JidoHexTest.TestAgent do
  use Jido.Agent,
    name: "test_agent",
    description: "Minimal agent to reproduce dialyzer issue",
    schema: [
      value: [type: :integer, default: 0]
    ]
end