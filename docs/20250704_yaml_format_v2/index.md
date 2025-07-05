# Pipeline YAML Format v2 - Documentation Index

## 📚 Complete Documentation Suite

Welcome to the comprehensive Pipeline YAML Format v2 documentation. This suite provides everything you need to understand and use the full capabilities of the pipeline system.

### 🚀 Quick Start

- **Quick Reference Card** - One-page summary of all features (see `docs/20250704_yaml_format_v2/10_quick_reference.md`)
- **Migration Guide** - Upgrade from v1 to v2 (see `docs/20250704_yaml_format_v2/09_migration_guide.md`)

### 📖 Core Documentation

1. **[Complete YAML Schema Reference](01_complete_schema_reference.md)**
   - Full schema definition with all fields and types
   - Validation rules and constraints
   - Configuration precedence

2. **[Step Types Reference](02_step_types_reference.md)**
   - All 17+ step types with examples
   - AI provider steps (Gemini, Claude variants)
   - Control flow steps (loops, conditions, pipelines)
   - Data and file operations

3. **[Prompt System Reference](03_prompt_system_reference.md)**
   - Prompt composition and templates
   - File-based prompt management
   - Content processing and extraction
   - Variable substitution

4. **[Control Flow & Logic](04_control_flow_logic.md)**
   - Conditional execution
   - Loop constructs (for, while)
   - Branching logic (switch/case)
   - State management

5. **[Pipeline Composition](05_pipeline_composition.md)**
   - Recursive pipeline execution
   - Input/output mapping
   - Context management
   - Safety features

6. **[Advanced Features](06_advanced_features.md)**
   - Data transformation (JSONPath)
   - Codebase intelligence
   - File operations
   - Schema validation
   - Session management

7. **Configuration & Environment** (see `docs/20250704_yaml_format_v2/07_configuration_environment.md`)
   - Workflow configuration
   - Authentication setup
   - Resource management
   - Monitoring and telemetry

8. **[Best Practices & Patterns](08_best_practices_patterns.md)**
   - Design principles
   - Common patterns
   - Error handling strategies
   - Performance optimization
   - Security guidelines

### 🎯 Feature Highlights

#### New in v2

- **Pipeline Composition**: Build complex workflows from reusable components
- **Enhanced Claude Steps**: Smart presets, sessions, extraction, batch processing
- **Advanced Control Flow**: Loops, conditions, parallel execution
- **Data Operations**: Transform, query, and manipulate data
- **Enterprise Features**: Authentication, monitoring, resource limits

#### Key Capabilities

- ✅ 17+ step types for every use case
- ✅ Modular pipeline composition
- ✅ Sophisticated error handling
- ✅ Performance optimization
- ✅ Enterprise-grade safety
- ✅ Full backward compatibility

### 📊 Format Evolution

| Version | Release | Key Features |
|---------|---------|--------------|
| v1.0 | 2024 | Basic Gemini/Claude orchestration |
| v1.5 | 2024 | Advanced features (loops, conditions) |
| v2.0 | 2025 | Recursive pipelines, enhanced Claude SDK |

### 🔍 Finding Information

#### By Use Case

- **Building a new pipeline**: Start with [Schema Reference](01_complete_schema_reference.md)
- **Using AI providers**: See [Step Types](02_step_types_reference.md)
- **Managing prompts**: Check [Prompt System](03_prompt_system_reference.md)
- **Adding logic**: Review [Control Flow](04_control_flow_logic.md)
- **Creating components**: Study [Pipeline Composition](05_pipeline_composition.md)

#### By Experience Level

- **Beginners**: [Quick Reference](10_quick_reference.md) → [Best Practices](08_best_practices_patterns.md)
- **Intermediate**: [Step Types](02_step_types_reference.md) → [Advanced Features](06_advanced_features.md)
- **Advanced**: [Pipeline Composition](05_pipeline_composition.md) → Configuration (see `docs/20250704_yaml_format_v2/07_configuration_environment.md`)

### 💡 Tips for Success

1. **Start Simple**: Begin with basic pipelines and gradually add features
2. **Use Composition**: Build reusable components instead of monolithic pipelines
3. **Test Thoroughly**: Use mock mode for development and testing
4. **Follow Patterns**: Apply proven patterns from the best practices guide
5. **Monitor Performance**: Enable telemetry and resource tracking

### 🛠️ Tools and Commands

```bash
# Validate pipeline syntax
mix pipeline.validate my_pipeline.yaml

# Run in mock mode (free, no API calls)
mix pipeline.run my_pipeline.yaml

# Run with real APIs
mix pipeline.run.live my_pipeline.yaml

# Check v2 feature usage
mix pipeline.analyze my_pipeline.yaml --check-v2-features
```

### 📝 Documentation Maintenance

- **Created**: July 4, 2025
- **Format Version**: 2.0
- **Documentation Version**: 1.0
- **Status**: Complete and production-ready

### 🤝 Contributing

To improve this documentation:
1. Identify gaps or unclear sections
2. Provide examples from real usage
3. Submit corrections or clarifications
4. Share patterns that work well

---

**Remember**: The pipeline system is designed for gradual adoption. You don't need to use every feature immediately. Start with what you need and expand as your requirements grow.