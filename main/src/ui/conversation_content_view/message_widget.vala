using Gee;
using Gdk;
using Gtk;
using Pango;
using Xmpp;

using Dino.Entities;

namespace Dino.Ui.ConversationSummary {

public class MessageMetaItem : ContentMetaItem {

    enum AdditionalInfo {
        NONE,
        PENDING,
        DELIVERY_FAILED
    }

    private StreamInteractor stream_interactor;
    private MessageItem message_item;
    public Message.Marked marked { get; set; }
    public Plugins.ConversationItemWidgetInterface outer = null;

    // Font scale factor for text zoom (1.0 = 100%, range: 0.5 to 2.0)
    private double font_scale = 1.0;

    MessageItemEditMode? edit_mode = null;
    ChatTextViewController? controller = null;
    AdditionalInfo additional_info = AdditionalInfo.NONE;

    ulong realize_id = -1;
    ulong mark_notify_handler_id = -1;
    uint pending_timeout_id = -1;

    public Label label = new Label("") { use_markup=true, xalign=0, selectable=true, wrap=true, wrap_mode=Pango.WrapMode.WORD_CHAR, hexpand=true, vexpand=true };
    
    // Read receipt indicator (always visible for sent messages)
    private Image? read_receipt_indicator = null;

    public MessageMetaItem(ContentItem content_item, StreamInteractor stream_interactor) {
        base(content_item);
        message_item = content_item as MessageItem;
        this.stream_interactor = stream_interactor;

        // Initialize font scale from saved settings
        var app = GLib.Application.get_default() as Dino.Ui.Application;
        font_scale = app != null ? app.settings.font_size : 1.0;

        stream_interactor.get_module(MessageCorrection.IDENTITY).received_correction.connect(on_updated_item);
        stream_interactor.get_module(MessageDeletion.IDENTITY).item_deleted.connect(on_updated_item);

        label.activate_link.connect(on_label_activate_link);

        Message message = ((MessageItem) content_item).message;
        if (message.direction == Message.DIRECTION_SENT) {
            // Create read receipt indicator for sent messages
            create_read_receipt_indicator();
            
            // Listen to mark property changes (already bound from Message → MessageItem → ContentMetaItem)
            if (!(message.marked in Message.MARKED_RECEIVED)) {
                mark_notify_handler_id = this.notify["mark"].connect(() => {
                    // Currently "pending", but not anymore
                    if (additional_info == AdditionalInfo.PENDING &&
                            mark != Message.Marked.SENDING && mark != Message.Marked.UNSENT) {
                        update_label();
                    }

                    // Currently "error", but not anymore
                    if (additional_info == AdditionalInfo.DELIVERY_FAILED && mark != Message.Marked.ERROR) {
                        update_label();
                    }

                    // Currently not error, but should be
                    if (additional_info != AdditionalInfo.DELIVERY_FAILED && mark == Message.Marked.ERROR) {
                        update_label();
                    }

                    // Update read receipt indicator
                    update_read_receipt_indicator();

                    // Nothing bad can happen anymore
                    if (mark in Message.MARKED_RECEIVED) {
                        this.disconnect(mark_notify_handler_id);
                        mark_notify_handler_id = -1;
                    }
                });
            }
        }

        update_label();
        update_read_receipt_indicator();
    }
    
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
    
    private void update_read_receipt_indicator() {
        if (read_receipt_indicator == null) return;
        
        switch (mark) {
            case Message.Marked.RECEIVED:
                read_receipt_indicator.icon_name = "dino-tick-symbolic";
                read_receipt_indicator.set_tooltip_text(_("Delivered"));
                read_receipt_indicator.visible = true;
                break;
            case Message.Marked.READ:
                read_receipt_indicator.icon_name = "dino-double-tick-symbolic";
                read_receipt_indicator.set_tooltip_text(_("Read"));
                read_receipt_indicator.visible = true;
                break;
            case Message.Marked.SENT:
                read_receipt_indicator.icon_name = "dino-tick-symbolic";
                read_receipt_indicator.set_tooltip_text(_("Sent"));
                read_receipt_indicator.visible = true;
                break;
            case Message.Marked.SENDING:
            case Message.Marked.UNSENT:
                read_receipt_indicator.icon_name = "dino-clock-symbolic";
                read_receipt_indicator.set_tooltip_text(_("Sending…"));
                read_receipt_indicator.visible = true;
                break;
            case Message.Marked.ERROR:
            case Message.Marked.WONTSEND:
                read_receipt_indicator.icon_name = "dino-dialog-warning-symbolic";
                Util.force_error_color(read_receipt_indicator);
                read_receipt_indicator.set_tooltip_text(_("Unable to send message"));
                read_receipt_indicator.visible = true;
                break;
            default:
                read_receipt_indicator.visible = false;
                break;
        }
    }

    private void generate_markup_text(ContentItem item, Label label) {
        MessageItem message_item = item as MessageItem;
        Conversation conversation = message_item.conversation;
        Message message = message_item.message;

        // Get a copy of the markup spans, such that we can modify them
        var markups = new ArrayList<Xep.MessageMarkup.Span>();
        foreach (var markup in message.get_markups()) {
            markups.add(new Xep.MessageMarkup.Span() { types=markup.types, start_char=markup.start_char, end_char=markup.end_char });
        }

        string markup_text = message.body;

        var attrs = new AttrList();
        label.set_attributes(attrs);

        if (markup_text == null) return; // TODO remove

        // Only process messages up to a certain size
        if (markup_text.length > 10000) {
            markup_text = markup_text.substring(0, 10000) + " [" + _("Message too long") + "]";
        }

        bool theme_dependent = false;

        markup_text = Util.remove_fallbacks_adjust_markups(markup_text, message.quoted_item_id > 0, message.get_fallbacks(), markups);

        var bold_attr = Pango.attr_weight_new(Pango.Weight.BOLD);
        var italic_attr = Pango.attr_style_new(Pango.Style.ITALIC);
        var strikethrough_attr = Pango.attr_strikethrough_new(true);

        // Apply font scale to the entire message text
        var scale_attr = Pango.attr_scale_new((float)font_scale);
        scale_attr.start_index = 0;
        scale_attr.end_index = uint.MAX;
        attrs.insert(scale_attr.copy());

        // Prefix message with name instead of /me
        if (markup_text.has_prefix("/me ")) {
            string display_name = Util.get_participant_display_name(stream_interactor, conversation, message.from);
            markup_text = display_name + " " + markup_text.substring(4);

            foreach (Xep.MessageMarkup.Span span in markups) {
                int length = display_name.char_count() - 4 + 1;
                span.start_char += length;
                span.end_char += length;
            }

            bold_attr.end_index = display_name.length;
            italic_attr.end_index = display_name.length;
            attrs.insert(bold_attr.copy());
            attrs.insert(italic_attr.copy());
        }

        foreach (var markup in markups) {
            foreach (var ty in markup.types) {
                Attribute attr = null;
                switch (ty) {
                    case Xep.MessageMarkup.SpanType.EMPHASIS:
                        attr = Pango.attr_style_new(Pango.Style.ITALIC);
                        break;
                    case Xep.MessageMarkup.SpanType.STRONG_EMPHASIS:
                        attr = Pango.attr_weight_new(Pango.Weight.BOLD);
                        break;
                    case Xep.MessageMarkup.SpanType.DELETED:
                        attr = Pango.attr_strikethrough_new(true);
                        break;
                }
                attr.start_index = markup_text.index_of_nth_char(markup.start_char);
                attr.end_index = markup_text.index_of_nth_char(markup.end_char);
                attrs.insert(attr.copy());
            }
        }

        // Work around pango bug
        markup_text = Util.unbreak_space_around_non_spacing_mark((owned) markup_text);

        if (conversation.type_ == Conversation.Type.GROUPCHAT) {
            markup_text = Util.parse_add_markup_theme(markup_text, conversation.nickname, true, true, true, Util.is_dark_theme(this.label), ref theme_dependent);
        } else {
            markup_text = Util.parse_add_markup_theme(markup_text, null, true, true, true, Util.is_dark_theme(this.label), ref theme_dependent);
        }

        int only_emoji_count = Util.get_only_emoji_count(markup_text);
        if (only_emoji_count != -1) {
            string size_str = only_emoji_count < 5 ? "xx-large" : "large";
            markup_text = @"<span size=\'$size_str\'>" + markup_text + "</span>";
        }

        string dim_color = Util.is_dark_theme(this.label) ? "#BDBDBD" : "#707070";

        if (message.body == "") {
            markup_text = @"<i><span size='small' color='$dim_color'>%s</span></i>".printf(_("Message deleted"));
            theme_dependent = true;
        }
        if (message.edit_to != null) {
            markup_text += @"  <span size='small' color='$dim_color'>(%s)</span>".printf(_("edited"));
            theme_dependent = true;
        }

        // Append message status info
        additional_info = AdditionalInfo.NONE;
        if (message.direction == Message.DIRECTION_SENT && (message.marked == Message.Marked.SENDING || message.marked == Message.Marked.UNSENT)) {
            // Append "pending..." iff message has not been sent yet
            if (message.time.compare(new DateTime.now_utc().add_seconds(-10)) < 0) {
                markup_text += @"  <span size='small' color='$dim_color'>%s</span>".printf(_("pending…"));
                theme_dependent = true;
                additional_info = AdditionalInfo.PENDING;
            } else {
                int time_diff = (- (int) message.time.difference(new DateTime.now_utc()) / 1000);
                if (pending_timeout_id != -1) Source.remove(pending_timeout_id);
                pending_timeout_id = Timeout.add(10000 - time_diff, () => {
                    update_label();
                    pending_timeout_id = -1;
                    return false;
                });
            }
        } else if (message.direction == Message.DIRECTION_SENT && message.marked == Message.Marked.ERROR) {
            // Append "delivery failed" if there was a server error
            string error_color = Util.rgba_to_hex(Util.get_label_pango_color(label, "@error_color"));
            markup_text += "  <span size='small' color='%s'>%s</span>".printf(error_color, _("delivery failed"));
            theme_dependent = true;
            additional_info = AdditionalInfo.DELIVERY_FAILED;
        }

        if (theme_dependent && realize_id == -1) {
            realize_id = label.realize.connect(update_label);
        } else if (!theme_dependent && realize_id != -1) {
            label.disconnect(realize_id);
        }
        label.label = markup_text;
    }

    public void update_label() {
        generate_markup_text(content_item, label);
    }

    // Update font scale and refresh the label
    public void set_font_scale(double scale) {
        font_scale = scale;
        update_label();
    }

    public override Object? get_widget(Plugins.ConversationItemWidgetInterface outer, Plugins.WidgetType type) {
        this.outer = outer;

        this.notify["in-edit-mode"].connect(on_in_edit_mode_changed);

        // Create a horizontal box to hold the label and read receipt indicator
        var message_box = new Box(Orientation.HORIZONTAL, 6) {
            hexpand = true,
            halign = Align.START
        };
        message_box.append(label);
        
        // Add read receipt indicator if available (for sent messages)
        if (read_receipt_indicator != null) {
            message_box.append(read_receipt_indicator);
        }

        outer.set_widget(message_box, Plugins.WidgetType.GTK4, 2);

        if (message_item.message.quoted_item_id > 0) {
            var quoted_content_item = stream_interactor.get_module(ContentItemStore.IDENTITY).get_item_by_id(message_item.conversation, message_item.message.quoted_item_id);
            if (quoted_content_item != null) {
                var quote_model = new Quote.Model.from_content_item(quoted_content_item, message_item.conversation, stream_interactor);
                quote_model.jump_to.connect(() => {
                    GLib.Application.get_default().activate_action("jump-to-conversation-message", new GLib.Variant.tuple(new GLib.Variant[] { new GLib.Variant.int32(message_item.conversation.id), new GLib.Variant.int32(quoted_content_item.id) }));
                });
                var quote_widget = Quote.get_widget(quote_model);
                outer.set_widget(quote_widget, Plugins.WidgetType.GTK4, 1);
            }
        }
        return message_box;
    }

    public override Gee.List<Plugins.MessageAction>? get_item_actions(Plugins.WidgetType type) {
        if (in_edit_mode) return null;

        Gee.List<Plugins.MessageAction> actions = new ArrayList<Plugins.MessageAction>();

        bool correction_allowed = stream_interactor.get_module(MessageCorrection.IDENTITY).is_own_correction_allowed(message_item.conversation, message_item.message);
        if (correction_allowed) {
            Plugins.MessageAction action1 = new Plugins.MessageAction();
            action1.name = "correction";
            action1.icon_name = "dino-document-edit-symbolic";
            action1.tooltip = _("Edit message");
            action1.shortcut_action = false;
            action1.callback = () => {
                this.in_edit_mode = true;
            };
            actions.add(action1);
        }

        actions.add(get_reply_action(content_item, message_item.conversation, stream_interactor));
        actions.add(get_reaction_action(content_item, message_item.conversation, stream_interactor));

        var delete_action = get_delete_action(content_item, message_item.conversation, stream_interactor);
        if (delete_action != null) actions.add(delete_action);

        return actions;
    }

    private void on_in_edit_mode_changed() {
        if (in_edit_mode == false) return;
        bool allowed = stream_interactor.get_module(MessageCorrection.IDENTITY).is_own_correction_allowed(message_item.conversation, message_item.message);
        if (allowed) {
            MessageItem message_item = content_item as MessageItem;
            Message message = message_item.message;

            edit_mode = new MessageItemEditMode();
            controller = new ChatTextViewController(edit_mode.chat_text_view, stream_interactor);
            Conversation conversation = message_item.conversation;
            controller.initialize_for_conversation(conversation);

            edit_mode.cancelled.connect(() => {
                in_edit_mode = false;
                outer.set_widget(label, Plugins.WidgetType.GTK4, 2);
            });
            edit_mode.send.connect(() => {
                string text = edit_mode.chat_text_view.text_view.buffer.text;
                var markups = edit_mode.chat_text_view.get_markups();
                Dino.send_message(message_item.conversation, text, message_item.message.quoted_item_id, message_item.message, markups);

                in_edit_mode = false;
                outer.set_widget(label, Plugins.WidgetType.GTK4, 2);
            });

            edit_mode.chat_text_view.set_text(message);

            outer.set_widget(edit_mode, Plugins.WidgetType.GTK4, 2);
            edit_mode.chat_text_view.text_view.grab_focus();
        } else {
            this.in_edit_mode = false;
        }
    }

    private void on_updated_item(ContentItem content_item) {
        if (this.content_item.id == content_item.id) {
            this.content_item = content_item;
            message_item = content_item as MessageItem;
            update_label();
            update_read_receipt_indicator();
        }
    }

    public static bool on_label_activate_link(string uri) {
        // Always handle xmpp URIs with Dino
        if (!uri.has_prefix("xmpp:")) return false;
        File file = File.new_for_uri(uri);
        Dino.Application.get_default().open(new File[]{file}, "");
        return true;
    }

    public override void dispose() {
        stream_interactor.get_module(MessageCorrection.IDENTITY).received_correction.disconnect(on_updated_item);
        stream_interactor.get_module(MessageDeletion.IDENTITY).item_deleted.disconnect(on_updated_item);
        this.notify["in-edit-mode"].disconnect(on_in_edit_mode_changed);
        if (mark_notify_handler_id != -1) {
            this.disconnect(mark_notify_handler_id);
        }
        if (realize_id != -1) {
            label.disconnect(realize_id);
        }
        if (pending_timeout_id != -1) {
            Source.remove(pending_timeout_id);
        }
        if (label != null) {
            label.unparent();
            label.dispose();
            label = null;
        }
        if (read_receipt_indicator != null) {
            read_receipt_indicator.unparent();
            read_receipt_indicator.dispose();
            read_receipt_indicator = null;
        }
        base.dispose();
    }
}

[GtkTemplate (ui = "/im/dino/Dino/message_item_widget_edit_mode.ui")]
public class MessageItemEditMode : Box {

    public signal void cancelled();
    public signal void send();

    [GtkChild] public unowned MenuButton emoji_button;
    [GtkChild] public unowned ChatTextView chat_text_view;
    [GtkChild] public unowned Button cancel_button;
    [GtkChild] public unowned Button send_button;
    [GtkChild] public unowned Frame frame;

    construct {
        Util.force_css(frame, "* { border-radius: 3px; padding: 0px 7px; }");

        EmojiChooser chooser = new EmojiChooser();
        chooser.emoji_picked.connect((emoji) => {
            chat_text_view.text_view.buffer.insert_at_cursor(emoji, emoji.data.length);
        });
        emoji_button.set_popover(chooser);

        chat_text_view.text_view.buffer.changed.connect_after(on_text_view_changed);

        cancel_button.clicked.connect(() => cancelled());
        send_button.clicked.connect(() => send());
        chat_text_view.cancel_input.connect(() => cancelled());
        chat_text_view.send_text.connect(() => send());
    }

    private void on_text_view_changed() {
        send_button.sensitive = chat_text_view.text_view.buffer.text != "";
    }
}

}
