# Quick Start: From Manual Prompts to Seamless Automation

## 5-Minute Setup

### 1. Make the helper script accessible

```bash
# Add to your PATH (choose one)

# Option A: Symlink to ~/bin
mkdir -p ~/bin
ln -s $(pwd)/scripts/ai ~/bin/ai
export PATH="$HOME/bin:$PATH"  # Add to ~/.bashrc or ~/.zshrc

# Option B: Add alias
echo 'alias ai="'$(pwd)'/scripts/ai"' >> ~/.bashrc
source ~/.bashrc
```

### 2. Test it works

```bash
# Mock mode (no API calls, no cost)
TEST_MODE=mock ai review examples/simple_test.yaml

# Should show mock output
```

### 3. Set up for real use

```bash
# Required: Gemini API key
export GEMINI_API_KEY="your-key-here"

# Required: Claude CLI
# Install from https://claude.ai/download
# Then run: claude auth

# Add to ~/.bashrc for persistence
echo 'export GEMINI_API_KEY="your-key"' >> ~/.bashrc
```

## Daily Usage

### Code Review (Most Common)

```bash
# Quick review of a file
ai review src/auth.ex

# Output appears in outputs/quick_review_*.md
```

### Understand Unfamiliar Code

```bash
ai explain lib/complex_module.ex

# Get plain-English explanation
```

### Debug an Error

```bash
# Save error to file first
mix test 2>&1 | tee logs/error.log

# Get analysis and fix suggestion
ai fix logs/error.log
```

## Your First Custom Workflow

Create `workflows/my_task.yaml`:

```yaml
workflow:
  name: "my_custom_task"

  steps:
    - name: "do_thing"
      type: "claude"
      output_to_file: "result.md"
      claude_options:
        model: "haiku"  # Fast and cheap
      prompt:
        - type: "file"
          path: "{{ input_file }}"
        - type: "static"
          content: "Do the thing I need done"
```

Run it:

```bash
mix pipeline.run.live workflows/my_task.yaml INPUT_FILE="data.txt"
cat outputs/result.md
```

## Integration Patterns

### Git Hook (Auto-review before commit)

```bash
# .git/hooks/pre-commit
#!/bin/bash

CHANGED=$(git diff --cached --name-only --diff-filter=ACM | grep '\.ex$')

for file in $CHANGED; do
  ./scripts/ai review $file

  # Optionally: fail if critical issues found
  if grep -q "CRITICAL" outputs/quick_review_*.md; then
    echo "❌ Critical issues in $file"
    exit 1
  fi
done
```

### Makefile (Team consistency)

```makefile
# Makefile
.PHONY: ai-review ai-fix

ai-review:
	@./scripts/ai review $(FILE)

ai-fix:
	@./scripts/ai fix $(LOG)

# Usage:
# make ai-review FILE=src/auth.ex
# make ai-fix LOG=logs/error.log
```

### IEx Helper (Elixir REPL)

```elixir
# .iex.exs
defmodule AI do
  def review(file), do: System.cmd("./scripts/ai", ["review", file]) |> elem(0) |> IO.puts()
  def explain(file), do: System.cmd("./scripts/ai", ["explain", file]) |> elem(0) |> IO.puts()
  def fix(log), do: System.cmd("./scripts/ai", ["fix", log]) |> elem(0) |> IO.puts()
end

# Usage:
# iex> AI.review("lib/my_app.ex")
```

## Common Workflows to Create

### Test Generation

```yaml
# workflows/test_gen.yaml
workflow:
  name: "generate_tests"
  steps:
    - name: "gen_tests"
      type: "claude"
      output_to_file: "tests_{{ timestamp }}.ex"
      claude_options:
        model: "sonnet"
        max_turns: 5
      prompt:
        - type: "file"
          path: "{{ code_file }}"
        - type: "static"
          content: |
            Generate comprehensive ExUnit tests for this module.
            Include: happy path, edge cases, error conditions.
```

### Documentation

```yaml
# workflows/gen_docs.yaml
workflow:
  name: "generate_docs"
  steps:
    - name: "write_docs"
      type: "gemini"
      output_to_file: "docs_{{ timestamp }}.md"
      model: "gemini-flash-lite-latest"
      prompt:
        - type: "file"
          path: "{{ code_file }}"
        - type: "static"
          content: |
            Generate comprehensive documentation:
            - Module overview
            - Function descriptions
            - Parameters and return values
            - Usage examples
            - Common pitfalls
```

### Refactoring Suggestions

```yaml
# workflows/refactor.yaml
workflow:
  name: "suggest_refactoring"
  steps:
    - name: "analyze"
      type: "claude"
      output_to_file: "refactor_{{ timestamp }}.md"
      claude_options:
        model: "sonnet"
      prompt:
        - type: "file"
          path: "{{ code_file }}"
        - type: "static"
          content: |
            Suggest refactoring improvements:
            - Code smells
            - Duplication
            - Complexity reduction
            - Better patterns
            - Specific changes with examples
```

## Tips for Success

1. **Start with ONE workflow you'll use daily**
2. **Use mock mode first** (TEST_MODE=mock)
3. **Review AI output** - don't blindly trust
4. **Iterate on prompts** - refine based on results
5. **Share with team** - commit workflows to git

## What to Automate (Priority Order)

**Week 1:**
- ✅ Code review (most common)
- ✅ Code explanation (learning)

**Week 2:**
- Test generation
- Bug fix suggestions

**Week 3:**
- Documentation generation
- Refactoring suggestions

**Week 4:**
- PR review automation
- CI/CD integration

## Troubleshooting

### "Mix task not found"
```bash
# Run from project root
cd /path/to/pipeline_ex
./scripts/ai review file.ex
```

### "GEMINI_API_KEY not set"
```bash
export GEMINI_API_KEY="your-key"
# Or add to ~/.bashrc
```

### "Claude CLI not found"
```bash
# Install Claude CLI
# https://claude.ai/download
# Then authenticate
claude auth
```

### "Outputs directory doesn't exist"
```bash
mkdir -p outputs
# Or run any pipeline - it auto-creates
```

## Next Steps

1. ✅ Set up the `ai` script
2. ✅ Run one workflow in mock mode
3. ✅ Run same workflow in live mode
4. ✅ Create your first custom workflow
5. ✅ Add to git hooks or Makefile
6. ✅ Share with team

**Goal:** Within 1 week, you should be running AI workflows without thinking about it.

## Resources

- [Full transition guide](docs/guides/transitioning_from_manual_prompts.md)
- [Programmatic usage](docs/guides/programmatic_usage.md)
- [Model selection](docs/guides/model_selection.md)
- [Robustness guide](docs/guides/robustness_and_reliability.md)
