# Async Streaming Implementation Guide for Pipeline System

## Overview

This guide provides step-by-step prompts for implementing async streaming functionality in the Pipeline system, based on the async streaming feature already implemented in ClaudeCodeSDK.

## Technical Documentation

### Background

The ClaudeCodeSDK has two streaming modes:
1. **Synchronous Mode** (`Process` module) - Collects all output before parsing
2. **Asynchronous Mode** (`ProcessAsync` module) - Real-time message streaming

The Pipeline system currently uses only synchronous mode, collecting all Claude messages before processing. This implementation will add async streaming support to enable real-time response streaming.

### Architecture Changes

#### 1. New Modules
- `Pipeline.Streaming.AsyncHandler` - Handles async message streams
- `Pipeline.Streaming.AsyncResponse` - Wraps streaming responses
- `Pipeline.Test.AsyncMocks` - Mock support for async streaming

#### 2. Modified Modules
- `Pipeline.Providers.ClaudeProvider` - Add async streaming support
- `Pipeline.Providers.EnhancedClaudeProvider` - Add async streaming support
- `Pipeline.Step.Claude` - Handle streaming responses
- `Pipeline.Executor` - Support streaming execution
- `Pipeline.Config` - Add streaming configuration options

#### 3. YAML Configuration
```yaml
- name: "streaming_assistant"
  type: "claude"
  claude_options:
    async_streaming: true      # Enable async streaming
    stream_handler: "console"  # Handler type
    stream_buffer_size: 100    # Buffer size for batching
```

### Implementation Prompts

## Prompt 1: Create Async Streaming Handler Module

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md` (this file)
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/result_stream.ex`
- `/home/home/p/g/n/claude_code_sdk_elixir/lib/claude_code_sdk/process_async.ex`

**Task:**
Create a new module `Pipeline.Streaming.AsyncHandler` that provides the behavior and base implementation for handling async message streams from ClaudeCodeSDK.

The module should:
1. Define a behavior with callbacks for handling different message types
2. Provide a default console handler implementation
3. Support message buffering and batching
4. Include proper error handling for stream interruptions

Create comprehensive tests in `test/pipeline/streaming/async_handler_test.exs` that verify:
- Message type routing
- Buffer management
- Error handling
- Console output formatting

Ensure all tests pass before proceeding.

## Prompt 2: Create Async Response Wrapper

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/async_handler.ex` (from Prompt 1)
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/result_manager.ex`

**Task:**
Create a new module `Pipeline.Streaming.AsyncResponse` that wraps streaming responses for use in the pipeline system.

The module should:
1. Wrap a Claude message stream with metadata
2. Support lazy evaluation of the stream
3. Provide methods to convert to synchronous response when needed
4. Track streaming metrics (first message time, total messages, etc.)

Create tests in `test/pipeline/streaming/async_response_test.exs` that verify:
- Stream wrapping and unwrapping
- Metric collection
- Conversion to sync response
- Stream interruption handling

Ensure all tests pass before proceeding.

## Prompt 3: Add Async Support to Claude Provider

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/providers/claude_provider.ex`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/async_handler.ex`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/async_response.ex`
- `/home/home/p/g/n/claude_code_sdk_elixir/lib/claude_code_sdk/options.ex`

**Task:**
Modify `Pipeline.Providers.ClaudeProvider` to support async streaming.

Changes needed:
1. Check for `async_streaming` option in claude_options
2. Pass through async options to ClaudeCodeSDK
3. Return AsyncResponse wrapper when streaming is enabled
4. Maintain backward compatibility for non-streaming calls

Create/update tests in `test/unit/pipeline/providers/claude_provider_test.exs` that verify:
- Async streaming option detection
- Proper SDK option building with async flag
- AsyncResponse creation for streaming mode
- Backward compatibility with sync mode

Ensure all existing and new tests pass.

## Prompt 4: Add Async Support to Enhanced Claude Provider

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/providers/enhanced_claude_provider.ex`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/providers/claude_provider.ex` (modified in Prompt 3)
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/async_response.ex`

**Task:**
Modify `Pipeline.Providers.EnhancedClaudeProvider` to support async streaming with telemetry and cost tracking.

Changes needed:
1. Add async streaming support similar to ClaudeProvider
2. Implement streaming telemetry events
3. Track streaming metrics (time to first token, tokens per second)
4. Support progressive cost calculation

Update tests in `test/unit/pipeline/providers/enhanced_claude_provider_test.exs` to verify:
- Async streaming with enhanced features
- Telemetry event emission during streaming
- Progressive cost tracking
- Metric collection

Ensure all tests pass.

## Prompt 5: Update Claude Step for Streaming

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/step/claude.ex`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/async_response.ex`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/async_handler.ex`

**Task:**
Modify `Pipeline.Step.Claude` to handle streaming responses.

Changes needed:
1. Detect AsyncResponse from providers
2. Route to appropriate stream handler based on configuration
3. Support stream interruption and cleanup
4. Provide option to collect stream into sync response

Update tests in `test/unit/pipeline/step/claude_test.exs` to verify:
- AsyncResponse handling
- Stream handler routing
- Proper cleanup on errors
- Sync/async mode switching

Ensure all tests pass.

## Prompt 6: Create Async Mock Support

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/test/mocks/claude_provider.ex`
- `/home/home/p/g/n/claude_code_sdk_elixir/lib/claude_code_sdk/mock/process_async.ex`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/async_response.ex`

**Task:**
Create `Pipeline.Test.AsyncMocks` module to support testing async streaming functionality.

The module should:
1. Provide mock async streams with configurable delays
2. Support different streaming patterns (fast, slow, chunked)
3. Allow error injection at specific points in the stream
4. Integrate with existing mock system

Create tests in `test/pipeline/test/async_mocks_test.exs` that verify:
- Mock stream generation
- Timing simulation
- Error injection
- Integration with test mode

Ensure all tests pass.

## Prompt 7: Update Executor for Streaming

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/executor.ex`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/async_response.ex`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/result_manager.ex`

**Task:**
Modify `Pipeline.Executor` to support streaming execution.

Changes needed:
1. Detect AsyncResponse results from steps
2. Support streaming passthrough to next steps
3. Handle mixed sync/async step chains
4. Maintain execution metrics for streaming

Update tests in `test/unit/pipeline/executor_test.exs` to verify:
- Streaming step execution
- Mixed sync/async pipelines
- Metric collection during streaming
- Error propagation in streams

Ensure all tests pass.

## Prompt 8: Add YAML Configuration Support

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/config.ex`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/enhanced_config.ex`
- `/home/home/p/g/n/pipeline_ex/docs/20250704_yaml_format_v2/02_step_types_reference.md`

**Task:**
Update configuration system to support async streaming options.

Changes needed:
1. Add async streaming options to YAML schema
2. Update config validation for new options
3. Add configuration examples
4. Update step type documentation

Create/update tests in `test/unit/pipeline/config_test.exs` that verify:
- New option parsing
- Schema validation
- Default value handling
- Invalid configuration detection

Ensure all tests pass.

## Prompt 9: Create Stream Handler Implementations

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/streaming/async_handler.ex`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/utils/file_utils.ex`

**Task:**
Create concrete stream handler implementations.

Implement:
1. `Pipeline.Streaming.Handlers.ConsoleHandler` - Real-time console output
2. `Pipeline.Streaming.Handlers.FileHandler` - Stream to file
3. `Pipeline.Streaming.Handlers.CallbackHandler` - Custom function callbacks
4. `Pipeline.Streaming.Handlers.BufferHandler` - Collect into memory buffer

Create tests for each handler in `test/pipeline/streaming/handlers/` that verify:
- Proper message handling
- Resource cleanup
- Error handling
- Configuration options

Ensure all tests pass.

## Prompt 10: Integration Testing and Examples

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/examples/claude_smart_example.yaml`
- `/home/home/p/g/n/pipeline_ex/test/integration/workflow_scenarios_test.exs`
- All modules created in previous prompts

**Task:**
Create comprehensive integration tests and example pipelines.

Create:
1. `examples/claude_streaming_example.yaml` - Basic streaming example
2. `examples/claude_streaming_advanced.yaml` - Advanced features
3. `test/integration/async_streaming_test.exs` - Full integration tests
4. Update documentation with streaming examples

Tests should verify:
- End-to-end streaming pipelines
- Mixed sync/async workflows
- Performance improvements
- Error handling across the stack

Ensure all tests pass and examples work correctly.

## Prompt 11: Performance Testing and Optimization

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/lib/pipeline/monitoring/performance.ex`
- `/home/home/p/g/n/pipeline_ex/test/pipeline/performance/load_test.exs`
- All streaming modules created in previous prompts

**Task:**
Create performance tests and optimize streaming implementation.

Create:
1. `test/pipeline/performance/streaming_performance_test.exs`
2. Benchmark sync vs async performance
3. Identify and fix any bottlenecks
4. Add performance metrics to monitoring

Tests should measure:
- Time to first token
- Throughput (tokens/second)
- Memory usage during streaming
- CPU usage patterns

Optimize any identified bottlenecks and ensure all tests pass.

## Prompt 12: Documentation and Release

**Required Reading:**
- `/home/home/p/g/n/pipeline_ex/docs/implementation/async_streaming_implementation_guide.md`
- `/home/home/p/g/n/pipeline_ex/README.md`
- `/home/home/p/g/n/pipeline_ex/ADVANCED_FEATURES.md`
- `/home/home/p/g/n/pipeline_ex/docs/20250704_yaml_format_v2/10_quick_reference.md`

**Task:**
Update all documentation for the async streaming feature.

Update:
1. README.md - Add streaming section
2. ADVANCED_FEATURES.md - Document streaming capabilities
3. Quick reference - Add streaming options
4. Create migration guide for existing users
5. Update CHANGELOG.md

Ensure:
- All examples are tested and working
- Documentation is clear and comprehensive
- Breaking changes are clearly noted
- Performance improvements are documented

## Success Criteria

Each prompt should result in:
1. Working code that passes all tests
2. Comprehensive test coverage (>95%)
3. Clear documentation
4. No breaking changes to existing functionality
5. Performance improvements demonstrated

## Testing Strategy

- Unit tests for each new module
- Integration tests for end-to-end flows
- Performance benchmarks
- Mock support for reliable testing
- Examples that demonstrate real usage

## Notes

- Maintain backward compatibility throughout
- Use feature flags if needed for gradual rollout
- Consider memory usage for long-running streams
- Ensure proper cleanup on process termination
- Document all configuration options clearly