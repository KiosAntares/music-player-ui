using Gtk;
using Soup;
using Gdk;

// The "now playing" view: album art, track metadata, progress and codec info.
// Owns its own polling loop against the shared Jellyfin client.
public class PlayerPage : Gtk.Box {
    private Jellyfin jf;

    private Gtk.Picture album_art;
    private Gtk.Label title_label;
    private Gtk.Label artist_label;
    private Gtk.Label album_label;
    private Gtk.ProgressBar progress;
    private Gtk.Label codec_label;
    private Gtk.Button play_button;
    // Identifies the track whose art is currently shown, so we fetch cover art
    // at most once per song. Holds the art URL (Jellyfin) or an artist/album/
    // title key (Bluetooth, whose art is looked up separately).
    private string? current_track_key = null;

    public PlayerPage (Jellyfin jf) {
        Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
        this.jf = jf;

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

        append (art_container);
        append (middle_box);
        append (right_box);

        // Initial fetch then poll on the configured interval.
        refresh.begin ();
        GLib.Timeout.add_seconds (Config.POLL_INTERVAL_SECONDS, () => {
            refresh.begin ();
            return GLib.Source.CONTINUE;
        });
    }

    private async void refresh () {
        try {
            // Strictly follow the Player -> Bluetooth menu selection: in
            // bluetooth mode show the connected device's track, otherwise the
            // Jellyfin session. No implicit switching on connection state.
            SessionInfo? info;
            if (SystemActions.bt_receiver_running ()) {
                info = BluetoothMedia.currently_playing ();
            } else {
                info = yield jf.currently_playing ();
            }
            if (info == null) {
                clear ();
                return;
            }

            title_label.label = info.title;
            artist_label.label = info.artist;
            album_label.label = info.album;
            progress.fraction = info.duration > 0
                ? (info.position / info.duration).clamp (0.0, 1.0)
                : 0.0;
            codec_label.label = info.sample_rate > 0
                ? "%s\n%d Hz / %d bit".printf (info.codec, info.sample_rate, info.bit_depth)
                : info.codec;

            play_button.icon_name = info.status == "Paused"
                ? "media-playback-pause-symbolic"
                : "media-playback-start-symbolic";

            // Resolve album art. Jellyfin gives a direct URL; bluetooth exposes
            // none, so look one up from a public API by track metadata. Keyed on
            // the track so we fetch at most once per song, not on every poll.
            string track_key = info.art_url ?? "%s|%s|%s".printf (info.artist, info.album, info.title);
            if (track_key != current_track_key) {
                current_track_key = track_key;
                album_art.paintable = null;
                string? art_url = info.art_url;
                if (art_url == null && info.title != "")
                    art_url = yield Artwork.lookup (info.artist, info.album, info.title);
                // Guard against the track changing while the lookup was in flight.
                if (art_url != null && current_track_key == track_key)
                    yield load_image_async (art_url, album_art);
            }

        } catch (Error e) {
            warning ("Refresh error: %s", e.message);
            clear ();
        }
    }

    private void clear () {
        title_label.label = "Nothing playing";
        artist_label.label = "";
        album_label.label = "";
        progress.fraction = 0.0;
        codec_label.label = "";
        play_button.icon_name = "media-playback-start-symbolic";
        current_track_key = null;
        album_art.paintable = null;
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
}
