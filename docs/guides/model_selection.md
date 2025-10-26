# Model Selection Guide

## Overview

PipelineEx supports multiple AI providers with explicit model selection. This guide covers how to choose and configure models for optimal performance and cost.

## Available Models

### Claude Models (via Claude Agent SDK)

Use the `ClaudeAgentSDK.Model.list_models()` function to get the complete list:

```elixir
iex> ClaudeAgentSDK.Model.list_models()
["claude-haiku-4-5-20251001", "claude-opus-4-1-20250805", "claude-sonnet-4-5-20250929",
 "claude-sonnet-4-5-20250929[1m]", "haiku", "opus", "sonnet", "sonnet[1m]"]
```

#### Short Forms (Recommended)

- `"haiku"` - Claude Haiku 4.5 (claude-haiku-4-5-20251001) - **Fastest, most cost-effective** ⭐ **DEFAULT**
- `"sonnet"` - Claude Sonnet 4.5 (claude-sonnet-4-5-20250929) - **Balanced quality and speed**
- `"opus"` - Claude Opus 4.1 (claude-opus-4-1-20250805) - **Highest quality**
- `"sonnet[1m]"` - Claude Sonnet 4.5 with 1M context (claude-sonnet-4-5-20250929[1m])

#### Full Model IDs

You can also use full model identifiers for explicit version control:

- `"claude-opus-4-1-20250805"`
- `"claude-sonnet-4-5-20250929"`
- `"claude-haiku-4-5-20251001"`
- `"claude-sonnet-4-5-20250929[1m]"`

### Gemini Models (via Gemini Ex)

Common Gemini models supported:

- `"gemini-flash-lite-latest"` - Latest lightweight Flash - **Fastest and most cost-effective** ⭐ **DEFAULT**
- `"gemini-2.5-flash"` - Latest Flash model - **Fast and cost-effective**
- `"gemini-2.5-flash-lite-preview-06-17"` - Specific lightweight variant
- `"gemini-2.0-flash"` - Previous generation Flash
- `"gemini-1.5-pro"` - Pro model - **Higher quality**
- `"gemini-1.5-flash"` - Previous generation Flash

## Configuration

### Gemini Steps

Specify the model directly on the step:

```yaml
steps:
  - name: "analysis"
    type: "gemini"
    model: "gemini-flash-lite-latest"  # Explicit model selection (default)
    prompt:
      - type: "static"
        content: "Analyze this code..."
```

### Claude Steps

Specify the model in `claude_options`:

```yaml
steps:
  - name: "code_review"
    type: "claude"
    claude_options:
      model: "haiku"            # Short form recommended (default)
      max_turns: 3
      allowed_tools: ["Read", "Grep"]
    prompt:
      - type: "static"
        content: "Review this code..."
```

### With Fallback Model

For production reliability, specify a fallback:

```yaml
steps:
  - name: "critical_task"
    type: "claude"
    claude_options:
      model: "opus"              # Primary model
      fallback_model: "sonnet"   # Falls back if opus unavailable
      max_turns: 5
```

## Model Selection Strategy

### Cost Optimization

**Lowest Cost → Highest Cost:**

1. **Gemini Flash Lite** (`gemini-flash-lite-latest`) - Best for high-volume tasks ⭐ **DEFAULT**
2. **Claude Haiku** (`haiku`) - Fast Claude responses ⭐ **DEFAULT**
3. **Gemini Flash** (`gemini-2.5-flash`) - Balanced Gemini option
4. **Claude Sonnet** (`sonnet`) - Balanced Claude option
5. **Gemini Pro** (`gemini-1.5-pro`) - Higher quality Gemini
6. **Claude Opus** (`opus`) - Highest quality, most expensive

### Quality vs Speed Trade-offs

| Use Case | Recommended Model | Rationale |
|----------|------------------|-----------|
| Quick analysis | `gemini-flash-lite-latest` or `haiku` | Fast, cost-effective (defaults) |
| Code generation | `haiku` or `sonnet` | Good balance of quality and speed |
| Code review | `haiku` or `sonnet` | Catches most issues efficiently |
| Security audit | `sonnet` or `opus` | Higher accuracy for critical tasks |
| Documentation | `gemini-flash-lite-latest` or `haiku` | Straightforward task (defaults) |
| Complex refactoring | `sonnet` or `opus` | Requires deep understanding |
| Batch processing | `gemini-flash-lite-latest` | Volume efficiency (default) |

## Examples

### Example 1: Cost-Effective Pipeline

```yaml
workflow:
  name: "batch_documentation"

  steps:
    - name: "generate_docs"
      type: "gemini"
      model: "gemini-flash-lite-latest"  # Most cost-effective (default)
      prompt:
        - type: "static"
          content: "Generate documentation for these functions..."
```

### Example 2: High-Quality Analysis

```yaml
workflow:
  name: "security_audit"

  steps:
    - name: "deep_analysis"
      type: "claude"
      claude_options:
        model: "opus"              # Highest quality
        fallback_model: "sonnet"
        max_turns: 10
        allowed_tools: ["Read", "Grep", "Glob"]
      prompt:
        - type: "static"
          content: "Perform comprehensive security audit..."
```

### Example 3: Mixed Strategy

```yaml
workflow:
  name: "code_review_pipeline"

  steps:
    # Fast initial scan
    - name: "quick_scan"
      type: "gemini"
      model: "gemini-flash-lite-latest"  # Default - fastest scan
      prompt:
        - type: "static"
          content: "Quick syntax and style check..."

    # Deep review of flagged issues
    - name: "detailed_review"
      type: "claude"
      claude_options:
        model: "sonnet"  # Upgrade for detailed analysis
        max_turns: 5
      condition: "quick_scan.issues_found"
      prompt:
        - type: "static"
          content: "Deep dive into identified issues..."
```

## Best Practices

### 1. **Always Use Explicit Models**

✅ **Good:**
```yaml
model: "gemini-flash-lite-latest"  # Explicit (uses default, but clear)
```

✅ **Also Good:**
```yaml
model: "gemini-2.5-flash"  # Explicit upgrade from default
```

⚠️ **Acceptable (uses implicit defaults):**
```yaml
# No model specified - uses gemini-flash-lite-latest or haiku
```

### 2. **Use Short Forms for Claude**

✅ **Good:**
```yaml
claude_options:
  model: "sonnet"
```

✅ **Also Good (for version pinning):**
```yaml
claude_options:
  model: "claude-sonnet-4-5-20250929"
```

### 3. **Add Fallbacks for Production**

```yaml
claude_options:
  model: "opus"
  fallback_model: "sonnet"  # Ensures reliability
```

### 4. **Match Model to Task Complexity**

- Simple tasks → Fast models (`gemini-flash-lite-latest`, `haiku`) ⭐ **DEFAULTS**
- Moderate tasks → Balanced models (`gemini-2.5-flash`, `sonnet`)
- Complex tasks → Quality models (`sonnet`, `opus`)
- Critical tasks → Highest quality + fallback (`opus` → `sonnet`)

## Programmatic Model Selection

### List Available Claude Models

```elixir
# In IEx or code
iex> ClaudeAgentSDK.Model.list_models()
["claude-haiku-4-5-20251001", "claude-opus-4-1-20250805", ...]

# Validate a model
iex> ClaudeAgentSDK.Model.validate("sonnet")
{:ok, "sonnet"}

iex> ClaudeAgentSDK.Model.validate("invalid")
{:error, :invalid_model}

# Get suggestions for typos
iex> ClaudeAgentSDK.Model.suggest("sonet")
["sonnet", "claude-sonnet-4-5-20250929"]
```

### Dynamic Model Selection (Future)

```elixir
# Example: Select model based on task complexity
def select_model(task_complexity) do
  case task_complexity do
    :simple -> "gemini-2.5-flash"
    :moderate -> "sonnet"
    :complex -> "opus"
  end
end
```

## Cost Tracking

Pipeline execution results include cost information:

```elixir
{:ok, results} = Pipeline.Executor.execute(config)

# Results include per-step costs
%{
  "analysis" => %{
    text: "...",
    cost: 0.025,     # USD
    model: "claude-sonnet-4-5-20250929"
  }
}
```

## Viewing Results with Model Info

When running pipelines, the Mix task displays which model was used:

```bash
$ mix pipeline.run.live examples/simple_test.yaml

✅ Pipeline completed successfully!

📊 Results summary:
  • claude_test [Claude Sonnet 4.5]: Hello! How can I help you today?
  • gemini_test [Gemini 2.5 Flash]: Hello!
```

## References

- [Model Selection Demo Example](../../examples/model_selection_demo.yaml)
- [Claude Agent SDK Model Module](https://github.com/your-org/claude_agent_sdk/blob/main/lib/claude_agent_sdk/model.ex)
- [Comprehensive Config Example](../../examples/comprehensive_config_example.yaml)

## See Also

- [Testing Guide](testing_recursive_pipelines.md) - Testing with different models
- [Cost Optimization Guide](../features/) - Advanced cost optimization strategies
- [Context Management](context_management.md) - Managing large contexts with 1M models
