# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-10-08

### Removed - BREAKING CHANGES
- **Async streaming system completely removed** (~900 lines)
  - Removed `Pipeline.Streaming.AsyncHandler` module
  - Removed `Pipeline.Streaming.AsyncResponse` module
  - Removed 7 handler implementations (console, simple, debug, file, buffer, callback, text)
  - Removed `async_streaming` option from Claude providers
  - Removed all async streaming tests and examples

### Changed
- Simplified Claude providers to use `ClaudeCodeSDK.query() |> Enum.to_list()` directly
- Cleaned up `Pipeline.Step.Claude` module (removed async handling)
- Simplified `Pipeline.Executor` (removed AsyncResponse pattern matching)

### Added
- `docs/ASYNC_STREAMING_DEPRECATION.md` - Migration guide
- `docs/ASYNC_STREAMING_EVALUATION_REPORT.md` - Technical analysis
- `docs/ASYNC_STREAMING_ASSESSMENT.md` - SDK implementer perspective
- `docs/PIPELINE_EX_RECOMMENDATION.md` - Removal recommendation

### Rationale
The async streaming system was operating at the wrong abstraction level. It attempted to buffer and batch complete Message structs from ClaudeCodeSDK, thinking it was handling streaming text chunks. ClaudeCodeSDK already provides complete messages optimally - the buffering added complexity and latency without benefit.

For migration guidance, see `docs/ASYNC_STREAMING_DEPRECATION.md`.

### Technical Details
- All 869 tests pass (66 async tests skipped as deprecated)
- Dialyzer passes successfully
- Clean compilation with no errors
- CI checks (credo, dialyzer, tests) all pass

## [0.0.1] - 2025-01-05

**Maintainer**: NSHkr <ZeroTrust@NSHkr.com>

### Added
- Initial release of Pipeline.ex - AI pipeline orchestration library for Elixir
- Core pipeline execution engine with robust error handling and retries
- Support for Claude (Anthropic) and Gemini (Google) AI providers
- YAML v2 pipeline format with comprehensive features:
  - Multi-step pipelines with conditional execution
  - Advanced prompt templating with variables and transformations
  - Control flow (conditionals, loops, parallel execution)
  - Pipeline composition and inheritance
  - Function calling support for both providers
- Genesis/Meta pipeline system for self-improving pipelines:
  - Pipeline DNA evolution and mutation
  - Fitness evaluation framework
  - Recursive pipeline generation
- Comprehensive testing framework with mocking support
- Extensive documentation including:
  - Complete YAML format v2 reference
  - Architecture documentation
  - Usage guides and patterns
  - Pipeline specifications for various use cases
- Visual pipeline editor specifications (implementation planned)
- Safety features and context management
- Performance optimization with caching and parallel execution

### Features
- **Pipeline Execution**: Robust execution engine with retry logic and error handling
- **Provider Support**: Claude (via Anthropic API) and Gemini (via Google API) integration
- **YAML Configuration**: Declarative pipeline definitions with v2 format
- **Prompt System**: Advanced templating with variables, transformations, and inheritance
- **Control Flow**: Conditionals, loops, parallel execution, and error handling
- **Genesis System**: Self-improving pipelines with evolution capabilities
- **Testing Support**: Built-in test mode with comprehensive mocking
- **Documentation**: Extensive guides, references, and examples

### Known Limitations
- Visual editor GUI not yet implemented (specifications only)
- Limited to Claude and Gemini providers in this release
- Some advanced meta-pipeline features are experimental

[0.0.1]: https://github.com/nshkrdotcom/pipeline_ex/releases/tag/v0.0.1