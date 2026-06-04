using Gtk;
using Soup;
using Json;
using Gdk;
using Vte;

public class PlayerApp : Gtk.Application {
    private Jellyfin jf;
    private Gtk.Stack stack;
    private Gtk.Picture album_art;
    private Gtk.Label title_label;
    private Gtk.Label artist_label;
    private Gtk.Label album_label;
    private Gtk.ProgressBar progress;
    private Gtk.Label codec_label;
    private Gtk.Button play_button;
    private string? current_art_url = null;

    public PlayerApp () {
        GLib.Object (application_id: "com.example.player");
    }

    protected override void activate () {
        jf = new Jellyfin ("https://jf.kios.ovh", "d761990c50a949e4811df7fcad6edfe4", "test-device");

        var window = new Gtk.ApplicationWindow (this) {
            title = "Player",
            default_width = 1920,
            default_height = 480,
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
                        change_volume (-5);
                    }
                    break;
                case Gdk.Key.Right:
                    if (stack.visible_child_name == "player") {
                        change_volume (5);
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

        var css = new Gtk.CssProvider ();
        css.load_from_data ("""
            * {
                font-family: "CaskaydiaCove Nerd Font";
                font-size: 1.2em;
            }
            window {
                background: radial-gradient(circle at center, #1a1a1e, #000000);
            }
            .play-button {
                -gtk-icon-size: 32px;
                padding: 0;
            }
        """.data);

        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        var main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        // main_box.margin_top = 20;
        // main_box.margin_bottom = 20;

        // --- LEFT: Album art ---
        var art_container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        art_container.set_size_request (480, 480);
        art_container.overflow = Gtk.Overflow.HIDDEN;
        art_container.margin_top = 16;
        art_container.margin_bottom = 16;
        art_container.margin_start = 16;
        art_container.margin_end = 16;


        album_art = new Gtk.Picture ();
	album_art.keep_aspect_ratio = true;
        // album_art.content_fit = Gtk.ContentFit.CONTAIN;
        album_art.hexpand = true;
        album_art.vexpand = true;
        art_container.append (album_art);

        // --- MIDDLE: Title, artist, album, progress, play button ---
        var middle_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        middle_box.hexpand = false;
        middle_box.set_size_request (800, -1);
        middle_box.valign = Gtk.Align.CENTER;
        middle_box.margin_start = 40;
        middle_box.margin_end = 40;

        title_label = new Gtk.Label ("Title");
        title_label.xalign = 0;
        title_label.add_css_class ("title-1");
        title_label.ellipsize = Pango.EllipsizeMode.END;
        title_label.max_width_chars = 1;  // forces ellipsize to kick in
        title_label.hexpand = true;

        artist_label = new Gtk.Label ("Artist");
        artist_label.xalign = 0;
        artist_label.add_css_class ("title-3");
        artist_label.ellipsize = Pango.EllipsizeMode.END;
        artist_label.max_width_chars = 1;
        artist_label.hexpand = true;

        album_label = new Gtk.Label ("Album");
        album_label.xalign = 0;
        album_label.ellipsize = Pango.EllipsizeMode.END;
        album_label.max_width_chars = 1;
        album_label.hexpand = true;

        progress = new Gtk.ProgressBar ();
        progress.fraction = 0.0;

        play_button = new Gtk.Button ();
        play_button.icon_name = "media-playback-start-symbolic";
        play_button.halign = Gtk.Align.CENTER;
        play_button.add_css_class ("flat");
        // play_button.add_css_class ("suggested-action");
        play_button.add_css_class ("play-button");
        play_button.clicked.connect (() => {
            jf.next_track.begin ((obj, res) => {
                try { jf.next_track.end (res); } catch (Error e) {
                    warning ("next_track error: %s", e.message);
                }
            });
        });

        middle_box.append (title_label);
        middle_box.append (artist_label);
        middle_box.append (album_label);
        middle_box.append (progress);
        middle_box.append (play_button);

        // --- RIGHT: Codec info ---
        var right_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
        right_box.set_size_request (320, -1);
        right_box.valign = Gtk.Align.CENTER;
        right_box.margin_end = 32;
        right_box.margin_start = 16;

        codec_label = new Gtk.Label ("");
        codec_label.xalign = 0;
        codec_label.add_css_class ("title-3");
        codec_label.wrap = true;

        right_box.append (codec_label);

        main_box.append (art_container);
        main_box.append (middle_box);
        main_box.append (right_box);

        var cava = new Vte.Terminal ();
        cava.spawn_async (
            Vte.PtyFlags.DEFAULT,
            null,                        // working directory
            // { "/bin/bash", "-c", "cava" }, // command + args
            { "cava"},
            null,                        // environment
            GLib.SpawnFlags.SEARCH_PATH,
            null,                        // child setup
            -1,                          // timeout
            null,                        // cancellable
            (terminal, pid, error) => {
                if (error != null)
                    warning ("Spawn error: %s", error.message);
            }
        );

        var menu_page = new MenuPage ();
        menu_page.page_requested.connect ((page_name) => {
            stack.visible_child_name = page_name;
        });

        stack = new Gtk.Stack ();
        stack.margin_top = 20;
        stack.margin_bottom = 20;
        stack.add_named (main_box, "player");
        stack.add_named (menu_page, "menu");
        stack.add_named (cava, "cava");
        stack.transition_type = Gtk.StackTransitionType.SLIDE_UP_DOWN;
        window.child = stack;
        window.present ();

        // Initial fetch then poll every 5 seconds
        refresh.begin ();
        GLib.Timeout.add_seconds (1, () => {
            refresh.begin ();
            return GLib.Source.CONTINUE;
        });
    }

    private async void refresh () {
        try {
            var info = yield jf.currently_playing ();
            if (info == null) {
                title_label.label = "Nothing playing";
                artist_label.label = "";
                album_label.label = "";
                progress.fraction = 0.0;
                codec_label.label = "";
                play_button.icon_name = "media-playback-start-symbolic";
                current_art_url = null;
                album_art.paintable = null;
                return;
            }

            title_label.label = info.title;
            artist_label.label = info.artist;
            album_label.label = info.album;
            progress.fraction = info.duration > 0
                ? (info.position / info.duration).clamp (0.0, 1.0)
                : 0.0;
            codec_label.label = "%s\n%d Hz / %d bit".printf (
                info.codec, info.sample_rate, info.bit_depth);

            play_button.icon_name = info.status == "Paused"
                ? "media-playback-pause-symbolic"
                : "media-playback-start-symbolic";

            // Only reload art if the URL changed
            if (info.art_url != null && info.art_url != current_art_url) {
                current_art_url = info.art_url;
                yield load_image_async (info.art_url, album_art);
            }

        } catch (Error e) {
            warning ("Refresh error: %s", e.message);
            title_label.label = "Nothing playing";
            artist_label.label = "";
            album_label.label = "";
            progress.fraction = 0.0;
            codec_label.label = "";
            play_button.icon_name = "media-playback-start-symbolic";
            current_art_url = null;
            album_art.paintable = null;
        }
    }

    private async void load_image_async (string url, Gtk.Picture picture) {
        try {
            var session = new Soup.Session ();
            session.user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
            var message = new Soup.Message ("GET", url);
            var bytes = yield session.send_and_read_async (message, Priority.DEFAULT, null);

            if (message.status_code != 200) {
                warning ("Image HTTP error: %u", message.status_code);
                return;
            }

            var texture = Gdk.Texture.from_bytes (bytes);
            picture.paintable = texture;

        } catch (Error e) {
            warning ("Failed to load image: %s", e.message);
        }
    }

    private void change_volume (int delta) {
        string sign = delta > 0 ? "+" : "-";
        string cmd = "pactl set-sink-volume @DEFAULT_SINK@ %s%d%%".printf (sign, delta.abs ());
        try {
            GLib.Process.spawn_command_line_async (cmd);
        } catch (Error e) {
            warning ("Volume error: %s", e.message);
        }
    }

    public static int main (string[] args) {
        return new PlayerApp ().run (args);
    }
}
