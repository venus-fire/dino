using Gee;
using Gdk;
using Gtk;

using Dino.Entities;

namespace Dino.Ui {

[GtkTemplate (ui = "/im/dino/Dino/main_window.ui")]
public class MainWindow : Adw.ApplicationWindow {

    public signal void conversation_selected(Conversation conversation);

    [GtkChild] public Stack stack;
    [GtkChild] public Adw.NavigationSplitView navigation_split_view;

    [GtkChild] public MenuButton add_button;
    [GtkChild] public MenuButton menu_button;

    [GtkChild] public Adw.HeaderBar conversation_headerbar;
    [GtkChild] public Adw.WindowTitle conversation_window_title;

    [GtkChild] public ConversationView conversation_view;
    [GtkChild] public ConversationSelector conversation_selector;
    [GtkChild] public Adw.Flap search_flap;
    [GtkChild] private Stack left_stack;
    [GtkChild] private Stack right_stack;
    [GtkChild] public Adw.Bin search_frame;

    public GlobalSearch global_search;

    public WelcomePlaceholder welcome_placeholder = new WelcomePlaceholder();
    public NoAccountsPlaceholder accounts_placeholder = new NoAccountsPlaceholder();

    private Database db;
    private Config config;

    class construct {
        var shortcut = new Shortcut(new KeyvalTrigger(Key.F, ModifierType.CONTROL_MASK), new CallbackAction((widget, args) => {
            ((MainWindow) widget).search_flap.reveal_flap = true;
            ((MainWindow) widget).navigation_split_view.show_content = true;
            return false;
        }));
        add_shortcut(shortcut);
    }

    // Sidebar resize with mouse drag
    private bool sidebar_resizing = false;
    private double sidebar_resize_start_x = 0;
    private double sidebar_resize_start_fraction = 0;
    
    private void setup_sidebar_resize() {
        // Wait for widgets to be realized
        Timeout.add(500, () => {
            if (conversation_selector == null) return true;
            
            // Find the ScrolledWindow parent - it might be nested
            Widget? parent = conversation_selector.get_parent();
            Gtk.ScrolledWindow? scrolled = null;
            
            while (parent != null && scrolled == null) {
                if (parent is Gtk.ScrolledWindow) {
                    scrolled = parent as Gtk.ScrolledWindow;
                    break;
                }
                parent = parent.get_parent();
            }
            
            if (scrolled == null) {
                warning("Could not find ScrolledWindow parent for conversation_selector");
                return false;
            }
            
            // Add motion controller to detect when mouse is at sidebar edge
            var motion_controller = new Gtk.EventControllerMotion();
            motion_controller.motion.connect((x, y) => {
                // Show resize cursor at right edge of sidebar (within 8 pixels)
                double sidebar_width = scrolled.get_allocated_width();
                if (x >= sidebar_width - 8 && x <= sidebar_width) {
                    scrolled.set_cursor_from_name("col-resize");
                } else {
                    scrolled.set_cursor_from_name("default");
                }
            });
            motion_controller.leave.connect(() => {
                scrolled.set_cursor_from_name("default");
            });
            scrolled.add_controller(motion_controller);
            
            // Add click gesture for resizing
            var click_gesture = new Gtk.GestureClick();
            click_gesture.pressed.connect((n_press, x, y) => {
                double sidebar_width = scrolled.get_allocated_width();
                // Check if click is at the right edge (within 12 pixels for easier grabbing)
                if (x >= sidebar_width - 12 && x <= sidebar_width + 4) {
                    sidebar_resizing = true;
                    // Store the offset from the edge where the user clicked
                    sidebar_resize_start_x = x - sidebar_width;
                    sidebar_resize_start_fraction = navigation_split_view.sidebar_width_fraction;
                    stderr.printf("DEBUG: Resize START - fraction=%.3f, sidebar_width=%.1f, click_offset=%.1f\n", 
                        sidebar_resize_start_fraction, sidebar_width, sidebar_resize_start_x);
                    // Temporarily expand min/max to allow resizing
                    navigation_split_view.min_sidebar_width = 150;
                    navigation_split_view.max_sidebar_width = 800;
                }
            });
            scrolled.add_controller(click_gesture);
            
            // Add motion controller for drag
            var drag_motion = new Gtk.EventControllerMotion();
            drag_motion.motion.connect((x, y) => {
                if (sidebar_resizing) {
                    double window_width = navigation_split_view.get_allocated_width();
                    // Calculate new sidebar width: current mouse position minus the offset where user grabbed
                    double new_sidebar_width = x - sidebar_resize_start_x;
                    // Convert to fraction
                    double new_fraction = new_sidebar_width / window_width;
                    new_fraction = new_fraction.clamp(0.15, 0.5);
                    stderr.printf("DEBUG: Resize DRAG - mouse_x=%.1f, offset=%.1f, new_width=%.1f, fraction=%.3f\n", 
                        x, sidebar_resize_start_x, new_sidebar_width, new_fraction);
                    navigation_split_view.sidebar_width_fraction = new_fraction;
                }
            });
            scrolled.add_controller(drag_motion);
            
            // Add release controller
            var release_controller = new Gtk.GestureClick();
            release_controller.released.connect((n_press, x, y) => {
                stderr.printf("DEBUG: Resize RELEASE\n");
                sidebar_resizing = false;
            });
            scrolled.add_controller(release_controller);
            
            return false;
        });
    }

    public MainWindow(Application application, StreamInteractor stream_interactor, Database db, Config config) {
        Object(application : application);
        this.db = db;
        this.config = config;

        this.title = "Dino";

        this.add_css_class("dino-main");

        ((Widget)this).realize.connect(restore_window_size);

        // Setup sidebar resize after UI is constructed
        Timeout.add(100, () => {
            setup_sidebar_resize();
            return false;
        });

        conversation_selector.init(stream_interactor);
        conversation_selector.conversation_selected.connect_after(() => { navigation_split_view.show_content = true; });

        global_search = new GlobalSearch(stream_interactor);
        search_frame.set_child(global_search.get_widget());

        create_add_menu(add_button, menu_button);

        stack.add_named(welcome_placeholder, "welcome_placeholder");
        stack.add_named(accounts_placeholder, "accounts_placeholder");
    }

    public enum StackState {
        CLEAN_START,
        NO_ACTIVE_ACCOUNTS,
        NO_ACTIVE_CONVERSATIONS,
        CONVERSATION
    }

    public void set_stack_state(StackState stack_state) {
        if (stack_state == StackState.CONVERSATION) {
            left_stack.set_visible_child_name("content");
            right_stack.set_visible_child_name("content");
            stack.set_visible_child_name("main");
        } else if (stack_state == StackState.CLEAN_START) {
            stack.set_visible_child_name("welcome_placeholder");
        } else if (stack_state == StackState.NO_ACTIVE_ACCOUNTS) {
            stack.set_visible_child_name("accounts_placeholder");
        } else if (stack_state == StackState.NO_ACTIVE_CONVERSATIONS) {
            stack.set_visible_child_name("main");
            left_stack.set_visible_child_name("placeholder");
            right_stack.set_visible_child_name("placeholder");
        }
    }

    public void loop_conversations(bool backwards) {
        conversation_selector.loop_conversations(backwards);
    }

    public void restore_window_size() {
        Gdk.Display? display = Gdk.Display.get_default();
        if (display != null) {
            Gdk.Surface? surface = get_surface();
            Gdk.Monitor? monitor = display.get_monitor_at_surface(surface);

            if (monitor != null &&
                    config.window_width <= monitor.geometry.width &&
                    config.window_height <= monitor.geometry.height) {
                set_default_size(config.window_width, config.window_height);
            }
        }
        if (config.window_maximize) {
            maximize();
        }

        ((Widget)this).unrealize.connect(() => {
            save_window_size();
            config.window_maximize = this.maximized;
        });
    }

    public void save_window_size() {
        if (this.maximized) return;

        Gdk.Display? display = get_display();
        Gdk.Surface? surface = get_surface();
        if (display != null && surface != null) {
            Gdk.Monitor monitor = display.get_monitor_at_surface(surface);

            // Only store if the values have changed and are reasonable-looking.
            if (config.window_width != default_width && default_width > 0 && default_width <= monitor.geometry.width) {
                config.window_width = default_width;
            }
            if (config.window_height != default_height && default_height > 0 && default_height <= monitor.geometry.height) {
                config.window_height = default_height;
            }
        }
    }

    private static void create_add_menu(MenuButton add_button, MenuButton menu_button) {
        add_button.tooltip_text = Util.string_if_tooltips_active(_("Start Conversation"));

        Builder add_builder = new Builder.from_resource("/im/dino/Dino/menu_add.ui");
        MenuModel add_menu_model = add_builder.get_object("menu_add") as MenuModel;
        add_button.set_menu_model(add_menu_model);

        Builder menu_builder = new Builder.from_resource("/im/dino/Dino/menu_app.ui");
        MenuModel menu_menu_model = menu_builder.get_object("menu_app") as MenuModel;
        menu_button.set_menu_model(menu_menu_model);
    }
}

public class WelcomePlaceholder : MainWindowPlaceholder {
    public WelcomePlaceholder() {
        status_page.title = _("Welcome to Dino!");
        status_page.description = _("Sign in or create an account to get started.");
        primary_button.label = _("Set up account");
        primary_button.visible = true;
    }
}

public class NoAccountsPlaceholder : MainWindowPlaceholder {
    public NoAccountsPlaceholder() {
        status_page.title = _("No active accounts");
        primary_button.label = _("Manage accounts");
        primary_button.visible = true;
    }
}

[GtkTemplate (ui = "/im/dino/Dino/main_window_placeholder.ui")]
public class MainWindowPlaceholder : Box {
    [GtkChild] public unowned Adw.StatusPage status_page;
    [GtkChild] public unowned Button primary_button;
    [GtkChild] public unowned Button secondary_button;
}

}
