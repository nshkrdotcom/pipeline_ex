# Streaming Guide

This guide walks through enabling streaming output in `pipeline_ex` pipelines.

## When to Use Streaming

- Long running prompts where you want partial progress updates.
- Tooling scenarios that push incremental tokens to a UI.
- Debugging runs that need to expose intermediate state as it is produced.

If your pipeline already emits small responses, synchronous execution is fine. Streaming makes the biggest difference when a step may take tens of seconds or more.

## Quick Start

1. Add the `stream` flag to the step that invokes your LLM provider.
2. Supply a streaming handler to capture events in real time.

```elixir
defmodule Pipeline.StreamingExample do
  use Pipeline.Step

  def run(ctx) do
    Pipeline.LLM.invoke!(
      ctx,
      prompt: ctx.prompt,
      stream: true,
      on_event: &handle_event/1
    )
  end

  defp handle_event({:delta, chunk}) do
    IO.write(chunk.content)
  end
end
```

Store handlers under `lib/pipeline/streaming/` so other pipelines can reuse them.

## YAML Configuration

Streaming can be toggled directly in pipeline YAML workflows.

```yaml
steps:
  - id: research_summary
    type: llm
    provider: claude
    prompt: >
      Summarize the latest findings on autonomous research pipelines.
    stream: true
    stream_handler: Pipeline.Streaming.ConsoleHandler
```

### Handler Requirements

- Accept events shaped as `{:delta, chunk}` and `{:done, response}`.
- Avoid blocking calls; use async tasks if you need to buffer or persist output.
- Keep handlers idempotent—retries can trigger duplicate events.

## Testing Streaming Pipelines

- Run `mix test test/streaming` to execute streaming regression suites.
- For ad-hoc verification, execute `mix pipeline.run pipelines/demo.yaml --stream`.
- Capture output with `tee` if you need to diff streamed tokens: `mix pipeline.run ... | tee log.txt`.

## Troubleshooting

- **Nothing appears on screen**: confirm your handler writes to stdout and that the provider supports streaming for the selected model.
- **Out-of-order chunks**: accumulate within a GenServer before printing to guarantee ordering.
- **State bleed between runs**: reset any ETS tables or Agent state in your handler's `init/1`.

For deeper design notes, continue with `docs/ASYNC_STREAMING_MIGRATION_GUIDE.md`.
