using Gtk;
using Gdk;

public class PlayerApp : Gtk.Application {
    private Jellyfin jf;
    private Gtk.Stack stack;

    public PlayerApp () {
        GLib.Object (application_id: "com.example.player");
    }

    protected override void activate () {
        jf = new Jellyfin (Config.JELLYFIN_URL, Config.JELLYFIN_KEY, Config.JELLYFIN_DEVICE);

        var window = new Gtk.ApplicationWindow (this) {
            title = "Player",
            default_width = Config.WINDOW_WIDTH,
            default_height = Config.WINDOW_HEIGHT,
            resizable = false
        };

        var key_controller = new Gtk.EventControllerKey ();
        key_controller.propagation_phase = Gtk.PropagationPhase.CAPTURE;
        (window as Gtk.Widget).add_controller (key_controller);
        key_controller.key_pressed.connect ((keyval, keycode, state) => {
            switch (keyval) {
                case Gdk.Key.q:
                    window.close ();
                    break;
                case Gdk.Key.F:
                case Gdk.Key.f:
                   if (stack.visible_child_name == "cava") {
                        stack.visible_child_name = "player";
                    } else if (stack.visible_child_name == "menu") {
                        stack.visible_child_name = "player";
                    } else {
                        stack.visible_child_name = "menu";
                    }
                    break;
                case Gdk.Key.g:
                    stack.visible_child_name = "cava";
                    break;
                case Gdk.Key.Left:
                    if (stack.visible_child_name == "player") {
                        SystemActions.change_volume (-5);
                    }
                    break;
                case Gdk.Key.Right:
                    if (stack.visible_child_name == "player") {
                        SystemActions.change_volume (5);
                    }
                    break;
                case Gdk.Key.a:
                case Gdk.Key.A:
                    jf.previous_track.begin ((obj, res) => {
                        try { jf.previous_track.end (res); } catch (Error e) {
                            warning ("previous_track error: %s", e.message);
                        }
                    });
                    break;
                case Gdk.Key.d:
                case Gdk.Key.D:
                    jf.next_track.begin ((obj, res) => {
                        try { jf.next_track.end (res); } catch (Error e) {
                            warning ("next_track error: %s", e.message);
                        }
                    });
                    break;
            }
            return false;
        });

        Style.apply ();

        var player_page = new PlayerPage (jf);
        var cava = Cava.create_terminal ();

        var menu_page = new MenuPage ();
        menu_page.page_requested.connect ((page_name) => {
            stack.visible_child_name = page_name;
        });

        stack = new Gtk.Stack ();
        stack.margin_top = 20;
        stack.margin_bottom = 20;
        stack.add_named (player_page, "player");
        stack.add_named (menu_page, "menu");
        stack.add_named (cava, "cava");
        stack.transition_type = Gtk.StackTransitionType.SLIDE_UP_DOWN;
        window.child = stack;
        window.present ();
    }

    public static int main (string[] args) {
        return new PlayerApp ().run (args);
    }
}
