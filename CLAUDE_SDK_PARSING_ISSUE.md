# Claude Code SDK Parsing Issue Documentation

## Issue Summary

The Claude Code SDK has a parsing issue when using `output_format: "text"` in live mode. The SDK fails with the error:

```
FunctionClauseError: no function clause matching in Access.get/3
(elixir 1.18.3) lib/access.ex:320: Access.get(4.0, "type", nil)
```

## Root Cause Analysis

### The Problem
1. **Claude CLI Output**: When `--output-format text` is used, Claude CLI returns plain text (e.g., `"4"`)
2. **SDK Expectation**: The SDK always expects JSON format and tries to parse all responses as JSON
3. **Parsing Failure**: The SDK attempts `Access.get(4.0, "type", nil)` on the numeric response, which fails

### Technical Details

**Claude CLI Outputs:**
```bash
# Text format (causes issue)
$ claude --print --output-format text --max-turns 1 "What is 2+2?"
4

# JSON format (works correctly)  
$ claude --print --output-format json --max-turns 1 "What is 2+2?"
{"type":"result","subtype":"success","is_error":false,"duration_ms":2363,"result":"4","session_id":"...","total_cost_usd":0.0041904}
```

**SDK Processing:**
- The SDK receives the plain text `"4"`
- It tries to parse this as JSON in `ClaudeCodeSDK.Message.parse_message/1`
- The parsing logic expects a map with a `"type"` key
- `Access.get(4.0, "type", nil)` fails because `4.0` is a number, not a map

## Affected Configurations

### ❌ Problematic Configurations
Any configuration using `output_format: "text"`:

```yaml
claude_options:
  output_format: "text"  # Will fail in live mode
```

### ✅ Working Configurations
```yaml
claude_options:
  output_format: "json"        # Works correctly
  output_format: "stream_json" # Likely works
```

## Examples That Reproduce the Issue

### Simple Reproduction
```yaml
workflow:
  name: "format_issue_test"
  steps:
    - name: "problematic_step"
      type: "claude_smart"
      preset: "development"
      prompt:
        - type: "static"
          content: "What is 2+2?"
      claude_options:
        output_format: "text"  # ❌ Fails in live mode
```

### Working Alternative
```yaml
workflow:
  name: "format_working_test"
  steps:
    - name: "working_step"
      type: "claude_smart"
      preset: "development"
      prompt:
        - type: "static"
          content: "What is 2+2?"
      claude_options:
        output_format: "json"  # ✅ Works in live mode
```

## Impact Assessment

### Affected Features
- ✅ **Mock Mode**: All formats work (uses mock responses)
- ❌ **Live Mode with Text Format**: Fails with parsing error
- ✅ **Live Mode with JSON Format**: Works correctly
- ❌ **All Enhanced Step Types**: Affected when using text format
  - `claude_smart`
  - `claude_session`
  - `claude_extract`
  - `claude_batch`
  - `claude_robust`

### Test Results
```bash
# Mock mode - all formats work
mix pipeline.run examples/claude_format_issue_simple.yaml
# ✅ Success: Both text and json steps complete

# Live mode - text format fails
TEST_MODE=live mix pipeline.run examples/claude_format_issue_simple.yaml
# ❌ Fails on first step with Access.get/3 error
```

## Workarounds

### Immediate Workaround
Always use `output_format: "json"` in live mode:

```yaml
claude_options:
  output_format: "json"  # Use JSON instead of text
```

### Preset Configuration
Update presets to use JSON format:

```elixir
# In OptionBuilder presets
%{
  "output_format" => "json",  # Changed from "text"
  # ... other options
}
```

## Solution Requirements

The Claude Code SDK needs to be updated to handle different output formats:

### Required Changes
1. **Format-Aware Parsing**: Check the configured output format before parsing
2. **Text Response Handling**: Handle plain text responses for `output_format: "text"`
3. **Response Wrapping**: Wrap text responses in a consistent message structure

### Proposed SDK Fix
```elixir
defp parse_response(raw_output, output_format) do
  case output_format do
    :text ->
      # Handle plain text response
      %ClaudeCodeSDK.Message{
        type: :assistant,
        data: %{message: %{"content" => String.trim(raw_output), "role" => "assistant"}},
        raw: raw_output
      }
    
    :json ->
      # Handle JSON response (current logic)
      Jason.decode!(raw_output)
      |> parse_json_message()
    
    :stream_json ->
      # Handle streaming JSON
      parse_streaming_json(raw_output)
  end
end
```

## Testing

### Comprehensive Test Cases
- [x] **Mock Mode**: All formats work
- [x] **Live JSON Format**: Works correctly  
- [x] **Live Text Format**: Fails with parsing error
- [ ] **Live Stream JSON**: Needs testing
- [ ] **Edge Cases**: Empty responses, special characters, multiline text

### Test Files Created
- `examples/claude_format_issue_simple.yaml` - Simple reproduction
- `examples/claude_output_formats_test.yaml` - Comprehensive format testing
- `test_claude_parsing_issue.exs` - Standalone reproduction script

## Current Status

- ✅ **Issue Identified**: Claude SDK parsing logic incompatible with text format
- ✅ **Root Cause Found**: `Access.get/3` called on numeric response
- ✅ **Workaround Available**: Use JSON format instead of text
- ❌ **SDK Fix Pending**: Requires format-aware parsing logic
- ✅ **Documentation Complete**: Issue fully documented with examples

## Recommendations

1. **Short Term**: Update all pipeline configurations to use `output_format: "json"`
2. **Medium Term**: Update OptionBuilder presets to default to JSON format
3. **Long Term**: Fix the Claude Code SDK to handle all output formats correctly
4. **Testing**: Implement comprehensive format testing in CI/CD pipeline