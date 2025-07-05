# Streaming Clarification

## What This Is: Message-by-Message Streaming

The Pipeline streaming functionality displays **complete messages** as they arrive from ClaudeCodeSDK, not character-by-character streaming.

### How It Works

1. ClaudeCodeSDK sends messages as a stream (using `--output-format stream-json`)
2. Each message arrives as a complete unit (e.g., an assistant response, a system message, etc.)
3. The handlers display these messages as they arrive

### Available Handlers

1. **console** - Fancy formatted output with headers and statistics
2. **simple** - Clean line-by-line output with optional timestamps
3. **file** - Write messages to a file
4. **buffer** - Collect messages in memory
5. **callback** - Custom processing function

### Example: Simple Handler

```yaml
claude_options:
  async_streaming: true
  stream_handler: "simple"
  stream_handler_opts:
    show_timestamps: true
```

Output:
```
[06:50:16] I'll answer each of your questions...
✓ Stream completed: 1 messages in 3968ms
```

### Example: Console Handler

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

I'll answer each of your questions...

╭─── Stream Statistics ───╮
│ Messages: 1             │
│ Tokens:   0             │
│ Duration: 3.5s          │
│ Avg/msg:  3.5s          │
╰─────────────────────────╯
```

## What This Is NOT

- **NOT character-by-character streaming** - Claude outputs complete thoughts/messages
- **NOT real-time typing effect** - Messages appear all at once when Claude finishes composing them
- **NOT token-by-token streaming** - ClaudeCodeSDK doesn't support this level of granularity

## Multiple Messages

To see multiple messages, you need Claude to make multiple responses. This happens when:
- Using tools (each tool use is a separate message)
- Having a conversation with multiple turns
- Claude breaks up a long response (rare)

The streaming shows each of these messages as they arrive from the API.