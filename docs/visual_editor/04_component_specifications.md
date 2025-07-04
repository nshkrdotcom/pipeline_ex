# Pipeline Visual Editor - Component Specifications

## Overview

This document provides detailed specifications for all React components in the Pipeline Visual Editor, including props, state management, and implementation guidelines.

## Component Hierarchy

```
App
├── Layout
│   ├── Header
│   ├── Toolbar
│   └── StatusBar
├── Editor
│   ├── GraphEditor
│   │   ├── GraphCanvas
│   │   ├── StepNode
│   │   ├── ParallelGroupNode
│   │   ├── LoopNode
│   │   ├── ConditionalNode
│   │   └── ConnectionLine
│   ├── CodeEditor
│   │   ├── MonacoWrapper
│   │   └── ValidationPanel
│   └── SplitView
├── Panels
│   ├── StepLibrary
│   │   ├── CategoryList
│   │   └── StepCard
│   ├── PropertiesPanel
│   │   ├── StepConfigForm
│   │   ├── PromptBuilder
│   │   ├── ConditionBuilder
│   │   └── AdvancedOptions
│   └── ValidationPanel
└── Dialogs
    ├── ImportDialog
    ├── ExportDialog
    ├── TemplateGallery
    └── SettingsDialog
```

## Core Components

### App Component

```typescript
interface AppProps {
  initialPipeline?: Pipeline
  onSave?: (pipeline: Pipeline) => void
  readOnly?: boolean
  theme?: 'light' | 'dark' | 'system'
}

export const App: React.FC<AppProps> = ({
  initialPipeline,
  onSave,
  readOnly = false,
  theme = 'system'
}) => {
  const { pipeline, actions } = usePipelineStore()
  const { viewMode } = useUIStore()
  
  return (
    <ThemeProvider theme={theme}>
      <Layout>
        <Header />
        <Toolbar />
        <div className="editor-container">
          <StepLibrary />
          <Editor viewMode={viewMode} readOnly={readOnly} />
          <PropertiesPanel />
        </div>
        <StatusBar />
      </Layout>
    </ThemeProvider>
  )
}
```

### Layout Components

#### Header

```typescript
interface HeaderProps {
  className?: string
}

export const Header: React.FC<HeaderProps> = ({ className }) => {
  const { pipeline, isDirty } = usePipelineStore()
  const { user } = useAuthStore()
  
  return (
    <header className={cn("header", className)}>
      <div className="header-left">
        <Logo />
        <PipelineName 
          name={pipeline.workflow.name}
          isDirty={isDirty}
        />
      </div>
      
      <div className="header-center">
        <PipelineStatus />
      </div>
      
      <div className="header-right">
        <NotificationBell />
        <UserMenu user={user} />
      </div>
    </header>
  )
}
```

#### Toolbar

```typescript
interface ToolbarProps {
  className?: string
}

export const Toolbar: React.FC<ToolbarProps> = ({ className }) => {
  const { actions } = usePipelineStore()
  const { viewMode, setViewMode } = useUIStore()
  
  return (
    <div className={cn("toolbar", className)}>
      <ToolbarSection>
        <ToolbarButton
          icon={<NewIcon />}
          label="New"
          onClick={actions.newPipeline}
          shortcut="Ctrl+N"
        />
        <ToolbarButton
          icon={<OpenIcon />}
          label="Open"
          onClick={actions.openPipeline}
          shortcut="Ctrl+O"
        />
        <ToolbarButton
          icon={<SaveIcon />}
          label="Save"
          onClick={actions.savePipeline}
          shortcut="Ctrl+S"
        />
      </ToolbarSection>
      
      <ToolbarSeparator />
      
      <ToolbarSection>
        <ViewToggle
          value={viewMode}
          onChange={setViewMode}
          options={[
            { value: 'graph', icon: <GraphIcon />, label: 'Graph View' },
            { value: 'code', icon: <CodeIcon />, label: 'Code View' },
            { value: 'split', icon: <SplitIcon />, label: 'Split View' }
          ]}
        />
      </ToolbarSection>
      
      <ToolbarSection className="ml-auto">
        <ToolbarButton
          icon={<ValidateIcon />}
          label="Validate"
          onClick={actions.validatePipeline}
        />
        <ToolbarButton
          icon={<RunIcon />}
          label="Run"
          onClick={actions.runPipeline}
          variant="primary"
        />
      </ToolbarSection>
    </div>
  )
}
```

### Graph Editor Components

#### GraphCanvas

```typescript
interface GraphCanvasProps {
  readOnly?: boolean
  onNodeClick?: (node: Node) => void
  onNodeDoubleClick?: (node: Node) => void
  onPaneClick?: () => void
}

export const GraphCanvas: React.FC<GraphCanvasProps> = ({
  readOnly,
  onNodeClick,
  onNodeDoubleClick,
  onPaneClick
}) => {
  const { nodes, edges, actions } = usePipelineStore()
  const reactFlowInstance = useRef<ReactFlowInstance>()
  
  const nodeTypes = useMemo(() => ({
    step: StepNode,
    parallelGroup: ParallelGroupNode,
    loop: LoopNode,
    conditional: ConditionalNode,
    nestedPipeline: NestedPipelineNode
  }), [])
  
  const edgeTypes = useMemo(() => ({
    dataFlow: DataFlowEdge,
    conditional: ConditionalEdge,
    loopBack: LoopBackEdge
  }), [])
  
  const onConnect = useCallback((connection: Connection) => {
    if (readOnly) return
    actions.connectNodes(connection)
  }, [actions, readOnly])
  
  const onNodeDragStop = useCallback((event: MouseEvent, node: Node) => {
    if (readOnly) return
    actions.updateNodePosition(node.id, node.position)
  }, [actions, readOnly])
  
  return (
    <ReactFlow
      nodes={nodes}
      edges={edges}
      nodeTypes={nodeTypes}
      edgeTypes={edgeTypes}
      onConnect={onConnect}
      onNodeClick={onNodeClick}
      onNodeDoubleClick={onNodeDoubleClick}
      onNodeDragStop={onNodeDragStop}
      onPaneClick={onPaneClick}
      onInit={(instance) => { reactFlowInstance.current = instance }}
      fitView
      attributionPosition="bottom-right"
    >
      <Background variant="dots" gap={12} size={1} />
      <Controls />
      <MiniMap 
        nodeColor={getNodeColor}
        nodeStrokeWidth={3}
        zoomable
        pannable
      />
    </ReactFlow>
  )
}
```

#### StepNode

```typescript
interface StepNodeProps {
  data: StepNodeData
  selected: boolean
  dragging: boolean
}

export const StepNode: React.FC<NodeProps<StepNodeData>> = memo(({
  data,
  selected,
  dragging
}) => {
  const { step, validation, executionStatus } = data
  const { updateNode } = usePipelineStore()
  const [showDetails, setShowDetails] = useState(false)
  
  const nodeColor = getStepTypeColor(step.type)
  const hasErrors = validation.errors.length > 0
  const hasWarnings = validation.warnings.length > 0
  
  return (
    <div
      className={cn(
        "step-node",
        `step-node--${step.type}`,
        {
          "step-node--selected": selected,
          "step-node--dragging": dragging,
          "step-node--error": hasErrors,
          "step-node--warning": hasWarnings && !hasErrors,
          "step-node--executing": executionStatus === 'running'
        }
      )}
      style={{
        '--node-color': nodeColor
      }}
    >
      <Handle
        type="target"
        position={Position.Top}
        className="step-node__handle step-node__handle--target"
        isConnectable={!dragging}
      />
      
      <div className="step-node__header">
        <StepIcon type={step.type} className="step-node__icon" />
        <span className="step-node__name">{step.name}</span>
        <div className="step-node__actions">
          {executionStatus && (
            <ExecutionStatusIcon status={executionStatus} />
          )}
          <button
            className="step-node__menu-btn"
            onClick={(e) => {
              e.stopPropagation()
              setShowDetails(!showDetails)
            }}
          >
            <MoreIcon />
          </button>
        </div>
      </div>
      
      <div className="step-node__body">
        <StepSummary step={step} />
        
        {(hasErrors || hasWarnings) && (
          <div className="step-node__validation">
            {hasErrors && (
              <div className="step-node__errors">
                <ErrorIcon />
                <span>{validation.errors.length} errors</span>
              </div>
            )}
            {hasWarnings && !hasErrors && (
              <div className="step-node__warnings">
                <WarningIcon />
                <span>{validation.warnings.length} warnings</span>
              </div>
            )}
          </div>
        )}
      </div>
      
      <Handle
        type="source"
        position={Position.Bottom}
        className="step-node__handle step-node__handle--source"
        isConnectable={!dragging}
      />
      
      {showDetails && (
        <StepNodePopover
          step={step}
          onClose={() => setShowDetails(false)}
        />
      )}
    </div>
  )
})
```

### Panel Components

#### StepLibrary

```typescript
interface StepLibraryProps {
  className?: string
}

export const StepLibrary: React.FC<StepLibraryProps> = ({ className }) => {
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null)
  const { recentSteps } = useUIStore()
  
  const categories = useMemo(() => getStepCategories(), [])
  const filteredSteps = useMemo(() => 
    filterSteps(categories, searchTerm, selectedCategory),
    [categories, searchTerm, selectedCategory]
  )
  
  const onDragStart = (event: DragEvent, stepType: StepType) => {
    event.dataTransfer.setData('application/reactflow', stepType)
    event.dataTransfer.effectAllowed = 'move'
  }
  
  return (
    <Panel className={cn("step-library", className)} title="Step Library">
      <SearchInput
        value={searchTerm}
        onChange={setSearchTerm}
        placeholder="Search steps..."
        className="step-library__search"
      />
      
      <div className="step-library__content">
        {filteredSteps.map(category => (
          <CategorySection
            key={category.id}
            category={category}
            expanded={selectedCategory === category.id}
            onToggle={() => setSelectedCategory(
              selectedCategory === category.id ? null : category.id
            )}
          >
            {category.steps.map(step => (
              <StepCard
                key={step.type}
                step={step}
                draggable
                onDragStart={(e) => onDragStart(e, step.type)}
              />
            ))}
          </CategorySection>
        ))}
        
        {recentSteps.length > 0 && (
          <CategorySection title="Recent" defaultExpanded>
            {recentSteps.map(step => (
              <StepCard
                key={step.type}
                step={step}
                draggable
                onDragStart={(e) => onDragStart(e, step.type)}
              />
            ))}
          </CategorySection>
        )}
      </div>
    </Panel>
  )
}
```

#### PropertiesPanel

```typescript
interface PropertiesPanelProps {
  className?: string
}

export const PropertiesPanel: React.FC<PropertiesPanelProps> = ({ 
  className 
}) => {
  const { selectedNodeId, nodes, actions } = usePipelineStore()
  const selectedNode = nodes.find(n => n.id === selectedNodeId)
  
  if (!selectedNode) {
    return (
      <Panel className={cn("properties-panel", className)} title="Properties">
        <EmptyState
          icon={<SelectIcon />}
          message="Select a step to view its properties"
        />
      </Panel>
    )
  }
  
  const step = selectedNode.data.step
  
  return (
    <Panel 
      className={cn("properties-panel", className)} 
      title={`${getStepTypeLabel(step.type)} Properties`}
    >
      <StepConfigForm
        step={step}
        onChange={(updates) => actions.updateStep(step.name, updates)}
      />
    </Panel>
  )
}
```

### Form Components

#### StepConfigForm

```typescript
interface StepConfigFormProps {
  step: Step
  onChange: (updates: Partial<Step>) => void
}

export const StepConfigForm: React.FC<StepConfigFormProps> = ({
  step,
  onChange
}) => {
  const schema = getStepSchema(step.type)
  const sections = getFormSections(step.type)
  
  return (
    <Formik
      initialValues={step}
      validationSchema={schema}
      onSubmit={onChange}
      validateOnChange
      enableReinitialize
    >
      {({ values, errors, touched, setFieldValue }) => (
        <Form className="step-config-form">
          <FormSection title="Basic Information">
            <TextField
              name="name"
              label="Step Name"
              required
              error={errors.name}
              touched={touched.name}
            />
            
            {step.type === 'gemini' && (
              <SelectField
                name="model"
                label="Model"
                options={GEMINI_MODELS}
                error={errors.model}
                touched={touched.model}
              />
            )}
            
            <TextField
              name="output_to_file"
              label="Output File"
              placeholder="e.g., analysis.json"
              error={errors.output_to_file}
              touched={touched.output_to_file}
            />
          </FormSection>
          
          {hasPromptConfiguration(step.type) && (
            <FormSection title="Prompt Configuration">
              <PromptBuilder
                prompts={values.prompt || []}
                onChange={(prompts) => setFieldValue('prompt', prompts)}
                stepNames={getAvailableStepNames(step.name)}
              />
            </FormSection>
          )}
          
          {step.type === 'gemini' && (
            <FormSection title="Token Budget">
              <TokenBudgetField
                value={values.token_budget}
                onChange={(budget) => setFieldValue('token_budget', budget)}
              />
            </FormSection>
          )}
          
          {isClaudeStep(step.type) && (
            <FormSection title="Claude Options">
              <ClaudeOptionsForm
                options={values.claude_options}
                onChange={(options) => setFieldValue('claude_options', options)}
                stepType={step.type}
              />
            </FormSection>
          )}
          
          <FormSection title="Execution Control" collapsible defaultCollapsed>
            <ConditionField
              value={values.condition}
              onChange={(condition) => setFieldValue('condition', condition)}
              stepNames={getAvailableStepNames(step.name)}
            />
          </FormSection>
          
          <FormActions>
            <Button type="submit" variant="primary">
              Apply Changes
            </Button>
          </FormActions>
        </Form>
      )}
    </Formik>
  )
}
```

#### PromptBuilder

```typescript
interface PromptBuilderProps {
  prompts: PromptElement[]
  onChange: (prompts: PromptElement[]) => void
  stepNames: string[]
}

export const PromptBuilder: React.FC<PromptBuilderProps> = ({
  prompts,
  onChange,
  stepNames
}) => {
  const addPrompt = (type: PromptElement['type']) => {
    const newPrompt = createDefaultPrompt(type)
    onChange([...prompts, newPrompt])
  }
  
  const updatePrompt = (index: number, updates: Partial<PromptElement>) => {
    const updated = [...prompts]
    updated[index] = { ...updated[index], ...updates }
    onChange(updated)
  }
  
  const deletePrompt = (index: number) => {
    onChange(prompts.filter((_, i) => i !== index))
  }
  
  const movePrompt = (index: number, direction: 'up' | 'down') => {
    const newIndex = direction === 'up' ? index - 1 : index + 1
    if (newIndex < 0 || newIndex >= prompts.length) return
    
    const updated = [...prompts]
    const temp = updated[index]
    updated[index] = updated[newIndex]
    updated[newIndex] = temp
    onChange(updated)
  }
  
  return (
    <div className="prompt-builder">
      <div className="prompt-builder__list">
        {prompts.map((prompt, index) => (
          <PromptElement
            key={index}
            prompt={prompt}
            index={index}
            totalCount={prompts.length}
            stepNames={stepNames}
            onChange={(updates) => updatePrompt(index, updates)}
            onDelete={() => deletePrompt(index)}
            onMove={(direction) => movePrompt(index, direction)}
          />
        ))}
      </div>
      
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline" className="w-full">
            <PlusIcon /> Add Prompt Element
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuItem onClick={() => addPrompt('static')}>
            <TextIcon /> Static Text
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => addPrompt('file')}>
            <FileIcon /> File Content
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => addPrompt('previous_response')}>
            <LinkIcon /> Previous Response
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => addPrompt('session_context')}>
            <HistoryIcon /> Session Context
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => addPrompt('claude_continue')}>
            <ContinueIcon /> Claude Continue
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  )
}
```

#### ConditionBuilder

```typescript
interface ConditionBuilderProps {
  condition?: string | ConditionExpression
  onChange: (condition: string | ConditionExpression | undefined) => void
  stepNames: string[]
}

export const ConditionBuilder: React.FC<ConditionBuilderProps> = ({
  condition,
  onChange,
  stepNames
}) => {
  const [mode, setMode] = useState<'simple' | 'advanced'>(
    typeof condition === 'string' ? 'simple' : 'advanced'
  )
  
  if (mode === 'simple') {
    return (
      <div className="condition-builder">
        <div className="condition-builder__header">
          <Label>Condition</Label>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setMode('advanced')}
          >
            Advanced Mode
          </Button>
        </div>
        
        <TextField
          value={typeof condition === 'string' ? condition : ''}
          onChange={(value) => onChange(value || undefined)}
          placeholder="e.g., analysis.score > 7"
          monospace
        />
        
        <div className="condition-builder__hints">
          <span>Available variables:</span>
          {stepNames.map(name => (
            <code key={name} className="hint-chip">
              {name}
            </code>
          ))}
        </div>
      </div>
    )
  }
  
  return (
    <div className="condition-builder condition-builder--advanced">
      <div className="condition-builder__header">
        <Label>Advanced Condition</Label>
        <Button
          variant="ghost"
          size="sm"
          onClick={() => setMode('simple')}
        >
          Simple Mode
        </Button>
      </div>
      
      <ConditionExpressionBuilder
        expression={typeof condition === 'object' ? condition : undefined}
        onChange={onChange}
        stepNames={stepNames}
      />
    </div>
  )
}
```

### Utility Components

#### EmptyState

```typescript
interface EmptyStateProps {
  icon?: React.ReactNode
  title?: string
  message: string
  action?: {
    label: string
    onClick: () => void
  }
}

export const EmptyState: React.FC<EmptyStateProps> = ({
  icon,
  title,
  message,
  action
}) => {
  return (
    <div className="empty-state">
      {icon && <div className="empty-state__icon">{icon}</div>}
      {title && <h3 className="empty-state__title">{title}</h3>}
      <p className="empty-state__message">{message}</p>
      {action && (
        <Button
          variant="outline"
          onClick={action.onClick}
          className="empty-state__action"
        >
          {action.label}
        </Button>
      )}
    </div>
  )
}
```

#### ValidationIndicator

```typescript
interface ValidationIndicatorProps {
  validation: ValidationResult
  inline?: boolean
}

export const ValidationIndicator: React.FC<ValidationIndicatorProps> = ({
  validation,
  inline = false
}) => {
  const { errors, warnings } = validation
  const hasIssues = errors.length > 0 || warnings.length > 0
  
  if (!hasIssues) return null
  
  if (inline) {
    return (
      <div className="validation-indicator validation-indicator--inline">
        {errors.length > 0 && (
          <span className="validation-indicator__error">
            <ErrorIcon /> {errors.length}
          </span>
        )}
        {warnings.length > 0 && (
          <span className="validation-indicator__warning">
            <WarningIcon /> {warnings.length}
          </span>
        )}
      </div>
    )
  }
  
  return (
    <Popover>
      <PopoverTrigger asChild>
        <button className="validation-indicator__trigger">
          {errors.length > 0 ? (
            <ErrorIcon className="text-red-500" />
          ) : (
            <WarningIcon className="text-yellow-500" />
          )}
        </button>
      </PopoverTrigger>
      <PopoverContent className="validation-popover">
        {errors.length > 0 && (
          <div className="validation-popover__section">
            <h4>Errors</h4>
            {errors.map((error, i) => (
              <ValidationMessage key={i} issue={error} type="error" />
            ))}
          </div>
        )}
        {warnings.length > 0 && (
          <div className="validation-popover__section">
            <h4>Warnings</h4>
            {warnings.map((warning, i) => (
              <ValidationMessage key={i} issue={warning} type="warning" />
            ))}
          </div>
        )}
      </PopoverContent>
    </Popover>
  )
}
```

## Custom Hooks

### usePipelineStore

```typescript
interface PipelineStore {
  // State
  pipeline: Pipeline
  nodes: Node[]
  edges: Edge[]
  selectedNodeId: string | null
  validationResult: ValidationResult
  isDirty: boolean
  
  // Actions
  actions: {
    loadPipeline: (yaml: string) => void
    savePipeline: () => string
    newPipeline: () => void
    
    addStep: (type: StepType, position: XYPosition) => void
    updateStep: (name: string, updates: Partial<Step>) => void
    deleteStep: (name: string) => void
    
    connectNodes: (connection: Connection) => void
    deleteEdge: (id: string) => void
    
    selectNode: (id: string | null) => void
    updateNodePosition: (id: string, position: XYPosition) => void
    
    validatePipeline: () => ValidationResult
    runPipeline: () => void
  }
}

export const usePipelineStore = create<PipelineStore>((set, get) => ({
  // Initial state
  pipeline: createEmptyPipeline(),
  nodes: [],
  edges: [],
  selectedNodeId: null,
  validationResult: { valid: true, errors: [], warnings: [] },
  isDirty: false,
  
  actions: {
    // Implementation details...
  }
}))
```

### useValidation

```typescript
export const useValidation = (step: Step) => {
  const { pipeline } = usePipelineStore()
  
  return useMemo(() => {
    const validator = new PipelineValidator()
    return validator.validateStep(step, pipeline)
  }, [step, pipeline])
}
```

### useGraphLayout

```typescript
export const useGraphLayout = (nodes: Node[], edges: Edge[]) => {
  const [layoutedNodes, setLayoutedNodes] = useState(nodes)
  
  useEffect(() => {
    const layoutEngine = new DagreLayout({
      rankdir: 'TB',
      nodesep: 80,
      ranksep: 120
    })
    
    const positioned = layoutEngine.layout(nodes, edges)
    setLayoutedNodes(positioned)
  }, [nodes, edges])
  
  return layoutedNodes
}
```

## Component Guidelines

### Performance
- Use `React.memo` for expensive components
- Implement virtualization for large lists
- Debounce form inputs and validation
- Use CSS containment for complex nodes

### Accessibility
- All interactive elements must be keyboard accessible
- Provide ARIA labels for icon-only buttons
- Announce state changes to screen readers
- Maintain proper focus management

### Testing
- Unit test all business logic
- Integration test form submissions
- E2E test critical user flows
- Visual regression test UI components

This component specification provides a comprehensive blueprint for implementing the Pipeline Visual Editor's user interface.