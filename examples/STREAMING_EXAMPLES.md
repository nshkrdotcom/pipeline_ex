# Claude Streaming Examples

This directory contains various examples of async streaming with Claude in the Pipeline system.

## Simple Streaming Examples

### 1. Streaming Numbers (`claude_streaming_numbers.yaml`)

A very simple example that outputs numbers 1, 2, and 3 with 5-second pauses between them.

**Run it:**
```bash
mix pipeline.run examples/claude_streaming_numbers.yaml
```

Or use the helper script:
```bash
./run_streaming_numbers.sh
```

**What it does:**
- Outputs "1"
- Waits 5 seconds
- Outputs "2" 
- Waits 5 seconds
- Outputs "3"
- Stops

### 2. Streaming Countdown (`claude_streaming_countdown.yaml`)

An ultra-simple countdown example with a system prompt.

**Run it:**
```bash
mix pipeline.run examples/claude_streaming_countdown.yaml
```

## Other Streaming Examples

### 3. Simple Streaming Demo (`claude_streaming_simple.yaml`)

Demonstrates basic streaming with different handlers:
- Console output streaming
- File output streaming
- Buffer handler with stats

**Run it:**
```bash
mix pipeline.run examples/claude_streaming_simple.yaml
```

### 4. Advanced Streaming (`claude_streaming_advanced.yaml`)

Shows advanced streaming features:
- Callback handlers
- Session streaming
- Robust streaming with error recovery
- Extraction with streaming
- Batch processing

**Run it:**
```bash
mix pipeline.run examples/claude_streaming_advanced.yaml
```

## Understanding Streaming Output

When you run a streaming example, you'll see:

1. **Console Handler**: Real-time output in your terminal
2. **File Handler**: Messages written to a file as they arrive
3. **Buffer Handler**: Messages collected in memory with statistics

## Configuration Options

### Basic Streaming Configuration
```yaml
claude_options:
  async_streaming: true
  stream_handler: "console"  # or "file", "buffer", "callback"
```

### Advanced Configuration
```yaml
claude_options:
  async_streaming: true
  stream_handler: "file"
  stream_file_path: "/path/to/output.jsonl"
  stream_buffer_size: 100
  stream_file_rotation:
    enabled: true
    max_size_mb: 10
    max_files: 5
```

## Tips

1. **Console Handler** is best for demos and development
2. **File Handler** is great for logging and debugging
3. **Buffer Handler** is useful when you need to process messages programmatically
4. **Callback Handler** allows custom processing of each message

## Troubleshooting

If streaming doesn't work:
1. Ensure you're not in mock mode: `unset PIPELINE_MODE`
2. Check that Claude Code SDK is installed
3. Verify your Claude API credentials are set up