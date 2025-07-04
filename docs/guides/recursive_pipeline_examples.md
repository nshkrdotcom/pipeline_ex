# Recursive Pipeline Examples Collection

## Table of Contents

1. [Overview](#overview)
2. [Data Processing Examples](#data-processing-examples)
3. [Code Generation Examples](#code-generation-examples)
4. [Analysis and Reporting Examples](#analysis-and-reporting-examples)
5. [DevOps and Automation Examples](#devops-and-automation-examples)
6. [Content Generation Examples](#content-generation-examples)
7. [Complex Workflow Examples](#complex-workflow-examples)
8. [Testing Strategy for Examples](#testing-strategy-for-examples)
9. [Running the Examples](#running-the-examples)
10. [Contributing Examples](#contributing-examples)

## Overview

This collection demonstrates real-world use cases for recursive pipelines, showcasing patterns and best practices for building complex, modular AI workflows. Each example includes complete pipeline definitions, expected inputs/outputs, and implementation notes.

### Example Structure

```
examples/
├── data_processing/
│   ├── etl_pipeline/
│   │   ├── main.yaml
│   │   ├── extract.yaml
│   │   ├── transform.yaml
│   │   ├── load.yaml
│   │   └── README.md
│   └── ...
├── code_generation/
├── analysis/
├── devops/
├── content/
└── complex_workflows/
```

## Data Processing Examples

### 1. Multi-Stage ETL Pipeline

**Purpose**: Extract, transform, and load data with validation at each stage.

```yaml
# examples/data_processing/etl_pipeline/main.yaml
workflow:
  name: "etl_pipeline"
  description: "Multi-stage ETL with nested validation"
  
  global_vars:
    source_config:
      type: "postgres"
      connection_string: "{{env.DB_CONNECTION}}"
    target_config:
      type: "data_warehouse"
      schema: "analytics"
    validation_rules:
      min_records: 1000
      required_fields: ["id", "timestamp", "value"]
  
  steps:
    - name: "extract_data"
      type: "pipeline"
      pipeline_file: "./extract.yaml"
      inputs:
        source: "{{global_vars.source_config}}"
        query: "SELECT * FROM transactions WHERE date >= '{{inputs.start_date}}'"
      outputs:
        - path: "raw_data"
          as: "extracted_data"
        - path: "metadata.record_count"
          as: "extract_count"
    
    - name: "validate_extracted"
      type: "claude"
      prompt: |
        Validate extracted data:
        - Record count: {{steps.extract_data.extract_count}}
        - Sample: {{json(slice(steps.extract_data.extracted_data, 0, 5))}}
        - Rules: {{json(global_vars.validation_rules)}}
        
        Return JSON: {"valid": boolean, "issues": []}
    
    - name: "transform_data"
      type: "pipeline"
      pipeline_file: "./transform.yaml"
      condition: "{{steps.validate_extracted.result.valid == true}}"
      inputs:
        raw_data: "{{steps.extract_data.extracted_data}}"
        transformation_rules:
          - type: "normalize_timestamps"
            timezone: "UTC"
          - type: "calculate_metrics"
            aggregations: ["sum", "avg", "max"]
          - type: "enrich_data"
            lookup_source: "{{global_vars.enrichment_api}}"
      outputs:
        - "transformed_data"
        - path: "metrics.quality_score"
          as: "quality_score"
    
    - name: "load_data"
      type: "pipeline"
      pipeline_file: "./load.yaml"
      inputs:
        data: "{{steps.transform_data.transformed_data}}"
        target: "{{global_vars.target_config}}"
        quality_score: "{{steps.transform_data.quality_score}}"
      config:
        continue_on_error: false
        timeout_seconds: 300
```

```yaml
# examples/data_processing/etl_pipeline/extract.yaml
workflow:
  name: "data_extractor"
  
  steps:
    - name: "connect_source"
      type: "claude"
      prompt: |
        Generate connection code for:
        Source: {{json(inputs.source)}}
        Query: {{inputs.query}}
        
        Return connection parameters and query plan.
    
    - name: "execute_extraction"
      type: "claude"
      prompt: |
        Execute extraction with:
        {{steps.connect_source.result}}
        
        Return extracted data in JSON format.
    
    - name: "raw_data"
      type: "claude"
      prompt: |
        Process and structure the raw data:
        {{steps.execute_extraction.result}}
        
        Ensure consistent format and data types.
```

### 2. Streaming Data Processor

**Purpose**: Process large datasets in chunks with parallel processing.

```yaml
# examples/data_processing/streaming_processor/main.yaml
workflow:
  name: "streaming_data_processor"
  description: "Process large files in parallel chunks"
  
  steps:
    - name: "analyze_file"
      type: "claude"
      prompt: |
        Analyze file structure:
        - Path: {{inputs.file_path}}
        - Size: {{inputs.file_size_mb}}MB
        
        Determine optimal chunk size and strategy.
        Return: {"chunk_size_mb": number, "parallel_chunks": number}
    
    - name: "create_chunks"
      type: "claude"
      prompt: |
        Split file into chunks:
        - Strategy: {{steps.analyze_file.result}}
        - File: {{inputs.file_path}}
        
        Return: {"chunks": [{"id": 1, "offset": 0, "size": 100}, ...]}
    
    - name: "process_chunks"
      type: "parallel_claude"
      parallel_tasks: "{{steps.create_chunks.result.chunks}}"
      task_template:
        id: "chunk_{{item.id}}"
        type: "pipeline"
        pipeline_file: "./process_chunk.yaml"
        inputs:
          chunk_info: "{{item}}"
          file_path: "{{inputs.file_path}}"
          processing_rules: "{{inputs.rules}}"
        config:
          memory_limit_mb: 256
          timeout_seconds: 120
    
    - name: "merge_results"
      type: "pipeline"
      pipeline_file: "./merge_chunks.yaml"
      inputs:
        chunk_results: "{{steps.process_chunks.results}}"
        original_order: "{{steps.create_chunks.result.chunks}}"
```

### 3. Data Quality Pipeline

**Purpose**: Comprehensive data quality checks with remediation.

```yaml
# examples/data_processing/data_quality/main.yaml
workflow:
  name: "data_quality_pipeline"
  
  steps:
    - name: "profile_data"
      type: "pipeline"
      pipeline_file: "./profilers/statistical_profiler.yaml"
      inputs:
        dataset: "{{inputs.data}}"
        
    - name: "check_completeness"
      type: "pipeline"
      pipeline_file: "./checks/completeness_check.yaml"
      inputs:
        data: "{{inputs.data}}"
        profile: "{{steps.profile_data.result}}"
        
    - name: "check_consistency"
      type: "pipeline"
      pipeline_file: "./checks/consistency_check.yaml"
      inputs:
        data: "{{inputs.data}}"
        rules: "{{inputs.consistency_rules}}"
        
    - name: "check_accuracy"
      type: "pipeline"
      pipeline_file: "./checks/accuracy_check.yaml"
      inputs:
        data: "{{inputs.data}}"
        reference_data: "{{inputs.reference}}"
        
    - name: "generate_quality_report"
      type: "pipeline"
      pipeline_file: "./reporting/quality_report.yaml"
      inputs:
        profile: "{{steps.profile_data.result}}"
        completeness: "{{steps.check_completeness.result}}"
        consistency: "{{steps.check_consistency.result}}"
        accuracy: "{{steps.check_accuracy.result}}"
        
    - name: "remediate_issues"
      type: "pipeline"
      pipeline_file: "./remediation/auto_fix.yaml"
      condition: "{{steps.generate_quality_report.result.auto_fixable_count > 0}}"
      inputs:
        issues: "{{steps.generate_quality_report.result.issues}}"
        data: "{{inputs.data}}"
        fix_strategy: "{{inputs.remediation_strategy}}"
```

## Code Generation Examples

### 4. Full-Stack Application Generator

**Purpose**: Generate complete application from specifications.

```yaml
# examples/code_generation/fullstack_generator/main.yaml
workflow:
  name: "fullstack_app_generator"
  description: "Generate complete web application from specs"
  
  steps:
    - name: "analyze_requirements"
      type: "pipeline"
      pipeline_file: "./analyzers/requirement_analyzer.yaml"
      inputs:
        specifications: "{{inputs.app_specs}}"
        constraints: "{{inputs.technical_constraints}}"
      outputs:
        - "architecture_design"
        - "feature_breakdown"
        - "tech_stack"
    
    - name: "generate_backend"
      type: "pipeline"
      pipeline_file: "./generators/backend_generator.yaml"
      inputs:
        architecture: "{{steps.analyze_requirements.architecture_design}}"
        features: "{{steps.analyze_requirements.feature_breakdown}}"
        tech_stack: "{{steps.analyze_requirements.tech_stack.backend}}"
      outputs:
        - "api_code"
        - "database_schema"
        - "api_documentation"
    
    - name: "generate_frontend"
      type: "pipeline"
      pipeline_file: "./generators/frontend_generator.yaml"
      inputs:
        features: "{{steps.analyze_requirements.feature_breakdown}}"
        api_spec: "{{steps.generate_backend.api_documentation}}"
        tech_stack: "{{steps.analyze_requirements.tech_stack.frontend}}"
      outputs:
        - "ui_components"
        - "state_management"
        - "routing_config"
    
    - name: "generate_tests"
      type: "parallel_claude"
      parallel_tasks:
        - id: "backend_tests"
          type: "pipeline"
          pipeline_file: "./generators/test_generator.yaml"
          inputs:
            code: "{{steps.generate_backend.api_code}}"
            type: "backend"
            
        - id: "frontend_tests"
          type: "pipeline"
          pipeline_file: "./generators/test_generator.yaml"
          inputs:
            code: "{{steps.generate_frontend.ui_components}}"
            type: "frontend"
            
        - id: "integration_tests"
          type: "pipeline"
          pipeline_file: "./generators/integration_test_generator.yaml"
          inputs:
            api_spec: "{{steps.generate_backend.api_documentation}}"
            ui_flows: "{{steps.generate_frontend.routing_config}}"
    
    - name: "generate_deployment"
      type: "pipeline"
      pipeline_file: "./generators/deployment_generator.yaml"
      inputs:
        backend: "{{steps.generate_backend.result}}"
        frontend: "{{steps.generate_frontend.result}}"
        infrastructure_requirements: "{{inputs.deployment_target}}"
```

### 5. API Client Generator

**Purpose**: Generate API clients in multiple languages from OpenAPI spec.

```yaml
# examples/code_generation/api_client_generator/main.yaml
workflow:
  name: "api_client_generator"
  
  steps:
    - name: "parse_openapi"
      type: "claude"
      prompt: |
        Parse OpenAPI specification:
        {{inputs.openapi_spec}}
        
        Extract endpoints, models, and authentication methods.
    
    - name: "generate_clients"
      type: "for_loop"
      over: "{{inputs.target_languages}}"
      as: "language"
      steps:
        - name: "generate_{{language}}_client"
          type: "pipeline"
          pipeline_file: "./generators/{{language}}_generator.yaml"
          inputs:
            api_spec: "{{steps.parse_openapi.result}}"
            language_config: "{{inputs.language_configs[language]}}"
            
    - name: "generate_documentation"
      type: "pipeline"
      pipeline_file: "./documentation/client_docs.yaml"
      inputs:
        api_spec: "{{steps.parse_openapi.result}}"
        generated_clients: "{{steps.generate_clients.results}}"
        
    - name: "create_examples"
      type: "pipeline"
      pipeline_file: "./examples/usage_examples.yaml"
      inputs:
        clients: "{{steps.generate_clients.results}}"
        common_use_cases: "{{inputs.example_scenarios}}"
```

## Analysis and Reporting Examples

### 6. Codebase Analysis Pipeline

**Purpose**: Comprehensive analysis of large codebases.

```yaml
# examples/analysis/codebase_analyzer/main.yaml
workflow:
  name: "codebase_analyzer"
  description: "Deep analysis of code quality, security, and architecture"
  
  steps:
    - name: "scan_codebase"
      type: "claude"
      prompt: |
        Scan codebase structure:
        - Root: {{inputs.repo_path}}
        - Include: {{inputs.include_patterns}}
        - Exclude: {{inputs.exclude_patterns}}
        
        Return file tree and statistics.
    
    - name: "parallel_analysis"
      type: "parallel_claude"
      parallel_tasks:
        - id: "security_analysis"
          type: "pipeline"
          pipeline_file: "./analyzers/security_scanner.yaml"
          inputs:
            file_list: "{{steps.scan_codebase.result.files}}"
            security_rules: "{{inputs.security_config}}"
            
        - id: "quality_analysis"
          type: "pipeline"
          pipeline_file: "./analyzers/quality_analyzer.yaml"
          inputs:
            file_list: "{{steps.scan_codebase.result.files}}"
            quality_metrics: "{{inputs.quality_config}}"
            
        - id: "dependency_analysis"
          type: "pipeline"
          pipeline_file: "./analyzers/dependency_scanner.yaml"
          inputs:
            root_path: "{{inputs.repo_path}}"
            check_vulnerabilities: true
            
        - id: "architecture_analysis"
          type: "pipeline"
          pipeline_file: "./analyzers/architecture_analyzer.yaml"
          inputs:
            file_tree: "{{steps.scan_codebase.result.tree}}"
            architecture_rules: "{{inputs.architecture_patterns}}"
    
    - name: "deep_dive_issues"
      type: "for_loop"
      over: "{{steps.parallel_analysis.security_analysis.critical_issues}}"
      as: "issue"
      max_iterations: 10
      steps:
        - name: "analyze_issue"
          type: "pipeline"
          pipeline_file: "./analyzers/issue_deep_dive.yaml"
          inputs:
            issue: "{{issue}}"
            context_files: "{{issue.affected_files}}"
            
    - name: "generate_report"
      type: "pipeline"
      pipeline_file: "./reporting/comprehensive_report.yaml"
      inputs:
        scan_results: "{{steps.scan_codebase.result}}"
        security: "{{steps.parallel_analysis.security_analysis}}"
        quality: "{{steps.parallel_analysis.quality_analysis}}"
        dependencies: "{{steps.parallel_analysis.dependency_analysis}}"
        architecture: "{{steps.parallel_analysis.architecture_analysis}}"
        deep_dives: "{{steps.deep_dive_issues.results}}"
```

### 7. Performance Analysis Pipeline

**Purpose**: Analyze application performance with recommendations.

```yaml
# examples/analysis/performance_analyzer/main.yaml
workflow:
  name: "performance_analyzer"
  
  steps:
    - name: "collect_metrics"
      type: "pipeline"
      pipeline_file: "./collectors/metric_collector.yaml"
      inputs:
        sources: "{{inputs.metric_sources}}"
        time_range: "{{inputs.analysis_period}}"
        
    - name: "analyze_patterns"
      type: "pipeline"
      pipeline_file: "./analyzers/pattern_analyzer.yaml"
      inputs:
        metrics: "{{steps.collect_metrics.result}}"
        baseline: "{{inputs.performance_baseline}}"
        
    - name: "identify_bottlenecks"
      type: "pipeline"
      pipeline_file: "./analyzers/bottleneck_finder.yaml"
      inputs:
        metrics: "{{steps.collect_metrics.result}}"
        patterns: "{{steps.analyze_patterns.result}}"
        system_architecture: "{{inputs.architecture_diagram}}"
        
    - name: "generate_recommendations"
      type: "pipeline"
      pipeline_file: "./recommendation/optimizer.yaml"
      inputs:
        bottlenecks: "{{steps.identify_bottlenecks.result}}"
        constraints: "{{inputs.optimization_constraints}}"
        current_config: "{{inputs.current_configuration}}"
        
    - name: "create_optimization_plan"
      type: "claude"
      prompt: |
        Create detailed optimization plan:
        
        Bottlenecks: {{json(steps.identify_bottlenecks.result)}}
        Recommendations: {{json(steps.generate_recommendations.result)}}
        Constraints: {{json(inputs.optimization_constraints)}}
        
        Generate prioritized action plan with expected improvements.
```

## DevOps and Automation Examples

### 8. CI/CD Pipeline Generator

**Purpose**: Generate complete CI/CD configuration from project analysis.

```yaml
# examples/devops/cicd_generator/main.yaml
workflow:
  name: "cicd_pipeline_generator"
  
  steps:
    - name: "analyze_project"
      type: "pipeline"
      pipeline_file: "./analyzers/project_analyzer.yaml"
      inputs:
        repo_path: "{{inputs.repository}}"
        
    - name: "detect_stack"
      type: "claude"
      prompt: |
        Detect technology stack from:
        {{json(steps.analyze_project.result)}}
        
        Identify languages, frameworks, and tools.
        
    - name: "generate_ci"
      type: "pipeline"
      pipeline_file: "./generators/ci_generator.yaml"
      inputs:
        stack: "{{steps.detect_stack.result}}"
        test_requirements: "{{inputs.testing_strategy}}"
        quality_gates: "{{inputs.quality_requirements}}"
        
    - name: "generate_cd"
      type: "pipeline"
      pipeline_file: "./generators/cd_generator.yaml"
      inputs:
        stack: "{{steps.detect_stack.result}}"
        environments: "{{inputs.deployment_environments}}"
        deployment_strategy: "{{inputs.deployment_strategy}}"
        
    - name: "generate_monitoring"
      type: "pipeline"
      pipeline_file: "./generators/monitoring_generator.yaml"
      inputs:
        application_type: "{{steps.detect_stack.result.app_type}}"
        sla_requirements: "{{inputs.sla_config}}"
        
    - name: "create_pipeline_files"
      type: "claude"
      prompt: |
        Generate pipeline configuration files:
        
        CI Config: {{json(steps.generate_ci.result)}}
        CD Config: {{json(steps.generate_cd.result)}}
        Monitoring: {{json(steps.generate_monitoring.result)}}
        Platform: {{inputs.ci_platform}}
        
        Create platform-specific configuration files.
```

### 9. Infrastructure as Code Generator

**Purpose**: Generate IaC from high-level requirements.

```yaml
# examples/devops/iac_generator/main.yaml
workflow:
  name: "infrastructure_generator"
  
  steps:
    - name: "design_architecture"
      type: "pipeline"
      pipeline_file: "./designers/architecture_designer.yaml"
      inputs:
        requirements: "{{inputs.infra_requirements}}"
        constraints: "{{inputs.constraints}}"
        cloud_provider: "{{inputs.provider}}"
        
    - name: "generate_network"
      type: "pipeline"
      pipeline_file: "./generators/network_generator.yaml"
      inputs:
        architecture: "{{steps.design_architecture.result}}"
        security_requirements: "{{inputs.security_config}}"
        
    - name: "generate_compute"
      type: "pipeline"
      pipeline_file: "./generators/compute_generator.yaml"
      inputs:
        architecture: "{{steps.design_architecture.result}}"
        scaling_requirements: "{{inputs.scaling_config}}"
        
    - name: "generate_storage"
      type: "pipeline"
      pipeline_file: "./generators/storage_generator.yaml"
      inputs:
        data_requirements: "{{inputs.data_config}}"
        backup_strategy: "{{inputs.backup_config}}"
        
    - name: "generate_security"
      type: "pipeline"
      pipeline_file: "./generators/security_generator.yaml"
      inputs:
        architecture: "{{steps.design_architecture.result}}"
        compliance: "{{inputs.compliance_requirements}}"
        
    - name: "create_terraform"
      type: "pipeline"
      pipeline_file: "./generators/terraform_generator.yaml"
      inputs:
        network: "{{steps.generate_network.result}}"
        compute: "{{steps.generate_compute.result}}"
        storage: "{{steps.generate_storage.result}}"
        security: "{{steps.generate_security.result}}"
```

## Content Generation Examples

### 10. Technical Documentation Generator

**Purpose**: Generate comprehensive documentation from code.

```yaml
# examples/content/doc_generator/main.yaml
workflow:
  name: "documentation_generator"
  
  steps:
    - name: "analyze_codebase"
      type: "pipeline"
      pipeline_file: "./analyzers/code_analyzer.yaml"
      inputs:
        repo_path: "{{inputs.repository}}"
        doc_comments: true
        
    - name: "generate_api_docs"
      type: "pipeline"
      pipeline_file: "./generators/api_doc_generator.yaml"
      inputs:
        code_analysis: "{{steps.analyze_codebase.result}}"
        style_guide: "{{inputs.doc_style}}"
        
    - name: "generate_guides"
      type: "for_loop"
      over: ["getting_started", "configuration", "deployment", "troubleshooting"]
      as: "guide_type"
      steps:
        - name: "create_{{guide_type}}_guide"
          type: "pipeline"
          pipeline_file: "./generators/guide_generator.yaml"
          inputs:
            type: "{{guide_type}}"
            codebase_info: "{{steps.analyze_codebase.result}}"
            examples: "{{inputs.example_code}}"
            
    - name: "generate_examples"
      type: "pipeline"
      pipeline_file: "./generators/example_generator.yaml"
      inputs:
        api_surface: "{{steps.generate_api_docs.result.endpoints}}"
        use_cases: "{{inputs.common_use_cases}}"
        
    - name: "create_site"
      type: "pipeline"
      pipeline_file: "./generators/docsite_generator.yaml"
      inputs:
        api_docs: "{{steps.generate_api_docs.result}}"
        guides: "{{steps.generate_guides.results}}"
        examples: "{{steps.generate_examples.result}}"
        theme: "{{inputs.doc_theme}}"
```

### 11. Blog Post Generator

**Purpose**: Generate technical blog posts from topics.

```yaml
# examples/content/blog_generator/main.yaml
workflow:
  name: "blog_post_generator"
  
  steps:
    - name: "research_topic"
      type: "pipeline"
      pipeline_file: "./research/topic_researcher.yaml"
      inputs:
        topic: "{{inputs.blog_topic}}"
        depth: "{{inputs.research_depth}}"
        sources: "{{inputs.allowed_sources}}"
        
    - name: "create_outline"
      type: "claude"
      prompt: |
        Create detailed blog post outline:
        
        Topic: {{inputs.blog_topic}}
        Research: {{json(steps.research_topic.result)}}
        Target audience: {{inputs.target_audience}}
        Style: {{inputs.writing_style}}
        Length: {{inputs.target_length}} words
        
    - name: "write_sections"
      type: "for_loop"
      over: "{{steps.create_outline.result.sections}}"
      as: "section"
      steps:
        - name: "write_{{section.id}}"
          type: "pipeline"
          pipeline_file: "./writers/section_writer.yaml"
          inputs:
            section: "{{section}}"
            research: "{{steps.research_topic.result}}"
            style: "{{inputs.writing_style}}"
            
    - name: "add_examples"
      type: "pipeline"
      pipeline_file: "./enhancers/example_generator.yaml"
      inputs:
        content: "{{steps.write_sections.results}}"
        topic: "{{inputs.blog_topic}}"
        code_style: "{{inputs.code_preferences}}"
        
    - name: "optimize_seo"
      type: "pipeline"
      pipeline_file: "./optimizers/seo_optimizer.yaml"
      inputs:
        content: "{{steps.add_examples.result}}"
        keywords: "{{inputs.target_keywords}}"
        
    - name: "final_review"
      type: "claude"
      prompt: |
        Review and polish the blog post:
        
        {{steps.optimize_seo.result}}
        
        Ensure consistency, flow, and engagement.
```

## Complex Workflow Examples

### 12. Multi-Stage ML Pipeline

**Purpose**: Complete machine learning workflow from data to deployment.

```yaml
# examples/complex_workflows/ml_pipeline/main.yaml
workflow:
  name: "ml_pipeline"
  description: "End-to-end ML pipeline with nested stages"
  
  steps:
    - name: "data_preparation"
      type: "pipeline"
      pipeline_file: "./stages/data_prep.yaml"
      inputs:
        data_sources: "{{inputs.data_sources}}"
        preprocessing_config: "{{inputs.preprocessing}}"
      outputs:
        - "train_data"
        - "test_data"
        - "feature_stats"
        
    - name: "feature_engineering"
      type: "pipeline"
      pipeline_file: "./stages/feature_engineering.yaml"
      inputs:
        train_data: "{{steps.data_preparation.train_data}}"
        feature_config: "{{inputs.feature_engineering_config}}"
        
    - name: "model_training"
      type: "parallel_claude"
      parallel_tasks:
        - id: "baseline_model"
          type: "pipeline"
          pipeline_file: "./models/baseline.yaml"
          inputs:
            data: "{{steps.feature_engineering.result}}"
            
        - id: "advanced_model"
          type: "pipeline"
          pipeline_file: "./models/advanced.yaml"
          inputs:
            data: "{{steps.feature_engineering.result}}"
            hyperparameters: "{{inputs.hyperparameter_config}}"
            
        - id: "ensemble_model"
          type: "pipeline"
          pipeline_file: "./models/ensemble.yaml"
          inputs:
            data: "{{steps.feature_engineering.result}}"
            
    - name: "model_evaluation"
      type: "pipeline"
      pipeline_file: "./stages/evaluation.yaml"
      inputs:
        models: "{{steps.model_training.results}}"
        test_data: "{{steps.data_preparation.test_data}}"
        evaluation_metrics: "{{inputs.evaluation_config}}"
        
    - name: "select_best_model"
      type: "claude"
      prompt: |
        Select best model based on evaluation:
        {{json(steps.model_evaluation.result)}}
        
        Consider performance, complexity, and requirements.
        
    - name: "deploy_model"
      type: "pipeline"
      pipeline_file: "./stages/deployment.yaml"
      inputs:
        model: "{{steps.select_best_model.result.selected_model}}"
        deployment_target: "{{inputs.deployment_config}}"
        monitoring_config: "{{inputs.monitoring_config}}"
```

### 13. Microservices Generator

**Purpose**: Generate complete microservices architecture.

```yaml
# examples/complex_workflows/microservices_generator/main.yaml
workflow:
  name: "microservices_generator"
  
  steps:
    - name: "analyze_domain"
      type: "pipeline"
      pipeline_file: "./analysis/domain_analyzer.yaml"
      inputs:
        requirements: "{{inputs.business_requirements}}"
        domain_model: "{{inputs.domain_model}}"
        
    - name: "design_services"
      type: "pipeline"
      pipeline_file: "./design/service_designer.yaml"
      inputs:
        domain_analysis: "{{steps.analyze_domain.result}}"
        patterns: "{{inputs.architecture_patterns}}"
        constraints: "{{inputs.technical_constraints}}"
        
    - name: "generate_services"
      type: "for_loop"
      over: "{{steps.design_services.result.services}}"
      as: "service"
      steps:
        - name: "generate_{{service.name}}"
          type: "pipeline"
          pipeline_file: "./generators/service_generator.yaml"
          inputs:
            service_spec: "{{service}}"
            shared_contracts: "{{steps.design_services.result.contracts}}"
            tech_stack: "{{inputs.technology_choices[service.type]}}"
            
    - name: "generate_api_gateway"
      type: "pipeline"
      pipeline_file: "./generators/gateway_generator.yaml"
      inputs:
        services: "{{steps.design_services.result.services}}"
        routing_rules: "{{steps.design_services.result.routing}}"
        security_config: "{{inputs.security_requirements}}"
        
    - name: "generate_orchestration"
      type: "pipeline"
      pipeline_file: "./generators/orchestration_generator.yaml"
      inputs:
        services: "{{steps.generate_services.results}}"
        deployment_platform: "{{inputs.orchestration_platform}}"
        scaling_policies: "{{inputs.scaling_requirements}}"
        
    - name: "generate_monitoring"
      type: "pipeline"
      pipeline_file: "./generators/monitoring_generator.yaml"
      inputs:
        services: "{{steps.generate_services.results}}"
        sla_requirements: "{{inputs.sla_config}}"
        alerting_rules: "{{inputs.alerting_config}}"
```

## Testing Strategy for Examples

### Example Test Framework

```yaml
# examples/test_framework/test_runner.yaml
workflow:
  name: "example_test_runner"
  description: "Test all examples for correctness"
  
  steps:
    - name: "discover_examples"
      type: "claude"
      prompt: |
        Scan examples directory and find all main.yaml files.
        Group by category.
        
    - name: "validate_examples"
      type: "for_loop"
      over: "{{steps.discover_examples.result.examples}}"
      as: "example"
      steps:
        - name: "validate_{{example.name}}"
          type: "pipeline"
          pipeline_file: "./validators/example_validator.yaml"
          inputs:
            example_path: "{{example.path}}"
            
    - name: "test_examples"
      type: "for_loop"
      over: "{{steps.discover_examples.result.examples}}"
      as: "example"
      max_concurrent: 5
      steps:
        - name: "test_{{example.name}}"
          type: "pipeline"
          pipeline_file: "{{example.path}}"
          inputs: "{{example.test_inputs}}"
          config:
            mock_mode: true
            timeout_seconds: 60
            
    - name: "generate_report"
      type: "claude"
      prompt: |
        Generate test report:
        
        Validation results: {{json(steps.validate_examples.results)}}
        Test results: {{json(steps.test_examples.results)}}
        
        Create markdown report with pass/fail status.
```

### Testing Individual Examples

```bash
# Test a specific example
pipeline test examples/data_processing/etl_pipeline/main.yaml \
  --mock-mode \
  --inputs test_inputs.json

# Validate example structure
pipeline validate examples/code_generation/api_client_generator/main.yaml

# Benchmark example performance
pipeline benchmark examples/analysis/codebase_analyzer/main.yaml \
  --iterations 5 \
  --profile
```

## Running the Examples

### Prerequisites

1. Install pipeline_ex:
   ```bash
   git clone https://github.com/your-org/pipeline_ex
   cd pipeline_ex
   mix deps.get
   ```

2. Set up environment variables:
   ```bash
   export CLAUDE_API_KEY="your-key"
   export GEMINI_API_KEY="your-key"
   ```

3. Configure example settings:
   ```bash
   cp examples/config.example.yaml examples/config.yaml
   # Edit config.yaml with your settings
   ```

### Running Examples

```bash
# Run an example
mix pipeline.run examples/data_processing/etl_pipeline/main.yaml \
  --inputs examples/data_processing/etl_pipeline/sample_inputs.json

# Run with custom configuration
mix pipeline.run examples/analysis/codebase_analyzer/main.yaml \
  --config custom_config.yaml \
  --inputs '{"repo_path": "./my-project"}'

# Run in debug mode
PIPELINE_DEBUG=true mix pipeline.run examples/complex_workflows/ml_pipeline/main.yaml
```

### Example Outputs

Each example includes sample outputs in its directory:

```
examples/data_processing/etl_pipeline/
├── main.yaml
├── sample_inputs.json
├── sample_outputs.json
├── execution_trace.json
└── README.md
```

## Contributing Examples

### Guidelines for New Examples

1. **Purpose**: Clearly define the real-world problem being solved
2. **Modularity**: Use nested pipelines to demonstrate composition
3. **Documentation**: Include comprehensive README with:
   - Problem description
   - Solution approach
   - Pipeline architecture
   - Usage instructions
   - Expected outputs
4. **Testing**: Provide test inputs and expected outputs
5. **Best Practices**: Follow recursive pipeline best practices

### Example Template

```yaml
# examples/category/example_name/main.yaml
workflow:
  name: "example_name"
  description: "Clear description of what this example does"
  metadata:
    author: "Your Name"
    version: "1.0.0"
    tags: ["category", "use-case"]
    
  # Well-documented global variables
  global_vars:
    config:
      description: "Configuration for the example"
      # ...
      
  steps:
    # Clear, logical flow with nested pipelines
    - name: "step_name"
      type: "pipeline"
      pipeline_file: "./substep.yaml"
      # Well-documented inputs/outputs
```

### Submission Process

1. Fork the repository
2. Create example in appropriate category
3. Add tests and documentation
4. Submit pull request with:
   - Example description
   - Test results
   - Performance metrics

---

This collection of examples demonstrates the power and flexibility of recursive pipelines for solving real-world problems. Each example can be adapted and extended for specific use cases, providing a foundation for building sophisticated AI engineering workflows.