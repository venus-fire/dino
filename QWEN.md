# Dino XMPP Client - Project Context

## Project Overview

**Dino** is a modern XMPP ("Jabber") instant messaging client for Linux, built with **GTK4** and **Vala**. It features a clean interface and supports:
- One-on-one and group chats
- End-to-end encryption (OMEMO, OpenPGP)
- File transfers
- Voice/video calls (via GStreamer)
- Message corrections and reactions

**This fork** includes an **AI-generated text zoom feature** (keyboard shortcuts: `Ctrl++`, `Ctrl+-`, `Ctrl+0`) that was implemented to address [GitHub issue #978](https://github.com/dino/dino/issues/978).

## Technology Stack

| Component | Technology |
|-----------|------------|
| **Language** | Vala |
| **UI Framework** | GTK4 + libadwaita (>= 1.5) |
| **Build System** | Meson + Ninja |
| **Database** | SQLite3 |
| **Encryption** | GPGME, libgcrypt, libomemo-c |
| **Media** | GStreamer 1.0 |
| **Network** | GLib, libsoup-3.0, libnice |

## Project Structure

```
dino/
├── libdino/          # Core library (entities, services, database)
├── main/             # Main application UI
│   └── src/ui/       # User interface components
├── plugins/          # Optional plugins
│   ├── omemo/        # OMEMO encryption
│   ├── openpgp/      # PGP encryption
│   ├── rtp/          # Voice/video calls
│   ├── ice/          # P2P communication
│   └── http-files/   # HTTP file upload
├── crypto-vala/      # Cryptography utilities
├── xmpp-vala/        # XMPP protocol implementation
├── qlite/            # SQLite ORM for Vala
└── build/            # Build output (generated)
```

## Building and Running

### Prerequisites (Debian/Ubuntu)

```bash
sudo apt-get install -y meson ninja-build valac \
    libgtk-4-dev libadwaita-1-dev libgee-0.8-dev libgpgme-dev libgcrypt20-dev \
    libsqlite3-dev libqrencode-dev libnice-dev libomemo-c-dev libsrtp2-dev \
    libsoup-3.0-dev libwebrtc-audio-processing-dev gettext libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev libgnutls28-dev libxml2-dev \
    libprotobuf-dev protobuf-compiler-grpc
```

### Build Commands

```bash
# Configure
meson setup build --prefix=$HOME/.local

# Compile
meson compile -C build

# Run without installing
./build/main/dino

# Install system-wide
sudo meson install -C build
sudo ldconfig
```

### Runtime Requirements

After installation, ensure the library path is configured:

```bash
# Add to /etc/ld.so.conf.d/venus-local.conf:
/home/venus/.local/lib/x86_64-linux-gnu

# Then run:
sudo ldconfig
```

## Zoom Feature (AI-Generated)

This fork adds a comprehensive text and UI zoom feature to address small, hard-to-read elements in chat conversations.

### Usage

| Shortcut | Action |
|----------|--------|
| `Ctrl` + `+` | Zoom in (+10%) |
| `Ctrl` + `=` | Zoom in (+10%, alternative) |
| `Ctrl` + `-` | Zoom out (-10%) |
| `Ctrl` + `0` | Reset to 100% |

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

**Note:** Avatar sizes reduced by 20% for better visual balance.

### Modified Files

| File | Changes |
|------|---------|
| `libdino/src/entity/settings.vala` | Added `font_size` setting (persisted to SQLite) |
| `main/src/ui/conversation_content_view/message_widget.vala` | Apply Pango scale to message labels |
| `main/src/ui/chat_input/chat_text_view.vala` | Apply CSS font scaling to input area |
| `main/src/ui/conversation_content_view/conversation_view.vala` | Apply CSS UI scaling (spacing, avatars, widgets) |
| `main/src/ui/conversation_selector/conversation_selector.vala` | Apply CSS UI scaling to sidebar |
| `main/src/ui/conversation_selector/conversation_selector_row.vala` | Apply per-row avatar scaling |
| `main/src/ui/conversation_view_controller.vala` | Add keyboard shortcut handlers and coordinate scaling |

### Technical Notes

- Font/UI scale range: 0.5–2.0 (50%–200%)
- Settings stored in `~/.local/share/dino/dino.db`
- Uses Pango attributes for text, CSS for UI elements
- GTK4-compatible implementation
- CSS `calc()` used for dynamic scaling of all measurements

> ⚠️ **Disclaimer:** This feature was entirely AI-generated ("vibe coded"). It's experimental and has not undergone human code review. Use at your own risk.

## Development Conventions

### Code Style

- **Vala naming:** CamelCase for classes, lowercase_with_underscores for variables
- **Namespaces:** `Dino.Entities`, `Dino.Ui`, `Dino.Plugins.*`
- **Error handling:** Use `try/catch` blocks; Vala has checked exceptions
- **Memory management:** Vala uses reference counting; watch for ownership transfers

### Key Patterns

1. **Settings:** Use `Dino.Entities.Settings` class with database persistence
2. **UI Components:** Extend GTK4 widgets; use `construct` blocks for initialization
3. **Plugins:** Implement plugin interfaces; register in `plugins/meson.build`
4. **Signals:** Use Vala's signal system for event handling

### Testing

No automated test suite is included. Manual testing is required:
- Build and run `./build/main/dino`
- Test XMPP connectivity, encryption, file transfers
- Verify zoom feature with various font sizes

## Common Tasks

### Add a new setting

```vala
// In libdino/src/entity/settings.vala
private bool my_setting_;
public bool my_setting {
    get { return my_setting_; }
    set {
        db.settings.upsert()
            .value(db.settings.key, "my_setting", true)
            .value(db.settings.value, value.to_string())
            .perform();
        my_setting_ = value;
    }
}
```

### Add a keyboard shortcut

```vala
// In conversation_view_controller.vala
Shortcut shortcut = new Shortcut(
    new KeyvalTrigger(Key.YourKey, ModifierType.CONTROL_MASK),
    new CallbackAction(() => {
        // Your action
        return true;
    })
);
((Gtk.Window)view.get_root()).add_shortcut(shortcut);
```

### Apply Pango attributes

```vala
var attrs = new AttrList();
attrs.insert(Pango.attr_scale_new(1.5));  // 150% scale
label.set_attributes(attrs);
```

## Debugging

Enable debug output:

```bash
G_MESSAGES_DEBUG=all ./build/main/dino
```

Or run with GDB:

```bash
gdb --args ./build/main/dino
```

## Resources

- **Official Website:** https://dino.im/
- **GitHub:** https://github.com/dino/dino
- **Wiki:** https://github.com/dino/dino/wiki
- **XMPP Chat:** `chat@dino.im`
- **License:** GPL-3.0

## Known Issues (Zoom Feature)

- No graphical settings UI (keyboard shortcuts only)
- Font size is global (not per-conversation)
- Minimal testing performed
- May have undiscovered bugs

---

**Last Updated:** March 20, 2026  
**Dino Version:** Master branch (fork with AI zoom feature)  
**GTK Version:** 4.18.6  
**libadwaita Version:** 1.7.6
