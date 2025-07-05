# Async Streaming Support

## Overview

Pipeline now supports async streaming for Claude-based steps, enabling real-time response streaming and improved performance for long-running operations.

## Configuration

Add async streaming to any Claude-based step by configuring the `claude_options`:

```yaml
claude_options:
  async_streaming: true        # Enable streaming
  stream_handler: "console"    # Handler type
  stream_buffer_size: 100      # Buffer size (optional)
```

## Stream Handlers

### Console Handler
Streams output directly to console in real-time:
```yaml
stream_handler: "console"
```

### File Handler
Streams output to a file as it arrives:
```yaml
stream_handler: "file"
```

### Buffer Handler
Collects stream into memory buffer:
```yaml
stream_handler: "buffer"
```

### Callback Handler
Uses custom callback function for handling stream:
```yaml
stream_handler: "callback"
```

## Supported Step Types

- `claude`
- `claude_smart`
- `claude_session`
- `claude_extract`
- `claude_batch`
- `claude_robust`
- `parallel_claude`

## Benefits

1. **Real-time Feedback**: See Claude's responses as they're generated
2. **Lower Memory Usage**: Large responses are streamed instead of buffered
3. **Better UX**: Progressive output for long-running tasks
4. **Early Interruption**: Can detect and stop on errors early

## Example

```yaml
workflow:
  name: "streaming_example"
  steps:
    - name: "implement_with_streaming"
      type: "claude"
      claude_options:
        async_streaming: true
        stream_handler: "console"
        stream_buffer_size: 50
        max_turns: 20
        allowed_tools: ["Write", "Edit", "Read"]
      prompt:
        - type: "static"
          content: "Implement the feature with real-time feedback"
```

## Integration with Pipeline Features

Async streaming works seamlessly with:
- Session management
- Parallel execution
- Retry mechanisms
- Cost tracking
- Telemetry

## Performance Considerations

- Smaller buffer sizes provide more frequent updates but may impact performance
- Console handler is best for interactive use
- File handler is recommended for logging/audit purposes
- Buffer handler is useful for post-processing streamed content