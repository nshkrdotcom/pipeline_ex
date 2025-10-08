# Async Streaming System - Deprecated and Removed

**Date:** October 7, 2025
**Status:** ⚠️ REMOVED

---

## Summary

The async streaming system (`AsyncHandler`, `AsyncResponse`, and all related handlers) has been **removed from pipeline_ex** as of this commit.

## Reason for Removal

After thorough analysis by three independent reviews (see reports in `docs/`), it was determined that the async streaming system was working at the **wrong abstraction level**:

### The Core Issue

The system was designed to buffer and batch **complete Message structs** from `ClaudeCodeSDK.query()`, under the mistaken assumption that it was handling streaming text chunks.

**Reality:** `ClaudeCodeSDK.query()` returns an enumerable of complete, structured messages (full conversation turns), **not character-by-character text deltas**.

This made the buffering/batching system add:
- ❌ Unnecessary complexity (~900 lines of code)
- ❌ Latency (waiting for buffers to fill)
- ❌ No performance benefit
- ❌ Maintenance burden

## What Was Removed

### Source Files
- `lib/pipeline/streaming/async_handler.ex` (~262 lines)
- `lib/pipeline/streaming/async_response.ex` (~365 lines)
- `lib/pipeline/streaming/handlers/*.ex` (7 handler implementations)

### Tests
- `test/pipeline/streaming/async_handler_test.exs`
- `test/pipeline/streaming/async_response_test.exs`
- `test/pipeline/streaming/handlers/*.exs` (4 test files)

### Documentation
- `docs/features/async_streaming.md`
- `docs/ASYNC_STREAMING_MIGRATION_GUIDE.md`
- `docs/implementation/async_streaming_implementation_guide.md`
- `examples/STREAMING_GUIDE.md`
- `examples/*_streaming_*.yaml` (12 example files)

### Provider Changes
- Removed `async_streaming` option from `ClaudeProvider`
- Removed `async_streaming` option from `EnhancedClaudeProvider`
- Removed all `AsyncResponse` wrapper code
- Removed mock async streaming implementations

**Total removal:** ~900 lines of code + documentation

---

## Migration Guide

### If You Were Using `async_streaming: true`

**Before:**
```yaml
- name: "analysis"
  type: "claude"
  claude_options:
    max_turns: 10
    async_streaming: true
    stream_handler: "simple"
  prompt: "Analyze this code..."
```

**After (recommended):**
```yaml
- name: "analysis"
  type: "claude"
  claude_options:
    max_turns: 10
  prompt: "Analyze this code..."
```

The SDK already streams messages optimally. Just remove the `async_streaming` and `stream_handler` options.

### If You Need Per-Message Callbacks

If you were using async streaming for logging, UI updates, or integration with external systems:

**Use simple `Stream.each` instead:**

```elixir
# Your custom processing
messages = ClaudeCodeSDK.query(prompt, opts)
|> Stream.each(&log_message_to_datadog/1)
|> Stream.each(&update_progress_ui/1)
|> Stream.each(&send_to_websocket/1)
|> Enum.to_list()
```

This provides the same functionality without the buffering/batching overhead.

### If You Need Character-Level Streaming

The async streaming system **never provided this**. It was working with complete messages, not text chunks.

**True character-by-character streaming will be available in `claude_code_sdk_elixir` v0.2.0:**
- Bidirectional streaming sessions
- Real `text_delta` SSE events
- Interactive chat UIs with typewriter effects
- See: `docs/20251007/06_BIDIRECTIONAL_STREAMING_PLAN.md` (in claude_code_sdk_elixir repo)

---

## What to Use Instead

### 1. Direct SDK Usage (99% of use cases)

```elixir
# Simple and direct
messages = ClaudeCodeSDK.query(prompt, opts) |> Enum.to_list()
process_result(messages)
```

### 2. Per-Message Processing (logging, UI updates)

```elixir
# Use Stream.each for side effects
messages = ClaudeCodeSDK.query(prompt, opts)
|> Stream.each(&your_callback/1)
|> Enum.to_list()
```

### 3. Real-Time UI Updates (Phoenix LiveView)

```elixir
# Send messages to LiveView as they arrive
ClaudeCodeSDK.query(prompt, opts)
|> Stream.each(fn message ->
  send(liveview_pid, {:claude_message, message})
end)
|> Enum.to_list()
```

---

## Technical Details

### Why This Happened

The async streaming system was built based on a misunderstanding of how `ClaudeCodeSDK` works:

**Misconception:** SDK provides character-by-character streaming text that needs buffering
**Reality:** SDK provides complete Message structs (full conversation turns)

### What ClaudeCodeSDK Actually Returns

```elixir
Stream.each([
  %Message{type: :assistant, data: %{message: %{"content" => "Complete turn 1"}}},
  %Message{type: :assistant, data: %{message: %{"content" => "Complete turn 2"}}},
  %Message{type: :result, data: %{total_cost_usd: 0.001}}
])
```

**Not this:**
```elixir
Stream.each(["I", "'ll", " analyze", " this", " code", "..."]) # ← Never happens
```

### How Claude Code 2.0 Actually Streams

- **CLI output:** Newline-delimited JSON (one complete message per line)
- **SDK output:** Enumerable of complete Message structs
- **Internal:** SDK handles SSE events and yields complete messages
- **No user-level character streaming:** By design (simplicity and reliability)

---

## References

### Analysis Reports

1. **ASYNC_STREAMING_EVALUATION_REPORT.md** - Initial analysis with Claude Code 2.0 feature comparison
2. **ASYNC_STREAMING_ASSESSMENT.md** - Deep technical analysis from SDK implementer perspective
3. **PIPELINE_EX_RECOMMENDATION.md** - Final recommendation to delete

All three reports reached the same conclusion independently.

### Related Documentation

- [Claude Code 2.0 Release Notes](https://www.anthropic.com/news/enabling-claude-code-to-work-more-autonomously)
- [Claude API Streaming Docs](https://docs.claude.com/en/docs/build-with-claude/streaming)
- `claude_code_sdk_elixir` bidirectional streaming plan (future feature)

---

## Questions?

**Q: Will this break my pipelines?**
A: Only if you explicitly used `async_streaming: true`. Just remove that option.

**Q: How do I get real streaming now?**
A: You already have it. `ClaudeCodeSDK.query()` streams messages as they arrive. Just use `Enum.to_list()` or `Stream.each()`.

**Q: What about character-by-character streaming?**
A: That was never available in the async streaming system. Wait for `claude_code_sdk_elixir` v0.2.0 bidirectional streaming.

**Q: Can I still log messages as they arrive?**
A: Yes! Use `Stream.each(&log_function/1)` before `Enum.to_list()`.

---

**Deprecation Status:** Removed
**Replacement:** Use `ClaudeCodeSDK.query() |> Enum.to_list()` directly or `Stream.each()` for callbacks
**Future:** True character-level streaming in SDK v0.2.0
