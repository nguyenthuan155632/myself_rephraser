# Modern UI Features & Visual Tour

## 🎨 Design Highlights

### Top Toolbar (56px)
```
┌─────────────────────────────────────────────────────────────────┐
│ 📁 💾 │ ↶ ↷ │ ➕📊 ➕📋 🗑️ 🔀 │ ☑️ 🧹 🌐 │        [2 cells] [●Unsaved] │
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- Icon-only buttons with hover tooltips
- Grouped by function with subtle dividers
- Dynamic cell selection badge (colored, pill-shaped)
- Unsaved indicator with orange dot
- Disabled state for unavailable actions

### Search Bar
```
┌─────────────────────────────────────────────────────────────────┐
│  🔍 Search in table...                              🔧 ▼        │
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- Large rounded input (12px border radius)
- Soft gray background
- Expandable advanced options
- Clear active filters indicator

### Advanced Search Panel (Expandable)
```
┌─────────────────────────────────────────────────────────────────┐
│ Advanced Search Options                                          │
│                                                                   │
│ [Case sensitive] [Use regex]                                     │
│                                                                   │
│ Row Range:  [From Row: 1    ] [To Row: 1000    ]               │
│                                                                   │
│ Search in columns:                                               │
│ [All] [Name] [Email] [Phone] [Address]                          │
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- Clean filter chips with selected state
- Row range inputs side-by-side
- Column selector with "All" shortcut
- Soft border and shadow

### Table Container
```
┌─────────────────────────────────────────────────────────────────┐
│ ☑️ │  #  │   Name    │   Email   │   Phone   │   Address      │
├───┼─────┼───────────┼───────────┼───────────┼────────────────┤
│ ☑ │  1  │ John Doe  │ john@...  │ 555-0100  │ 123 Main St   │  ← White
│ □ │  2  │ Jane Smith│ jane@...  │ 555-0101  │ 456 Oak Ave   │  ← Light gray
│ □ │  3  │ Bob Jones │ bob@...   │ 555-0102  │ 789 Pine Rd   │  ← White
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- Rounded corners (12px) with subtle shadow
- Alternating row colors (white / very light gray)
- Clean 1px borders in soft gray
- Drag handle indicator (⋮⋮) on line numbers
- Checkbox column (optional, toggleable)
- Header with light background

### Status Bar (32px)
```
┌─────────────────────────────────────────────────────────────────┐
│ 📄 data.csv │ 📊 100 rows │ 📋 5 columns │ UTF-8   ⋯ Tips... │
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- File name with icon
- Row/column counts
- Selected rows indicator (when applicable)
- Encoding display
- Keyboard hints in italic (right side)
- Separated by subtle dividers

### Empty State
```
                    ┌─────────────┐
                    │     📊      │  ← Circular icon badge
                    │   (indigo)  │
                    └─────────────┘
                    
                No CSV file loaded
        
    Click the button below or drag & drop
              a CSV file to get started
              
            ┌──────────────────┐
            │  📤 Open CSV File │  ← Primary button
            └──────────────────┘
```

**Features:**
- Centered content with max-width
- Large circular icon badge with background
- Clear heading and description
- Prominent call-to-action button

### Drag & Drop Overlay
```
┌─────────────────────────────────────────────────────────────────┐
│                         [BLUR EFFECT]                            │
│                                                                   │
│                    ╔═══════════════╗                             │
│                    ║               ║                              │
│                    ║   ┌─────┐     ║                              │
│                    ║   │ 📤  │     ║  ← Large upload icon         │
│                    ║   └─────┘     ║                              │
│                    ║               ║                              │
│                    ║ Drop CSV file ║  ← Large heading             │
│                    ║     here      ║                              │
│                    ║               ║                              │
│                    ║ Release to    ║  ← Instruction               │
│                    ║ load the file ║                              │
│                    ╚═══════════════╝                             │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

**Features:**
- Backdrop blur (2px sigma)
- Light indigo overlay (5% opacity)
- White card with rounded corners
- Indigo border (2px)
- Large shadow for depth
- Circular icon badge background

## 🎯 Color Usage

### Backgrounds
- **Main**: `#F7F8FA` - Soft gray, easy on the eyes
- **Surface**: `#FFFFFF` - Pure white for cards/table
- **Table Header**: `#FAFAFB` - Very light gray

### Accents
- **Primary**: `#6366F1` - Indigo for actions and focus
- **Primary Light**: `#EEF2FF` - Hover states and selections
- **Success**: `#10B981` - Green for confirmations
- **Warning**: `#F59E0B` - Orange for unsaved changes
- **Error**: `#EF4444` - Red for destructive actions

### Text
- **Primary**: `#111827` - Near black for main content
- **Secondary**: `#6B7280` - Gray for labels
- **Tertiary**: `#9CA3AF` - Light gray for hints

### Borders
- **Default**: `#E5E7EB` - Standard gray
- **Light**: `#F3F4F6` - Subtle dividers

## ✨ Interactive States

### Buttons
```
Default:  [Icon] ← Gray icon
Hover:    [Icon] ← Background: transparent → light gray
Active:   [Icon] ← Background: indigo light, Icon: indigo
Disabled: [Icon] ← Gray icon, 50% opacity
```

### Table Rows
```
Default:  White or light gray (alternating)
Hover:    Light gray (#F3F4F6)
Selected: Light indigo (#EEF2FF)
```

### Cells
```
Default:  Transparent
Selected: Light indigo background + indigo border (2px)
Editing:  Modal dialog opens
```

### Filter Chips
```
Default:  White bg, gray border, gray text
Selected: Light indigo bg, indigo border, indigo text + checkmark
Hover:    Slightly darker background
```

## 📏 Spacing & Sizing

### Spacing Scale
- **XS**: 4px - Tight spacing
- **SM**: 8px - Small gaps
- **MD**: 12px - Standard spacing
- **LG**: 16px - Larger gaps
- **XL**: 24px - Section spacing
- **2XL**: 32px - Major dividers

### Component Heights
- **Toolbar**: 56px
- **Status Bar**: 32px
- **Table Header**: 40px
- **Table Row**: Min 40px (auto-expands)
- **Search Bar**: ~56px (with padding)

### Border Radius
- **Small**: 4px - Tight corners
- **Medium**: 6px - Buttons, inputs
- **Large**: 8px - Cards
- **XL**: 12px - Modals, main containers

### Shadows
- **Small**: 1px offset, 3px blur - Subtle elevation
- **Medium**: 4px offset, 6px blur - Cards
- **Large**: 10px offset, 15px blur - Modals

## 🎭 Typography

### Font Sizes
- **Heading Large**: 24px / Semi-bold / -0.5 spacing
- **Heading Medium**: 18px / Semi-bold / -0.3 spacing
- **Heading Small**: 14px / Semi-bold / -0.1 spacing
- **Body Large**: 15px / Regular / 1.5 line-height
- **Body Medium**: 14px / Regular / 1.5 line-height
- **Body Small**: 13px / Regular / 1.4 line-height
- **Label**: 12px / Medium / 0.3 spacing
- **Caption**: 11px / Regular / 0.2 spacing

### Font Weights
- **Regular**: 400 - Body text
- **Medium**: 500 - Labels, secondary emphasis
- **Semi-bold**: 600 - Headings, important text

## 🔔 Notifications

### Snackbar Style
```
┌─────────────────────────────────────┐
│ ✓ Changes saved successfully!       │  ← Success (green)
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ ⚠ Please select at least 2 rows     │  ← Warning (orange)
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ ✕ Error loading file: ...           │  ← Error (red)
└─────────────────────────────────────┘
```

**Features:**
- Floating style with margin
- Rounded corners (6px)
- Icon + message layout
- Color-coded by type
- Auto-dismiss after 3 seconds

## 🎮 Interactions

### Keyboard Shortcuts
- **Cmd+S / Ctrl+S**: Save
- **Cmd+Z / Ctrl+Z**: Undo
- **Cmd+Shift+Z / Ctrl+Shift+Z**: Redo
- **Cmd+Click / Ctrl+Click**: Multi-select cells
- **Double-click cell**: Edit
- **Right-click header**: Column menu
- **Right-click row**: Row menu

### Mouse Interactions
- **Hover**: Subtle background color change
- **Click cell**: Edit dialog opens
- **Multi-select**: Cmd/Ctrl + Click multiple cells
- **Select row**: Click checkbox
- **Select all**: Click header checkbox
- **Drag file**: Shows overlay with blur

### Context Menus
```
╔═══════════════════════════╗
║ ✎ Edit Column             ║
║ ➕ Add Column After        ║
║ ⎘ Duplicate Column        ║
║ 🗑️ Delete Column           ║
╚═══════════════════════════╝
```

**Features:**
- Rounded corners (12px)
- Icon + text layout
- 40px item height
- Hover highlight
- Subtle border

## 🌟 Professional Touches

1. **Tabular Figures**: Line numbers use monospace tabular figures for perfect alignment
2. **Icon Consistency**: All icons from Material Icons Outlined set
3. **Micro-animations**: 150ms transitions on hover states
4. **Visual Hierarchy**: Clear primary/secondary/tertiary levels
5. **Breathing Room**: Generous padding and margins
6. **Subtle Details**: Shadow on scroll, border on focus, etc.

---

**Design inspired by**: Notion (colors & spacing), TablePlus (table design), Airtable (interactions)  
**Design principles**: Minimalism, clarity, consistency, professionalism

