# Dino XMPP Client - Project Context

> **⚠️ AI INITIALIZATION: Read All Documentation First**
> 
> Before making any code changes or answering questions about this project:
> 
> 1. **Read all documentation files:**
>    - `README.md` - Feature overview and build instructions
>    - `FORK_STATUS.md` - Current fork status, upstream divergence, maintenance options
>    - `ZOOM_FEATURE_DOCUMENTATION.md` - Text zoom feature implementation
>    - `READ_RECEIPTS_FEATURE.md` - Read receipts user guide
>    - `READ_RECEIPTS_IMPLEMENTATION.md` - Read receipts technical details
>    - This file (`QWEN.md`) - Development context and conventions
> 
> 2. **Understand the current state:**
>    - Version: v0.4 (hover/click positioning fix)
>    - 14 commits ahead of upstream, 3 commits behind
>    - Key features: UI zoom, read receipts with XEP-0333, resizable sidebar
> 
> 3. **Check git status before changes:**
>    ```bash
>    git status && git log -n 3 --oneline
>    ```
> 
> 4. **Build and verify after changes:**
>    ```bash
>    meson compile -C build && ./build/main/dino
>    ```
> 
> **Do not proceed with code changes until you have read all relevant documentation.**

## Project Overview

**Dino** is a modern XMPP ("Jabber") instant messaging client for Linux, built with **GTK4** and **Vala**. It features a clean interface and supports:
- One-on-one and group chats
- End-to-end encryption (OMEMO, OpenPGP)
- File transfers
- Voice/video calls (via GStreamer)
- Message corrections and reactions
- Read receipts with visual indicators

**This fork** includes:
- **AI-generated text zoom feature** (keyboard shortcuts: `Ctrl++`, `Ctrl+-`, `Ctrl+0`) - addresses [GitHub issue #978](https://github.com/dino/dino/issues/978)
- **Visible read receipt indicators** - shows message status (sending, sent, delivered, read) for all sent messages
- **Resizable sidebar** - drag the right edge to resize

## Repository

| | |
|---|---|
| **Fork URL** | https://github.com/venus-fire/dino |
| **Upstream** | https://github.com/dino/dino |
| **License** | GPL-3.0 |

## GitHub Maintenance

### Release Workflow

```bash
# 1. Stage changes
git add <modified_files>

# 2. Commit with descriptive message
git commit -m "Add feature name

- Bullet point 1
- Bullet point 2

Feature: Brief description"

# 3. Create annotated tag
git tag -a vX.Y -m "Release title

Feature list:
- Feature 1
- Feature 2

Build: GTK4 X.X.X, libadwaita X.X.X"

# 4. Push to GitHub
git push origin master
git push origin vX.Y
```

### Version History

| Version | Date | Features |
|---------|------|----------|
| v0.4 | March 27, 2026 | Fixed hover/click positioning (GTK margin properties instead of CSS calc); reactions appear below messages |
| v0.3 | March 26, 2026 | Fixed read receipt positioning (checkmarks now appear directly after message text) |
| v0.2 | March 22, 2026 | Read receipt indicators, XEP-0333 support |
| v0.1 | March 20, 2026 | Text zoom feature, resizable sidebar |

### Syncing with Upstream

```bash
# Fetch upstream changes
git fetch upstream

# Rebase your master on upstream master
git checkout master
git rebase upstream/master

# Resolve conflicts if any, then force push
git push origin master --force-with-lease
```

### Creating a Release on GitHub

1. Go to https://github.com/venus-fire/dino/releases
2. Click "Draft a new release"
3. Select the tag (e.g., `v0.2`)
4. Add release notes from the tag message
5. Optionally attach build artifacts
6. Publish release

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

## Building and Installation

### Prerequisites (Debian/Ubuntu)

```bash
sudo apt-get install -y meson ninja-build valac \
    libgtk-4-dev libadwaita-1-dev libgee-0.8-dev libgpgme-dev libgcrypt20-dev \
    libsqlite3-dev libqrencode-dev libnice-dev libomemo-c-dev libsrtp2-dev \
    libsoup-3.0-dev libwebrtc-audio-processing-dev gettext libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev libgnutls28-dev libxml2-dev \
    libprotobuf-dev protobuf-compiler-grpc
```

### Build

```bash
# Configure
meson setup build

# Compile
meson compile -C build
```

### Run Without Installing

```bash
# Run directly from build folder
./build/main/dino
```

### Desktop Integration (Recommended)

To add Dino to your application menu:

1. **Copy the desktop file:**
   ```bash
   sudo cp main/data/im.dino.Dino.desktop /usr/share/applications/
   ```

2. **Edit the Exec line** to point to your build folder:
   ```bash
   sudo nano /usr/share/applications/im.dino.Dino.desktop
   ```
   
   Change:
   ```
   Exec=/home/venus/src/dino/build/main/dino %U
   ```

3. **Refresh desktop database:**
   ```bash
   sudo update-desktop-database
   ```

### Full System Installation (Optional)

```bash
# Install to /usr/local
sudo meson install -C build
sudo ldconfig

# Or install to local prefix
meson setup build --prefix=$HOME/.local
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
| `main/src/ui/conversation_content_view/conversation_view.vala` | Apply UI scaling; fixed hover detection using GTK allocation |
| `main/src/ui/conversation_content_view/conversation_item_skeleton.vala` | GTK margin-based scaling; fixed reaction positioning |
| `main/src/ui/conversation_selector/conversation_selector.vala` | Apply CSS UI scaling to sidebar |
| `main/src/ui/conversation_selector/conversation_selector_row.vala` | Apply per-row avatar scaling |
| `main/src/ui/conversation_view_controller.vala` | Add keyboard shortcut handlers and coordinate scaling |
| `main/src/ui/main_window.vala` | Add resizable sidebar (drag right edge to resize) |
| `main/data/style.css` | Removed conflicting CSS padding/margin rules |

### Technical Notes

- Font/UI scale range: 0.5–2.0 (50%–200%)
- Settings stored in `~/.local/share/dino/dino.db`
- Uses Pango attributes for text, GTK margin properties for UI layout
- GTK4-compatible implementation
- CSS `calc()` used only for non-layout properties (avatar sizes, reactions, etc.)
- Layout-critical spacing uses GTK `margin_*` properties for accurate hit detection

> ⚠️ **Disclaimer:** This feature was entirely AI-generated ("vibe coded"). It's experimental and has not undergone human code review. Use at your own risk.

## Read Receipts Feature

Visual indicators showing message delivery and read status for sent messages.

### Status Indicators

| Icon | Status | Description |
|------|--------|-------------|
| 🕐 Clock | Sending… | Message is being sent to server |
| ✓ Single tick | Sent/Delivered | Sent to server or delivered to client |
| ✓✓ Double tick | Read | Recipient has viewed the message |
| ⚠️ Warning | Error | Message failed to send |

### How It Works

1. **XEP-0333 Chat Markers** protocol is used for delivery/read notifications
2. **Both clients must support XEP-0333** (Dino, Gajim, Conversations on Android)
3. **Indicators are always visible** next to sent messages (not just in headers)
4. **Real-time updates** as message status changes
5. **Checkmarks appear directly after message text** using horizontal Box layout

### Modified Files

| File | Changes |
|------|---------|
| `main/src/ui/conversation_content_view/conversation_item_skeleton.vala` | Refactored layout to use horizontal Box; checkmarks positioned after message text |
| `main/src/ui/conversation_content_view/message_widget.vala` | Added read receipt indicator image and update logic |

### Technical Notes

- Works with 1-on-1 chats only (not group chats/MUC)
- Requires XEP-0333 support from recipient's client
- Uses `dino-tick-symbolic` and `dino-double-tick-symbolic` icons
- Message states: `NONE` → `SENT` → `RECEIVED` → `READ`

**Documentation:** See `READ_RECEIPTS_FEATURE.md` for full details.

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

### Official Dino
- **Website:** https://dino.im/
- **GitHub:** https://github.com/dino/dino
- **Wiki:** https://github.com/dino/dino/wiki
- **XMPP Chat:** `chat@dino.im`

### This Fork
- **GitHub:** https://github.com/venus-fire/dino
- **Releases:** https://github.com/venus-fire/dino/releases

### Documentation
- `README.md` - Project overview and build instructions
- `QWEN.md` - This file (development context)
- `ZOOM_FEATURE_DOCUMENTATION.md` - Text zoom feature details
- `READ_RECEIPTS_FEATURE.md` - Read receipts feature details

### Development
- **GTK4 Docs:** https://docs.gtk.org/gtk4/
- **libadwaita Docs:** https://gnome.pages.gitlab.gnome.org/libadwaita/doc/
- **Vala Docs:** https://docs.vala.dev/
- **XEP-0333:** https://xmpp.org/extensions/xep-0333.html (Chat Markers)

## Known Issues

### Zoom Feature
- No graphical settings UI (keyboard shortcuts only)
- Font size is global (not per-conversation)
- Minimal testing performed
- May have undiscovered bugs

### Read Receipts Feature
- Only works in 1-on-1 chats (not group chats)
- Requires recipient's client to support XEP-0333
- No settings UI toggle (uses global setting from Preferences)
- May not work with all XMPP servers

---

**Last Updated:** March 22, 2026  
**Dino Version:** v0.2 (fork with zoom + read receipts)  
**GTK Version:** 4.18.6  
**libadwaita Version:** 1.7.6
