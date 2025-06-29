defmodule Pipeline.Config do
  @moduledoc """
  Configuration parser for pipeline YAML files.
  """

  defstruct [:workflow]

  @doc """
  Load and parse a YAML configuration file.
  """
  def load(config_path) do
    with {:ok, yaml_content} <- File.read(config_path),
         {:ok, raw_config} <- YamlElixir.read_from_string(yaml_content) do
      
      workflow = parse_workflow(raw_config["workflow"])
      {:ok, %__MODULE__{workflow: workflow}}
    else
      {:error, reason} -> {:error, "Failed to load config: #{inspect(reason)}"}
    end
  end

  defp parse_workflow(nil), do: raise("Missing 'workflow' section in config")
  defp parse_workflow(workflow) do
    %{
      name: workflow["name"] || raise("Missing workflow name"),
      checkpoint_enabled: workflow["checkpoint_enabled"] || false,
      workspace_dir: workflow["workspace_dir"],
      checkpoint_dir: workflow["checkpoint_dir"],
      defaults: parse_defaults(workflow["defaults"]),
      gemini_functions: workflow["gemini_functions"] || %{},
      steps: parse_steps(workflow["steps"])
    }
  end

  defp parse_defaults(nil), do: %{}
  defp parse_defaults(defaults) do
    %{
      gemini_model: defaults["gemini_model"],
      gemini_token_budget: parse_token_budget(defaults["gemini_token_budget"]),
      claude_output_format: defaults["claude_output_format"],
      output_dir: defaults["output_dir"]
    }
  end

  defp parse_token_budget(nil), do: %{}
  defp parse_token_budget(budget) do
    %{
      max_output_tokens: budget["max_output_tokens"],
      temperature: budget["temperature"],
      top_p: budget["top_p"],
      top_k: budget["top_k"]
    }
  end

  defp parse_steps(nil), do: []
  defp parse_steps(steps) do
    Enum.map(steps, &parse_step/1)
  end

  defp parse_step(step) do
    %{
      name: step["name"] || raise("Step missing name"),
      type: step["type"] || raise("Step missing type"),
      role: step["role"],
      condition: step["condition"],
      output_to_file: step["output_to_file"],
      model: step["model"],
      token_budget: parse_token_budget(step["token_budget"]),
      functions: step["functions"],
      claude_options: parse_claude_options(step["claude_options"]),
      prompt: parse_prompt(step["prompt"]),
      parallel_tasks: parse_parallel_tasks(step["parallel_tasks"])
    }
  end

  defp parse_claude_options(nil), do: %{}
  defp parse_claude_options(opts) do
    %{
      print: opts["print"],
      output_format: opts["output_format"],
      max_turns: opts["max_turns"],
      allowed_tools: opts["allowed_tools"],
      verbose: opts["verbose"],
      append_system_prompt: opts["append_system_prompt"],
      cwd: opts["cwd"]
    }
  end

  defp parse_prompt(nil), do: []
  defp parse_prompt(prompt) when is_binary(prompt) do
    # Handle simple string prompts
    [%{
      type: "text",
      content: prompt,
      path: nil,
      step: nil,
      extract: nil
    }]
  end
  defp parse_prompt(prompt_parts) when is_list(prompt_parts) do
    Enum.map(prompt_parts, fn part ->
      %{
        type: part["type"] || raise("Prompt part missing type"),
        content: part["content"],
        path: part["path"],
        step: part["step"],
        extract: part["extract"]
      }
    end)
  end

  defp parse_parallel_tasks(nil), do: []
  defp parse_parallel_tasks(tasks) do
    Enum.map(tasks, fn task ->
      %{
        id: task["id"] || raise("Parallel task missing id"),
        claude_options: parse_claude_options(task["claude_options"]),
        prompt: parse_prompt(task["prompt"]),
        output_to_file: task["output_to_file"]
      }
    end)
  end
end