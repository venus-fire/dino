# Dino XMPP Client - Read Receipts Indicator Feature

## Overview

This document describes the read receipts indicator feature added to Dino XMPP client to provide visual feedback showing when sent messages have been delivered and read by the recipient.

## Problem Statement

While Dino had the underlying infrastructure for XEP-0333 Chat Markers (read receipts), the visual indicators were only shown in the message header skeleton, which is hidden for consecutive messages from the same sender (merged messages). This meant users couldn't see read status for most messages in an active conversation.

**GitHub Issue:** Read receipts not visible for merged messages

## Solution

A dedicated read receipt indicator was added directly to each sent message that:
- Is **always visible** for sent messages (not just in headers)
- Updates in real-time as message status changes
- Shows different icons for different states (sending, sent, delivered, read, error)
- Works independently of message merging/grouping

## Features

### Message Status Indicators

| Icon | Status | Description |
|------|--------|-------------|
| 🕐 Clock | Sending… | Message is being sent to the server |
| ✓ Single tick | Sent | Message has been sent to the server |
| ✓ Single tick | Delivered | Message has been delivered to the recipient's client |
| ✓✓ Double tick | Read | Recipient has opened/read the message |
| ⚠️ Warning | Error | Message failed to send |

### What Messages Show Indicators

✅ **Shows indicator:**
- All sent messages (1-on-1 chats)
- Messages in group chats from yourself (other devices)

❌ **Does not show indicator:**
- Received messages (incoming)
- System messages
- Group chat messages from others (XEP-0333 doesn't support MUC read receipts)

## Implementation Details

### Files Modified

| File | Changes |
|------|---------|
| `main/src/ui/conversation_content_view/conversation_item_skeleton.vala` | Refactored read receipt positioning to use horizontal Box layout; checkmarks now appear directly after message text |
| `main/src/ui/conversation_content_view/message_widget.vala` | Added read receipt indicator image and update logic |

### UI Layout

The read receipt indicator is positioned using a horizontal `Box` layout that contains both the message content and the checkmark icon:

```vala
// Message content box wraps message text + received_image
message_content_box = new Box(Orientation.HORIZONTAL, 6);
message_content_box.append(message_label);
message_content_box.append(received_image);  // Always appears after message text
```

This ensures the checkmarks stay aligned with the message text regardless of message merging.

### Key Changes

#### 1. New Private Field

```vala
// Read receipt indicator (always visible for sent messages)
private Image? read_receipt_indicator = null;
```

#### 2. Constructor Updates

```vala
Message message = ((MessageItem) content_item).message;
if (message.direction == Message.DIRECTION_SENT) {
    // Create read receipt indicator for sent messages
    create_read_receipt_indicator();
    
    // Bind to marked property for real-time updates
    if (!(message.marked in Message.MARKED_RECEIVED)) {
        var binding = message.bind_property("marked", this, "marked");
        // ... handler updates indicator when status changes
    }
}
update_read_receipt_indicator();
```

#### 3. New Methods

**`create_read_receipt_indicator()`** - Creates the image widget:
```vala
private void create_read_receipt_indicator() {
    read_receipt_indicator = new Image() {
        opacity = 0.5,
        pixel_size = 14,
        halign = Align.START,
        valign = Align.START,
        margin_top = 2
    };
    read_receipt_indicator.set_tooltip_text(_("Message status"));
}
```

**`update_read_receipt_indicator()`** - Updates icon based on message status:
```vala
private void update_read_receipt_indicator() {
    if (read_receipt_indicator == null) return;
    
    Message message = message_item.message;
    switch (message.marked) {
        case Message.Marked.RECEIVED:
            read_receipt_indicator.icon_name = "dino-tick-symbolic";
            read_receipt_indicator.set_tooltip_text(_("Delivered"));
            break;
        case Message.Marked.READ:
            read_receipt_indicator.icon_name = "dino-double-tick-symbolic";
            read_receipt_indicator.set_tooltip_text(_("Read"));
            break;
        // ... other states
    }
}
```

#### 4. Widget Layout Update

The `get_widget()` method now wraps the message label and read receipt indicator in a horizontal box:

```vala
var message_box = new Box(Orientation.HORIZONTAL, 6) {
    hexpand = true,
    halign = Align.START
};
message_box.append(label);

if (read_receipt_indicator != null) {
    message_box.append(read_receipt_indicator);
}

outer.set_widget(message_box, Plugins.WidgetType.GTK4, 2);
```

#### 5. Cleanup in `dispose()`

```vala
if (read_receipt_indicator != null) {
    read_receipt_indicator.unparent();
    read_receipt_indicator.dispose();
    read_receipt_indicator = null;
}
```

## Technical Notes

### XEP-0333 Chat Markers

The read receipts feature relies on **XEP-0333: Chat Markers** protocol support:
- Both sender and recipient clients must support XEP-0333
- The XMPP server must forward marker stanzas correctly
- Works best with 1-on-1 encrypted (OMEMO) chats

### Message States

The `Message.Marked` enum defines these states:

```vala
public enum Marked {
    NONE,        // No status information
    RECEIVED,    // Delivered to recipient's client
    READ,        // Recipient has viewed the message
    ACKNOWLEDGED,// Explicit acknowledgment (rarely used)
    UNSENT,      // Message not yet sent (queued)
    WONTSEND,    // Message will not be sent (cancelled)
    SENDING,     // Currently being sent
    SENT,        // Sent to server
    ERROR        // Failed to send
}
```

### Icon Resources

The feature uses these built-in GTK icon names:
- `dino-tick-symbolic` - Single checkmark
- `dino-double-tick-symbolic` - Double checkmark
- `dino-clock-symbolic` - Clock/pending
- `dino-dialog-warning-symbolic` - Error/warning

These icons must be available in the application's icon theme.

## Usage

### For Users

1. **Send a message** to another XEP-0333-capable client (e.g., another Dino user, Gajim, Conversations on Android)
2. **Watch the indicator** next to your message:
   - Clock icon appears while sending
   - Single tick when sent to server
   - Single tick changes when delivered to recipient
   - Double tick when recipient reads the message
3. **Hover over the icon** to see a tooltip with the current status

### For Developers

The read receipt indicator is automatically created for all sent messages. No additional configuration is needed.

To test:
```bash
# Build the project
meson compile -C build

# Run with debug output
G_MESSAGES_DEBUG=all ./build/main/dino
```

## Known Limitations

1. **Requires XEP-0333 support** - Both clients must implement chat markers
2. **No MUC support** - Group chat read receipts are not supported by XEP-0333
3. **Server dependency** - Some XMPP servers may not forward marker stanzas correctly
4. **Encryption compatibility** - May not work with all message encryption types
5. **No per-message control** - Users cannot disable read receipts for individual messages (only globally in settings)

## Comparison with Other Clients

| Client | Read Receipts | Visual Indicator |
|--------|---------------|------------------|
| **Dino (this fork)** | ✓ XEP-0333 | ✓ Always visible |
| Dino (original) | ✓ XEP-0333 | ⚠️ Header only |
| Gajim | ✓ XEP-0333 | ✓ Yes |
| Conversations (Android) | ✓ XEP-0333 | ✓ Yes |
| Pidgin | ✗ | ✗ |
| Xabber | ✓ | ✓ |

## Future Improvements

1. **Settings UI** - Add per-contact read receipt toggle in contact details
2. **Animation** - Smooth transition when status changes
3. **Color coding** - Different colors for different states
4. **Debug mode** - Show marker stanza exchange in developer tools
5. **Fallback indicators** - Show "sent" even without XEP-0333 (server acknowledgment)

## Testing Checklist

- [ ] Send message to another Dino user - verify double tick appears
- [ ] Send message to Gajim user - verify double tick appears
- [ ] Send message in group chat - verify no indicator (expected)
- [ ] Send message with poor connection - verify clock icon appears
- [ ] Send message that fails - verify warning icon appears
- [ ] Send multiple consecutive messages - verify all show indicators
- [ ] Hover over indicator - verify tooltip shows correct status
- [ ] Restart app - verify indicators persist correctly

## References

- [XEP-0333: Chat Markers](https://xmpp.org/extensions/xep-0333.html)
- [Dino GitHub Repository](https://github.com/dino/dino)
- [Dino Official Website](https://dino.im)
- [GTK4 Image Widget Documentation](https://docs.gtk.org/gtk4/class.Image.html)

## License

This feature implementation follows Dino's license: **GPL-3.0**

---

**Author:** Implementation completed March 22, 2026  
**Dino Version:** Based on master branch (commit varies)  
**GTK Version:** GTK4 4.18.6  
**libadwaita Version:** 1.7.6  
**Last Updated:** March 22, 2026
