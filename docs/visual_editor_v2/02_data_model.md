# Data Model: ElectricSQL Schema Design

## Overview

The data model is designed to support the full Pipeline YAML v2 specification while enabling real-time collaboration, version history, and efficient querying. We use PostgreSQL with JSONB for flexibility and ElectricSQL for synchronization.

## Core Design Principles

1. **Normalized where it matters**: Core entities are normalized for integrity
2. **JSONB for flexibility**: Step configurations stored as JSONB
3. **Immutable history**: All changes tracked for audit and undo
4. **Electric-ready**: All tables designed for conflict-free replication
5. **Performance optimized**: Indexes for common query patterns

## Entity Relationship Diagram

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Users       │     │   Organizations │     │     Teams       │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ id (UUID) PK    │     │ id (UUID) PK    │     │ id (UUID) PK    │
│ email           │     │ name            │     │ name            │
│ name            │     │ slug            │     │ org_id FK       │
│ avatar_url      │     │ settings        │     │ settings        │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                         │
         └───────────┬───────────┴─────────────────────────┘
                     │
         ┌───────────▼────────────┐
         │      Pipelines         │
         ├────────────────────────┤
         │ id (UUID) PK           │
         │ name                   │
         │ description            │
         │ team_id FK             │
         │ created_by FK          │
         │ yaml_version           │
         │ config (JSONB)         │
         │ tags (TEXT[])          │
         │ status                 │
         │ is_template            │
         │ parent_pipeline_id FK  │
         │ created_at             │
         │ updated_at             │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐     ┌─────────────────┐
         │        Steps           │     │   Connections   │
         ├────────────────────────┤     ├─────────────────┤
         │ id (UUID) PK           │     │ id (UUID) PK    │
         │ pipeline_id FK         ├─────┤ from_step_id FK │
         │ name                   │     │ to_step_id FK   │
         │ type                   │     │ from_output     │
         │ config (JSONB)         │     │ to_input        │
         │ position_x             │     │ path_data       │
         │ position_y             │     └─────────────────┘
         │ width                  │
         │ height                 │
         │ parent_step_id FK      │
         │ order_index            │
         │ created_at             │
         │ updated_at             │
         └────────────────────────┘
```

## Table Definitions

### Users Table

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  avatar_url TEXT,
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE users ENABLE ELECTRIC;
CREATE INDEX idx_users_email ON users(email);
```

### Organizations & Teams

```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE team_members (
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (team_id, user_id)
);

ALTER TABLE organizations ENABLE ELECTRIC;
ALTER TABLE teams ENABLE ELECTRIC;
ALTER TABLE team_members ENABLE ELECTRIC;
```

### Pipelines Table

```sql
CREATE TABLE pipelines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  created_by UUID REFERENCES users(id),
  
  -- Core fields
  name TEXT NOT NULL,
  description TEXT,
  yaml_version TEXT DEFAULT 'v2',
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'archived')),
  
  -- Configuration
  config JSONB DEFAULT '{}', -- stores workflow.config
  defaults JSONB DEFAULT '{}', -- stores workflow.defaults
  authentication JSONB DEFAULT '{}', -- stores workflow.authentication
  
  -- Metadata
  tags TEXT[] DEFAULT '{}',
  is_template BOOLEAN DEFAULT FALSE,
  parent_pipeline_id UUID REFERENCES pipelines(id),
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  published_at TIMESTAMPTZ,
  
  -- Search
  search_vector tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B')
  ) STORED
);

ALTER TABLE pipelines ENABLE ELECTRIC;

CREATE INDEX idx_pipelines_team ON pipelines(team_id);
CREATE INDEX idx_pipelines_status ON pipelines(status);
CREATE INDEX idx_pipelines_tags ON pipelines USING GIN(tags);
CREATE INDEX idx_pipelines_search ON pipelines USING GIN(search_vector);
CREATE INDEX idx_pipelines_updated ON pipelines(updated_at DESC);
```

### Steps Table

```sql
CREATE TABLE steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id UUID REFERENCES pipelines(id) ON DELETE CASCADE,
  
  -- Core fields matching YAML
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  enabled BOOLEAN DEFAULT TRUE,
  
  -- Configuration (stores all step config as JSONB)
  config JSONB NOT NULL DEFAULT '{}',
  
  -- Visual positioning
  position_x FLOAT DEFAULT 0,
  position_y FLOAT DEFAULT 0,
  width FLOAT DEFAULT 200,
  height FLOAT DEFAULT 100,
  
  -- Hierarchy (for nested steps like loops)
  parent_step_id UUID REFERENCES steps(id) ON DELETE CASCADE,
  order_index INTEGER NOT NULL DEFAULT 0,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE steps ENABLE ELECTRIC;

CREATE INDEX idx_steps_pipeline ON steps(pipeline_id);
CREATE INDEX idx_steps_type ON steps(type);
CREATE INDEX idx_steps_parent ON steps(parent_step_id);
CREATE INDEX idx_steps_order ON steps(pipeline_id, order_index);

-- Trigger to update pipeline.updated_at when steps change
CREATE OR REPLACE FUNCTION update_pipeline_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE pipelines SET updated_at = NOW() WHERE id = NEW.pipeline_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_pipeline_on_step_change
AFTER INSERT OR UPDATE OR DELETE ON steps
FOR EACH ROW EXECUTE FUNCTION update_pipeline_timestamp();
```

### Connections Table

```sql
CREATE TABLE connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id UUID REFERENCES pipelines(id) ON DELETE CASCADE,
  
  -- Connection endpoints
  from_step_id UUID REFERENCES steps(id) ON DELETE CASCADE,
  to_step_id UUID REFERENCES steps(id) ON DELETE CASCADE,
  
  -- Connection metadata
  from_output TEXT DEFAULT 'output',
  to_input TEXT DEFAULT 'input',
  
  -- Visual path data for rendering
  path_data JSONB, -- SVG path coordinates
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(from_step_id, to_step_id, from_output, to_input)
);

ALTER TABLE connections ENABLE ELECTRIC;

CREATE INDEX idx_connections_pipeline ON connections(pipeline_id);
CREATE INDEX idx_connections_from ON connections(from_step_id);
CREATE INDEX idx_connections_to ON connections(to_step_id);
```

### Version History

```sql
CREATE TABLE pipeline_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id UUID REFERENCES pipelines(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  
  -- Snapshot of pipeline state
  pipeline_snapshot JSONB NOT NULL,
  steps_snapshot JSONB NOT NULL,
  connections_snapshot JSONB NOT NULL,
  
  -- Change metadata
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  change_summary TEXT,
  
  UNIQUE(pipeline_id, version_number)
);

CREATE INDEX idx_versions_pipeline ON pipeline_versions(pipeline_id, version_number DESC);
```

### Templates & Components

```sql
CREATE TABLE pipeline_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
  
  -- Template metadata
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  icon TEXT,
  
  -- Template content
  pipeline_config JSONB NOT NULL,
  default_values JSONB DEFAULT '{}',
  
  -- Usage tracking
  usage_count INTEGER DEFAULT 0,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE pipeline_templates ENABLE ELECTRIC;
```

### Collaboration Features

```sql
-- Comments on pipelines and steps
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id UUID REFERENCES pipelines(id) ON DELETE CASCADE,
  step_id UUID REFERENCES steps(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id),
  
  content TEXT NOT NULL,
  resolved BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CHECK (pipeline_id IS NOT NULL OR step_id IS NOT NULL)
);

ALTER TABLE comments ENABLE ELECTRIC;

-- Real-time presence tracking
CREATE TABLE presence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id UUID REFERENCES pipelines(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  
  -- Cursor position
  cursor_x FLOAT,
  cursor_y FLOAT,
  
  -- Current selection
  selected_step_ids UUID[] DEFAULT '{}',
  
  -- Activity status
  status TEXT DEFAULT 'active',
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(pipeline_id, user_id)
);

-- Note: Presence doesn't need Electric sync as it's ephemeral
```

## JSONB Schema Examples

### Pipeline Config Structure

```json
{
  "workspace_dir": "./workspace",
  "output_dir": "./outputs",
  "checkpoint_dir": "./checkpoints",
  "max_tokens": 100000,
  "max_steps": 1000,
  "timeout": 3600,
  "environment": "production",
  "feature_flags": {
    "enable_parallel": true,
    "enable_checkpoints": true
  }
}
```

### Step Config Structure

```json
{
  // Common fields
  "description": "Analyze codebase",
  "condition": "previous_step.success == true",
  "timeout": 300,
  
  // Type-specific fields (example: claude step)
  "prompt": [
    {
      "type": "static",
      "content": "Analyze this code..."
    }
  ],
  "tools": ["read", "grep", "search"],
  "model": "claude-3-opus-20240229",
  "max_tokens": 4000,
  
  // Validation rules
  "validation": {
    "output_schema": {...},
    "required_outputs": ["analysis", "recommendations"]
  }
}
```

## Performance Optimizations

### Indexes

```sql
-- Full-text search
CREATE INDEX idx_pipelines_search ON pipelines USING GIN(search_vector);

-- Common queries
CREATE INDEX idx_steps_type_enabled ON steps(type, enabled) WHERE enabled = true;
CREATE INDEX idx_pipelines_team_status ON pipelines(team_id, status);

-- JSONB queries
CREATE INDEX idx_steps_config_type ON steps((config->>'step_type'));
CREATE INDEX idx_pipelines_config_env ON pipelines((config->>'environment'));
```

### Materialized Views

```sql
-- Pipeline statistics
CREATE MATERIALIZED VIEW pipeline_stats AS
SELECT 
  p.id,
  p.team_id,
  COUNT(DISTINCT s.id) as step_count,
  COUNT(DISTINCT s.type) as step_type_count,
  MAX(s.updated_at) as last_modified
FROM pipelines p
LEFT JOIN steps s ON s.pipeline_id = p.id
GROUP BY p.id, p.team_id;

CREATE INDEX idx_pipeline_stats_team ON pipeline_stats(team_id);
```

## Data Migration from v1

```sql
-- Migration function for v1 YAML data
CREATE OR REPLACE FUNCTION migrate_v1_pipeline(yaml_content TEXT)
RETURNS UUID AS $$
DECLARE
  pipeline_id UUID;
  v1_data JSONB;
BEGIN
  -- Parse v1 YAML to JSONB
  v1_data := parse_yaml(yaml_content);
  
  -- Create pipeline
  INSERT INTO pipelines (name, description, yaml_version, config)
  VALUES (
    v1_data->>'name',
    v1_data->>'description',
    'v1',
    v1_data->'config'
  )
  RETURNING id INTO pipeline_id;
  
  -- Migrate steps
  -- ... step migration logic ...
  
  RETURN pipeline_id;
END;
$$ LANGUAGE plpgsql;
```

## Electric Sync Configuration

```typescript
// Electric client configuration
const electric = await electrify(
  conn,
  schema,
  {
    auth: {
      token: async () => getUserToken()
    }
  }
);

// Sync rules
await electric.sync.pipelines.sync({
  where: {
    team_id: currentTeamId
  },
  include: {
    steps: true,
    connections: true,
    comments: {
      include: {
        user: true
      }
    }
  }
});
```

## Security Considerations

### Row-Level Security

```sql
-- Enable RLS
ALTER TABLE pipelines ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see pipelines in their teams
CREATE POLICY pipelines_select ON pipelines
  FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM team_members 
      WHERE user_id = current_user_id()
    )
  );

-- Policy: Only team members can modify
CREATE POLICY pipelines_modify ON pipelines
  FOR ALL
  USING (
    team_id IN (
      SELECT team_id FROM team_members 
      WHERE user_id = current_user_id() 
      AND role IN ('owner', 'admin', 'member')
    )
  );
```

### Data Validation

```sql
-- Ensure step names are unique within pipeline
ALTER TABLE steps ADD CONSTRAINT unique_step_name 
  UNIQUE (pipeline_id, name);

-- Validate step types
ALTER TABLE steps ADD CONSTRAINT valid_step_type
  CHECK (type IN (
    'claude', 'gemini', 'claude_smart', 'claude_session',
    'claude_extract', 'claude_batch', 'claude_robust',
    'parallel_claude', 'gemini_instructor', 'pipeline',
    'for_loop', 'while_loop', 'switch', 'data_transform',
    'file_ops', 'codebase_query', 'set_variable', 'checkpoint'
  ));
```