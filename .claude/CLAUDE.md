# PipelineEx Development Context

## Project Overview
PipelineEx is an advanced AI pipeline orchestration library for Elixir that integrates Claude and Gemini AI providers with enterprise-grade features including self-improving Genesis pipelines, advanced workflow patterns, and comprehensive testing.

## Technology Stack
- **Language:** Elixir
- **AI Providers:** Claude Agent SDK, Gemini Ex
- **Database:** Ecto with PostgreSQL (for future features)
- **Testing:** ExUnit with comprehensive mocking
- **Build:** Mix with Hex package publishing

## Key Features Implemented

### Core Functionality
- ✅ YAML-based workflow configuration
- ✅ Multiple AI provider support (Claude, Gemini)
- ✅ Mock/live testing modes
- ✅ Comprehensive error handling
- ✅ Streaming responses

### Advanced Features
- ✅ Loop constructs (for/while loops)
- ✅ Complex conditional logic
- ✅ File operations and data transformation
- ✅ Codebase intelligence
- ✅ Session management

### Claude Agent SDK Integration (Latest)
- ✅ MCP server support for external integrations
- ✅ Hooks system for event-driven execution
- ✅ Subagent orchestration for specialization
- ✅ Agent skills framework
- ✅ Context management with CLAUDE.md

## Current Development Phase
**Phase 2: Enhanced Features Implementation**
- MCP server integration ✅
- Hooks system ✅
- Subagent support ✅
- Agent skills ✅
- Context management ✅

## Architectural Decisions

### Provider Architecture
- **EnhancedClaudeProvider:** Full Claude Agent SDK integration with advanced features
- **ClaudeProvider:** Basic SDK integration with timeout handling
- **GeminiProvider:** Gemini Ex integration with InstructorLite migration

### Configuration System
- **OptionBuilder:** Preset-based configuration (development/production/analysis/test/chat)
- **YAML-first:** Declarative configuration with runtime overrides
- **Environment-aware:** Automatic preset selection based on Mix environment

### Testing Strategy
- **Mock-first:** All tests use mocked providers by default
- **Integration tests:** Live API testing with proper isolation
- **Comprehensive coverage:** Unit, integration, and performance tests

## Implementation Patterns

### Error Handling
- Structured error responses with detailed context
- Graceful degradation for partial failures
- Comprehensive logging with correlation IDs
- Circuit breaker patterns for resilience

### Performance Optimization
- Streaming responses to reduce memory usage
- Lazy evaluation for large datasets
- Connection pooling for API calls
- Caching strategies for repeated operations

### Security Considerations
- Input validation and sanitization
- Tool permission management
- Safe command execution
- Audit logging for compliance

## Development Guidelines

### Code Quality
- Comprehensive test coverage (>95%)
- Credo code quality checks
- Dialyzer type checking
- Proper documentation with examples

### API Design
- Consistent error response format
- Backward compatibility maintenance
- Clear separation of concerns
- Functional programming patterns

### Testing Practices
- Mock providers for fast unit tests
- Integration tests with live APIs
- Performance benchmarking
- Regression testing automation

## Future Roadmap

### Phase 3: Enterprise Features
- Advanced security controls
- Audit logging and compliance
- High-availability deployment
- Performance monitoring dashboard

### Phase 4: Ecosystem Expansion
- Plugin system for custom providers
- Marketplace for shared pipelines
- Multi-tenant support
- Cloud-native deployment options

## Known Issues & TODOs

### Immediate Priorities
- [ ] Complete memory compaction implementation
- [ ] Add performance monitoring dashboard
- [ ] Implement advanced security controls

### Future Enhancements
- [ ] Plugin system for custom providers
- [ ] Marketplace integration
- [ ] Multi-tenant architecture
- [ ] Advanced analytics and reporting

## Contact & Collaboration

This context file maintains continuity across development sessions and team collaboration. Update this file when making significant architectural decisions or implementing new features.

**Maintainer:** PipelineEx Development Team
**Last Updated:** October 24, 2025
**Version:** 0.1.0
