using Gee;
using Gdk;
using Gtk;

using Dino.Entities;

namespace Dino.Ui {

[GtkTemplate (ui = "/im/dino/Dino/conversation_view.ui")]
public class ConversationView : Widget {

    [GtkChild] public unowned Revealer goto_end_revealer;
    [GtkChild] public unowned Button goto_end_button;
    [GtkChild] public unowned ChatInput.View chat_input;
    [GtkChild] public unowned ConversationSummary.ConversationView conversation_frame;
    [GtkChild] private unowned Box read_marker_box;
    [GtkChild] private unowned Image read_marker_icon;
    [GtkChild] private unowned Label read_marker_label;

    construct {
        this.layout_manager = new BinLayout();
    }
    
    public void update_read_marker(string? text) {
        if (text == null || text == "") {
            read_marker_box.visible = false;
        } else {
            read_marker_label.label = text;
            read_marker_box.visible = true;
        }
    }
}

}
