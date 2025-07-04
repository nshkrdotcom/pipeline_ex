# Pipeline Visual Editor v2: Phoenix + ElectricSQL

## Executive Summary

Pipeline Visual Editor v2 is a state-of-the-art, full-stack solution for managing AI pipeline schemas using Phoenix LiveView and ElectricSQL. This system provides real-time collaborative editing, offline-first capabilities, and seamless synchronization for the pipeline_ex YAML v2 format.

## Vision

Transform pipeline management from file-based editing to a sophisticated visual experience that:
- Enables real-time collaboration between AI engineers
- Works seamlessly offline with automatic sync
- Provides instant validation and feedback
- Scales from single-user to enterprise teams
- Maintains 100% compatibility with pipeline_ex YAML v2 format

## Core Principles

### 1. **Pipeline Schema First**
- Strict focus on managing pipeline YAML schemas
- No pipeline execution or runtime features
- Complete fidelity to YAML v2 specification
- Bidirectional YAML <-> Visual conversion

### 2. **Real-Time Collaboration**
- Multiple users editing the same pipeline simultaneously
- Live cursor tracking and presence indicators
- Conflict-free replicated data types (CRDTs) via ElectricSQL
- Instant updates across all connected clients

### 3. **Offline-First Architecture**
- Full functionality without internet connection
- Local-first data storage with SQLite
- Automatic sync when connection restored
- Zero data loss guarantee

### 4. **Developer Experience**
- Type-safe from database to frontend
- Hot-reload development workflow
- Comprehensive error messages
- Keyboard-first navigation

## Technology Stack

### Backend
- **Phoenix 1.7+**: Modern web framework with LiveView
- **PostgreSQL**: Primary database with ElectricSQL extensions
- **ElectricSQL**: Real-time sync engine
- **Ecto**: Database wrapper and migrations

### Frontend
- **Phoenix LiveView**: Server-rendered reactive UI
- **Alpine.js**: Lightweight interactivity
- **Tailwind CSS**: Utility-first styling
- **Phoenix Hooks**: JavaScript integration

### Infrastructure
- **SQLite**: Local offline storage
- **WebSockets**: Real-time communication
- **Docker**: Containerized deployment
- **Fly.io**: Recommended hosting platform

## Key Features

### 1. Visual Pipeline Builder
- Drag-and-drop step creation
- Visual connection management
- Nested pipeline support
- Step library with search

### 2. Schema Management
- Version control integration
- Pipeline templates
- Import/export capabilities
- Schema validation

### 3. Collaboration Tools
- Real-time presence
- Commenting system
- Change history
- User permissions

### 4. Developer Tools
- YAML preview/edit mode
- Schema documentation
- Validation feedback
- Performance metrics

## Scope Boundaries

### In Scope ✅
- Pipeline schema creation and editing
- YAML v2 format support (all 17+ step types)
- Visual workflow design
- Real-time collaboration
- Offline editing with sync
- Schema validation
- Template management
- Import/export functionality

### Out of Scope ❌
- Pipeline execution
- AI provider integration
- Runtime monitoring
- Cost tracking
- Performance analytics
- Log viewing
- Result visualization
- Deployment features

## Success Metrics

1. **Performance**
   - Page load time < 200ms
   - Sync latency < 100ms
   - Support 1000+ step pipelines
   - 60fps drag interactions

2. **Reliability**
   - 99.9% uptime
   - Zero data loss
   - Automatic conflict resolution
   - Graceful offline handling

3. **Usability**
   - Create pipeline in < 5 minutes
   - Zero training required for basic use
   - Keyboard shortcuts for power users
   - Mobile-responsive design

4. **Scalability**
   - Support 100+ concurrent editors
   - Handle 10,000+ pipelines
   - Sub-second search across all pipelines
   - Efficient storage (< 1KB per step)

## Project Structure

```
docs/visual_editor_v2/
├── 00_overview.md                    # This file
├── 01_technical_architecture.md      # System design
├── 02_data_model.md                  # Database schema
├── 03_phoenix_liveview_components.md # UI components
├── 04_real_time_collaboration.md    # Multiplayer features
├── 05_offline_sync.md                # ElectricSQL sync
├── 06_validation_engine.md           # Schema validation
├── 07_integration_api.md             # REST/GraphQL APIs
└── 08_deployment_guide.md            # Production setup
```

## Next Steps

1. Review technical architecture (01_technical_architecture.md)
2. Understand data model design (02_data_model.md)
3. Explore LiveView components (03_phoenix_liveview_components.md)
4. Set up development environment
5. Begin implementation phase

## Target Audience

- **Primary**: AI engineers creating pipelines
- **Secondary**: Team leads managing pipeline libraries
- **Tertiary**: System administrators deploying editor

## Implementation Timeline

- **Phase 1** (Weeks 1-2): Core data model and sync
- **Phase 2** (Weeks 3-4): Basic visual editor
- **Phase 3** (Weeks 5-6): Collaboration features
- **Phase 4** (Weeks 7-8): Polish and optimization

## References

- [Pipeline YAML v2 Specification](../20250704_yaml_format_v2/)
- [ElectricSQL Documentation](https://electric-sql.com/)
- [Phoenix LiveView Guide](https://hexdocs.pm/phoenix_live_view/)