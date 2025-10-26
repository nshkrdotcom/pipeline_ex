# Transitioning from Manual Prompts to Automated Pipelines

## Your Current Workflow (Manual)

You're probably doing something like this:

```bash
# Terminal 1: Claude CLI
$ claude "Review this code for security issues"
[copy/paste code]
[read response]
[decide next step]

# Terminal 2: Codex
$ codex "Fix the issues Claude found"
[copy/paste issues from Claude]
[review generated code]

# Terminal 3: Gemini (via browser/API)
[paste original code + Claude's findings + Codex's fixes]
"Write tests for these changes"
```

**Problems:**
- Copy/paste between tools
- Context loss between steps
- Can't reproduce
- Can't share with team
- Can't run in CI/CD

## The Transition Strategy

### Phase 1: Document Your Actual Workflows (No Pipeline Yet)

**Start by just writing down what you do:**

```markdown
# my_actual_workflow.md

## Code Review Workflow
1. Claude: "Review for security and style issues"
2. Read response, copy issues
3. Codex: "Fix these issues: [paste]"
4. Review fixes
5. Gemini: "Write tests for changes"
6. Manually integrate everything

## Bug Analysis Workflow
1. Gemini: "Analyze this error log"
2. Claude: "Suggest fixes based on: [analysis]"
3. Codex: "Implement fix: [suggestion]"
4. Test manually
```

### Phase 2: Hybrid Approach - Semi-Automation

**Create simple pipeline for repetitive parts, manual for decisions:**

```yaml
# workflows/code_review_helper.yaml
workflow:
  name: "code_review_helper"

  steps:
    # Automated: Get multiple AI opinions
    - name: "claude_review"
      type: "claude"
      output_to_file: "claude_review.md"
      claude_options:
        model: "haiku"
        max_turns: 1
      prompt:
        - type: "file"
          path: "{{ code_file }}"
        - type: "static"
          content: "Review this code for security, performance, and style issues."

    - name: "gemini_review"
      type: "gemini"
      output_to_file: "gemini_review.md"
      model: "gemini-flash-lite-latest"
      prompt:
        - type: "file"
          path: "{{ code_file }}"
        - type: "static"
          content: "Provide a fresh perspective on this code's quality and maintainability."

# Still manual: You read both reviews, decide what to fix
# Still manual: You use codex to implement fixes
# Still manual: You test and integrate
```

**Usage:**
```bash
# Run the automated part
CODE_FILE=src/auth.ex mix pipeline.run.live workflows/code_review_helper.yaml

# Manual: Read outputs/claude_review.md and outputs/gemini_review.md
# Manual: Decide what to fix
# Manual: Use codex to fix
```

### Phase 3: Progressive Automation

**Automate one more step at a time:**

```yaml
# workflows/code_review_with_fixes.yaml
workflow:
  name: "code_review_with_fixes"

  steps:
    - name: "multi_review"
      type: "gemini"
      output_to_file: "review.md"
      prompt:
        - type: "file"
          path: "{{ code_file }}"
        - type: "static"
          content: |
            Review this code and list specific issues.
            Format as:
            1. [SECURITY] Issue description
            2. [PERFORMANCE] Issue description

    - name: "suggest_fixes"
      type: "claude"
      output_to_file: "fixes.md"
      claude_options:
        model: "sonnet"
        allowed_tools: ["Read", "Edit"]
        max_turns: 5
      prompt:
        - type: "static"
          content: "Based on these code review findings, suggest specific fixes:"
        - type: "previous_response"
          step: "multi_review"

# Still manual: You review suggested fixes
# Still manual: You apply the ones you want
# Still manual: You test
```

### Phase 4: Full Automation for Standard Cases

**Fully automated for common patterns:**

```yaml
# workflows/security_scan_and_fix.yaml
workflow:
  name: "security_scan_and_fix"

  steps:
    - name: "scan"
      type: "gemini"
      model: "gemini-flash-lite-latest"
      prompt:
        - type: "file"
          path: "{{ code_file }}"
        - type: "static"
          content: "List security vulnerabilities in this code."

    - name: "fix"
      type: "claude"
      claude_options:
        model: "haiku"
        allowed_tools: ["Read", "Write", "Edit"]
        max_turns: 10
      prompt:
        - type: "static"
          content: "Fix these security issues and save the fixed code:"
        - type: "previous_response"
          step: "scan"
        - type: "file"
          path: "{{ code_file }}"

    - name: "verify"
      type: "gemini"
      prompt:
        - type: "static"
          content: "Verify all security issues were fixed:"
        - type: "previous_response"
          step: "fix"

# Automated: Runs without intervention
# Manual: You review the fixes before committing
```

## Seamless Integration Patterns

### Pattern 1: Alias for Quick Access

Add to your `.bashrc` or `.zshrc`:

```bash
# Quick code review
alias cr='function _cr() { mix pipeline.run.live workflows/quick_review.yaml CODE_FILE="$1"; }; _cr'

# Usage:
$ cr src/auth.ex
# Automatically reviews and shows results
```

### Pattern 2: Git Hook Integration

```bash
# .git/hooks/pre-commit
#!/bin/bash

# Get changed files
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.ex$')

if [ -n "$CHANGED_FILES" ]; then
  echo "🔍 Running automated code review..."

  for file in $CHANGED_FILES; do
    mix pipeline.run.live workflows/pre_commit_check.yaml CODE_FILE="$file"

    # Check if review found critical issues
    if grep -q "CRITICAL" "outputs/review_$file.md"; then
      echo "❌ Critical issues found in $file"
      echo "Review: outputs/review_$file.md"
      exit 1
    fi
  done
fi

exit 0
```

### Pattern 3: VS Code Integration

**Create VS Code task (`.vscode/tasks.json`):**

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "AI Code Review",
      "type": "shell",
      "command": "mix pipeline.run.live workflows/review.yaml CODE_FILE=${file}",
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "AI Fix Issues",
      "type": "shell",
      "command": "mix pipeline.run.live workflows/fix_issues.yaml CODE_FILE=${file}",
      "problemMatcher": []
    }
  ]
}
```

**Usage:** Right-click file → Run Task → "AI Code Review"

### Pattern 4: Interactive CLI Wrapper

```bash
#!/bin/bash
# scripts/ai_workflow.sh

echo "🤖 AI Workflow Helper"
echo ""
echo "What do you want to do?"
echo "1) Review code"
echo "2) Fix bugs"
echo "3) Write tests"
echo "4) Explain code"
echo "5) Custom prompt"
read -p "Choice: " choice

read -p "File path: " file

case $choice in
  1)
    mix pipeline.run.live workflows/review.yaml CODE_FILE="$file"
    cat outputs/review.md
    ;;
  2)
    read -p "Describe the bug: " bug
    echo "$bug" > /tmp/bug_description.txt
    mix pipeline.run.live workflows/fix_bug.yaml CODE_FILE="$file" BUG_DESC="/tmp/bug_description.txt"
    cat outputs/fix.md
    ;;
  3)
    mix pipeline.run.live workflows/write_tests.yaml CODE_FILE="$file"
    cat outputs/tests.ex
    ;;
  4)
    mix pipeline.run.live workflows/explain.yaml CODE_FILE="$file"
    cat outputs/explanation.md
    ;;
  5)
    read -p "Your prompt: " prompt
    echo "$prompt" > /tmp/custom_prompt.txt
    mix pipeline.run.live workflows/custom.yaml CODE_FILE="$file" PROMPT="/tmp/custom_prompt.txt"
    cat outputs/result.md
    ;;
esac
```

### Pattern 5: Tmux/Screen Integration

```bash
# .tmux.conf or script
# Open split panes for multi-AI workflow

#!/bin/bash
# scripts/ai_session.sh

tmux new-session -d -s ai_workflow

# Pane 1: Code editor
tmux send-keys -t ai_workflow "vim $1" C-m

# Pane 2: Pipeline runner
tmux split-window -h -t ai_workflow
tmux send-keys -t ai_workflow "# Pipeline outputs appear here" C-m

# Pane 3: Results viewer
tmux split-window -v -t ai_workflow
tmux send-keys -t ai_workflow "tail -f outputs/*.md" C-m

tmux attach -t ai_workflow
```

## Real-World Workflow Examples

### Example 1: Your Current PR Review Process

**Before (Manual):**
```bash
$ claude "Review this PR"
[paste PR diff]
[read response]
[manually check each file]
```

**After (Hybrid):**
```yaml
# workflows/pr_review.yaml
workflow:
  name: "pr_review"
  steps:
    - name: "get_diff"
      type: "claude"
      claude_options:
        model: "haiku"
        allowed_tools: ["Bash"]
      prompt:
        - type: "static"
          content: "Run: git diff main...HEAD and save to diff.txt"

    - name: "review_changes"
      type: "claude"
      output_to_file: "pr_review.md"
      claude_options:
        model: "sonnet"
      prompt:
        - type: "file"
          path: "diff.txt"
        - type: "static"
          content: |
            Review this PR for:
            - Breaking changes
            - Security issues
            - Performance concerns
            - Test coverage
            Format as a GitHub PR comment.

# Usage: Just run once per PR
$ mix pipeline.run.live workflows/pr_review.yaml
$ cat outputs/pr_review.md
# Copy/paste into GitHub
```

### Example 2: Bug Investigation

**Before (Manual):**
```bash
$ gemini "What's wrong with this error?"
[paste error log]
[read analysis]
$ claude "How do I fix: [paste analysis]"
[read fix]
$ codex "Implement: [paste fix]"
```

**After (Automated):**
```yaml
# workflows/debug_error.yaml
workflow:
  name: "debug_error"
  steps:
    - name: "analyze_error"
      type: "gemini"
      model: "gemini-2.5-flash"
      prompt:
        - type: "file"
          path: "{{ error_log }}"
        - type: "static"
          content: "Analyze this error and identify root cause."

    - name: "find_code"
      type: "claude"
      claude_options:
        allowed_tools: ["Grep", "Read"]
        model: "haiku"
      prompt:
        - type: "static"
          content: "Find the code causing this error:"
        - type: "previous_response"
          step: "analyze_error"

    - name: "suggest_fix"
      type: "claude"
      output_to_file: "fix_suggestion.md"
      claude_options:
        model: "sonnet"
      prompt:
        - type: "static"
          content: "Suggest a fix for this bug:"
        - type: "previous_response"
          step: "find_code"

    - name: "implement_fix"
      type: "claude"
      claude_options:
        allowed_tools: ["Read", "Edit", "Write"]
        model: "sonnet"
        max_turns: 15
      prompt:
        - type: "static"
          content: "Implement this fix:"
        - type: "previous_response"
          step: "suggest_fix"

# Usage:
$ mix pipeline.run.live workflows/debug_error.yaml ERROR_LOG="logs/error.log"
# Review outputs/fix_suggestion.md
# Code changes applied automatically!
```

### Example 3: Documentation Generation

**Before (Manual):**
```bash
$ claude "Document this function"
[paste code]
[copy response]
[manually add to docs]
```

**After (Fully Automated):**
```yaml
# workflows/auto_document.yaml
workflow:
  name: "auto_document"
  steps:
    - name: "generate_docs"
      type: "gemini"
      model: "gemini-flash-lite-latest"
      prompt:
        - type: "file"
          path: "{{ source_file }}"
        - type: "static"
          content: |
            Generate comprehensive documentation for this module.
            Include: purpose, functions, parameters, return values, examples.

    - name: "write_doc_file"
      type: "claude"
      claude_options:
        allowed_tools: ["Write"]
        model: "haiku"
      prompt:
        - type: "static"
          content: "Save this documentation to docs/{{ module_name }}.md:"
        - type: "previous_response"
          step: "generate_docs"

# Run for entire project:
$ for file in lib/**/*.ex; do
    MODULE=$(basename $file .ex)
    mix pipeline.run.live workflows/auto_document.yaml \
      SOURCE_FILE="$file" MODULE_NAME="$MODULE"
  done
```

## Making It "Seamless"

### 1. Shell Functions (Most Seamless)

```bash
# Add to ~/.bashrc

# Quick review
review() {
  mix pipeline.run.live workflows/review.yaml CODE_FILE="$1" && \
  bat outputs/review.md  # or cat
}

# Fix issues
fix() {
  mix pipeline.run.live workflows/fix.yaml CODE_FILE="$1" ISSUE="$2"
}

# Write tests
test-gen() {
  mix pipeline.run.live workflows/test_gen.yaml CODE_FILE="$1"
}

# Usage:
$ review src/auth.ex
$ fix src/auth.ex "SQL injection vulnerability"
$ test-gen src/auth.ex
```

### 2. Project-Specific Makefile

```makefile
# Makefile
.PHONY: ai-review ai-fix ai-test ai-docs

ai-review:
	@mix pipeline.run.live workflows/review.yaml CODE_FILE=$(FILE)
	@cat outputs/review.md

ai-fix:
	@mix pipeline.run.live workflows/fix.yaml CODE_FILE=$(FILE) ISSUE="$(ISSUE)"
	@cat outputs/fix.md

ai-test:
	@mix pipeline.run.live workflows/test_gen.yaml CODE_FILE=$(FILE)
	@cat outputs/tests.ex

ai-docs:
	@for file in lib/**/*.ex; do \
		mix pipeline.run.live workflows/doc_gen.yaml SOURCE_FILE=$$file; \
	done

# Usage:
$ make ai-review FILE=src/auth.ex
$ make ai-fix FILE=src/auth.ex ISSUE="add rate limiting"
$ make ai-docs
```

### 3. IEx Helper (Elixir REPL)

```elixir
# .iex.exs

defmodule AIHelper do
  def review(file) do
    System.cmd("mix", ["pipeline.run.live", "workflows/review.yaml", "CODE_FILE=#{file}"])
    File.read!("outputs/review.md") |> IO.puts()
  end

  def fix(file, issue) do
    System.cmd("mix", ["pipeline.run.live", "workflows/fix.yaml",
                       "CODE_FILE=#{file}", "ISSUE=#{issue}"])
    File.read!("outputs/fix.md") |> IO.puts()
  end

  def explain(file) do
    System.cmd("mix", ["pipeline.run.live", "workflows/explain.yaml", "CODE_FILE=#{file}"])
    File.read!("outputs/explanation.md") |> IO.puts()
  end
end

# Usage in IEx:
iex> AIHelper.review("lib/my_app/auth.ex")
iex> AIHelper.fix("lib/my_app/auth.ex", "add tests")
```

## Gradual Adoption Checklist

- [ ] **Week 1:** Document your current manual workflows
- [ ] **Week 2:** Create one simple pipeline for most common task
- [ ] **Week 3:** Add shell alias for that pipeline
- [ ] **Week 4:** Create pipelines for 2-3 more common tasks
- [ ] **Month 2:** Add git hooks for automated checks
- [ ] **Month 3:** Integrate into CI/CD
- [ ] **Month 4:** Team adoption - share workflows

## Common Pitfalls to Avoid

1. **Don't try to automate everything at once**
   - Start with ONE repetitive task
   - Get comfortable
   - Expand gradually

2. **Don't lose the human in the loop (initially)**
   - Keep manual review step
   - Pipelines suggest, you decide
   - Build trust gradually

3. **Don't make pipelines too rigid**
   - Use variables: `{{ file }}`, `{{ issue }}`
   - Support multiple use cases
   - Easy to customize per run

4. **Don't forget to version control workflows**
   ```bash
   git add workflows/
   git commit -m "Add code review workflow"
   ```

## Success Metrics

You'll know integration is successful when:

- ✅ You run pipelines without thinking
- ✅ You forget how you did it manually
- ✅ Team members ask for your workflows
- ✅ CI/CD uses your pipelines
- ✅ You spend more time reviewing AI output than prompting
- ✅ You can reproduce results reliably

## Next Steps

1. Pick ONE task you do multiple times per day
2. Write it down as manual steps
3. Create a simple pipeline for it
4. Add a shell alias
5. Use it for a week
6. Iterate based on what's annoying
7. Add one more task

**Start small, stay consistent, expand gradually.**
