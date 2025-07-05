# Async Streaming Migration Guide

This guide helps you add async streaming to your existing Pipeline workflows for real-time message display.

## What is Async Streaming?

Async streaming displays Claude's messages **as complete units when they arrive**, not character-by-character. This provides:

- Real-time feedback as Claude processes your request
- Better user experience with progressive message display
- Lower memory usage for long responses
- Ability to see tool uses and results as they happen

## Quick Start

### Basic Migration

Transform any Claude step to use streaming by adding two options:

```yaml
# Before: Standard Claude step
- name: "analysis"
  type: "claude"
  claude_options:
    max_turns: 10
  prompt: "Analyze this code..."

# After: Streaming Claude step
- name: "analysis"
  type: "claude"
  claude_options:
    max_turns: 10
    async_streaming: true      # Enable streaming
    stream_handler: "simple"   # Choose a handler
  prompt: "Analyze this code..."
```

That's it! Your step now streams messages in real-time.

## Available Stream Handlers

### 1. Simple Handler (Recommended for most use cases)

Shows clean, timestamped messages:

```yaml
claude_options:
  async_streaming: true
  stream_handler: "simple"
  stream_handler_opts:
    show_timestamps: true
```

Output:
```
[12:34:56] ASSISTANT: I'll analyze this code for you...
[12:34:57] TOOL USE: Read
[12:34:58] TOOL RESULT: File contents loaded
[12:34:59] ASSISTANT: Based on my analysis...
```

### 2. Console Handler (Fancy formatting)

Displays styled output with statistics:

```yaml
claude_options:
  async_streaming: true
  stream_handler: "console"
```

Shows a formatted header, message content, and completion statistics.

### 3. Debug Handler (Development)

See all message types including system messages:

```yaml
claude_options:
  async_streaming: true
  stream_handler: "debug"
```

### 4. File Handler (Logging)

Stream messages to a file:

```yaml
claude_options:
  async_streaming: true
  stream_handler: "file"
  stream_handler_opts:
    file_path: "./logs/claude_stream.log"
    append: true
```

### 5. Buffer Handler (Programmatic access)

Collect messages in memory:

```yaml
claude_options:
  async_streaming: true
  stream_handler: "buffer"
  stream_handler_opts:
    max_size: 1000
```

### 6. Callback Handler (Custom processing)

Use your own handler:

```yaml
claude_options:
  async_streaming: true
  stream_handler: "callback"
  stream_handler_opts:
    module: "MyApp.StreamHandler"
    function: "process_message"
```

## Migration Patterns

### Pattern 1: Add Streaming to Development Workflows

For development and debugging, add streaming to see what Claude is doing:

```yaml
# Development pipeline with streaming
workflow:
  name: "development_pipeline"
  environment:
    mode: "development"
  
  steps:
    - name: "implement_feature"
      type: "claude_smart"
      preset: "development"
      claude_options:
        async_streaming: true
        stream_handler: "simple"
        stream_handler_opts:
          show_timestamps: true
```

### Pattern 2: Production Logging

For production, stream to files for audit trails:

```yaml
# Production pipeline with file logging
workflow:
  name: "production_pipeline"
  environment:
    mode: "production"
  
  steps:
    - name: "process_request"
      type: "claude"
      claude_options:
        async_streaming: true
        stream_handler: "file"
        stream_handler_opts:
          file_path: "./logs/claude_{{execution_id}}.log"
```

### Pattern 3: Enhanced Claude Steps

All enhanced Claude steps support streaming:

```yaml
# Claude Session with streaming
- name: "interactive_session"
  type: "claude_session"
  session_config:
    session_name: "dev_session"
  claude_options:
    async_streaming: true
    stream_handler: "console"

# Claude Batch with streaming
- name: "batch_process"
  type: "claude_batch"
  batch_config:
    max_parallel: 3
  claude_options:
    async_streaming: true
    stream_handler: "simple"
```

## Understanding Message Counts

When streaming shows "3 messages" but you only see one output line, it's because the stream includes:

1. **System message** - Initialization (not displayed by default)
2. **Assistant message** - The actual response (displayed)
3. **Result message** - Completion status (not displayed by default)

Use the `debug` handler to see all message types.

## Performance Considerations

- **No performance penalty**: Streaming doesn't slow down responses
- **Memory efficient**: Messages are processed as they arrive
- **Network friendly**: Uses the same API connection

## Testing Streaming

### Mock Mode
```bash
# Test with mock streaming (instant, no API calls)
mix pipeline.run examples/clean_streaming_numbers.yaml
```

### Live Mode
```bash
# Test with real API streaming
TEST_MODE=live mix pipeline.run examples/streaming_file_operations.yaml
```

## Common Issues

### Issue: No output visible

**Solution**: Check your handler configuration. The `simple` or `console` handlers show output by default.

### Issue: Output appears all at once

**Solution**: This happens in mock mode. Use `TEST_MODE=live` to see real streaming behavior.

### Issue: Missing tool use messages

**Solution**: Some handlers hide tool use by default. Use `show_tool_use: true` in handler options.

## Best Practices

1. **Development**: Use `simple` handler with timestamps
2. **Production**: Use `file` handler for logging
3. **Debugging**: Use `debug` handler to see all messages
4. **User-facing**: Use `console` handler for pretty output

## Examples

See these example files:
- `examples/clean_streaming_numbers.yaml` - Minimal streaming example
- `examples/streaming_file_operations.yaml` - Multi-turn streaming
- `examples/STREAMING_GUIDE.md` - Complete implementation details

## Summary

Adding async streaming is simple:
1. Add `async_streaming: true` to claude_options
2. Choose a stream_handler
3. Optionally configure handler options

The feature works with all Claude step types and provides real-time visibility into Claude's processing.