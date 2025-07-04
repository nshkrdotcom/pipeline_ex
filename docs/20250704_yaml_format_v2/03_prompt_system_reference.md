# Prompt System Reference

## Table of Contents

1. [Overview](#overview)
2. [Prompt Types](#prompt-types)
   - [Static Content](#static-content)
   - [File Content](#file-content)
   - [Previous Response](#previous-response)
   - [Session Context](#session-context)
   - [Claude Continue](#claude-continue)
3. [Prompt Composition](#prompt-composition)
4. [File-Based Prompts](#file-based-prompts)
5. [Template Variables](#template-variables)
6. [Content Processing](#content-processing)
7. [Prompt Libraries](#prompt-libraries)
8. [Advanced Patterns](#advanced-patterns)
9. [Best Practices](#best-practices)

## Overview

The Pipeline Prompt System enables sophisticated prompt management through:

- **Multiple prompt types** for different content sources
- **Dynamic composition** of prompts from various sources
- **External file management** for reusable prompts
- **Template variables** for dynamic content
- **Content extraction** and processing
- **Session management** for stateful conversations

## Prompt Types

### Static Content

**Type**: `static`  
**Purpose**: Inline text content defined directly in YAML

```yaml
prompt:
  - type: "static"
    content: |
      Analyze this code for the following aspects:
      1. Security vulnerabilities
      2. Performance bottlenecks
      3. Code quality issues
      4. Best practice violations
      
      Provide your analysis in JSON format.
```

**Features**:
- Multi-line content with YAML `|` syntax
- Direct embedding in workflow files
- No external dependencies
- Template variable support

**Use Cases**:
- Short, workflow-specific instructions
- Connecting text between other prompt types
- Dynamic prompts with variables
- Quick prototyping

### File Content

**Type**: `file`  
**Purpose**: Load content from external files

```yaml
prompt:
  - type: "file"
    path: "pipelines/prompts/analysis/security_review.md"
    
  # With variables
  - type: "file"
    path: "pipelines/prompts/templates/code_review.md"
    variables:
      language: "Python"
      framework: "FastAPI"
      focus_areas: ["security", "performance"]
    
  # Inject as variable
  - type: "file"
    path: "src/main.py"
    inject_as: "SOURCE_CODE"
    
  # With encoding
  - type: "file"
    path: "data/unicode_content.txt"
    encoding: "utf-8"
```

**Features**:
- Automatic file caching
- Change detection
- Variable substitution
- Content injection
- Encoding support

**Path Resolution**:
- Relative to project root
- Supports glob patterns (future)
- Environment variable expansion

### Previous Response

**Type**: `previous_response`  
**Purpose**: Reference outputs from earlier workflow steps

```yaml
prompt:
  # Simple reference
  - type: "previous_response"
    step: "analysis"
  
  # Extract specific field
  - type: "previous_response"
    step: "code_review"
    extract: "critical_issues"
  
  # With content processing
  - type: "previous_response"
    step: "detailed_analysis"
    extract_with: "content_extractor"
    format: "structured"
    post_processing:
      - "extract_code_blocks"
      - "extract_recommendations"
  
  # With summarization
  - type: "previous_response"
    step: "long_report"
    summary: true
    max_length: 1000
```

**Extract Options**:
- JSONPath expressions: `"data.items[0].value"`
- Nested field access: `"results.security.vulnerabilities"`
- Array indexing: `"items[2]"`
- Wildcard selection: `"items[*].name"`

**Content Processing**:
- `extract_with`: Use advanced extraction
- `summary`: Generate content summary
- `max_length`: Truncate to length
- `format`: Output format selection

### Session Context

**Type**: `session_context`  
**Purpose**: Include conversation history from Claude sessions

```yaml
prompt:
  # Include recent messages
  - type: "session_context"
    session_id: "development_session"
    include_last_n: 10
  
  # Include all messages
  - type: "session_context"
    session_id: "tutorial_session"
  
  # With filtering (future)
  - type: "session_context"
    session_id: "debug_session"
    include_last_n: 20
    filter: "role == 'assistant'"
```

**Features**:
- Session state retrieval
- Message history inclusion
- Turn limiting
- Context window management

**Use Cases**:
- Multi-turn conversations
- Continuing interrupted work
- Building on previous sessions
- Tutorial continuity

### Claude Continue

**Type**: `claude_continue`  
**Purpose**: Continue existing Claude conversation with new instructions

```yaml
prompt:
  - type: "claude_continue"
    new_prompt: |
      Now that we have the basic implementation, please:
      1. Add comprehensive error handling
      2. Include input validation
      3. Add unit tests
      4. Update the documentation
```

**Features**:
- Seamless conversation continuation
- Context preservation
- New instruction injection
- Session state maintenance

**Requirements**:
- Must be used with `claude_session` step type
- Requires active session
- Maintains conversation flow

## Prompt Composition

### Sequential Composition

Build complex prompts by combining multiple sources:

```yaml
prompt:
  # Context setup
  - type: "static"
    content: "## Project Context"
    
  - type: "file"
    path: "docs/project_overview.md"
  
  # Previous work
  - type: "static"
    content: "\n## Previous Analysis Results"
    
  - type: "previous_response"
    step: "initial_analysis"
    extract: "summary"
  
  # Current task
  - type: "static"
    content: "\n## Current Task"
    
  - type: "file"
    path: "pipelines/prompts/tasks/implementation.md"
    variables:
      component: "authentication"
      priority: "high"
  
  # Code context
  - type: "static"
    content: "\n## Existing Code"
    
  - type: "file"
    path: "src/auth.py"
```

### Conditional Composition

Include prompt parts based on conditions:

```yaml
steps:
  - name: "adaptive_prompt"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Analyze this code:"
        
      - type: "file"
        path: "src/main.py"
      
      # Include based on previous step
      - type: "previous_response"
        step: "security_scan"
        extract: "vulnerabilities"
        condition: "{{steps.security_scan.found_issues == true}}"
      
      # Dynamic file selection
      - type: "file"
        path: "{{steps.detect_type.template_path}}"
```

## File-Based Prompts

### Directory Structure

```
pipelines/prompts/
├── analysis/
│   ├── code_review.md
│   ├── security_audit.md
│   ├── performance_analysis.md
│   └── architecture_review.md
├── generation/
│   ├── api_endpoints.md
│   ├── test_cases.md
│   ├── documentation.md
│   └── implementation.md
├── extraction/
│   ├── data_parsing.md
│   ├── entity_extraction.md
│   └── summarization.md
├── templates/
│   ├── base_analysis.md
│   ├── base_generation.md
│   └── base_validation.md
└── common/
    ├── context_setup.md
    ├── output_format.md
    └── error_handling.md
```

### Prompt File Format

```markdown
# Security Analysis Prompt

## Purpose
Comprehensive security vulnerability assessment for {LANGUAGE} applications.

## Context Requirements
- Source code files
- Dependency list
- Previous security reports (if available)

## Analysis Instructions

Analyze the provided {PROJECT_TYPE} codebase for security vulnerabilities:

### 1. Authentication & Authorization
- Check for proper authentication mechanisms
- Verify authorization controls
- Assess session management
- Review password policies

### 2. Input Validation
- SQL injection vulnerabilities
- XSS (Cross-site scripting) risks
- Command injection possibilities
- Path traversal vulnerabilities

### 3. Data Protection
- Encryption usage (at rest and in transit)
- Sensitive data exposure
- Proper data sanitization
- PII handling compliance

## Output Format
{OUTPUT_FORMAT}

## Previous Findings
{PREVIOUS_FINDINGS}

## Code to Analyze
{CODE_CONTENT}
```

### Using Prompt Files

```yaml
steps:
  - name: "security_analysis"
    type: "claude"
    prompt:
      - type: "file"
        path: "pipelines/prompts/analysis/security_audit.md"
        variables:
          LANGUAGE: "Python"
          PROJECT_TYPE: "web application"
          OUTPUT_FORMAT: "JSON with severity levels"
      
      - type: "previous_response"
        step: "dependency_scan"
        inject_as: "PREVIOUS_FINDINGS"
      
      - type: "file"
        path: "src/"
        inject_as: "CODE_CONTENT"
```

## Template Variables

### Variable Definition

Variables can be defined at multiple levels:

```yaml
workflow:
  variables:
    project_name: "MyApp"
    language: "Python"
    
  steps:
    - name: "analyze"
      type: "gemini"
      variables:
        analysis_type: "security"
        depth: "comprehensive"
      prompt:
        - type: "file"
          path: "prompts/analysis.md"
          variables:
            PROJECT: "{{workflow.variables.project_name}}"
            LANG: "{{workflow.variables.language}}"
            TYPE: "{{step.variables.analysis_type}}"
```

### Variable Substitution

In prompt files:

```markdown
# {ANALYSIS_TYPE} Analysis for {PROJECT}

Perform a {DEPTH} analysis of this {LANG} project focusing on {FOCUS_AREAS}.

## Special Considerations for {FRAMEWORK}
{if FRAMEWORK == "Django"}
- Check Django-specific security settings
- Verify CSRF protection
- Review middleware configuration
{endif}
```

### Built-in Variables

Available in all prompts:

- `{{workflow.name}}`: Current workflow name
- `{{step.name}}`: Current step name
- `{{timestamp}}`: Current timestamp
- `{{date}}`: Current date
- `{{execution_id}}`: Unique execution ID

## Content Processing

### Content Extraction

Advanced extraction with ContentExtractor:

```yaml
prompt:
  - type: "previous_response"
    step: "comprehensive_analysis"
    extract_with: "content_extractor"
    format: "structured"              # Output format
    post_processing:
      - "extract_code_blocks"         # Extract code snippets
      - "extract_recommendations"      # Extract suggestions
      - "extract_links"               # Extract URLs
      - "extract_key_points"          # Extract main points
      - "extract_errors"              # Extract error messages
    include_metadata: true            # Include extraction metadata
    max_length: 5000                  # Length limit
```

### Summarization

Automatic content summarization:

```yaml
prompt:
  - type: "file"
    path: "docs/large_spec.md"
    summary: true
    max_summary_length: 500
    summary_focus: "technical_requirements"
  
  - type: "previous_response"
    step: "detailed_report"
    summary: true
    summary_style: "bullet_points"
```

### Format Transformations

Transform content between formats:

```yaml
prompt:
  - type: "previous_response"
    step: "data_analysis"
    transform: "json_to_markdown"
    
  - type: "file"
    path: "data.csv"
    transform: "csv_to_table"
```

## Prompt Libraries

### Creating Reusable Components

Define prompt components in YAML:

```yaml
# pipelines/prompts/components/analysis_base.yaml
analysis_base:
  security_check:
    - type: "static"
      content: |
        Perform security analysis focusing on:
        - Authentication vulnerabilities
        - Input validation issues
        - Data exposure risks
  
  performance_check:
    - type: "static"
      content: |
        Analyze performance characteristics:
        - Algorithm complexity
        - Resource usage
        - Scalability factors
  
  quality_check:
    - type: "static"
      content: |
        Assess code quality:
        - Readability and maintainability
        - Design patterns usage
        - Testing coverage
```

### Using Prompt Components

```yaml
steps:
  - name: "comprehensive_analysis"
    type: "gemini"
    prompt:
      # Include base context
      - type: "file"
        path: "prompts/components/context_setup.yaml"
        component: "project_context"
      
      # Include analysis components
      - type: "file"
        path: "prompts/components/analysis_base.yaml"
        component: "security_check"
      
      - type: "file"
        path: "prompts/components/analysis_base.yaml"
        component: "performance_check"
      
      # Add specific instructions
      - type: "static"
        content: "Focus particularly on the authentication module"
```

## Advanced Patterns

### Progressive Prompt Building

Build increasingly complex prompts:

```yaml
steps:
  - name: "initial_analysis"
    type: "gemini"
    prompt:
      - type: "file"
        path: "prompts/analysis/basic_review.md"
      - type: "file"
        path: "src/main.py"
  
  - name: "deep_analysis"
    type: "gemini"
    prompt:
      - type: "file"
        path: "prompts/analysis/comprehensive_review.md"
      - type: "previous_response"
        step: "initial_analysis"
        extract: "areas_of_concern"
      - type: "file"
        path: "src/"
  
  - name: "final_recommendations"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Based on all analysis:"
      - type: "previous_response"
        step: "initial_analysis"
      - type: "previous_response"
        step: "deep_analysis"
      - type: "file"
        path: "prompts/templates/recommendations.md"
```

### Context-Aware Prompts

Adapt prompts based on context:

```yaml
steps:
  - name: "detect_framework"
    type: "gemini"
    prompt:
      - type: "static"
        content: "Detect the framework used in this project"
      - type: "file"
        path: "package.json"
  
  - name: "framework_specific_analysis"
    type: "claude"
    prompt:
      # Dynamic prompt selection based on framework
      - type: "file"
        path: "prompts/frameworks/{{steps.detect_framework.result.framework}}.md"
      - type: "file"
        path: "src/"
```

### Multi-Modal Prompts

Combine different content types:

```yaml
prompt:
  # Textual context
  - type: "file"
    path: "prompts/analysis/ui_review.md"
  
  # Code files
  - type: "file"
    path: "src/components/Dashboard.jsx"
  
  # Data files
  - type: "file"
    path: "test_data/sample_output.json"
  
  # Previous analysis
  - type: "previous_response"
    step: "accessibility_check"
    extract: "issues"
  
  # Dynamic content
  - type: "static"
    content: "Consider mobile responsiveness for viewport: {{config.target_viewport}}"
```

## Best Practices

### 1. Prompt Organization

- **Single Responsibility**: Each prompt file should have one clear purpose
- **Descriptive Names**: Use clear, action-oriented file names
- **Version Control**: Track prompt changes in git
- **Documentation**: Include purpose and requirements in prompt files

### 2. Variable Usage

- **Clear Naming**: Use descriptive variable names
- **Default Values**: Provide defaults where appropriate
- **Type Safety**: Document expected variable types
- **Validation**: Validate variables before use

### 3. Content Management

- **Size Limits**: Monitor prompt sizes to avoid token limits
- **Caching**: Leverage file caching for performance
- **Compression**: Use summarization for large content
- **Chunking**: Split large prompts into manageable parts

### 4. Reusability

- **Templates**: Create reusable prompt templates
- **Components**: Build modular prompt components
- **Libraries**: Organize prompts in logical categories
- **Inheritance**: Use base prompts with extensions

### 5. Error Handling

- **Fallbacks**: Provide fallback prompts for failures
- **Validation**: Check file existence before use
- **Encoding**: Handle different file encodings properly
- **Recovery**: Design prompts that can recover from partial failures

### 6. Performance

- **Lazy Loading**: Load prompts only when needed
- **Caching**: Cache frequently used prompts
- **Preprocessing**: Prepare prompts during idle time
- **Optimization**: Minimize prompt token usage

This reference provides comprehensive documentation for the Pipeline Prompt System, enabling sophisticated prompt management and composition strategies.