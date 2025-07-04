# Pipeline Visual Editor - Data Model

## Overview

This document defines the complete data model for the Pipeline Visual Editor, including type definitions, validation schemas, and data transformations between the visual representation and YAML format.

## Core Type Definitions

### Pipeline Types

```typescript
// Root pipeline structure
interface Pipeline {
  workflow: Workflow
}

interface Workflow {
  // Basic metadata
  name: string
  description?: string
  version?: string
  
  // Execution configuration
  checkpoint_enabled?: boolean
  workspace_dir?: string
  checkpoint_dir?: string
  
  // Enhanced authentication (future)
  claude_auth?: ClaudeAuth
  environment?: Environment
  
  // Default configurations
  defaults?: WorkflowDefaults
  
  // Function definitions for Gemini
  gemini_functions?: Record<string, GeminiFunctionDef>
  
  // Pipeline steps
  steps: Step[]
}

interface WorkflowDefaults {
  gemini_model?: GeminiModel
  gemini_token_budget?: TokenBudget
  claude_output_format?: ClaudeOutputFormat
  claude_preset?: ClaudePreset
  output_dir?: string
}

interface TokenBudget {
  max_output_tokens: number      // 256-8192
  temperature: number            // 0.0-1.0
  top_p?: number                // 0.0-1.0
  top_k?: number                // 1-40
}
```

### Step Type Hierarchy

```typescript
// Base step interface
interface BaseStep {
  name: string
  type: StepType
  role?: 'brain' | 'muscle'
  condition?: string | ConditionExpression
  output_to_file?: string
}

// Step type discriminated union
type Step = 
  | GeminiStep
  | ClaudeStep
  | ClaudeSmartStep
  | ClaudeSessionStep
  | ClaudeExtractStep
  | ClaudeBatchStep
  | ClaudeRobustStep
  | ParallelClaudeStep
  | PipelineStep
  | ForLoopStep
  | WhileLoopStep
  | SwitchStep
  | FileOpsStep
  | DataTransformStep
  | CodebaseQueryStep
  | SetVariableStep
  | CheckpointStep

// AI Provider Steps
interface GeminiStep extends BaseStep {
  type: 'gemini'
  model?: GeminiModel
  token_budget?: TokenBudget
  functions?: string[]
  prompt: PromptElement[]
}

interface ClaudeStep extends BaseStep {
  type: 'claude'
  claude_options?: ClaudeOptions
  prompt: PromptElement[]
}

interface ClaudeSmartStep extends BaseStep {
  type: 'claude_smart'
  preset: ClaudePreset
  environment_aware?: boolean
  prompt: PromptElement[]
  claude_options?: Partial<ClaudeOptions>
}

interface ClaudeSessionStep extends BaseStep {
  type: 'claude_session'
  session_name?: string
  session_config?: SessionConfig
  prompt: PromptElement[]
}

interface ClaudeExtractStep extends BaseStep {
  type: 'claude_extract'
  preset?: ClaudePreset
  extraction_config?: ExtractionConfig
  prompt: PromptElement[]
  schema?: JsonSchema
}

interface ClaudeBatchStep extends BaseStep {
  type: 'claude_batch'
  batch_config?: BatchConfig
  tasks: BatchTask[]
}

interface ClaudeRobustStep extends BaseStep {
  type: 'claude_robust'
  retry_config?: RetryConfig
  claude_options?: ClaudeOptions
  prompt: PromptElement[]
}

interface ParallelClaudeStep extends BaseStep {
  type: 'parallel_claude'
  parallel_tasks: ParallelTask[]
}

// Control Flow Steps
interface ForLoopStep extends BaseStep {
  type: 'for_loop'
  iterator: string
  data_source: string
  parallel?: boolean
  max_parallel?: number
  max_iterations?: number
  break_on_error?: boolean
  steps: Step[]
}

interface WhileLoopStep extends BaseStep {
  type: 'while_loop'
  condition: string | ConditionExpression
  max_iterations: number
  steps: Step[]
}

interface SwitchStep extends BaseStep {
  type: 'switch'
  expression: string
  cases: Record<string, Step[]>
  default?: Step[]
}

// Nested Pipeline Step
interface PipelineStep extends BaseStep {
  type: 'pipeline'
  pipeline_file?: string
  pipeline_ref?: string
  pipeline?: Pipeline
  inputs?: Record<string, any>
  outputs?: OutputMapping[]
  config?: NestedPipelineConfig
}

// Data Operation Steps
interface FileOpsStep extends BaseStep {
  type: 'file_ops'
  operation: FileOperation
  source?: string
  destination?: string
  files?: FileValidation[]
  format?: ConversionFormat
}

interface DataTransformStep extends BaseStep {
  type: 'data_transform'
  input_source: string
  operations: DataOperation[]
  output_field?: string
  output_format?: string
}

interface CodebaseQueryStep extends BaseStep {
  type: 'codebase_query'
  codebase_context?: boolean
  queries: Record<string, CodebaseQuery>
}

interface SetVariableStep extends BaseStep {
  type: 'set_variable'
  variables: Record<string, any>
}

interface CheckpointStep extends BaseStep {
  type: 'checkpoint'
  state: Record<string, any>
}
```

### Configuration Types

```typescript
// Claude configuration options
interface ClaudeOptions {
  // Core configuration
  print?: boolean
  max_turns?: number
  output_format?: ClaudeOutputFormat
  verbose?: boolean
  
  // Tool management
  allowed_tools?: ClaudeTool[]
  disallowed_tools?: ClaudeTool[]
  
  // System prompts
  system_prompt?: string
  append_system_prompt?: string
  
  // Working environment
  cwd?: string
  
  // Permission management (future)
  permission_mode?: PermissionMode
  permission_prompt_tool?: string
  
  // Advanced features
  mcp_config?: string
  
  // Session management
  session_id?: string
  resume_session?: boolean
  
  // Performance & reliability
  retry_config?: RetryConfig
  timeout_ms?: number
  
  // Debug & monitoring
  debug_mode?: boolean
  telemetry_enabled?: boolean
  cost_tracking?: boolean
}

// Type definitions for configurations
type ClaudeOutputFormat = 'text' | 'json' | 'stream-json'
type ClaudeTool = 'Write' | 'Edit' | 'Read' | 'Bash' | 'Search' | 'Glob' | 'Grep'
type ClaudePreset = 'development' | 'production' | 'analysis' | 'chat'
type PermissionMode = 'default' | 'accept_edits' | 'bypass_permissions' | 'plan'

interface RetryConfig {
  max_retries: number
  backoff_strategy: 'linear' | 'exponential'
  retry_on?: string[]
  fallback_action?: string
}

interface SessionConfig {
  persist: boolean
  session_name?: string
  continue_on_restart?: boolean
  checkpoint_frequency?: number
  max_turns?: number
  description?: string
}

interface ExtractionConfig {
  use_content_extractor?: boolean
  format?: ExtractionFormat
  post_processing?: PostProcessingOp[]
  max_summary_length?: number
  include_metadata?: boolean
}

interface BatchConfig {
  max_parallel: number
  timeout_per_task?: number
  consolidate_results?: boolean
}

interface NestedPipelineConfig {
  inherit_context?: boolean
  inherit_providers?: boolean
  inherit_functions?: boolean
  workspace_dir?: string
  checkpoint_enabled?: boolean
  timeout_seconds?: number
  max_retries?: number
  continue_on_error?: boolean
  max_depth?: number
  memory_limit_mb?: number
  enable_tracing?: boolean
}

// Prompt system types
type PromptElement = 
  | StaticPrompt
  | FilePrompt
  | PreviousResponsePrompt
  | SessionContextPrompt
  | ClaudeContinuePrompt

interface StaticPrompt {
  type: 'static'
  content: string
}

interface FilePrompt {
  type: 'file'
  path: string
  variables?: Record<string, string>
  inject_as?: string
}

interface PreviousResponsePrompt {
  type: 'previous_response'
  step: string
  extract?: string
  extract_with?: 'content_extractor'
  summary?: boolean
  max_length?: number
}

interface SessionContextPrompt {
  type: 'session_context'
  session_id: string
  include_last_n?: number
}

interface ClaudeContinuePrompt {
  type: 'claude_continue'
  new_prompt: string
}

// Data operation types
type FileOperation = 'copy' | 'move' | 'delete' | 'validate' | 'list' | 'convert'
type ConversionFormat = 'csv_to_json' | 'json_to_csv' | 'yaml_to_json' | 'xml_to_json'
type DataOperation = FilterOp | AggregateOp | JoinOp | TransformOp | QueryOp
type PostProcessingOp = 'extract_code_blocks' | 'extract_recommendations' | 'extract_links' | 'extract_key_points'
type ExtractionFormat = 'text' | 'json' | 'structured' | 'summary' | 'markdown'

// Gemini types
type GeminiModel = 
  | 'gemini-2.5-flash'
  | 'gemini-2.5-flash-lite-preview-06-17'
  | 'gemini-2.5-pro'
  | 'gemini-2.0-flash'

interface GeminiFunctionDef {
  description: string
  parameters: JsonSchema
}
```

### Condition System

```typescript
// Condition expression types
type ConditionExpression = 
  | SimpleCondition
  | AndCondition
  | OrCondition
  | NotCondition
  | ComparisonCondition
  | FunctionCondition

interface SimpleCondition {
  type: 'simple'
  expression: string
}

interface AndCondition {
  type: 'and'
  conditions: ConditionExpression[]
}

interface OrCondition {
  type: 'or'
  conditions: ConditionExpression[]
}

interface NotCondition {
  type: 'not'
  condition: ConditionExpression
}

interface ComparisonCondition {
  type: 'comparison'
  left: string | number
  operator: ComparisonOperator
  right: string | number
}

interface FunctionCondition {
  type: 'function'
  function: ConditionFunction
  args: any[]
}

type ComparisonOperator = '>' | '<' | '==' | '!=' | '>=' | '<=' | 'contains' | 'matches' | 'between'
type ConditionFunction = 'length' | 'any' | 'all' | 'count' | 'sum' | 'average'
```

### Visual Editor Types

```typescript
// React Flow node types
interface NodeData {
  step: Step
  validation: ValidationResult
  executionStatus?: ExecutionStatus
}

interface StepNode extends Node<NodeData> {
  type: 'step'
}

interface ParallelGroupNode extends Node<ParallelGroupData> {
  type: 'parallelGroup'
}

interface LoopNode extends Node<LoopNodeData> {
  type: 'loop'
}

interface ConditionalNode extends Node<ConditionalNodeData> {
  type: 'conditional'
}

// Edge types
interface DataFlowEdge extends Edge {
  type: 'dataFlow'
}

interface ConditionalEdge extends Edge {
  type: 'conditional'
  data: {
    condition: string
    label: string
  }
}

interface LoopBackEdge extends Edge {
  type: 'loopBack'
}

// Execution status
type ExecutionStatus = 
  | 'pending'
  | 'running'
  | 'completed'
  | 'failed'
  | 'skipped'
  | 'cancelled'
```

## Validation Schemas

### JSON Schema Definitions

```typescript
// Pipeline validation schema
const pipelineSchema: JsonSchema = {
  type: 'object',
  required: ['workflow'],
  properties: {
    workflow: {
      type: 'object',
      required: ['name', 'steps'],
      properties: {
        name: {
          type: 'string',
          minLength: 1,
          maxLength: 100,
          pattern: '^[a-zA-Z0-9_-]+$'
        },
        description: { type: 'string', maxLength: 500 },
        version: { type: 'string', pattern: '^\\d+\\.\\d+\\.\\d+$' },
        checkpoint_enabled: { type: 'boolean' },
        workspace_dir: { type: 'string' },
        checkpoint_dir: { type: 'string' },
        defaults: { $ref: '#/definitions/workflowDefaults' },
        gemini_functions: {
          type: 'object',
          additionalProperties: { $ref: '#/definitions/geminiFunctionDef' }
        },
        steps: {
          type: 'array',
          minItems: 1,
          items: { $ref: '#/definitions/step' }
        }
      }
    }
  }
}

// Step validation schemas
const stepSchemas: Record<StepType, JsonSchema> = {
  gemini: {
    type: 'object',
    required: ['name', 'type', 'prompt'],
    properties: {
      name: { $ref: '#/definitions/stepName' },
      type: { const: 'gemini' },
      model: { $ref: '#/definitions/geminiModel' },
      token_budget: { $ref: '#/definitions/tokenBudget' },
      functions: {
        type: 'array',
        items: { type: 'string' }
      },
      prompt: { $ref: '#/definitions/promptArray' }
    }
  },
  claude: {
    type: 'object',
    required: ['name', 'type', 'prompt'],
    properties: {
      name: { $ref: '#/definitions/stepName' },
      type: { const: 'claude' },
      claude_options: { $ref: '#/definitions/claudeOptions' },
      prompt: { $ref: '#/definitions/promptArray' }
    }
  },
  // ... additional step schemas
}
```

### Validation Rules

```typescript
interface ValidationRules {
  // Name validation
  isValidStepName(name: string): boolean
  isUniqueStepName(name: string, existingNames: string[]): boolean
  
  // Reference validation
  stepExists(stepName: string, pipeline: Pipeline): boolean
  isValidStepReference(reference: string, currentStep: Step, pipeline: Pipeline): boolean
  
  // Circular dependency checks
  hasCircularDependency(pipeline: Pipeline): boolean
  detectCircularReferences(step: Step, pipeline: Pipeline): string[]
  
  // Resource validation
  isWithinTokenLimit(step: Step): boolean
  estimateTokenUsage(prompt: PromptElement[]): number
  
  // Type compatibility
  areTypesCompatible(source: Step, target: Step): boolean
  getStepOutputType(step: Step): DataType
  getStepInputType(step: Step): DataType
  
  // Condition validation
  isValidCondition(condition: string | ConditionExpression): boolean
  validateConditionReferences(condition: ConditionExpression, pipeline: Pipeline): boolean
}
```

## Data Transformations

### YAML to Graph Transformation

```typescript
class PipelineToGraphTransformer {
  transform(pipeline: Pipeline): GraphData {
    const nodes: Node[] = []
    const edges: Edge[] = []
    
    // Transform steps to nodes
    pipeline.workflow.steps.forEach((step, index) => {
      const node = this.stepToNode(step, index)
      nodes.push(node)
      
      // Create edges based on step dependencies
      const dependencies = this.extractDependencies(step)
      dependencies.forEach(dep => {
        edges.push(this.createEdge(dep, step.name))
      })
    })
    
    // Group parallel tasks
    const groups = this.identifyParallelGroups(nodes, edges)
    
    return { nodes, edges, groups }
  }
  
  private stepToNode(step: Step, index: number): Node {
    const position = this.calculatePosition(step, index)
    const nodeType = this.getNodeType(step.type)
    
    return {
      id: step.name,
      type: nodeType,
      position,
      data: {
        step,
        validation: this.validateStep(step),
        executionStatus: 'pending'
      }
    }
  }
  
  private extractDependencies(step: Step): string[] {
    const deps: string[] = []
    
    // Extract from prompts
    if ('prompt' in step) {
      step.prompt.forEach(prompt => {
        if (prompt.type === 'previous_response') {
          deps.push(prompt.step)
        }
      })
    }
    
    // Extract from conditions
    if (step.condition) {
      const conditionDeps = this.extractConditionDependencies(step.condition)
      deps.push(...conditionDeps)
    }
    
    return [...new Set(deps)]
  }
}
```

### Graph to YAML Transformation

```typescript
class GraphToPipelineTransformer {
  transform(graphData: GraphData): Pipeline {
    const steps = this.sortTopologically(graphData)
    
    return {
      workflow: {
        name: this.generatePipelineName(),
        steps: steps.map(node => this.nodeToStep(node))
      }
    }
  }
  
  private nodeToStep(node: Node<NodeData>): Step {
    const step = node.data.step
    
    // Update position-dependent properties
    if (this.isInParallelGroup(node)) {
      return this.wrapInParallelStep(step)
    }
    
    return step
  }
  
  private sortTopologically(graphData: GraphData): Node[] {
    // Kahn's algorithm for topological sort
    const sorted: Node[] = []
    const inDegree = new Map<string, number>()
    const queue: string[] = []
    
    // Calculate in-degrees
    graphData.nodes.forEach(node => {
      inDegree.set(node.id, 0)
    })
    
    graphData.edges.forEach(edge => {
      const count = inDegree.get(edge.target) || 0
      inDegree.set(edge.target, count + 1)
    })
    
    // Find nodes with no dependencies
    inDegree.forEach((count, nodeId) => {
      if (count === 0) queue.push(nodeId)
    })
    
    // Process queue
    while (queue.length > 0) {
      const nodeId = queue.shift()!
      const node = graphData.nodes.find(n => n.id === nodeId)!
      sorted.push(node)
      
      // Update dependencies
      graphData.edges
        .filter(edge => edge.source === nodeId)
        .forEach(edge => {
          const count = inDegree.get(edge.target)! - 1
          inDegree.set(edge.target, count)
          if (count === 0) queue.push(edge.target)
        })
    }
    
    return sorted
  }
}
```

## State Synchronization

### Bidirectional Sync

```typescript
class PipelineStateSynchronizer {
  private pipeline: Pipeline
  private graphData: GraphData
  private yamlText: string
  
  // Update from graph changes
  onGraphChange(change: GraphChange) {
    switch (change.type) {
      case 'nodeAdded':
        this.addStepToPipeline(change.node)
        break
      case 'nodeUpdated':
        this.updateStepInPipeline(change.node)
        break
      case 'nodeDeleted':
        this.deleteStepFromPipeline(change.nodeId)
        break
      case 'edgeAdded':
        this.updateStepDependencies(change.edge)
        break
    }
    
    this.regenerateYaml()
    this.validatePipeline()
  }
  
  // Update from YAML changes
  onYamlChange(newYaml: string) {
    try {
      const pipeline = this.parseYaml(newYaml)
      const validation = this.validatePipeline(pipeline)
      
      if (validation.valid) {
        this.pipeline = pipeline
        this.graphData = this.pipelineToGraph(pipeline)
        this.yamlText = newYaml
      }
      
      return validation
    } catch (error) {
      return { valid: false, errors: [error] }
    }
  }
  
  // Update from form changes
  onFormChange(stepName: string, changes: Partial<Step>) {
    const step = this.findStep(stepName)
    Object.assign(step, changes)
    
    this.updateGraphNode(stepName, step)
    this.regenerateYaml()
    this.validateStep(step)
  }
}
```

## Performance Optimizations

### Incremental Updates

```typescript
class IncrementalUpdater {
  // Track changes for minimal updates
  private changeSet = new Set<string>()
  
  markChanged(stepName: string) {
    this.changeSet.add(stepName)
    // Mark dependent steps
    const dependents = this.findDependents(stepName)
    dependents.forEach(dep => this.changeSet.add(dep))
  }
  
  applyChanges() {
    // Only update changed nodes
    this.changeSet.forEach(stepName => {
      this.updateNode(stepName)
      this.validateStep(stepName)
    })
    
    // Clear change set
    this.changeSet.clear()
  }
}
```

### Memoization

```typescript
// Memoize expensive calculations
const memoizedValidation = memoize(
  (step: Step) => validateStep(step),
  (step: Step) => `${step.name}-${JSON.stringify(step)}`
)

const memoizedTokenEstimate = memoize(
  (prompt: PromptElement[]) => estimateTokens(prompt),
  (prompt: PromptElement[]) => JSON.stringify(prompt)
)
```

This data model provides a comprehensive foundation for the Pipeline Visual Editor, supporting all current and planned features of the pipeline_ex system.