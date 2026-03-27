# Read Receipts Implementation - Technical Documentation

## Overview

Dino implements XEP-0333 Chat Markers for read receipts. This document explains how the system actually works, based on reverse-engineering the codebase.

## Architecture

### Message Flow

```
User sends message → Message created → MessageItem → ContentMetaItem → MessageMetaItem (UI widget)
                                              ↓
                                    MessageItem.bind_property("marked" → "mark")
                                              ↓
                                    ContentMetaItem.bind_property("mark" → "item-mark")
                                              ↓
                                    ConversationItemSkeleton updates UI
```

### Key Classes

#### 1. `Entities.Message` (libdino/src/entity/message.vala)

The core message entity with a `marked` property:

```vala
public enum Marked {
    NONE,           // No status yet
    RECEIVED,       // Server received (delivery receipt)
    READ,           // User has seen the message (read receipt)
    ACKNOWLEDGED,   // Acknowledged by client
    UNSENT,         // Not sent yet (draft)
    WONTSEND,       // Won't be sent (error)
    SENDING,        // Currently sending
    SENT,           // Sent to server
    ERROR           // Failed to send
}

public static Marked[] MARKED_RECEIVED = new Marked[] { 
    Marked.READ, Marked.RECEIVED, Marked.ACKNOWLEDGED 
};
```

**Important:** The `marked` property has special logic:
```vala
set {
    if (value == Marked.RECEIVED && marked == Marked.READ) return;
    marked_ = value;
}
```
This prevents downgrading from READ back to RECEIVED.

#### 2. `MessageItem` (libdino/src/service/content_item_store.vala)

Wraps `Message` for the content store. Binds to Message.marked:

```vala
public MessageItem(Message message, Conversation conversation, int id) {
    base(id, TYPE, message.from, message.time, message.encryption, message.marked);
    this.message = message;
    this.conversation = conversation;
    message.bind_property("marked", this, "mark");  // One-way binding
}
```

#### 3. `ContentMetaItem` (main/src/ui/conversation_content_view/content_populator.vala)

UI wrapper that binds to MessageItem.mark:

```vala
public ContentMetaItem(ContentItem content_item) {
    this.mark = content_item.mark;
    content_item.bind_property("mark", this, "mark");  // One-way binding
}
```

#### 4. `ConversationItemSkeleton` (main/src/ui/conversation_content_view/conversation_item_skeleton.vala)

The actual UI widget that displays messages. Has:
- `encryption_image` - Lock icon (encryption status)
- `received_image` - Checkmark icon (read receipt)

**Critical behavior:** When messages are "merged" (consecutive from same sender), `show_skeleton = false` hides:
- Avatar
- Name label
- Timestamp
- Encryption icon
- **Received icon** ← This was a bug we fixed

#### 5. `ChatInteraction` (libdino/src/service/chat_interaction.vala)

Handles sending chat markers (XEP-0333):

```vala
// When message is displayed (user sees it)
send_chat_marker(message, null, selected_conversation, Xep.ChatMarkers.MARKER_DISPLAYED);

// When message is received (server delivers)
send_chat_marker(message, stanza, conversation, Xep.ChatMarkers.MARKER_RECEIVED);
```

#### 6. `CounterpartInteractionManager` (libdino/src/service/counterpart_interaction_manager.vala)

Processes incoming chat markers from other clients:

```vala
case Xep.ChatMarkers.MARKER_RECEIVED:
    message.marked = Entities.Message.Marked.RECEIVED;
    
case Xep.ChatMarkers.MARKER_DISPLAYED:
    // Upgrade all RECEIVED messages to READ
    foreach (Message m in messages) {
        if (m.marked == Entities.Message.Marked.RECEIVED) 
            m.marked = Entities.Message.Marked.READ;
    }
    message.marked = Entities.Message.Marked.READ;
```

## Current Implementation Status

### What Works (Updated)

1. **Checkmarks next to encryption lock** - Shows full message status progression:
   - No icon = Message is being sent (UNSENT/SENDING)
   - Single tick (✓) = Sent to server (SENT)
   - Saving icon (↓) = Still sending (SENDING/UNSENT)
   - Double tick (✓✓) = Delivered to recipient (RECEIVED) or Read (READ)
   - Warning icon (⚠️) = Failed to send (ERROR/WONTSEND)

2. **"Read up to this point" bar** - Shows at bottom of conversation:
   - Only appears when at least one message has been READ (not just delivered)
   - Shows "%s has read up to this point" for 1-on-1 chats
   - Shows "Read up to this point" for group chats
   - Hidden when no messages have been read yet

3. **Merged message handling** - Checkmarks visible even when avatars/names hidden

4. **Real-time updates** - Marks update when:
   - Switching between conversations
   - New messages arrive
   - Message status changes (via notify signal)

### Status Mapping

| Message.Marked | Icon | Tooltip | When |
|----------------|------|---------|------|
| UNSENT | ↓ | "Sending…" | Message created, not yet sending |
| SENDING | ↓ | "Sending…" | Currently transmitting |
| SENT | ✓ | "Sent" | Server acknowledged receipt |
| RECEIVED | ✓✓ | "Delivered" | Recipient's client received it |
| READ | ✓✓ | "Read" | Recipient opened the conversation |
| ACKNOWLEDGED | ✓✓ | "Read" | Recipient acknowledged (rare) |
| ERROR | ⚠️ | "Unable to send message" | Failed to send |
| WONTSEND | ⚠️ | "Unable to send message" | Won't be sent |

### Known Limitations

1. **No visual distinction between RECEIVED and READ** - Both show double tick
   - Reason: XEP-0333 doesn't provide a separate "read" visual indicator
   - The "Read up to this point" bar indicates actual reading

2. **Automatic updates may be delayed** - Depends on GTK property binding propagation
   - Working: Switching conversations triggers update
   - Working: New message arrival triggers update
   - May need: Explicit `notify["marked"]` signal connection for instant updates

3. **No per-recipient tracking in group chats** - Shows generic "Read up to this point"
   - Would need significant architecture changes for MUC read receipts

## Why Automatic Updates Didn't Work (FIXED)

### The Problem (RESOLVED)

When a message's `marked` property changed:
1. `Message.marked` setter was called
2. **No signal was emitted** ← This was the bug
3. Property bindings couldn't propagate the change
4. UI never updated

### Root Cause

The `Message.marked` property didn't have the `[Notify]` attribute:

```vala
// BEFORE (broken)
public Marked marked {
    get { return marked_; }
    set {
        if (value == Marked.RECEIVED && marked == Marked.READ) return;
        marked_ = value;
    }
}

// AFTER (fixed)
[Notify]
public Marked marked {
    get { return marked_; }
    set {
        if (value == Marked.RECEIVED && marked == Marked.READ) return;
        marked_ = value;
    }
}
```

### Additional Fixes

1. **Merged messages not updating** - `set_header()` returned early for merged messages, so mark binding was never set up
   - **Fix:** Created separate `setup_mark_binding()` method called for ALL messages

2. **Read bar not updating** - Only listened to last message's `marked` property
   - **Fix:** Listen to ALL sent messages in the conversation

3. **GTK warnings** - `[GtkChild]` fields missing `unowned` keyword
   - **Fix:** Added `unowned` to all `[GtkChild]` declarations

### The Binding Chain (Now Working)

When a message's `marked` property changes:
1. `Message.marked` setter is called
2. Vala emits `notify["marked"]` signal (due to `[Notify]` attribute)
3. Property binding propagates to `MessageItem.mark`
4. Another binding propagates to `ContentMetaItem.mark`
5. `ConversationItemSkeleton` updates via `notify["item-mark"]`
6. `update_received_mark()` and `update_margin()` are called
7. UI shows correct icon

The bindings are set up correctly:
```vala
// Message → MessageItem
message.bind_property("marked", this, "mark");

// MessageItem → ContentMetaItem
content_item.bind_property("mark", this, "mark");

// ContentMetaItem → ConversationItemSkeleton
item.bind_property("mark", this, "item-mark", BindingFlags.SYNC_CREATE);
```

## UI Structure

### conversation_view.ui

```
GtkBox (vertical)
├── GtkOverlay
│   └── ConversationView (conversation_frame)
│       └── Messages...
├── GtkBox (read_marker_box) ← NEW
│   ├── GtkImage (double-tick icon)
│   └── GtkLabel ("%s has read up to this point")
└── ChatInputView (chat_input)
```

### Message Row Structure

```
GtkGrid (main_grid)
├── Avatar (row 0, rowspan 2)
├── Name label (row 0)
├── Timestamp (row 0)
├── Encryption icon (row 0)
└── Box (row 1) ← NEW: Horizontal box containing:
    ├── Message content widget
    └── Received icon (checkmarks) ← Always appears after message text
```

When `show_skeleton = false` (merged messages):
- Avatar, name, timestamp, encryption icon are hidden
- Message content box remains visible with checkmarks directly after text

## XEP-0333 Chat Markers

### Marker Types

| Marker | XML | Meaning | Dino Display |
|--------|-----|---------|--------------|
| `received` | `<received xmlns="urn:xmpp:chat-markers:0"/>` | Server delivered | Single tick |
| `displayed` | `<displayed xmlns="urn:xmpp:chat-markers:0"/>` | User saw message | Double tick |
| `acknowledged` | `<acknowledged xmlns="urn:xmpp:chat-markers:0"/>` | User acknowledged | (not used) |

### When Markers Are Sent

**Received (delivery receipt):**
- When message arrives and client is NOT focused on conversation
- Sent immediately upon receipt

**Displayed (read receipt):**
- When user focuses on conversation AND there's a message to mark
- Sent when user scrolls to see the message

### Marker Flow Example

```
Alice sends "Hello"
├─→ Bob's server receives (no marker yet)
├─→ Bob's client receives (not focused)
│   └─→ Sends <received/> back to Alice
│       └─→ Alice sees: ✓ (delivered)
└─→ Bob opens conversation
    └─→ Sends <displayed/> back to Alice
        └─→ Alice sees: ✓✓ (read)
```

## Database Schema

Messages stored in `~/.local/share/dino/dino.db`:

```sql
CREATE TABLE message (
    id INTEGER PRIMARY KEY,
    account_id INTEGER,
    stanza_id TEXT,
    server_id TEXT,
    type INTEGER,
    counterpart_id INTEGER,
    counterpart_resource TEXT,
    our_resource TEXT,
    direction INTEGER,
    time INTEGER,
    local_time INTEGER,
    body TEXT,
    encryption INTEGER,
    marked INTEGER  -- ← Message.Marked enum value
);

CREATE INDEX message_account_marked_idx ON message(account_id, marked);
```

## Testing Checklist

- [ ] Send message to another Dino user
- [ ] Verify single tick appears when delivered
- [ ] Verify double tick appears when they read it
- [ ] Switch conversations and verify marks update
- [ ] Send message while recipient is offline
- [ ] Verify marks update when they come online
- [ ] Test in group chats (should show "Read up to this point")
- [ ] Test with Gajim/Conversations (cross-client compatibility)

## Files Modified

| File | Purpose |
|------|---------|
| `libdino/src/entity/message.vala` | Added `[Notify]` attribute to `marked` property to emit change signals |
| `main/src/ui/conversation_content_view/conversation_item_skeleton.vala` | Added SENT/SENDING status handling in `update_received_mark()` |
| `main/src/ui/conversation_content_view/conversation_item_skeleton.vala` | Created `setup_mark_binding()` for all messages (including merged) |
| `main/src/ui/conversation_content_view/conversation_item_skeleton.vala` | Fixed `update_margin()` to always show received_image for sent messages |
| `main/src/ui/conversation_content_view/conversation_item_skeleton.vala` | Added `update_margin()` call in mark notify handler |
| `main/src/ui/conversation_content_view/conversation_item_skeleton.vala` | **Refactored layout**: Use horizontal Box to position checkmarks directly after message text |
| `main/data/conversation_view.ui` | Added read_marker_box UI element between messages and chat input |
| `main/src/ui/conversation_view.vala` | Added `update_read_marker()` method and widget references |
| `main/src/ui/conversation_view_controller.vala` | Added read marker tracking with notify handlers for ALL sent messages |
| `main/src/ui/conversation_view_controller.vala` | Fixed `update_read_marker()` to only show for READ messages |
| `main/src/ui/main_window.vala` | Added `unowned` to all `[GtkChild]` fields to fix warnings |

## Future Improvements

1. **Per-message read receipts** - Show who read each message in group chats
2. **Read receipt details popup** - Click checkmark to see detailed status
3. **Animation on status change** - Visual feedback when mark updates
4. **Settings toggle** - Allow users to disable sending read receipts
5. **XEP-0333 compliance** - Send displayed markers when scrolling, not just on focus
