# Pipeline Visual Editor - UI/UX Design

## Design Philosophy

The Pipeline Visual Editor follows a **progressive disclosure** philosophy, presenting simple interfaces for basic tasks while revealing advanced features as users need them. The design emphasizes clarity, efficiency, and visual feedback.

## Visual Design System

### Color Palette

```scss
// Primary Colors
$primary-blue: #2563eb;      // Primary actions, selections
$primary-blue-dark: #1e40af; // Hover states
$primary-blue-light: #dbeafe; // Backgrounds

// Step Type Colors
$claude-purple: #7c3aed;      // Claude steps
$gemini-orange: #f97316;      // Gemini steps
$system-gray: #6b7280;        // System steps
$nested-teal: #14b8a6;        // Nested pipelines
$loop-yellow: #f59e0b;        // Loop constructs
$condition-pink: #ec4899;     // Conditional steps

// Status Colors
$success-green: #10b981;
$error-red: #ef4444;
$warning-yellow: #f59e0b;
$info-blue: #3b82f6;

// Neutral Colors
$gray-50: #f9fafb;
$gray-100: #f3f4f6;
$gray-200: #e5e7eb;
$gray-300: #d1d5db;
$gray-400: #9ca3af;
$gray-500: #6b7280;
$gray-600: #4b5563;
$gray-700: #374151;
$gray-800: #1f2937;
$gray-900: #111827;
```

### Typography

```scss
// Font Stack
$font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
$font-mono: 'JetBrains Mono', 'Fira Code', Consolas, monospace;

// Type Scale
$text-xs: 0.75rem;    // 12px - Labels, captions
$text-sm: 0.875rem;   // 14px - Body small, form labels
$text-base: 1rem;     // 16px - Body text
$text-lg: 1.125rem;   // 18px - Headings
$text-xl: 1.25rem;    // 20px - Section titles
$text-2xl: 1.5rem;    // 24px - Page titles

// Font Weights
$font-normal: 400;
$font-medium: 500;
$font-semibold: 600;
$font-bold: 700;
```

### Spacing System

```scss
// Base unit: 4px
$space-1: 0.25rem;  // 4px
$space-2: 0.5rem;   // 8px
$space-3: 0.75rem;  // 12px
$space-4: 1rem;     // 16px
$space-5: 1.25rem;  // 20px
$space-6: 1.5rem;   // 24px
$space-8: 2rem;     // 32px
$space-10: 2.5rem;  // 40px
$space-12: 3rem;    // 48px
$space-16: 4rem;    // 64px
```

## Layout Structure

### Main Application Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Header Bar (56px)                                           │
│ ┌─────────┬────────────────────────────┬─────────────────┐ │
│ │ Logo    │ Pipeline Name / Status     │ User Menu       │ │
│ └─────────┴────────────────────────────┴─────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ Toolbar (48px)                                              │
│ ┌─────────────────────┬─────────────┬───────────────────┐ │
│ │ File Actions        │ View Toggle │ Tools & Actions   │ │
│ └─────────────────────┴─────────────┴───────────────────┘ │
├──────────────┬──────────────────────────┬──────────────────┤
│ Left Panel   │ Main Canvas              │ Right Panel      │
│ (280px)      │ (flexible)               │ (320px)          │
│              │                          │                  │
│ Step Library │ Graph View / Code Editor │ Properties       │
│              │                          │                  │
│              │                          │ Details Panel    │
│              │                          │                  │
└──────────────┴──────────────────────────┴──────────────────┘
```

### Responsive Breakpoints

- **Mobile**: < 640px (single column, drawer navigation)
- **Tablet**: 640px - 1024px (collapsible panels)
- **Desktop**: 1024px - 1280px (standard layout)
- **Wide**: > 1280px (expanded panels, dual view)

## Component Design

### Graph View Components

#### Step Node Design
```
┌─────────────────────────────────────┐
│ ┌───┐  Step Name          [•••]    │ <- Header (type color)
│ │ 🤖 │  ─────────────────           │
│ └───┘  Provider • 2.5k tokens      │ <- Metadata
├─────────────────────────────────────┤
│ Brief description of step purpose   │ <- Summary
│                                     │
│ ⚠️ 2 warnings                       │ <- Status
└─────────────────────────────────────┘
  ○ <- Input handle
  ○ <- Output handle
```

#### Node States
- **Default**: Light border, subtle shadow
- **Hover**: Highlighted border, elevated shadow
- **Selected**: Primary color border, glow effect
- **Error**: Red border, error icon
- **Executing**: Pulsing animation
- **Completed**: Green checkmark

#### Connection Types
- **Data Flow**: Solid line with arrow
- **Conditional**: Dashed line with condition label
- **Loop Back**: Curved line with loop icon
- **Parallel**: Multiple lines from single point

### Panel Components

#### Step Library Panel
```
┌─────────────────────────────────────┐
│ 🔍 Search steps...                  │
├─────────────────────────────────────┤
│ ▼ AI Providers                      │
│   📜 Claude                         │
│   📜 Claude Smart                   │
│   📜 Gemini                         │
│   📜 Parallel Claude                │
│                                     │
│ ▼ Control Flow                      │
│   🔄 For Loop                       │
│   🔁 While Loop                     │
│   🔀 Conditional                    │
│   📦 Nested Pipeline                │
│                                     │
│ ▼ Data Operations                   │
│   📁 File Operations                │
│   🔄 Data Transform                 │
│   💾 Set Variable                   │
├─────────────────────────────────────┤
│ ⭐ Recent Steps                     │
│   • Data Cleaning                   │
│   • API Analysis                    │
└─────────────────────────────────────┘
```

#### Properties Panel
```
┌─────────────────────────────────────┐
│ Claude Smart Step                   │ <- Step type
│ ─────────────────                   │
│ Name: analyze_code                  │
│                                     │
│ ▼ Configuration                     │
│ ┌─────────────────────────────────┐ │
│ │ Preset:     [Analysis    ▼]    │ │
│ │ Max Turns:  [3_______]          │ │
│ │ Tools:      ☑ Read  ☑ Search    │ │
│ │             ☐ Write ☐ Edit      │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ▼ Prompt Configuration              │
│ ┌─────────────────────────────────┐ │
│ │ [+ Add Prompt Element]          │ │
│ │ ┌───────────────────────────┐   │ │
│ │ │ Static Text              │   │ │
│ │ │ Analyze this code...     │   │ │
│ │ └───────────────────────────┘   │ │
│ │ ┌───────────────────────────┐   │ │
│ │ │ File: src/main.py        │   │ │
│ │ └───────────────────────────┘   │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ▼ Advanced Options                  │
│   Output Format: [JSON      ▼]     │
│   Output File: [analysis.json___]  │
└─────────────────────────────────────┘
```

### Form Components

#### Token Budget Control
```
┌─────────────────────────────────────┐
│ Token Budget                        │
│                                     │
│ Max Output Tokens                   │
│ [====|==============] 2048         │
│ 256              8192              │
│                                     │
│ Temperature                         │
│ [=======|===========] 0.7          │
│ 0.0 Focused      1.0 Creative      │
│                                     │
│ Estimated Cost: $0.05 - $0.08      │
└─────────────────────────────────────┘
```

#### Prompt Builder
```
┌─────────────────────────────────────┐
│ Prompt Elements                     │
│                                     │
│ 1. [Static ▼] │ [↑] [↓] [×]        │
│    ┌───────────────────────────┐   │
│    │ Enter your prompt text...  │   │
│    │                           │   │
│    └───────────────────────────┘   │
│                                     │
│ 2. [File   ▼] │ [↑] [↓] [×]        │
│    Path: [requirements.md_____]    │
│                                     │
│ 3. [Previous Response ▼] │ [×]     │
│    Step: [analysis_step    ▼]      │
│    Extract: [findings_______]       │
│                                     │
│ [+ Add Element]                     │
└─────────────────────────────────────┘
```

#### Condition Builder
```
┌─────────────────────────────────────┐
│ Condition Builder                   │
│                                     │
│ [AND ▼]                            │
│ ├─ score > 7                       │
│ ├─ [OR ▼]                          │
│ │  ├─ status == "passed"           │
│ │  └─ warnings.length < 3          │
│ └─ [NOT] errors.length > 0         │
│                                     │
│ [+ Add Condition]                   │
│                                     │
│ Preview: score > 7 AND (status ==  │
│ "passed" OR warnings.length < 3)   │
│ AND NOT errors.length > 0          │
└─────────────────────────────────────┘
```

## Interaction Patterns

### Drag and Drop
- **From Library**: Drag step type to canvas
- **Reorder**: Drag nodes to rearrange
- **Into Groups**: Drag into loop/parallel containers
- **File Upload**: Drag YAML files to import

### Keyboard Shortcuts
```
File Operations:
Ctrl/Cmd + S    Save pipeline
Ctrl/Cmd + O    Open pipeline
Ctrl/Cmd + N    New pipeline
Ctrl/Cmd + E    Export YAML

View Controls:
Ctrl/Cmd + 1    Graph view
Ctrl/Cmd + 2    Code view
Ctrl/Cmd + 3    Split view
Ctrl/Cmd + \    Toggle panels

Graph Editing:
Delete          Delete selected
Ctrl/Cmd + D    Duplicate selected
Ctrl/Cmd + A    Select all
Ctrl/Cmd + G    Group selected
Tab             Next node
Shift + Tab     Previous node

Zoom Controls:
Ctrl/Cmd + +    Zoom in
Ctrl/Cmd + -    Zoom out
Ctrl/Cmd + 0    Fit to screen
```

### Context Menus

#### Node Context Menu
```
┌─────────────────────┐
│ ✂️  Cut            │
│ 📋 Copy            │
│ 📋 Paste           │
│ ─────────────────  │
│ 🔄 Duplicate       │
│ 🗑️  Delete         │
│ ─────────────────  │
│ 🔧 Configure       │
│ 📝 Add Note        │
│ ─────────────────  │
│ ▶️  Run from Here  │
│ 🐛 Debug Step      │
└─────────────────────┘
```

## Visual Feedback

### Loading States
- **Skeleton screens** for initial loads
- **Progress indicators** for long operations
- **Subtle animations** for state transitions

### Validation Feedback
- **Real-time indicators** on invalid fields
- **Error summaries** in dedicated panel
- **Inline suggestions** for fixes
- **Success confirmations** for valid configs

### Execution Visualization
- **Flow animation** showing current step
- **Progress bars** for long-running steps
- **Log streaming** in bottom panel
- **Status badges** on completed steps

## Accessibility

### WCAG 2.1 AA Compliance
- **Color contrast** ratios > 4.5:1
- **Focus indicators** on all interactive elements
- **Keyboard navigation** for all features
- **Screen reader** announcements
- **Reduced motion** options

### Semantic HTML
- Proper heading hierarchy
- ARIA labels and descriptions
- Form field associations
- Status announcements

## Dark Mode

The editor supports both light and dark themes with automatic OS detection:

### Dark Theme Adjustments
- Inverted color scheme
- Adjusted contrast ratios
- Muted accent colors
- Preserved semantic meaning

## Mobile Considerations

### Responsive Design
- **Collapsible panels** on tablets
- **Bottom sheet** pattern on mobile
- **Touch-friendly** tap targets (44px min)
- **Gesture support** for pan/zoom

### Progressive Enhancement
- Core features work on all devices
- Advanced features on larger screens
- Graceful degradation
- Performance optimization

## User Onboarding

### First-Time User Experience
1. **Welcome Tour**: Interactive walkthrough
2. **Template Gallery**: Start from examples
3. **Tooltips**: Contextual help
4. **Sample Data**: Pre-loaded examples

### Help System
- **Inline documentation** on hover
- **Contextual help** panel
- **Video tutorials** for complex features
- **Keyboard shortcut** reference

## Error Handling

### User-Friendly Messages
```
❌ Connection Error
Unable to connect these steps because the output
type 'string' doesn't match the expected input
type 'object'.

💡 Suggestion: Add a data transformation step
between these nodes to convert the data format.

[Learn More] [Add Transform Step]
```

### Recovery Options
- **Undo/Redo** with history
- **Auto-save** with recovery
- **Version history** browsing
- **Conflict resolution** for team edits

This UI/UX design creates an intuitive, powerful, and accessible interface for pipeline creation and management.