#!/usr/bin/env elixir

# Add the lib directory to the path
Code.append_path("lib")

# Load required modules
{:ok, _} = Application.ensure_all_started(:pipeline)

alias Pipeline.Context.Nested

# Test the template resolution
parent_context = %{
  results: %{"prepare_data" => %{"name" => "test_item", "count" => 42}},
  global_vars: %{"base_url" => "https://api.example.com"}
}

template1 = "{{steps.prepare_data.result.name}}"
template2 = "{{steps.prepare_data.result.count}}"
template3 = "{{global_vars.base_url}}"

IO.puts("Testing template resolution:")
IO.puts("Parent context: #{inspect(parent_context)}")
IO.puts("")

IO.puts("Template 1: #{template1}")
result1 = Nested.resolve_template(template1, parent_context)
IO.puts("Result 1: #{inspect(result1)}")
IO.puts("")

IO.puts("Template 2: #{template2}")
result2 = Nested.resolve_template(template2, parent_context)
IO.puts("Result 2: #{inspect(result2)}")
IO.puts("")

IO.puts("Template 3: #{template3}")
result3 = Nested.resolve_template(template3, parent_context)
IO.puts("Result 3: #{inspect(result3)}")