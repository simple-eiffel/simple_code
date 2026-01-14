# EiffelStudio IDE Tool Development Guide

**A Comprehensive Reference for Extending EiffelStudio with Custom Dockable Tools**

> This guide consolidates documentation from [dev.eiffel.com/Tool_Integration_Development](https://dev.eiffel.com/Tool_Integration_Development), the Smart Docking library docs, and EiffelStudio source code patterns.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Core Classes](#3-core-classes)
4. [Required Implementations](#4-required-implementations)
5. [Tool Lifecycle](#5-tool-lifecycle)
6. [Registration Points](#6-registration-points)
7. [Smart Docking System](#7-smart-docking-system)
8. [Toolbar Integration](#8-toolbar-integration)
9. [Complete Implementation Example](#9-complete-implementation-example)
10. [Advanced Topics](#10-advanced-topics)
11. [Reference Implementation](#11-reference-implementation)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Overview

EiffelStudio's tool system allows developers to create custom dockable panels that integrate seamlessly with the IDE. These tools can:

- Dock to any edge of the main window
- Float as independent windows
- Tab with other tools
- Auto-hide to side panels
- Persist layout across sessions
- Integrate with EiffelStudio's command system

### Requirements

- EiffelStudio 6.1+ (preferably 25.x)
- Access to EiffelStudio source code (for compilation)
- Understanding of EiffelVision2 widget library

### Source Code Access

```bash
# SVN (primary)
svn checkout https://svn.eiffel.com/eiffelstudio/trunk/Src/Eiffel

# GitHub mirror (12-month delay)
git clone https://github.com/EiffelSoftware/EiffelStudio
```

---

## 2. Architecture

### Two-Part Tool Structure

Every EiffelStudio tool consists of two components:

```
+-------------------------------------------------------------+
|                      ES_TOOL [G]                            |
|                   (Tool Descriptor)                         |
|  +-------------------------------------------------------+  |
|  | - Icon/Pixmap management                              |  |
|  | - Title string                                        |  |
|  | - Shortcut preference binding                         |  |
|  | - Menu item generation                                |  |
|  | - Toolbar button creation                             |  |
|  | - Factory method for panel creation                   |  |
|  +-------------------------------------------------------+  |
+-------------------------------------------------------------+
                              |
                              | creates
                              v
+-------------------------------------------------------------+
|              ES_DOCKABLE_TOOL_WINDOW [G]                    |
|                    (Tool Panel)                             |
|  +-------------------------------------------------------+  |
|  | - User interface widgets                              |  |
|  | - Event handlers                                      |  |
|  | - Business logic                                      |  |
|  | - Toolbar items                                       |  |
|  | - State management                                    |  |
|  +-------------------------------------------------------+  |
+-------------------------------------------------------------+
```

### Class Hierarchy

```
ANY
  +-- EB_TOOL (legacy - do not use directly)
        +-- ES_DOCKABLE_TOOL_WINDOW [G -> EV_WIDGET]
              +-- YOUR_CUSTOM_TOOL [EV_YOUR_WIDGET]
```

---

## 3. Core Classes

### ES_DOCKABLE_TOOL_WINDOW [G -> EV_WIDGET]

The primary base class for all new tools. The generic parameter `G` represents your tool's main widget type.

**Location**: `$EIFFEL_SRC/Eiffel/interface/new_graphical/tools/`

**Key Inherited Features**:

| Feature | Type | Purpose |
|---------|------|---------|
| `develop_window` | `EB_DEVELOPMENT_WINDOW` | Reference to parent IDE window |
| `user_widget` | `G` | Your tool's main widget (lazily created) |
| `content` | `SD_CONTENT` | Smart Docking content wrapper |
| `icon` | `EV_PIXEL_BUFFER` | Current display icon |
| `title` | `STRING_32` | Current display title |
| `is_visible` | `BOOLEAN` | Visibility state |
| `is_initialized` | `BOOLEAN` | Whether UI has been built |

**Key Inherited Routines**:

| Routine | Purpose |
|---------|---------|
| `make (a_window)` | Creation procedure |
| `show` | Display the tool |
| `hide` | Hide the tool |
| `close` | Close and cleanup |
| `set_icon (a_icon)` | Change display icon |
| `set_title (a_title)` | Change display title |
| `initialize` | Force early initialization |

### ES_TOOL [G]

The tool descriptor that manages tool creation, commands, and menu integration.

**Key Features**:

| Feature | Purpose |
|---------|---------|
| `icon` / `icon_pixmap` | Tool's graphical representation |
| `title` | Display name for menus/tabs |
| `shortcut_preference_name` | Optional preference key for shortcuts |
| `create_tool` | Factory method to instantiate the panel |

### EB_TOOL (Legacy)

**Do not inherit from this class directly.** It exists only for backward compatibility. All new tools should use `ES_DOCKABLE_TOOL_WINDOW`.

---

## 4. Required Implementations

When inheriting from `ES_DOCKABLE_TOOL_WINDOW`, you must implement these **5 deferred features**:

### 4.1 tool_title

```eiffel
tool_title: STRING_32
    -- Constant tool title (used during initialization)
    once
        Result := "My Custom Tool"
    end
```

**Notes**:
- Should be a constant (use `once` function)
- This value seeds the mutable `title` attribute
- Used in tab buttons and window titles when undocked

### 4.2 tool_icon_buffer

```eiffel
tool_icon_buffer: EV_PIXEL_BUFFER
    -- Icon with alpha channel support
    once
        Result := stock_pixmaps.tool_output_icon_buffer
        -- Or load custom icon:
        -- create Result.make_with_size (16, 16)
        -- Result.draw_pixmap (0, 0, my_custom_icon)
    end
```

**Notes**:
- Use `EV_PIXEL_BUFFER` for alpha transparency support
- Access stock icons via `stock_pixmaps` helper
- Icon should be 16x16 pixels for best display
- Generate custom icons using Eiffel Matrix Code Generator

### 4.3 create_widget

```eiffel
create_widget: EV_VERTICAL_BOX
    -- Factory function for main widget
    do
        create Result
        -- Widget will be populated in build_tool_interface
    end
```

**Notes**:
- Returns widget of type matching generic parameter `G`
- Called exactly once per tool instance
- Do NOT populate the widget here - use `build_tool_interface`
- The result becomes accessible via `user_widget`

### 4.4 build_tool_interface

```eiffel
build_tool_interface (a_widget: EV_VERTICAL_BOX)
    -- Main UI construction routine
    local
        l_label: EV_LABEL
        l_button: EV_BUTTON
    do
        -- Create UI elements
        create l_label.make_with_text ("Hello from my tool!")
        create l_button.make_with_text ("Click Me")

        -- Wire up events
        l_button.select_actions.extend (agent on_button_clicked)

        -- Add to widget hierarchy
        a_widget.extend (l_label)
        a_widget.extend (l_button)
        a_widget.disable_item_expand (l_button)
    end
```

**Notes**:
- This is where ALL UI construction should happen
- Called during **delayed initialization** (first visibility)
- Parameter is the same object returned by `create_widget`
- Use this to add child widgets, wire events, apply styles

### 4.5 create_tool_bar_items

```eiffel
create_tool_bar_items: ARRAYED_LIST [SD_TOOL_BAR_ITEM]
    -- Optional toolbar buttons
    do
        create Result.make (2)
        Result.extend (create {SD_TOOL_BAR_BUTTON}.make (
            stock_pixmaps.general_add_icon,
            agent on_add_clicked))
        Result.extend (create {SD_TOOL_BAR_BUTTON}.make (
            stock_pixmaps.general_remove_icon,
            agent on_remove_clicked))
    end
```

**Notes**:
- Return `Void` or empty list to suppress toolbar
- Use `SD_TOOL_BAR_BUTTON` for standard buttons
- Use `SD_TOOL_BAR_TOGGLE_BUTTON` for toggle state
- Use `SD_TOOL_BAR_DUAL_POPUP_BUTTON` for dropdown menus
- Access standard icons via `stock_pixmaps`

---

## 5. Tool Lifecycle

### 5.1 Creation Phase

```
1. EB_DEVELOPMENT_WINDOW_MAIN_BUILDER.build_your_tool called
2. create YOUR_TOOL.make (develop_window)
3. YOUR_TOOL.on_before_initialize called (if redefined)
4. Tool registered with EB_DEVELOPMENT_WINDOW_TOOLS
5. setup_tool called (registers shortcut preference)
```

### 5.2 Delayed Initialization

Tools are NOT fully initialized at creation to improve startup performance:

```
User clicks View -> Tools -> Your Tool
         |
         v
    show called
         |
         v
  +----------------------+
  | is_initialized = No? |--Yes--> Display existing UI
  +----------------------+
         | No
         v
   create_widget called
         |
         v
 build_tool_interface called
         |
         v
  is_initialized := True
         |
         v
    Display new UI
```

### 5.3 Widget Access Gotcha

**Problem**: Accessing `user_widget` before initialization returns detached (void) reference.

**Solutions**:

```eiffel
-- Option 1: Test attachment before use
if attached user_widget as l_widget then
    l_widget.do_something
end

-- Option 2: Force early initialization
feature {NONE} -- Access
    safe_user_widget: EV_VERTICAL_BOX
        do
            if not is_initialized then
                initialize
            end
            Result := user_widget
        end
```

### 5.4 on_before_initialize Hook

```eiffel
on_before_initialize
    -- Called DURING creation (affects startup time!)
    do
        Precursor -- Call parent
        -- Initialize class attributes that do not depend on UI
        create internal_data.make
    end
```

**Warning**: Keep this minimal - it runs at EiffelStudio startup!

---

## 6. Registration Points

### 6.1 EB_DEVELOPMENT_WINDOW_TOOLS

**Location**: `$EIFFEL_SRC/Eiffel/interface/new_graphical/windows/development_window/`

Add accessor and assigner:

```eiffel
feature -- Access: Custom Tools

    my_ai_tool: ES_MY_AI_TOOL
        -- AI integration tool
        assign set_my_ai_tool

feature -- Element Change: Custom Tools

    set_my_ai_tool (a_tool: like my_ai_tool)
        -- Set `my_ai_tool` to `a_tool`
        do
            my_ai_tool := a_tool
        ensure
            my_ai_tool_set: my_ai_tool = a_tool
        end
```

Update `all_tools`:

```eiffel
all_tools: ARRAYED_LIST [EB_TOOL]
    do
        create Result.make (50)
        -- ... existing tools ...
        if my_ai_tool /= Void then
            Result.extend (my_ai_tool)
        end
    end
```

### 6.2 EB_DEVELOPMENT_WINDOW_MAIN_BUILDER

**Location**: Same directory as above.

Add build routine:

```eiffel
feature {NONE} -- Building: Custom Tools

    build_my_ai_tool
        -- Build AI integration tool
        local
            l_tool: ES_MY_AI_TOOL
        do
            create l_tool.make (develop_window)
            develop_window.tools.set_my_ai_tool (l_tool)
            setup_tool (l_tool, "show_my_ai_tool")
        end
```

Register in `build_tools`:

```eiffel
build_tools
    do
        -- ... existing build calls ...
        build_my_ai_tool
    end
```

### 6.3 EB_DEVELOPMENT_WINDOW_MENU_BUILDER

**Location**: Same directory.

Add menu entry in `tool_list_menu`:

```eiffel
tool_list_menu: EV_MENU
    do
        create Result.make_with_text ("Tools")
        -- ... existing entries ...
        if develop_window.tools.my_ai_tool /= Void then
            fill_show_menu_for_tool (Result, develop_window.tools.my_ai_tool)
        end
    end
```

---

## 7. Smart Docking System

EiffelStudio uses the Smart Docking library for all panel management.

### 7.1 Content Types

```eiffel
feature -- Content Type

    content_type: INTEGER
        -- SD_CONTENT type identifier
        once
            Result := {SD_ENUMERATION}.tool_type
            -- Or: {SD_ENUMERATION}.editor_type
        end
```

| Type | Behavior |
|------|----------|
| `tool_type` | Can float, can dock to edges, cannot go in editor area |
| `editor_type` | Cannot float, restricted to editor docking zone |

### 7.2 Docking Zones

Tools can dock to:
- **Top/Bottom**: Horizontal panel across window
- **Left/Right**: Vertical panel with rotated tab text
- **Tabbed**: Share space with other tools
- **Floating**: Independent window

### 7.3 Auto-Hide Feature

When docked to edges, tools can auto-hide:

```eiffel
feature -- Auto-hide

    supports_auto_hide: BOOLEAN = True
        -- Can this tool auto-hide?

    request_auto_hide
        -- Trigger auto-hide behavior
        do
            if attached content as l_content then
                l_content.set_auto_hide ({SD_ENUMERATION}.left)
            end
        end
```

### 7.4 Layout Persistence

Tool layouts are automatically saved and restored. To participate:

```eiffel
feature -- Layout

    internal_name: STRING_32
        -- Unique identifier for layout persistence
        once
            Result := "es_my_ai_tool"
        end
```

---

## 8. Toolbar Integration

### 8.1 Standard Toolbar

```eiffel
create_tool_bar_items: ARRAYED_LIST [SD_TOOL_BAR_ITEM]
    local
        l_btn: SD_TOOL_BAR_BUTTON
        l_toggle: SD_TOOL_BAR_TOGGLE_BUTTON
        l_sep: SD_TOOL_BAR_SEPARATOR
    do
        create Result.make (5)

        -- Standard button
        create l_btn.make (icon_refresh, agent on_refresh)
        l_btn.set_tooltip ("Refresh data")
        Result.extend (l_btn)

        -- Separator
        create l_sep.make
        Result.extend (l_sep)

        -- Toggle button
        create l_toggle.make (icon_auto_update)
        l_toggle.set_tooltip ("Auto-update")
        l_toggle.select_actions.extend (agent on_auto_update_toggled)
        Result.extend (l_toggle)
    end
```

### 8.2 Right-Aligned Toolbar

```eiffel
create_right_tool_bar_items: ARRAYED_LIST [SD_TOOL_BAR_ITEM]
    do
        create Result.make (2)
        Result.extend (create {SD_TOOL_BAR_BUTTON}.make (
            stock_pixmaps.general_close_icon,
            agent close))
    end
```

### 8.3 Mini Toolbar

For compact displays:

```eiffel
create_mini_tool_bar_items: ARRAYED_LIST [SD_TOOL_BAR_ITEM]
    -- Compact toolbar variant
    do
        -- Return subset of create_tool_bar_items
        Result := create_tool_bar_items
    end
```

### 8.4 Toolbar Positioning

```eiffel
is_tool_bar_bottom_aligned: BOOLEAN = True
    -- Place toolbar at bottom instead of top
```

---

## 9. Complete Implementation Example

### 9.1 ES_MY_AI_TOOL Class

```eiffel
note
    description: "AI integration tool for EiffelStudio"
    author: "Your Name"
    date: "$Date$"
    revision: "$Revision$"

class
    ES_MY_AI_TOOL

inherit
    ES_DOCKABLE_TOOL_WINDOW [EV_VERTICAL_BOX]
        redefine
            on_before_initialize,
            create_right_tool_bar_items
        end

create
    make

feature {NONE} -- Initialization

    on_before_initialize
        -- Initialize non-UI attributes
        do
            Precursor
            create message_history.make (100)
            create ai_connection
        end

feature -- Access

    tool_title: STRING_32
        once
            Result := "AI Assistant"
        end

    tool_icon_buffer: EV_PIXEL_BUFFER
        once
            Result := stock_pixmaps.tool_output_icon_buffer
        end

feature {NONE} -- Factory

    create_widget: EV_VERTICAL_BOX
        do
            create Result
        end

feature {NONE} -- User Interface

    build_tool_interface (a_widget: EV_VERTICAL_BOX)
        do
            -- Create output area
            create output_text
            output_text.disable_edit
            output_text.set_minimum_height (200)

            -- Create input area
            create input_field
            input_field.return_actions.extend (agent on_send_message)

            -- Create send button
            create send_button.make_with_text ("Send")
            send_button.select_actions.extend (agent on_send_message)

            -- Layout: input + button in horizontal box
            create input_box
            input_box.extend (input_field)
            input_box.extend (send_button)
            input_box.disable_item_expand (send_button)

            -- Add to main widget
            a_widget.extend (output_text)
            a_widget.extend (input_box)
            a_widget.disable_item_expand (input_box)
        end

feature {NONE} -- Toolbar

    create_tool_bar_items: ARRAYED_LIST [SD_TOOL_BAR_ITEM]
        do
            create Result.make (3)
            Result.extend (create {SD_TOOL_BAR_BUTTON}.make (
                stock_pixmaps.general_reset_icon,
                agent on_clear_history))
            Result.extend (create {SD_TOOL_BAR_SEPARATOR}.make)
            Result.extend (create {SD_TOOL_BAR_BUTTON}.make (
                stock_pixmaps.general_save_icon,
                agent on_save_transcript))
        end

    create_right_tool_bar_items: ARRAYED_LIST [SD_TOOL_BAR_ITEM]
        do
            create Result.make (1)
            Result.extend (create {SD_TOOL_BAR_BUTTON}.make (
                stock_pixmaps.tool_config_icon,
                agent on_configure))
        end

feature {NONE} -- Event Handlers

    on_send_message
        -- Send message to AI
        local
            l_message: STRING_32
        do
            l_message := input_field.text
            if not l_message.is_empty then
                process_ai_query (l_message)
                input_field.remove_text
            end
        end

    on_clear_history
        -- Clear conversation
        do
            message_history.wipe_out
            output_text.remove_text
        end

    on_save_transcript
        -- Save to file
        do
            -- Implementation
        end

    on_configure
        -- Open settings
        do
            -- Implementation
        end

feature {NONE} -- AI Integration

    process_ai_query (a_query: STRING_32)
        -- Process AI query and display response
        do
            -- Add to history
            message_history.extend (["user", a_query])
            output_text.append_text ("You: " + a_query + "%N%N")

            -- Call AI service (async recommended)
            if attached ai_connection.query (a_query) as l_response then
                message_history.extend (["ai", l_response])
                output_text.append_text ("AI: " + l_response + "%N%N")
            end
        end

feature {NONE} -- Implementation

    output_text: EV_RICH_TEXT
    input_field: EV_TEXT_FIELD
    input_box: EV_HORIZONTAL_BOX
    send_button: EV_BUTTON
    message_history: ARRAYED_LIST [TUPLE [role, content: STRING_32]]
    ai_connection: AI_SERVICE_CONNECTION

invariant
    message_history_attached: message_history /= Void

end
```

---

## 10. Advanced Topics

### 10.1 Preference Integration

```eiffel
feature -- Preferences

    preferences: AI_TOOL_PREFERENCES
        once
            create Result.make (develop_window.preferences)
        end

feature {NONE} -- Preference Keys

    pref_model_name: STRING = "tools.ai_assistant.model"
    pref_temperature: STRING = "tools.ai_assistant.temperature"
```

### 10.2 Command Integration

Register commands that can be triggered globally:

```eiffel
feature -- Commands

    send_to_ai_command: ES_SEND_TO_AI_COMMAND
        -- Command to send selected text to AI
        once
            create Result.make (develop_window)
        end
```

### 10.3 Editor Integration

Access the current editor content:

```eiffel
feature -- Editor Access

    selected_text: detachable STRING_32
        -- Get selected text from active editor
        do
            if attached develop_window.editors_manager.current_editor as l_editor then
                if attached l_editor.text_displayed as l_text then
                    if l_text.has_selection then
                        Result := l_text.selected_text
                    end
                end
            end
        end
```

### 10.4 Stone Protocol

EiffelStudio uses "stones" and "pebbles" for drag-and-drop:

```eiffel
feature -- Stone Protocol

    stone: detachable STONE
        -- Current stone (if any)

    set_stone (a_stone: like stone)
        -- Accept dropped stone
        do
            stone := a_stone
            if attached {CLASSI_STONE} a_stone as l_class then
                analyze_class (l_class.class_i)
            end
        end

    stone_type: INTEGER
        -- Accepted stone type
        once
            Result := {STONE_TYPES}.class_stone_type
        end
```

### 10.5 Event Subscription

Subscribe to EiffelStudio events:

```eiffel
feature {NONE} -- Events

    subscribe_to_events
        do
            if attached develop_window.events as l_events then
                l_events.compile_start_actions.extend (agent on_compile_start)
                l_events.compile_stop_actions.extend (agent on_compile_stop)
            end
        end

    on_compile_start
        do
            -- Compilation started
        end

    on_compile_stop
        do
            -- Compilation finished
        end
```

---

## 11. Reference Implementation

The recommended reference implementation is `ES_ERRORS_AND_WARNINGS_TOOL`:

**Location**: `$EIFFEL_SRC/Eiffel/interface/new_graphical/tools/eb_errors_and_warnings_tool/`

This tool demonstrates:
- Event subscription (`on_event_added`, `on_event_removed`)
- Grid-based UI with sorting
- Toolbar with filtering options
- Stone protocol for navigation
- Preference integration

---

## 12. Troubleshooting

### Tool Not Appearing

1. Check `all_tools` includes your tool
2. Verify `build_your_tool` is called from `build_tools`
3. Check menu builder adds entry

### Void Widget Access

- Ensure code that accesses `user_widget` handles detachment
- Or force initialization with `initialize` call

### Icon Not Displaying

- Verify icon is 16x16 pixels
- Use `EV_PIXEL_BUFFER` for alpha support
- Check `tool_icon_buffer` returns valid buffer

### Startup Performance

- Keep `on_before_initialize` minimal
- Use delayed initialization (default behavior)
- Avoid heavy processing in `build_tool_interface`

### Layout Not Persisting

- Ensure `internal_name` returns unique identifier
- Check tool is properly registered in `all_tools`

---

## Resources

- [Tool Integration Development](https://dev.eiffel.com/Tool_Integration_Development)
- [Smart Docking Library](https://dev.eiffel.com/What_the_Smart_Docking_library_looks_like)
- [EiffelStudio Source (GitHub)](https://github.com/EiffelSoftware/EiffelStudio)
- [EiffelVision2 Documentation](https://www.eiffel.org/doc/solutions/EiffelVision_2)

---

*Document version 1.0 - Created for simple_code project*
