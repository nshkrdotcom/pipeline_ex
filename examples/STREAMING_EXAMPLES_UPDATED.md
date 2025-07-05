# Streaming Examples - Updated

This directory contains working examples of async streaming functionality in Pipeline.

## Working Examples

### 1. Clean Numbers Streaming
**File:** `clean_streaming_numbers.yaml`

Demonstrates basic streaming output of numbers. Claude outputs "1\n2\n3" in a single response.

```bash
# Run in live mode to see actual streaming
TEST_MODE=live mix pipeline.run examples/clean_streaming_numbers.yaml
```

Expected output:
```
╭─────────────────────────────────────────╮
│      Claude Streaming Response          │
╰─────────────────────────────────────────╯

1
2
3
[Completed]

╭─── Stream Statistics ───╮
│ Messages: 3             │
│ Tokens:   0             │
│ Duration: 3.5s          │
│ Avg/msg:  1.2s          │
╰─────────────────────────╯
```

### 2. Countdown Example
**File:** `streaming_countdown.yaml`

A countdown from 5 to 1 with "BLAST OFF!" at the end.

```bash
TEST_MODE=live mix pipeline.run examples/streaming_countdown.yaml
```

## How Streaming Works

1. **ClaudeCodeSDK Integration**: The pipeline uses ClaudeCodeSDK's async streaming mode
2. **Message Processing**: Messages are processed through handlers that format and display them
3. **Console Handler**: The console handler extracts text from assistant messages and displays them in real-time

## Key Configuration Options

```yaml
claude_options:
  async_streaming: true          # Enable streaming mode
  stream_handler: "console"      # Use console output handler
  max_turns: 1                  # Single response
  allowed_tools: []             # No tool usage
```

## Notes

- Streaming requires `TEST_MODE=live` to make actual API calls
- The console handler shows a header, the streamed content, and statistics
- Claude doesn't actually pause between outputs - it generates the entire response quickly
- The streaming infrastructure handles ClaudeCodeSDK message format conversion automatically