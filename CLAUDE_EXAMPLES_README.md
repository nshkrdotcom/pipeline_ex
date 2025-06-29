# Claude SDK Integration Examples

This directory contains comprehensive examples demonstrating all Claude SDK functionality within the pipeline orchestration system.

## Quick Start

```bash
# Test basic Claude integration
mix run test_claude_features_final.exs

# Test comprehensive showcase workflow
mix run pipeline.yaml claude_features_showcase.yaml
```

## Example Files

### 1. `claude_features_showcase.yaml` ⭐
**Complete working example showcasing all Claude features:**

- ✅ Basic Claude interaction
- ✅ Multi-turn conversation control (`max_turns`)
- ✅ Tool restrictions (`allowed_tools`)
- ✅ System prompts (`system_prompt`)
- ✅ Working directory control (`cwd`)
- ✅ Verbose logging (`verbose`)
- ✅ Previous response chaining
- ✅ File output and result tracking

### 2. `claude_comprehensive_example.yaml`
**Advanced example with all Claude SDK options:**

- Complex multi-step workflows
- Permission modes (`default`, `plan`, `bypass_permissions`)
- Advanced tool usage (`Glob`, `Grep`, `Task`, `WebSearch`)
- System prompt variations (`append_system_prompt`)
- Error handling demonstrations
- Security-focused configurations

### 3. Test Scripts

#### `test_claude_features_final.exs`
Comprehensive test that verifies all Claude functionality is working correctly.

#### `test_comprehensive_claude.exs` 
Tests the advanced comprehensive example workflow.

#### Legacy test files:
- `debug_claude_response.exs` - Debug Claude response processing
- `test_claude_simple.exs` - Simple Claude SDK test
- `test_options_issue.exs` - Options configuration testing

## Claude SDK Features Demonstrated

### 🔧 Core Features
- **Basic Interaction**: Simple prompt → response workflows
- **Multi-turn Control**: Manage conversation length with `max_turns`
- **Streaming Processing**: Real-time message handling
- **Cost Tracking**: Automatic cost calculation and reporting

### ⚙️ Configuration Options
- **Tool Management**: 
  - `allowed_tools` - Whitelist specific tools
  - `disallowed_tools` - Blacklist specific tools
- **System Prompts**:
  - `system_prompt` - Override default system instructions
  - `append_system_prompt` - Add additional instructions
- **Execution Control**:
  - `verbose` - Enable detailed logging
  - `cwd` - Set working directory
  - `permission_mode` - Control security permissions

### 🔗 Integration Features
- **Previous Response Chaining**: Reference outputs from earlier steps
- **File Output**: Save results to structured JSON files
- **Error Handling**: Graceful failure recovery
- **Workspace Management**: Isolated execution environments

### 🛠️ Tool Ecosystem
- **File Operations**: `Write`, `Edit`, `Read`
- **System Commands**: `Bash`
- **Search Tools**: `Glob`, `Grep` 
- **Advanced Features**: `Task`, `LS`, `WebSearch`

## Configuration Examples

### Basic Claude Step
```yaml
- name: "simple_task"
  type: "claude"
  role: "muscle"
  prompt:
    - type: "static"
      content: "Create a Python hello world program"
```

### Advanced Claude Step
```yaml
- name: "advanced_task"
  type: "claude"
  role: "muscle"
  claude_options:
    max_turns: 3
    allowed_tools: ["Write", "Read", "Bash"]
    system_prompt: "You are a senior Python developer"
    verbose: true
    cwd: "./project"
  prompt:
    - type: "static"
      content: "Create a complete Python project"
    - type: "previous_response"
      step: "planning_step"
  output_to_file: "result.json"
```

### Previous Response Integration
```yaml
- name: "build_on_previous"
  type: "claude"
  claude_options:
    max_turns: 2
  prompt:
    - type: "static"
      content: "Enhance this code:"
    - type: "previous_response"
      step: "initial_implementation"
```

## Implementation Details

### Message Processing
The Claude SDK returns a stream of messages with different types:
- `system` - Session initialization
- `assistant` - Claude's responses  
- `result` - Final results with cost/duration stats

### Response Structure
All Claude steps return:
```elixir
%{
  text: "Claude's response content",
  success: true,
  cost: 0.0545374
}
```

### Error Handling
Failed executions return:
```elixir
%{
  text: "Error description",
  success: false,
  error: "Detailed error info"
}
```

## Testing and Validation

### Run All Tests
```bash
# Test basic functionality
mix run test_claude_features_final.exs

# Test specific configurations  
mix run debug_claude_response.exs

# Test full workflow
mix run pipeline.yaml claude_features_showcase.yaml
```

### Verify Output
Check `./outputs/claude_showcase/` for result files demonstrating:
- Successful Claude interactions
- Cost tracking
- Response formatting
- Error handling

## Production Usage

This Claude SDK integration is ready for production use in:
- **Code Generation Pipelines**: Automated code creation
- **Documentation Systems**: API doc generation
- **Code Review Workflows**: Automated analysis
- **Testing Automation**: Test case generation
- **Refactoring Tools**: Code improvement
- **Security Audits**: Vulnerability scanning

The examples provide a complete foundation for building sophisticated AI-powered development workflows.

## Troubleshooting

### Common Issues
1. **Empty Responses**: Ensure prompts are properly formatted
2. **Tool Restrictions**: Verify `allowed_tools` includes required tools
3. **Cost Tracking**: Check API credentials and usage limits
4. **File Permissions**: Ensure workspace directories are writable

### Debug Mode
Enable verbose logging:
```yaml
claude_options:
  verbose: true
```

Check debug logs in `/tmp/` for detailed execution traces.