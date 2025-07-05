# Async Streaming Guide

This guide explains the async streaming functionality implemented in Pipeline, which displays **complete messages** as they arrive from ClaudeCodeSDK.

## What This Is: Message-by-Message Streaming

The Pipeline streaming functionality shows each complete message from ClaudeCodeSDK as it arrives. This is NOT character-by-character streaming, but rather message-by-message streaming where each message appears as a complete unit.

## Implementation Features

### 1. Stream Handlers

Three specialized handlers were implemented to display streaming messages:

#### **console** - Fancy Formatted Output
- Shows a styled header and footer
- Displays streaming statistics
- Handles escaped newlines (`\n` → actual line breaks)
- Color-coded output for different message types

```yaml
claude_options:
  async_streaming: true
  stream_handler: "console"
```

Output:
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

#### **simple** - Clean Line-by-Line Output
- Shows timestamped messages
- Displays assistant responses, tool uses, and tool results
- Minimal formatting for clarity

```yaml
claude_options:
  async_streaming: true
  stream_handler: "simple"
  stream_handler_opts:
    show_timestamps: true
```

Output:
```
[06:54:52] ASSISTANT: I'll perform these file operations...
[06:54:53] TOOL USE: Write
[06:54:53] TOOL RESULT: File created successfully...
[06:54:56] ASSISTANT: ✅ Step 1 completed...

✓ Stream completed: 5 messages in 23356ms
```

#### **debug** - Complete Message Debugging
- Shows ALL message types (system, assistant, tool_use, tool_result, result)
- Displays message metadata and timing
- Useful for understanding the complete stream

```yaml
claude_options:
  async_streaming: true
  stream_handler: "debug"
```

Output:
```
=== DEBUG STREAM START ===

[06:56:27] SYSTEM:init
    Session: 023793c4-4685-438a-b18b-0d848889c5f4
    Model: claude-opus-4-20250514

[06:56:30] ASSISTANT
    Content: Hello! 👋\n\nLet me count to 3...

[06:56:30] RESULT:success
    Status: success
    Duration: 3310ms

=== DEBUG STREAM END ===
Total messages: 3
Duration: 3842ms
```

### 2. Message Format Support

The implementation properly handles ClaudeCodeSDK message format:

- **ClaudeCodeSDK.Message struct handling** in `AsyncResponse.message_to_map/1`
- **Content extraction** from nested message structures
- **Newline conversion** (`\n` → actual line breaks)
- **Text extraction** from various content formats (string, array, nested)

### 3. Examples

#### Simple Numbers Example
```yaml
# examples/clean_streaming_numbers.yaml
workflow:
  name: "clean_streaming_numbers"
  steps:
    - name: "numbers_only"
      type: "claude"
      claude_options:
        async_streaming: true
        stream_handler: "console"
        max_turns: 1
        allowed_tools: []
        system_prompt: |
          Output ONLY the requested numbers with NO other text.
      prompt:
        - type: "static"
          content: |
            Output these three things in order:
            1. The number 1
            2. The number 2  
            3. The number 3
```

#### File Operations Example (Multiple Messages)
```yaml
# examples/streaming_file_operations.yaml
workflow:
  name: "streaming_file_operations"
  steps:
    - name: "file_operations_stream"
      type: "claude"
      claude_options:
        async_streaming: true
        stream_handler: "simple"
        stream_handler_opts:
          show_timestamps: true
        max_turns: 5
        allowed_tools: ["Write", "Read", "Bash", "Edit"]
      prompt:
        - type: "static"
          content: |
            Please perform these file operations in order:
            1. Create a file called test_file.txt
            2. Read the file to confirm it was created
            3. Append a new line to the file
            4. Delete the file using rm command
```

## How to Run

```bash
# Mock mode (default, no API calls)
mix pipeline.run examples/clean_streaming_numbers.yaml

# Live mode (real API calls)
TEST_MODE=live mix pipeline.run examples/streaming_file_operations.yaml
```

## Understanding Message Counts

When you see "3 messages" in statistics but only one visible output, it's because the stream includes:

1. **System/init message** - Stream initialization (not displayed by default)
2. **Assistant message** - The actual response content (displayed)
3. **Result message** - Stream completion status (not displayed by default)

Use the `debug` handler to see all message types.

## Key Implementation Details

- **Streaming is per-message, not per-character** - Each message arrives as a complete unit
- **Handlers process messages as they arrive** - Real-time display of streaming content
- **Multiple handler types** - Choose based on your needs (fancy, simple, or debug)
- **Proper message extraction** - Handles ClaudeCodeSDK's nested message format
- **Escaped newline handling** - Converts `\n` to actual line breaks for proper formatting

## Technical Notes

- ClaudeCodeSDK uses `--output-format stream-json` for streaming
- Messages arrive as complete units, not character streams
- The infrastructure supports real-time display of messages as they arrive
- Stream timing reflects actual API response times (e.g., ~3-4 seconds for simple responses)