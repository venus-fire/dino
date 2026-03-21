# Dino XMPP Client - Text Zoom Feature

## Overview

This document describes the custom text zoom feature added to Dino XMPP client to address the issue of small, hard-to-read text in chat conversations.

## Problem Statement

Dino XMPP client did not have a built-in zoom or font size adjustment feature. Users with high-DPI displays or vision impairments found the default text size too small to read comfortably. The only system-wide solution (`gsettings set org.gnome.desktop.interface text-scaling-factor`) affected all GTK applications, making other apps like browsers display too large.

**GitHub Issue:** [#978 - Shortcut to increase font size ("Zoom")](https://github.com/dino/dino/issues/978) (opened January 2021, still open)

## Solution

A custom text zoom feature was implemented that:
- Provides per-application font scaling (only affects Dino)
- Persists settings across restarts
- Uses keyboard shortcuts for quick adjustment
- Scales both text AND entire UI (spacing, avatars, widgets, etc.)

## Features

### What Gets Scaled

✅ **Text Elements:**
- Chat message text
- Chat input text area
- Timestamps and names
- All UI labels

✅ **UI Elements:**
- Message padding and spacing
- Avatar sizes (conversation view + sidebar)
- File attachment boxes
- Call widgets
- Reaction buttons
- Quote blocks
- All margins and borders
- Sidebar conversation rows
- Unread count badges

**Note:** Avatar sizes are reduced by 20% from default for better visual balance.

This ensures a consistent, proportional zoom experience across the entire application.

## Implementation Details

### Architecture

Dino is written in **Vala** using **GTK4** and **libadwaita-1** (version >= 1.5). The build system is **Meson**.

### Files Modified

#### 1. `libdino/src/entity/settings.vala`

**Purpose:** Add font_size setting to Dino's settings entity

**Changes:**
- Added `font_size_` private field (default: 1.0)
- Added `font_size` public property with getter/setter
- Settings are persisted to SQLite database (`~/.local/share/dino/dino.db`)
- Values are clamped to range 0.5-2.0 (50%-200%)

**Code:**
```vala
// Font size scaling factor (1.0 = 100%, range: 0.5 to 2.0)
private double font_size_;
public double font_size {
    get { return font_size_; }
    set {
        // Clamp value to reasonable range (50% to 200%)
        double clamped_value = value.clamp(0.5, 2.0);
        db.settings.upsert()
            .value(db.settings.key, "font_size", true)
            .value(db.settings.value, clamped_value.to_string())
            .perform();
        font_size_ = clamped_value;
    }
}
```

#### 2. `main/src/ui/conversation_content_view/message_widget.vala`

**Purpose:** Apply font scaling to chat message labels

**Changes:**
- Added `font_scale` private field (default: 1.0)
- Modified constructor to read saved font size from settings
- Modified `generate_markup_text()` to apply Pango scale attribute
- Added `set_font_scale()` public method for dynamic updates

**Key Implementation:**
```vala
// In constructor - initialize from saved settings
var app = GLib.Application.get_default() as Dino.Ui.Application;
font_scale = app != null ? app.settings.font_size : 1.0;

// Apply font scale to the entire message text
var scale_attr = Pango.attr_scale_new((float)font_scale);
scale_attr.start_index = 0;
scale_attr.end_index = uint.MAX;
attrs.insert(scale_attr.copy());

public void set_font_scale(double scale) {
    font_scale = scale;
    update_label();
}
```

**Namespace:** `Dino.Ui.ConversationSummary.MessageMetaItem`

**Note:** New messages automatically use the saved font size from settings, ensuring consistent display between old and new messages.

#### 3. `main/src/ui/chat_input/chat_text_view.vala`

**Purpose:** Apply font scaling to the chat input text view

**Changes:**
- Added `font_scale` private field (default: 1.0)
- Added `apply_font_scale()` method using CSS styling
- Added `set_font_scale()` public method
- Font scale is initialized asynchronously after widget construction

**Key Implementation (GTK4 compatible):**
```vala
private void apply_font_scale() {
    // Calculate font size based on scale (base size 14px)
    double base_font_size = 14.0;
    double scaled_size = base_font_size * font_scale;
    
    // Apply CSS style to set font size
    var css_provider = new Gtk.CssProvider();
    string css = ".chat-text-view { font-size: " + scaled_size.to_string() + "px; }";
    
    try {
        css_provider.load_from_data(css.data);
        text_view.add_css_class("chat-text-view");
        text_view.get_style_context().add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    } catch (Error e) {
        warning("Failed to apply font scale CSS: %s", e.message);
    }
}
```

**Note:** GTK4's `TextView` does not have `get_attributes()`/`set_attributes()` methods like GTK3, so CSS is used instead.

#### 4. `main/src/ui/conversation_view_controller.vala`

**Purpose:** Add keyboard shortcuts for zoom control

**Changes:**
- Added `change_font_size(double delta)` method
- Added `reset_font_size()` method
- Added `update_font_scale_on_widgets(double scale)` method
- Registered four keyboard shortcuts

**Keyboard Shortcuts:**
```vala
// Ctrl++ - Zoom in (increase by 0.1)
Shortcut zoom_in_shortcut = new Shortcut(
    new KeyvalTrigger(Key.plus, ModifierType.CONTROL_MASK), 
    new CallbackAction(() => {
        change_font_size(0.1);
        return true;
    })
);

// Ctrl+= - Zoom in (alternative key)
Shortcut zoom_in_equal_shortcut = new Shortcut(
    new KeyvalTrigger(Key.equal, ModifierType.CONTROL_MASK), 
    new CallbackAction(() => {
        change_font_size(0.1);
        return true;
    })
);

// Ctrl+- - Zoom out (decrease by 0.1)
Shortcut zoom_out_shortcut = new Shortcut(
    new KeyvalTrigger(Key.minus, ModifierType.CONTROL_MASK), 
    new CallbackAction(() => {
        change_font_size(-0.1);
        return true;
    })
);

// Ctrl+0 - Reset to default (1.0)
Shortcut zoom_reset_shortcut = new Shortcut(
    new KeyvalTrigger(Key.@0, ModifierType.CONTROL_MASK), 
    new CallbackAction(() => {
        reset_font_size();
        return true;
    })
);
```

**Note:** In GTK4 Vala bindings, number keys use the `@` prefix (e.g., `Key.@0`, `Key.@1`) because they conflict with numeric literals.

#### 5. `main/src/ui/conversation_content_view/conversation_view.vala`

**Purpose:** Apply UI scaling to entire conversation view (spacing, avatars, widgets)

**Changes:**
- Added `current_ui_scale` private field
- Added `set_ui_scale(double scale)` public method
- Applies CSS-based scaling to:
  - Message box padding
  - Avatar sizes
  - File/call widget margins
  - Reaction button sizes
  - Quote block styling
  - All spacing elements

**Key Implementation:**
```vala
public void set_ui_scale(double scale) {
    current_ui_scale = scale.clamp(0.5, 2.0);
    
    var css_provider = new CssProvider();
    string css = @"
        .dino-conversation {
            --dino-ui-scale: $(current_ui_scale);
        }
        .dino-conversation .message-box {
            padding: calc(3px * $(current_ui_scale)) ...;
        }
        .dino-conversation picture.avatar {
            min-width: calc(48px * $(current_ui_scale));
            min-height: calc(48px * $(current_ui_scale));
        }
        // ... more scalable properties
    ";
    
    css_provider.load_from_data(css.data);
    this.get_style_context().add_provider(css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
}
```

**Namespace:** `Dino.Ui.ConversationSummary.ConversationView`

#### 7. `main/src/ui/conversation_selector/conversation_selector.vala`

**Purpose:** Apply UI scaling to sidebar conversation list

**Changes:**
- Added `current_ui_scale` private field
- Added `set_ui_scale(double scale)` public method
- Applies CSS-based scaling to:
  - Sidebar row padding
  - Avatar sizes
  - Label font sizes
  - Unread count badge sizes
- Updates all existing rows when scale changes

**Key Implementation:**
```vala
public void set_ui_scale(double scale) {
    current_ui_scale = scale.clamp(0.5, 2.0);
    
    var css_provider = new CssProvider();
    string css = @"
        .navigation-sidebar list row {
            padding: calc(6px * $(current_ui_scale)) ...;
        }
        .navigation-sidebar picture.avatar {
            min-width: calc(32px * $(current_ui_scale));
            min-height: calc(32px * $(current_ui_scale));
        }
        .navigation-sidebar label {
            font-size: calc(14px * $(current_ui_scale));
        }
    ";
    
    css_provider.load_from_data(css.data);
    Gtk.StyleContext.add_provider_for_display(...);
    
    // Update all existing rows
    foreach (ConversationSelectorRow row in rows.values) {
        row.set_ui_scale(current_ui_scale);
    }
}
```

#### 8. `main/src/ui/conversation_selector/conversation_selector_row.vala`

**Purpose:** Apply per-row avatar scaling

**Changes:**
- Added `set_ui_scale(double scale)` public method
- Updates avatar widget dimensions directly

**Key Implementation:**
```vala
public void set_ui_scale(double scale) {
    double ui_scale = scale.clamp(0.5, 2.0);
    picture.width_request = (int)(32 * ui_scale);
    picture.height_request = (int)(32 * ui_scale);
}
```

#### 9. `main/src/ui/conversation_view_controller.vala` (Updated)

**Purpose:** Expose content items for font scale updates

**Changes:**
- The `get_content_items()` method already existed; no changes needed
- This method returns `Gee.TreeSet<ContentMetaItem>` which includes all message widgets

## Build Instructions

### Prerequisites

Install build dependencies (Debian/Ubuntu):
```bash
sudo apt-get install -y \
    meson ninja-build valac \
    libgtk-4-dev libadwaita-1-dev \
    libgee-0.8-dev libgpgme-dev libgcrypt20-dev \
    libsqlite3-dev libqrencode-dev libnice-dev \
    libomemo-c-dev libsrtp2-dev libsoup-3.0-dev \
    libwebrtc-audio-processing-dev gettext \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    libgnutls28-dev libxml2-dev libprotobuf-dev \
    protobuf-compiler-grpc
```

### Build Steps

```bash
# Clone the repository (if not already done)
git clone https://github.com/dino/dino.git
cd dino

# Configure build
meson setup build --prefix=$HOME/.local

# Compile
meson compile -C build

# Run without installing
./build/main/dino

# Install system-wide (optional)
sudo meson install -C build
sudo ldconfig
```

## Usage

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl` + `+` | Increase font size by 10% |
| `Ctrl` + `=` | Increase font size by 10% (alternative) |
| `Ctrl` + `-` | Decrease font size by 10% |
| `Ctrl` + `0` | Reset to default (100%) |

### Settings Range

- **Minimum:** 0.5 (50% - very small)
- **Default:** 1.0 (100% - original size)
- **Maximum:** 2.0 (200% - very large)
- **Step:** 0.1 (10% per keypress)

### Persistence

Font size settings are stored in:
```
~/.local/share/dino/dino.db
```

The setting persists across application restarts and is specific to the user account.

## Technical Challenges and Solutions

### 1. GTK4 TextView Attributes

**Problem:** GTK4's `TextView` does not have `get_attributes()` and `set_attributes()` methods that were available in GTK3.

**Solution:** Use CSS providers to apply font size styling:
```vala
var css_provider = new Gtk.CssProvider();
css_provider.load_from_data(css.data);
text_view.get_style_context().add_provider(css_provider, priority);
```

### 2. Application Instance Access

**Problem:** Widgets need access to the `Application.settings` object, but `Application.get_default()` doesn't exist in GTK4.

**Solution:** Navigate the widget hierarchy using `get_root()`:
```vala
var root = this.get_root();
if (root is Gtk.ApplicationWindow) {
    var app = ((Gtk.ApplicationWindow)root).get_application() as Dino.Ui.Application;
    if (app != null) {
        // Access app.settings
    }
}
```

### 3. GTK4 Key Constants

**Problem:** Number keys in GTK4 Vala bindings use `@` prefix to avoid conflicts with numeric literals.

**Solution:** Use `Key.@0` instead of `Key._0` or `Key.KEY_0`:
```vala
new KeyvalTrigger(Key.@0, ModifierType.CONTROL_MASK)
```

### 4. Pango Attribute Ownership

**Problem:** Vala's memory management requires explicit handling of `Pango.Attribute` ownership when inserting into `AttrList`.

**Solution:** Use `.copy()` to transfer ownership:
```vala
attrs.insert(scale_attr.copy());
```

### 5. Namespace Resolution

**Problem:** `MessageMetaItem` is in `Dino.Ui.ConversationSummary` namespace, not `Dino.Ui`.

**Solution:** Use fully qualified type name:
```vala
ConversationSummary.MessageMetaItem? message_item = item as ConversationSummary.MessageMetaItem;
```

## Testing

### Manual Testing Checklist

- [ ] Launch Dino with modified build
- [ ] Open a conversation with existing messages
- [ ] Press `Ctrl++` multiple times - text should grow
- [ ] Press `Ctrl+-` multiple times - text should shrink
- [ ] Press `Ctrl+0` - text should return to default
- [ ] Close and reopen Dino - font size should persist
- [ ] Verify browser and other apps are unaffected
- [ ] Test with emoji-only messages (special scaling already exists)
- [ ] Test with /me messages (special formatting)
- [ ] Test in group chats (display names)

### Known Limitations

1. **Settings UI:** No graphical control in preferences window (keyboard shortcuts only)
2. **Per-conversation:** Font size is global, not per-conversation
3. **Minimum font size:** Very small scales (< 0.7) may be hard to read
4. **CSS approach:** Input area uses CSS, messages use Pango attributes (slight rendering differences possible)

### Bug Fixes

**Issue:** New messages appeared at default size while existing messages retained zoom level.

**Cause:** New `MessageMetaItem` instances were initialized with `font_scale = 1.0` and only updated when zoom shortcuts were pressed.

**Fix:** Modified constructor to read current font size from saved settings:
```vala
var app = GLib.Application.get_default() as Dino.Ui.Application;
font_scale = app != null ? app.settings.font_size : 1.0;
```

**Date Fixed:** March 20, 2026

## Future Improvements

1. **Preferences UI:** Add font size slider to Settings > General
2. **Per-conversation settings:** Allow different zoom levels per chat
3. **Help overlay:** Add shortcuts to help dialog (Ctrl+?)
4. **Mouse wheel zoom:** Ctrl+scroll to zoom
5. **Minimum font size enforcement:** Prevent scales that make text unreadable

## References

- [Dino GitHub Repository](https://github.com/dino/dino)
- [Dino Official Website](https://dino.im)
- [GTK4 Documentation](https://docs.gtk.org/gtk4/)
- [Pango Attribute Documentation](https://docs.gtk.org/Pango/)
- [Vala Language Documentation](https://docs.vala.dev/)
- [GitHub Issue #978](https://github.com/dino/dino/issues/978)

## License

This feature implementation follows Dino's license: **GPL-3.0**

---

**Author:** Implementation completed March 20, 2026
**Dino Version:** Based on master branch (commit varies)
**GTK Version:** GTK4 4.18.6
**libadwaita Version:** 1.7.6
**Last Updated:** March 20, 2026 (bug fix: new messages now use saved font size)
