# Pipeline Flow Diagrams

This document provides visual representations of the Pipeline.ex architecture and execution flow using Mermaid diagrams.

## Pipeline Execution Flow

The following diagram shows the overall execution flow of a pipeline:

```mermaid
graph TD
    A[Load YAML Config] --> B[Parse & Validate]
    B --> C{Valid Config?}
    C -->|No| D[Return Error]
    C -->|Yes| E[Initialize Context]
    E --> F[Execute Steps]
    F --> G{Step Type}
    G -->|Claude| H[Claude Provider]
    G -->|Gemini| I[Gemini Provider]
    G -->|Loop| J[Loop Executor]
    G -->|Nested| K[Nested Pipeline]
    H --> L[Process Response]
    I --> L
    J --> L
    K --> L
    L --> M{More Steps?}
    M -->|Yes| F
    M -->|No| N[Return Results]
```

## Genesis Pipeline Architecture

The Genesis/Meta pipeline system enables self-improving pipelines:

```mermaid
graph LR
    A[User Request] --> B[Genesis Pipeline]
    B --> C[Analyze Requirements]
    C --> D[Generate Pipeline DNA]
    D --> E[Create Pipeline Config]
    E --> F[Validate & Test]
    F --> G{Success?}
    G -->|No| H[Mutate DNA]
    H --> D
    G -->|Yes| I[Save Pipeline]
    I --> J[Execute Pipeline]
    J --> K[Evaluate Fitness]
    K --> L[Update DNA Pool]
```

## Provider Architecture

```mermaid
classDiagram
    class AIProvider {
        <<interface>>
        +execute(prompt, options)
        +health_check()
    }
    
    class ClaudeProvider {
        -sdk_client
        +execute(prompt, options)
        +health_check()
        +create_session()
    }
    
    class GeminiProvider {
        -api_key
        +execute(prompt, options)
        +health_check()
        +function_calling()
    }
    
    class MockProvider {
        -responses
        +execute(prompt, options)
        +health_check()
        +set_response()
    }
    
    AIProvider <|-- ClaudeProvider
    AIProvider <|-- GeminiProvider
    AIProvider <|-- MockProvider
```

## Step Processing Flow

```mermaid
sequenceDiagram
    participant E as Executor
    participant S as Step
    participant P as Provider
    participant C as Context
    
    E->>S: execute(step_config, context)
    S->>C: get_variables()
    S->>S: build_prompt()
    S->>P: execute(prompt, options)
    P-->>S: response
    S->>C: update_results()
    S-->>E: step_result
```

## Control Flow Features

```mermaid
graph TD
    A[Step Execution] --> B{Condition?}
    B -->|True| C[Execute Step]
    B -->|False| D[Skip Step]
    C --> E{Loop?}
    E -->|Yes| F[Loop Iterator]
    F --> G{More Items?}
    G -->|Yes| C
    G -->|No| H[Continue]
    E -->|No| H
    D --> H
    H --> I[Next Step]
```

## Error Handling Flow

```mermaid
stateDiagram-v2
    [*] --> Executing
    Executing --> Success: No Errors
    Executing --> Error: Exception
    Error --> Retrying: Retry Config
    Error --> Failed: No Retry
    Retrying --> Executing: Backoff
    Retrying --> Failed: Max Retries
    Success --> [*]
    Failed --> [*]
```

## Data Transformation Pipeline

```mermaid
graph LR
    A[Input Data] --> B[Validation]
    B --> C{Valid?}
    C -->|No| D[Error]
    C -->|Yes| E[Transform]
    E --> F[Filter]
    F --> G[Aggregate]
    G --> H[Join]
    H --> I[Output Data]
```

These diagrams provide a visual understanding of the Pipeline.ex system architecture and execution flows.