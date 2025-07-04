defmodule Pipeline.Test.EnhancedMocks do
  @moduledoc """
  Enhanced mock system for testing Claude Code SDK integration features.
  Provides sophisticated mocking for new step types and advanced features.
  """

  alias Pipeline.Test.EnhancedFactory

  @doc """
  Mock implementation of the enhanced Claude provider.
  """
  def enhanced_claude_provider do
    quote do
      def query(prompt, options \\ %{}) do
        # Extract step type from the mock key or options
        step_type = extract_step_type_from_options(options)
        mock_key = "#{step_type}_#{:rand.uniform(10000)}"

        # Get mock responses based on step type
        responses = get_mock_responses_for_step_type(step_type)

        # Simulate processing time (reduced in test mode)
        sleep_time = if Mix.env() == :test, do: 1, else: 10
        :timer.sleep(sleep_time)

        # Process mock response based on step type
        case step_type do
          "claude_smart" ->
            process_claude_smart_mock(prompt, options, responses)

          "claude_session" ->
            process_claude_session_mock(prompt, options, responses)

          "claude_extract" ->
            process_claude_extract_mock(prompt, options, responses)

          "claude_batch" ->
            process_claude_batch_mock(prompt, options, responses)

          "claude_robust" ->
            process_claude_robust_mock(prompt, options, responses)

          _ ->
            process_default_claude_mock(prompt, options, responses)
        end
      end

      # Private helper functions for different step types

      defp extract_step_type_from_options(options) do
        cond do
          Map.get(options, "preset") -> "claude_smart"
          Map.get(options, "session_config") -> "claude_session"
          Map.get(options, "extraction_config") -> "claude_extract"
          Map.get(options, "batch_config") -> "claude_batch"
          Map.get(options, "retry_config") -> "claude_robust"
          true -> "claude"
        end
      end

      defp get_mock_responses_for_step_type(step_type) do
        mock_responses = EnhancedFactory.enhanced_mock_responses()
        Map.get(mock_responses, step_type, mock_responses["claude_smart"])
      end

      defp process_claude_smart_mock(prompt, options, responses) do
        preset = Map.get(options, "preset", "development")

        enhanced_response = enhance_mock_response_for_preset(responses, preset)

        {:ok,
         %{
           "text" => extract_text_from_mock_response(enhanced_response),
           "success" => true,
           "cost" => calculate_mock_cost(preset),
           "preset_applied" => preset,
           "environment_aware" => Map.get(options, "environment_aware", false),
           "session_id" => get_session_id_from_response(enhanced_response)
         }}
      end

      defp process_claude_session_mock(prompt, options, responses) do
        session_config = Map.get(options, "session_config", %{})
        session_name = Map.get(session_config, "session_name", "default")

        {:ok,
         %{
           "text" => extract_text_from_mock_response(responses),
           "success" => true,
           "cost" => 0.002,
           "session_id" => "persistent-#{session_name}-#{:rand.uniform(1000)}",
           "session_persisted" => Map.get(session_config, "persist", false),
           "checkpoint_frequency" => Map.get(session_config, "checkpoint_frequency", 5)
         }}
      end

      defp process_claude_extract_mock(prompt, options, responses) do
        extraction_config = Map.get(options, "extraction_config", %{})
        format = Map.get(extraction_config, "format", "text")

        extracted_content = generate_mock_extracted_content(format)

        {:ok,
         %{
           "text" => extracted_content,
           "success" => true,
           "cost" => 0.003,
           "extraction_format" => format,
           "content_extracted" => true,
           "metadata" => generate_mock_extraction_metadata(extraction_config)
         }}
      end

      defp process_claude_batch_mock(prompt, options, responses) do
        batch_config = Map.get(options, "batch_config", %{})
        tasks = Map.get(options, "tasks", [])
        max_parallel = Map.get(batch_config, "max_parallel", 1)

        # Simulate batch processing
        batch_results =
          Enum.map(tasks, fn task ->
            %{
              "file" => Map.get(task, "file", "unknown.py"),
              "result" => "Mock analysis completed",
              "status" => "success"
            }
          end)

        {:ok,
         %{
           "text" => "Batch processing completed for #{length(tasks)} tasks",
           "success" => true,
           "cost" => length(tasks) * 0.001,
           "batch_results" => batch_results,
           "tasks_completed" => length(tasks),
           "max_parallel" => max_parallel
         }}
      end

      defp process_claude_robust_mock(prompt, options, responses) do
        retry_config = Map.get(options, "retry_config", %{})
        max_retries = Map.get(retry_config, "max_retries", 3)

        # Simulate potential retry scenario
        # 20% chance of retry simulation
        should_simulate_retry = :rand.uniform(10) > 8

        if should_simulate_retry and max_retries > 1 do
          simulate_retry_scenario(prompt, options, responses, max_retries)
        else
          {:ok,
           %{
             "text" => extract_text_from_mock_response(responses),
             "success" => true,
             "cost" => 0.001,
             "retry_info" => %{
               "attempts_made" => 1,
               "max_retries" => max_retries,
               "retry_strategy" => Map.get(retry_config, "backoff_strategy", "exponential")
             }
           }}
        end
      end

      defp process_default_claude_mock(prompt, options, responses) do
        {:ok,
         %{
           "text" => extract_text_from_mock_response(responses),
           "success" => true,
           "cost" => 0.001
         }}
      end

      # Helper functions for mock processing

      defp enhance_mock_response_for_preset(responses, preset) do
        # Enhance responses based on preset
        case preset do
          "development" ->
            add_development_enhancements(responses)

          "production" ->
            add_production_constraints(responses)

          "analysis" ->
            add_analysis_focus(responses)

          "chat" ->
            add_chat_simplification(responses)

          _ ->
            responses
        end
      end

      defp add_development_enhancements(responses) do
        # Simulate development preset with verbose output
        enhanced_assistant = %{
          "type" => "assistant",
          "data" => %{
            "message" => %{
              "content" =>
                "Development preset applied: Verbose logging enabled, full tool access granted, permissive settings active."
            }
          }
        }

        List.replace_at(responses, 1, enhanced_assistant)
      end

      defp add_production_constraints(responses) do
        # Simulate production preset with restricted output
        enhanced_assistant = %{
          "type" => "assistant",
          "data" => %{
            "message" => %{
              "content" =>
                "Production preset applied: Restricted tool access, security-focused settings, minimal logging."
            }
          }
        }

        List.replace_at(responses, 1, enhanced_assistant)
      end

      defp add_analysis_focus(responses) do
        # Simulate analysis preset with read-only tools
        enhanced_assistant = %{
          "type" => "assistant",
          "data" => %{
            "message" => %{
              "content" =>
                "Analysis preset applied: Read-only tool access, code analysis focused, detailed reporting enabled."
            }
          }
        }

        List.replace_at(responses, 1, enhanced_assistant)
      end

      defp add_chat_simplification(responses) do
        # Simulate chat preset with simple conversation
        enhanced_assistant = %{
          "type" => "assistant",
          "data" => %{
            "message" => %{
              "content" =>
                "Chat preset applied: Simple conversation mode, basic tools only, user-friendly responses."
            }
          }
        }

        List.replace_at(responses, 1, enhanced_assistant)
      end

      defp calculate_mock_cost(preset) do
        case preset do
          # Higher cost due to verbose mode
          "development" -> 0.002
          # Lower cost due to restrictions
          "production" -> 0.001
          # Medium cost for analysis
          "analysis" -> 0.0015
          # Lowest cost for simple chat
          "chat" -> 0.0005
          _ -> 0.001
        end
      end

      defp generate_mock_extracted_content(format) do
        case format do
          "text" ->
            "Extracted plain text content from the response"

          "json" ->
            "{\"extracted\": \"data\", \"format\": \"json\", \"items\": 3}"

          "structured" ->
            """
            ## Analysis Results

            ### Summary
            Mock structured extraction completed successfully.

            ### Key Findings
            1. Code structure is well organized
            2. Minor improvements suggested
            3. Security practices are adequate

            ### Recommendations
            - Add more error handling
            - Improve documentation coverage
            """

          "summary" ->
            "Brief summary: Mock content successfully extracted and summarized."

          "markdown" ->
            """
            # Extraction Results

            **Status**: Success
            **Format**: Markdown
            **Content Type**: Mock Data

            ## Details
            This is mock extracted content formatted as Markdown.
            """

          _ ->
            "Mock extracted content in default format"
        end
      end

      defp generate_mock_extraction_metadata(extraction_config) do
        %{
          "format" => Map.get(extraction_config, "format", "text"),
          "post_processing_enabled" => Map.has_key?(extraction_config, "post_processing"),
          "content_length" => :rand.uniform(1000) + 100,
          "extraction_time_ms" => :rand.uniform(500) + 100,
          "include_metadata" => Map.get(extraction_config, "include_metadata", false)
        }
      end

      defp simulate_retry_scenario(prompt, options, responses, max_retries) do
        # Simulate a retry that succeeds on the second attempt
        # Simulate retry delay (reduced in test mode)
        retry_sleep_time = if Mix.env() == :test, do: 5, else: 50
        :timer.sleep(retry_sleep_time)

        {:ok,
         %{
           "text" => "Mock response after successful retry",
           "success" => true,
           # Higher cost due to retry
           "cost" => 0.002,
           "retry_info" => %{
             "attempts_made" => 2,
             "max_retries" => max_retries,
             "retry_successful" => true,
             "retry_reason" => "Mock timeout on first attempt"
           }
         }}
      end

      defp extract_text_from_mock_response(responses) do
        assistant_response =
          Enum.find(responses, fn resp ->
            resp["type"] == "assistant"
          end)

        case assistant_response do
          %{"data" => %{"message" => %{"content" => content}}} when is_binary(content) ->
            content

          %{"data" => %{"message" => %{"content" => [%{"text" => text}]}}} ->
            text

          _ ->
            "Mock Claude response text"
        end
      end

      defp get_session_id_from_response(responses) do
        system_response =
          Enum.find(responses, fn resp ->
            resp["type"] == "system"
          end)

        case system_response do
          %{"data" => %{"session_id" => session_id}} ->
            session_id

          _ ->
            "mock-session-#{:rand.uniform(10000)}"
        end
      end
    end
  end

  @doc """
  Mock implementation for OptionBuilder integration.
  """
  def option_builder_mock do
    quote do
      def for_environment do
        case Application.get_env(:pipeline, :environment, :development) do
          :development -> build_development_options()
          :production -> build_production_options()
          :test -> build_test_options()
          _ -> build_development_options()
        end
      end

      def build_development_options do
        %{
          "max_turns" => 20,
          "verbose" => true,
          "allowed_tools" => ["Write", "Edit", "Read", "Bash", "Search"],
          "output_format" => "stream_json",
          "debug_mode" => true,
          "preset" => "development"
        }
      end

      def build_production_options do
        %{
          "max_turns" => 10,
          "verbose" => false,
          "allowed_tools" => ["Read"],
          "output_format" => "json",
          "debug_mode" => false,
          "preset" => "production"
        }
      end

      def build_analysis_options do
        %{
          "max_turns" => 5,
          "verbose" => true,
          "allowed_tools" => ["Read"],
          "output_format" => "json",
          "debug_mode" => true,
          "preset" => "analysis"
        }
      end

      def build_chat_options do
        %{
          "max_turns" => 15,
          "verbose" => false,
          "allowed_tools" => [],
          "output_format" => "text",
          "debug_mode" => false,
          "preset" => "chat"
        }
      end

      def build_test_options do
        %{
          "max_turns" => 3,
          "verbose" => true,
          "allowed_tools" => ["Read"],
          "output_format" => "json",
          "debug_mode" => true,
          "preset" => "test"
        }
      end

      def merge(preset_name, overrides) when is_atom(preset_name) do
        base_options =
          case preset_name do
            :development -> build_development_options()
            :production -> build_production_options()
            :analysis -> build_analysis_options()
            :chat -> build_chat_options()
            :test -> build_test_options()
            _ -> build_development_options()
          end

        Map.merge(base_options, overrides)
      end

      def merge(preset_name, overrides) when is_binary(preset_name) do
        merge(String.to_atom(preset_name), overrides)
      end
    end
  end

  @doc """
  Mock implementation for AuthChecker.
  """
  def auth_checker_mock do
    quote do
      def authenticated? do
        # Always return true in test mode
        true
      end

      def diagnose do
        %{
          "cli_installed" => true,
          "authenticated" => true,
          "provider" => "mock",
          "status" => "ready",
          "recommendations" => [],
          "mock_mode" => true
        }
      end

      def ensure_ready! do
        # Always pass in test mode
        :ok
      end

      def check_environment do
        %{
          "environment" => "test",
          "mock_mode" => true,
          "authentication_required" => false,
          "provider_available" => true
        }
      end
    end
  end

  @doc """
  Mock implementation for ContentExtractor.
  """
  def content_extractor_mock do
    quote do
      def extract_text(message) when is_map(message) do
        case message do
          %{"text" => text} -> text
          %{"content" => content} when is_binary(content) -> content
          %{"data" => %{"message" => %{"content" => content}}} when is_binary(content) -> content
          %{"data" => %{"message" => %{"content" => [%{"text" => text}]}}} -> text
          _ -> "Mock extracted text"
        end
      end

      def extract_text(text) when is_binary(text) do
        text
      end

      def extract_text(_) do
        "Mock extracted text"
      end

      def has_text?(message) do
        case extract_text(message) do
          "" -> false
          nil -> false
          _ -> true
        end
      end

      def extract_all_text(messages, separator \\ "\n") do
        messages
        |> Enum.map(&extract_text/1)
        |> Enum.filter(fn text -> text != "" and not is_nil(text) end)
        |> Enum.join(separator)
      end

      def summarize(message, max_length) do
        text = extract_text(message)

        if String.length(text) <= max_length do
          text
        else
          String.slice(text, 0, max_length - 3) <> "..."
        end
      end
    end
  end

  @doc """
  Mock implementation for session management.
  """
  def session_manager_mock do
    quote do
      def create_session(session_name, options \\ %{}) do
        session_id = "mock-session-#{session_name}-#{:rand.uniform(10000)}"

        %{
          "session_id" => session_id,
          "session_name" => session_name,
          "created_at" => DateTime.utc_now(),
          "persist" => Map.get(options, "persist", false),
          "status" => "active"
        }
      end

      def get_session(session_id) do
        case String.contains?(session_id, "mock-session") do
          true ->
            %{
              "session_id" => session_id,
              "session_name" => "mock_session",
              "created_at" => DateTime.utc_now(),
              "status" => "active",
              "interactions" => []
            }

          false ->
            nil
        end
      end

      def continue_session(session_id, prompt) do
        case get_session(session_id) do
          nil ->
            {:error, "Session not found"}

          session ->
            {:ok,
             %{
               "session_id" => session_id,
               "response" => "Mock continuation response for: #{prompt}",
               "interaction_count" => :rand.uniform(10)
             }}
        end
      end

      def checkpoint_session(session_id, data) do
        {:ok,
         %{
           "session_id" => session_id,
           "checkpoint_id" => "checkpoint-#{:rand.uniform(1000)}",
           "timestamp" => DateTime.utc_now(),
           "data_size" => byte_size(inspect(data))
         }}
      end

      def list_sessions do
        [
          %{
            "session_id" => "mock-session-1",
            "session_name" => "test_session_1",
            "status" => "active"
          },
          %{
            "session_id" => "mock-session-2",
            "session_name" => "test_session_2",
            "status" => "archived"
          }
        ]
      end
    end
  end
end
