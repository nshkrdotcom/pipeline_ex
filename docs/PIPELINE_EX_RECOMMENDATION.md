# Recommendation for pipeline_ex Async Streaming System
## Date: 2025-10-07
## Decision: Option A - Delete

---

## 📋 Recommendation

**DELETE the async streaming system from pipeline_ex.**

### Files to Remove:
- `lib/pipeline/streaming/async_handler.ex` (~262 lines)
- `lib/pipeline/streaming/async_response.ex` (~510 lines)
- Associated tests and docs
- ~900 lines total

### Reason:

The async streaming system buffers complete `ClaudeCodeSDK.Message` objects (full conversation turns), not streaming text chunks. This adds complexity and latency with zero benefit.

**ClaudeCodeSDK.query() already returns messages optimally as an enumerable.**

---

## 🔄 Migration Path

### Before (with AsyncHandler):
```elixir
async_response = AsyncResponse.new(stream, "step_name", handler: MyHandler)
AsyncHandler.process_stream(async_response.stream, %{
  buffer_size: 10,
  flush_interval: 100,
  handler_module: MyHandler
})
```

### After (direct SDK):
```elixir
# Just use the SDK directly
messages = ClaudeCodeSDK.query(prompt, opts) |> Enum.to_list()
process_messages(messages)
```

### If You Need Callbacks:
```elixir
# Use simple Stream.each (no custom behavior needed)
messages = ClaudeCodeSDK.query(prompt, opts)
|> Stream.each(&log_message/1)
|> Stream.each(&update_ui/1)
|> Enum.to_list()
```

---

## ✅ Benefits of Deletion

- **-900 lines of code** (less maintenance)
- **Simpler architecture** (no custom behaviors)
- **Better compatibility** with Claude Code 2.0 features
- **Lower latency** (no buffering delay)
- **Easier to understand** for other developers

---

## 🔮 Future: If You Need TRUE Streaming

If you actually need character-by-character streaming (typewriter effect, chat UIs):

**Wait for `claude_code_sdk_elixir` v0.2.0** which will include:
- Bidirectional streaming with `--include-partial-messages`
- Real `text_delta` events
- Interactive session management
- Proper SSE event handling

**Implementation plan**: `docs/20251007/06_BIDIRECTIONAL_STREAMING_PLAN.md`

---

**Recommendation Status**: Ready to implement
**Action Required**: Delete async streaming files from pipeline_ex
