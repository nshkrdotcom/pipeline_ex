# Async Streaming Migration Guide

This document helps teams migrate from the legacy async streaming hooks to the current streaming architecture introduced in `pipeline_ex` v0.3.

## 1. Migration Checklist

- Audit pipelines for `Pipeline.AsyncStreaming.Handler` usage.
- Replace handler modules with the new `Pipeline.Streaming.*` namespace.
- Confirm each LLM step sets `stream: true` in YAML or step configs.
- Run `mix test --only streaming` to validate the new flow.

## 2. Architectural Changes

| Area | Legacy System | Current System | Migration Notes |
| --- | --- | --- | --- |
| Event shape | `{:chunk, binary}` | `{:delta, %{content: binary}}` | Update pattern matches to extract `%{content: chunk}`. |
| Final callback | `{:complete, result}` | `{:done, response}` | Final responses now carry metadata such as tokens and finish reason. |
| Handler state | Global Agent | Lightweight module functions | Move mutable state into per-run processes (e.g., Task or GenServer). |
| Configuration | `async_stream: true` | `stream: true` | Remove the `async_` prefix everywhere. |

## 3. Updating Elixir Steps

```elixir
# BEFORE
Pipeline.AsyncStreaming.invoke!(
  prompt: ctx.prompt,
  handler: Pipeline.AsyncStreaming.ConsoleHandler
)

# AFTER
Pipeline.LLM.invoke!(
  ctx,
  prompt: ctx.prompt,
  stream: true,
  on_event: &Pipeline.Streaming.ConsoleHandler.handle_event/1
)
```

- Use `Pipeline.Streaming.Handler` behaviour for shared handlers.
- Prefer function captures (`&Module.handle_event/1`) over anonymous functions so the handler remains testable.

## 4. YAML Workflow Changes

```yaml
# BEFORE
- id: draft_report
  type: llm
  provider: claude
  async_stream: true
  async_handler: Pipeline.AsyncStreaming.ConsoleHandler

# AFTER
- id: draft_report
  type: llm
  provider: claude
  stream: true
  stream_handler: Pipeline.Streaming.ConsoleHandler
```

Make sure the handler module is compiled and available when running `mix pipeline.run`.

## 5. Testing Strategy

- **Unit tests**: use the `Pipeline.TestMode.StreamingRecorder` helper to capture deltas without hitting real providers.
- **Integration tests**: tag scenarios that depend on live streaming with `@tag :streaming` and execute via `mix test --only streaming`.
- **Diagnostics**: set `PIPELINE_STREAM_DEBUG=1` to print raw events during runs.

## 6. Common Issues

- **Handler not invoked**: confirm the module implements `handle_event/1` and is referenced correctly in YAML.
- **Duplicate output**: most often caused by reusing the same handler process; ensure each run starts a fresh handler.
- **Fallback to sync execution**: some providers disable streaming for certain models; verify the chosen model supports it.

## 7. Further Reading

- `examples/STREAMING_GUIDE.md` for a quick-start implementation.
- `docs/ASYNC_STREAMING_ASSESSMENT.md` for evaluation notes on the old system.
- `docs/ASYNC_STREAMING_EVALUATION_REPORT.md` for design trade-offs and roadmap.
