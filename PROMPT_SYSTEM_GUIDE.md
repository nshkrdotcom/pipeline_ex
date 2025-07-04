# Pipeline Prompt System Guide

## Table of Contents

1. [Overview](#overview)
2. [Prompt Types Reference](#prompt-types-reference)
3. [File-Based Prompt Management](#file-based-prompt-management)
4. [Prompt Template Standards](#prompt-template-standards)
5. [Component Library Standards](#component-library-standards)
6. [Advanced Prompt Patterns](#advanced-prompt-patterns)
7. [Content Processing Features](#content-processing-features)
8. [Best Practices](#best-practices)
9. [Complete Examples](#complete-examples)
10. [Migration Guide](#migration-guide)

## Overview

The Pipeline Prompt System provides a comprehensive framework for managing, reusing, and composing prompts across AI workflows. This system enables:

- **External Prompt Files**: Store prompts in dedicated files for reusability
- **Dynamic Composition**: Combine multiple prompt sources into complex instructions
- **Template Libraries**: Standardized prompt components for common patterns
- **Content Processing**: Advanced extraction and transformation of prompt content
- **Version Control**: Track and manage prompt evolution over time

### Architecture

```
pipeline_ex/
├── pipelines/
│   ├── prompts/           # Reusable prompt templates
│   │   ├── analysis/      # Analysis-focused prompts
│   │   ├── generation/    # Content generation prompts
│   │   ├── extraction/    # Data extraction prompts
│   │   └── validation/    # Quality check prompts
│   └── components/        # Reusable step components
│       ├── validation_steps.yaml
│       ├── transformation_steps.yaml
│       └── llm_steps.yaml
└── workflows/             # Complete workflow definitions
    ├── development/       # Development workflows
    ├── analysis/          # Analysis workflows
    └── production/        # Production workflows
```

## Prompt Types Reference

### 1. Static Content (`static`)

Inline text content defined directly in the YAML:

```yaml
prompt:
  - type: "static"
    content: |
      Analyze this code for the following criteria:
      1. Security vulnerabilities
      2. Performance issues
      3. Code maintainability
      4. Best practice adherence
```

**Use Cases:**
- Short, workflow-specific instructions
- Connecting text between other prompt types
- Conditional logic instructions

### 2. File Content (`file`)

Load content from external files:

```yaml
prompt:
  - type: "file"
    path: "pipelines/prompts/analysis/security_review.md"
  - type: "file"
    path: "src/main.py"
```

**Features:**
- Automatic file change detection and caching
- Support for any text-based file format
- Relative and absolute path support
- Error handling for missing files

**Use Cases:**
- Reusable prompt templates
- Loading source code for analysis
- Loading documentation or requirements
- Standard prompt components

### 3. Previous Response (`previous_response`)

Reference outputs from earlier workflow steps:

```yaml
prompt:
  - type: "previous_response"
    step: "code_analysis"
  - type: "previous_response"
    step: "security_scan"
    extract: "vulnerabilities"
```

**Fields:**
- `step` (required): Name of the previous step
- `extract` (optional): Extract specific JSON field
- `extract_with` (optional): Use ContentExtractor for processing
- `summary` (optional): Generate summary of content
- `max_length` (optional): Limit content length

**Use Cases:**
- Building on previous analysis
- Passing structured data between steps
- Context accumulation across workflow

### 4. Session Context (`session_context`)

Reference conversation history from Claude sessions:

```yaml
prompt:
  - type: "session_context"
    session_id: "code_review_session"
    include_last_n: 5
```

**Fields:**
- `session_id` (required): Session identifier
- `include_last_n` (optional): Number of recent messages to include

**Use Cases:**
- Multi-turn conversations
- Maintaining context across session restarts
- Referencing earlier decisions in long workflows

### 5. Claude Continue (`claude_continue`)

Continue existing Claude conversations with new prompts:

```yaml
prompt:
  - type: "claude_continue"
    new_prompt: "Now add comprehensive error handling to the implementation"
```

**Use Cases:**
- Extending existing implementations
- Iterative development workflows
- Progressive enhancement patterns

## File-Based Prompt Management

### Directory Structure Standards

#### `/pipelines/prompts/` - Prompt Template Library

Organized by purpose and domain:

```
pipelines/prompts/
├── analysis/
│   ├── code_review.md
│   ├── security_audit.md
│   ├── performance_analysis.md
│   └── dependency_check.md
├── generation/
│   ├── api_documentation.md
│   ├── test_generation.md
│   ├── code_scaffolding.md
│   └── tutorial_creation.md
├── extraction/
│   ├── data_parsing.md
│   ├── entity_extraction.md
│   └── content_summarization.md
├── validation/
│   ├── quality_checks.md
│   ├── compliance_review.md
│   └── output_validation.md
└── common/
    ├── system_prompts.md
    ├── error_handling.md
    └── context_setup.md
```

#### Prompt File Naming Conventions

- **Descriptive names**: `security_vulnerability_scan.md` not `scan.md`
- **Action-oriented**: `generate_api_tests.md` not `api_tests.md`
- **Domain prefixes**: `frontend_component_analysis.md`, `backend_service_review.md`
- **Version suffixes**: `code_review_v2.md` for major updates

#### Prompt File Structure

Each prompt file should follow this template:

```markdown
# Prompt Title

## Purpose
Brief description of what this prompt accomplishes.

## Context Requirements
- List of required context or input data
- Expected format of inputs
- Prerequisites or dependencies

## Variables
Document any template variables used:
- `{PROJECT_TYPE}` - Type of project being analyzed
- `{LANGUAGE}` - Programming language
- `{FRAMEWORK}` - Framework or library being used

## Prompt Content

[Main prompt content here, using clear sections and examples]

## Expected Output Format
Description of expected response structure.

## Usage Examples
Reference to workflows that use this prompt.

## Version History
- v1.0 (2024-07-03): Initial version
- v1.1 (2024-07-04): Added error handling instructions
```

### Template Variables System

Support for dynamic prompt content:

```markdown
# Security Analysis Prompt

Analyze the {LANGUAGE} {PROJECT_TYPE} for security vulnerabilities.

Focus areas for {FRAMEWORK} projects:
- Authentication mechanisms
- Data validation
- Error handling
- Dependency security

## Code to Analyze
{CODE_CONTENT}

## Previous Findings
{PREVIOUS_ANALYSIS}
```

Usage in workflows:

```yaml
prompt:
  - type: "file"
    path: "pipelines/prompts/analysis/security_review.md"
    variables:
      LANGUAGE: "Python"
      PROJECT_TYPE: "web application"
      FRAMEWORK: "FastAPI"
  - type: "file"
    path: "src/main.py"
    inject_as: "CODE_CONTENT"
  - type: "previous_response"
    step: "initial_scan"
    inject_as: "PREVIOUS_ANALYSIS"
```

## Prompt Template Standards

### Template Categories

#### 1. Analysis Templates (`/analysis/`)

**Code Review Template** (`code_review.md`):
```markdown
# Code Review Analysis

## Objective
Perform comprehensive code review focusing on quality, security, and maintainability.

## Review Criteria
1. **Code Quality**
   - Readability and clarity
   - Proper naming conventions
   - Code organization and structure
   - Documentation completeness

2. **Security Assessment**
   - Input validation
   - Authentication and authorization
   - Data handling and storage
   - Dependency vulnerabilities

3. **Performance Considerations**
   - Algorithm efficiency
   - Resource usage
   - Scalability factors
   - Caching strategies

4. **Maintainability**
   - Code modularity
   - Test coverage
   - Error handling
   - Configuration management

## Output Format
Provide analysis in JSON format:
```json
{
  "overall_score": 85,
  "categories": {
    "quality": {"score": 90, "issues": []},
    "security": {"score": 80, "issues": []},
    "performance": {"score": 85, "issues": []},
    "maintainability": {"score": 85, "issues": []}
  },
  "critical_issues": [],
  "recommendations": [],
  "next_steps": []
}
```
```

**Security Audit Template** (`security_audit.md`):
```markdown
# Security Vulnerability Assessment

## Scope
Comprehensive security analysis covering OWASP Top 10 and industry best practices.

## Assessment Areas
1. **Authentication & Authorization**
   - User authentication mechanisms
   - Session management
   - Access control implementation
   - Multi-factor authentication

2. **Data Protection**
   - Data encryption at rest and in transit
   - Sensitive data handling
   - PII protection measures
   - Database security

3. **Input Validation**
   - SQL injection prevention
   - XSS protection
   - CSRF safeguards
   - Input sanitization

4. **Infrastructure Security**
   - Server configuration
   - Network security
   - Dependency management
   - Container security

## Risk Classification
- **Critical**: Immediate security risk, requires urgent attention
- **High**: Significant vulnerability, should be addressed soon
- **Medium**: Potential security concern, plan for resolution
- **Low**: Minor security improvement opportunity

## Output Requirements
Security assessment report with:
- Executive summary
- Detailed findings by category
- Risk-prioritized recommendations
- Remediation timeline suggestions
```

#### 2. Generation Templates (`/generation/`)

**API Documentation Template** (`api_documentation.md`):
```markdown
# API Documentation Generator

## Objective
Generate comprehensive API documentation from source code and specifications.

## Documentation Requirements
1. **API Overview**
   - Purpose and scope
   - Authentication methods
   - Base URLs and versioning
   - Rate limiting information

2. **Endpoint Documentation**
   - HTTP methods and paths
   - Request/response schemas
   - Parameter descriptions
   - Example requests and responses
   - Error codes and messages

3. **Data Models**
   - Schema definitions
   - Validation rules
   - Relationship mappings
   - Example payloads

4. **Integration Guides**
   - Getting started tutorial
   - Common use cases
   - Code examples in multiple languages
   - Troubleshooting guide

## Output Format
Generate documentation in OpenAPI 3.0 specification format with accompanying Markdown guides.
```

**Test Generation Template** (`test_generation.md`):
```markdown
# Comprehensive Test Suite Generator

## Testing Strategy
Generate tests covering unit, integration, and end-to-end scenarios.

## Test Categories
1. **Unit Tests**
   - Function-level testing
   - Edge case coverage
   - Error condition handling
   - Mock and stub usage

2. **Integration Tests**
   - API endpoint testing
   - Database integration
   - External service mocking
   - Configuration testing

3. **End-to-End Tests**
   - User journey testing
   - Cross-browser compatibility
   - Performance benchmarks
   - Security testing

## Code Coverage Requirements
- Target: 90%+ line coverage
- 100% coverage for critical paths
- Include negative test cases
- Test error handling paths

## Test Framework Selection
Choose appropriate testing frameworks based on technology stack and project requirements.
```

#### 3. Extraction Templates (`/extraction/`)

**Data Parsing Template** (`data_parsing.md`):
```markdown
# Structured Data Extraction

## Extraction Objectives
Parse and structure unstructured or semi-structured data into standardized formats.

## Supported Input Formats
- Plain text documents
- CSV and TSV files
- JSON and XML data
- Log files and reports
- Configuration files

## Extraction Patterns
1. **Entity Recognition**
   - Names, dates, and identifiers
   - Technical specifications
   - Configuration parameters
   - Error messages and codes

2. **Relationship Mapping**
   - Dependency relationships
   - Hierarchical structures
   - Sequential processes
   - Cross-references

3. **Data Validation**
   - Format compliance
   - Completeness checks
   - Consistency validation
   - Quality scoring

## Output Schema
Provide extracted data in JSON format with metadata about extraction confidence and validation results.
```

#### 4. Validation Templates (`/validation/`)

**Quality Assurance Template** (`quality_checks.md`):
```markdown
# Quality Assurance Validation

## Quality Metrics
Comprehensive evaluation of deliverable quality across multiple dimensions.

## Evaluation Criteria
1. **Functional Correctness**
   - Requirements compliance
   - Feature completeness
   - Business logic accuracy
   - User experience quality

2. **Technical Excellence**
   - Code quality standards
   - Architecture compliance
   - Performance benchmarks
   - Security requirements

3. **Documentation Quality**
   - Completeness and accuracy
   - Clarity and organization
   - Example quality
   - Maintenance procedures

4. **Process Compliance**
   - Development standards
   - Review procedures
   - Testing requirements
   - Deployment readiness

## Validation Output
Quality scorecard with pass/fail status, improvement recommendations, and certification readiness assessment.
```

## Component Library Standards

### `/pipelines/components/` - Reusable Step Components

#### Component Categories

**Validation Steps** (`validation_steps.yaml`):
```yaml
# Reusable validation step components
components:
  code_quality_check:
    type: "gemini"
    role: "brain"
    model: "gemini-2.5-flash"
    token_budget:
      max_output_tokens: 2048
      temperature: 0.3
    prompt:
      - type: "file"
        path: "pipelines/prompts/validation/quality_checks.md"
      - type: "previous_response"
        step: "${source_step}"
    functions:
      - "evaluate_quality"
    output_to_file: "quality_assessment.json"

  security_validation:
    type: "gemini"
    role: "brain"
    model: "gemini-2.5-flash"
    token_budget:
      max_output_tokens: 4096
      temperature: 0.2
    prompt:
      - type: "file"
        path: "pipelines/prompts/validation/security_audit.md"
      - type: "file"
        path: "${code_path}"
    functions:
      - "assess_security"
    output_to_file: "security_report.json"

  compliance_check:
    type: "gemini"
    role: "brain"
    prompt:
      - type: "file"
        path: "pipelines/prompts/validation/compliance_review.md"
      - type: "previous_response"
        step: "${implementation_step}"
        extract: "deliverables"
    output_to_file: "compliance_status.json"
```

**Transformation Steps** (`transformation_steps.yaml`):
```yaml
components:
  data_normalizer:
    type: "gemini"
    role: "brain"
    model: "gemini-2.5-flash"
    prompt:
      - type: "file"
        path: "pipelines/prompts/extraction/data_parsing.md"
      - type: "file"
        path: "${input_data_path}"
    functions:
      - "normalize_data"
    output_to_file: "normalized_data.json"

  content_summarizer:
    type: "gemini"
    role: "brain"
    token_budget:
      max_output_tokens: 1024
      temperature: 0.4
    prompt:
      - type: "file"
        path: "pipelines/prompts/extraction/content_summarization.md"
      - type: "previous_response"
        step: "${source_step}"
        summary: true
        max_length: 2000
    output_to_file: "content_summary.json"

  format_converter:
    type: "claude"
    role: "muscle"
    claude_options:
      max_turns: 5
      allowed_tools: ["Write", "Read"]
      output_format: "json"
    prompt:
      - type: "static"
        content: "Convert the following data to ${target_format} format:"
      - type: "previous_response"
        step: "${source_step}"
    output_to_file: "converted_${target_format}.${target_extension}"
```

**LLM Steps** (`llm_steps.yaml`):
```yaml
components:
  smart_analysis:
    type: "claude_smart"
    preset: "analysis"
    claude_options:
      max_turns: 3
      allowed_tools: ["Read"]
    prompt:
      - type: "file"
        path: "pipelines/prompts/analysis/${analysis_type}.md"
      - type: "file"
        path: "${target_file}"
    output_to_file: "${analysis_type}_result.json"

  robust_implementation:
    type: "claude_robust"
    retry_config:
      max_retries: 3
      backoff_strategy: "exponential"
      fallback_action: "simplified_prompt"
    claude_options:
      max_turns: 20
      allowed_tools: ["Write", "Edit", "Read", "Bash"]
      output_format: "json"
    prompt:
      - type: "file"
        path: "pipelines/prompts/generation/${implementation_type}.md"
      - type: "previous_response"
        step: "${planning_step}"
    output_to_file: "${implementation_type}_result.json"

  session_continuation:
    type: "claude_session"
    session_config:
      persist: true
      session_name: "${workflow_name}_session"
      max_turns: 50
    prompt:
      - type: "claude_continue"
        new_prompt: "${continuation_instruction}"
    output_to_file: "session_result.json"
```

#### Component Usage Patterns

**Including Components in Workflows**:
```yaml
workflow:
  name: "comprehensive_analysis"
  
  steps:
    - name: "initial_scan"
      type: "gemini"
      prompt:
        - type: "file"
          path: "src/main.py"

    # Use validation component
    - <<: *code_quality_check
      name: "quality_assessment"
      variables:
        source_step: "initial_scan"

    # Use transformation component  
    - <<: *content_summarizer
      name: "summary_generation"
      variables:
        source_step: "quality_assessment"

    # Use LLM component with customization
    - <<: *smart_analysis
      name: "detailed_analysis"
      variables:
        analysis_type: "security_audit"
        target_file: "src/main.py"
      claude_options:
        max_turns: 5  # Override component default
```

## Advanced Prompt Patterns

### 1. Progressive Enhancement Pattern

Build complexity gradually through connected prompts:

```yaml
steps:
  - name: "basic_analysis"
    type: "gemini"
    prompt:
      - type: "file"
        path: "pipelines/prompts/analysis/basic_code_review.md"
      - type: "file"
        path: "src/main.py"

  - name: "detailed_analysis"
    type: "gemini"
    prompt:
      - type: "file"
        path: "pipelines/prompts/analysis/detailed_security_audit.md"
      - type: "previous_response"
        step: "basic_analysis"
        extract: "concerns"
      - type: "file"
        path: "src/main.py"

  - name: "comprehensive_report"
    type: "gemini"
    prompt:
      - type: "file"
        path: "pipelines/prompts/generation/comprehensive_report.md"
      - type: "previous_response"
        step: "basic_analysis"
      - type: "previous_response"
        step: "detailed_analysis"
```

### 2. Context Accumulation Pattern

Build rich context across multiple steps:

```yaml
steps:
  - name: "requirements_analysis"
    type: "gemini"
    prompt:
      - type: "file"
        path: "pipelines/prompts/analysis/requirements_review.md"
      - type: "file"
        path: "requirements.md"

  - name: "architecture_review"
    type: "gemini"
    prompt:
      - type: "file"
        path: "pipelines/prompts/analysis/architecture_analysis.md"
      - type: "file"
        path: "architecture.md"
      - type: "previous_response"
        step: "requirements_analysis"
        extract: "constraints"

  - name: "implementation_plan"
    type: "gemini"
    prompt:
      - type: "file"
        path: "pipelines/prompts/generation/implementation_planning.md"
      - type: "static"
        content: "Requirements Analysis:"
      - type: "previous_response"
        step: "requirements_analysis"
      - type: "static"
        content: "\nArchitecture Review:"
      - type: "previous_response"
        step: "architecture_review"
```

### 3. Iterative Refinement Pattern

Refine outputs through multiple iterations:

```yaml
steps:
  - name: "initial_draft"
    type: "claude"
    claude_options:
      max_turns: 10
      allowed_tools: ["Write"]
    prompt:
      - type: "file"
        path: "pipelines/prompts/generation/initial_implementation.md"
      - type: "file"
        path: "requirements.md"

  - name: "review_draft"
    type: "gemini"
    prompt:
      - type: "file"
        path: "pipelines/prompts/validation/implementation_review.md"
      - type: "previous_response"
        step: "initial_draft"

  - name: "refine_implementation"
    type: "claude_session"
    session_config:
      persist: true
      continue_on_restart: true
    prompt:
      - type: "claude_continue"
        new_prompt: |
          Based on this review feedback, please refine the implementation:
      - type: "previous_response"
        step: "review_draft"
        extract: "improvement_suggestions"
```

### 4. Parallel Processing Pattern

Process multiple aspects simultaneously:

```yaml
steps:
  - name: "parallel_analysis"
    type: "parallel_claude"
    parallel_tasks:
      - id: "security_analysis"
        claude_options:
          max_turns: 15
          allowed_tools: ["Read"]
        prompt:
          - type: "file"
            path: "pipelines/prompts/analysis/security_focus.md"
          - type: "file"
            path: "src/main.py"
        output_to_file: "security_analysis.json"

      - id: "performance_analysis"
        claude_options:
          max_turns: 15
          allowed_tools: ["Read"]
        prompt:
          - type: "file"
            path: "pipelines/prompts/analysis/performance_focus.md"
          - type: "file"
            path: "src/main.py"
        output_to_file: "performance_analysis.json"

      - id: "maintainability_analysis"
        claude_options:
          max_turns: 15
          allowed_tools: ["Read"]
        prompt:
          - type: "file"
            path: "pipelines/prompts/analysis/maintainability_focus.md"
          - type: "file"
            path: "src/main.py"
        output_to_file: "maintainability_analysis.json"

  - name: "synthesize_results"
    type: "gemini"
    prompt:
      - type: "file"
        path: "pipelines/prompts/synthesis/comprehensive_synthesis.md"
      - type: "previous_response"
        step: "parallel_analysis"
```

## Content Processing Features

### Enhanced Extraction Options

```yaml
prompt:
  - type: "previous_response"
    step: "code_analysis"
    extract_with: "content_extractor"  # Use ContentExtractor
    format: "structured"               # structured, summary, markdown
    post_processing:
      - "extract_code_blocks"
      - "extract_recommendations"
      - "extract_links"
    include_metadata: true
    max_length: 5000
```

### Content Summarization

```yaml
prompt:
  - type: "file"
    path: "large_specification.md"
    summary: true
    max_summary_length: 1000
  - type: "previous_response"
    step: "detailed_analysis"
    summary: true
    extract: "findings"
```

### Variable Injection

```yaml
prompt:
  - type: "file"
    path: "pipelines/prompts/analysis/project_analysis.md"
    variables:
      PROJECT_NAME: "MyApp"
      LANGUAGE: "Python"
      FRAMEWORK: "FastAPI"
  - type: "file"
    path: "${PROJECT_PATH}/src/main.py"
    inject_as: "SOURCE_CODE"
```

## Best Practices

### 1. Prompt Organization

- **Single Responsibility**: Each prompt file should focus on one specific task
- **Clear Naming**: Use descriptive, action-oriented names
- **Version Control**: Track prompt evolution with version comments
- **Documentation**: Include purpose, context, and expected outputs

### 2. Template Design

- **Parameterization**: Use variables for reusable templates
- **Flexibility**: Design templates that work across different contexts
- **Clarity**: Write clear, unambiguous instructions
- **Examples**: Include examples of expected inputs and outputs

### 3. Component Architecture

- **Modularity**: Design components that can be easily combined
- **Configuration**: Support customization through variables
- **Reusability**: Create components that work across workflows
- **Testing**: Include test cases for component validation

### 4. Content Management

- **Caching**: Leverage file caching for performance
- **Size Limits**: Monitor and control prompt sizes
- **Processing**: Use content extraction for large inputs
- **Validation**: Verify prompt content before execution

### 5. Error Handling

- **Fallbacks**: Provide fallback prompts for error conditions
- **Validation**: Validate file paths and references
- **Recovery**: Design recovery strategies for failed prompts
- **Monitoring**: Track prompt performance and success rates

## Complete Examples

### Example 1: Full-Stack Application Analysis

```yaml
workflow:
  name: "fullstack_app_analysis"
  
  steps:
    # Requirements gathering
    - name: "requirements_analysis"
      type: "gemini"
      prompt:
        - type: "file"
          path: "pipelines/prompts/analysis/requirements_analysis.md"
        - type: "file"
          path: "docs/requirements.md"
        - type: "file"
          path: "docs/user_stories.md"
      output_to_file: "requirements_analysis.json"

    # Architecture review
    - name: "architecture_review"
      type: "gemini"
      prompt:
        - type: "file"
          path: "pipelines/prompts/analysis/architecture_review.md"
        - type: "file"
          path: "docs/architecture.md"
        - type: "previous_response"
          step: "requirements_analysis"
          extract: "technical_requirements"
      output_to_file: "architecture_review.json"

    # Parallel code analysis
    - name: "code_analysis"
      type: "parallel_claude"
      parallel_tasks:
        - id: "frontend_analysis"
          claude_options:
            max_turns: 15
            allowed_tools: ["Read"]
          prompt:
            - type: "file"
              path: "pipelines/prompts/analysis/frontend_analysis.md"
            - type: "file"
              path: "frontend/src"
          output_to_file: "frontend_analysis.json"

        - id: "backend_analysis"
          claude_options:
            max_turns: 15
            allowed_tools: ["Read"]
          prompt:
            - type: "file"
              path: "pipelines/prompts/analysis/backend_analysis.md"
            - type: "file"
              path: "backend/src"
          output_to_file: "backend_analysis.json"

        - id: "database_analysis"
          claude_options:
            max_turns: 10
            allowed_tools: ["Read"]
          prompt:
            - type: "file"
              path: "pipelines/prompts/analysis/database_analysis.md"
            - type: "file"
              path: "database/schema.sql"
          output_to_file: "database_analysis.json"

    # Security assessment
    - name: "security_assessment"
      type: "claude_smart"
      preset: "analysis"
      prompt:
        - type: "file"
          path: "pipelines/prompts/validation/comprehensive_security_audit.md"
        - type: "previous_response"
          step: "code_analysis"
        - type: "previous_response"
          step: "architecture_review"
          extract: "security_considerations"
      output_to_file: "security_assessment.json"

    # Comprehensive report
    - name: "final_report"
      type: "gemini"
      token_budget:
        max_output_tokens: 8192
        temperature: 0.4
      prompt:
        - type: "file"
          path: "pipelines/prompts/generation/comprehensive_analysis_report.md"
        - type: "static"
          content: "## Requirements Analysis"
        - type: "previous_response"
          step: "requirements_analysis"
        - type: "static"
          content: "\n## Architecture Review"
        - type: "previous_response"
          step: "architecture_review"
        - type: "static"
          content: "\n## Code Analysis Results"
        - type: "previous_response"
          step: "code_analysis"
        - type: "static"
          content: "\n## Security Assessment"
        - type: "previous_response"
          step: "security_assessment"
      output_to_file: "comprehensive_analysis_report.md"
```

### Example 2: Iterative Code Improvement

```yaml
workflow:
  name: "iterative_code_improvement"
  
  steps:
    # Initial assessment
    - name: "initial_assessment"
      type: "gemini"
      prompt:
        - type: "file"
          path: "pipelines/prompts/analysis/code_quality_assessment.md"
        - type: "file"
          path: "src/legacy_code.py"
      functions:
        - "assess_code_quality"
      output_to_file: "initial_assessment.json"

    # First improvement iteration
    - name: "first_improvement"
      type: "claude_robust"
      retry_config:
        max_retries: 3
        backoff_strategy: "exponential"
      claude_options:
        max_turns: 20
        allowed_tools: ["Read", "Write", "Edit"]
      prompt:
        - type: "file"
          path: "pipelines/prompts/generation/code_improvement.md"
        - type: "previous_response"
          step: "initial_assessment"
          extract: "improvement_priorities"
        - type: "file"
          path: "src/legacy_code.py"
      output_to_file: "first_improvement.json"

    # Review first iteration
    - name: "review_first_iteration"
      type: "gemini"
      prompt:
        - type: "file"
          path: "pipelines/prompts/validation/improvement_review.md"
        - type: "previous_response"
          step: "first_improvement"
        - type: "previous_response"
          step: "initial_assessment"
          extract: "quality_targets"
      output_to_file: "first_review.json"

    # Second improvement iteration
    - name: "second_improvement"
      type: "claude_session"
      session_config:
        persist: true
        session_name: "code_improvement_session"
      prompt:
        - type: "claude_continue"
          new_prompt: |
            Based on the review feedback, please make the following additional improvements:
        - type: "previous_response"
          step: "review_first_iteration"
          extract: "additional_improvements"
      output_to_file: "second_improvement.json"

    # Final validation
    - name: "final_validation"
      type: "gemini"
      prompt:
        - type: "file"
          path: "pipelines/prompts/validation/final_quality_check.md"
        - type: "previous_response"
          step: "second_improvement"
        - type: "previous_response"
          step: "initial_assessment"
          extract: "quality_targets"
      functions:
        - "validate_improvements"
      output_to_file: "final_validation.json"
```

## Migration Guide

### Migrating from Inline Prompts

**Before (Inline):**
```yaml
steps:
  - name: "analyze_code"
    type: "gemini"
    prompt:
      - type: "static"
        content: |
          Analyze this code for security issues:
          1. Check for SQL injection vulnerabilities
          2. Look for XSS vulnerabilities
          3. Review authentication mechanisms
          4. Check for insecure data handling
          
          Provide analysis in JSON format with severity levels.
```

**After (File-based):**
```yaml
steps:
  - name: "analyze_code"
    type: "gemini"
    prompt:
      - type: "file"
        path: "pipelines/prompts/analysis/security_analysis.md"
```

### Creating Prompt Libraries

1. **Extract Common Patterns**: Identify frequently used prompt patterns
2. **Create Template Files**: Move prompts to organized template files
3. **Add Variables**: Parameterize templates for reusability
4. **Update Workflows**: Convert workflows to use file references
5. **Test Migration**: Verify equivalent functionality

### Component Migration

1. **Identify Reusable Steps**: Find step patterns used across workflows
2. **Create Component Definitions**: Extract steps into component files
3. **Parameterize Components**: Add variables for customization
4. **Update Workflows**: Use component references instead of inline definitions
5. **Validate Components**: Test components across different contexts

This guide provides a comprehensive framework for leveraging the Pipeline Prompt System's advanced capabilities. Use these patterns and standards to build maintainable, reusable, and powerful AI workflows.