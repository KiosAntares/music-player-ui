public class MenuPage : Gtk.Box {
    private Gtk.ListBox category_list;
    private Gtk.ListBox entry_list;
    private bool in_entries = false;

    private HashTable<string, GLib.List<string>> data;

    public signal void page_requested (string page_name);

    public MenuPage () {
        Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);

        // Define your categories and entries
        data = new HashTable<string, GLib.List<string>> (str_hash, str_equal);

        GLib.List<string> server_entries = new GLib.List<string> ();
        server_entries.append ("Poweroff");
        server_entries.append ("Reboot");
        server_entries.append ("VNC Server");
        data.insert ("Device", (owned) server_entries);

        GLib.List<string> display_entries = new GLib.List<string> ();
        display_entries.append ("Player");
        display_entries.append ("Audio Display");
        display_entries.append ("Lyrics");
        data.insert ("Display", (owned) display_entries);

        GLib.List<string> player_entries = new GLib.List<string> ();
        player_entries.append ("Spotify");
        player_entries.append ("Jellyfin");
        player_entries.append ("Bluetooth");
        data.insert ("Player", (owned) player_entries);

        GLib.List<string> playback_entries = new GLib.List<string> ();
        playback_entries.append ("Poll Interval");
        playback_entries.append ("Default Volume");
        data.insert ("Playback", (owned) playback_entries);

        // --- LEFT: category list ---
        var left_scroll = new Gtk.ScrolledWindow ();
        left_scroll.set_size_request (200, -1);
        left_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;

        category_list = new Gtk.ListBox ();
        category_list.add_css_class ("navigation-sidebar");

        foreach (var category in data.get_keys ()) {
            var row = new Gtk.ListBoxRow ();
            var label = new Gtk.Label (category);
            label.xalign = 0;
            label.margin_start = 12;
            label.margin_top = 8;
            label.margin_bottom = 8;
            row.child = label;
            row.set_data ("category", category);
            category_list.append (row);
        }

        category_list.row_selected.connect ((row) => {
            if (row == null) return;
            var category = row.get_data<string> ("category");
            populate_entries (category);
        });

        left_scroll.child = category_list;

        // --- RIGHT: entry list ---
        var right_scroll = new Gtk.ScrolledWindow ();
        right_scroll.hexpand = true;
        right_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;

        entry_list = new Gtk.ListBox ();
        entry_list.add_css_class ("boxed-list");
        entry_list.margin_top = 12;
        entry_list.margin_bottom = 12;
        entry_list.margin_start = 12;
        entry_list.margin_end = 12;

        right_scroll.child = entry_list;

        // --- Divider ---
        var separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);

        append (left_scroll);
        append (separator);
        append (right_scroll);

        var key_controller = new Gtk.EventControllerKey ();
        (this as Gtk.Widget).add_controller (key_controller);

        key_controller.key_pressed.connect ((keyval, keycode, state) => {
            switch (keyval) {
                case Gdk.Key.Left:
                    navigate (-1);
                    return true;
                case Gdk.Key.Right:
                    navigate (1);
                    return true;
                case Gdk.Key.e:
                    on_enter ();
                    return true;
                case Gdk.Key.a:
                    on_back ();
                    return true;
            }
            return false;
        });

        // Select first category by default
        category_list.select_row (category_list.get_row_at_index (0));
    }

    private void populate_entries (string category) {
        // Clear existing entries
        var child = entry_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            entry_list.remove ((Gtk.ListBoxRow) child);
            child = next;
        }

        unowned GLib.List<string> entries = data.get (category);
        if (entries == null) return;

        foreach (var entry in entries) {
            var row = new Gtk.ListBoxRow ();
            var label = new Gtk.Label (entry_label (entry));
            label.xalign = 0;
            label.margin_start = 12;
            label.margin_top = 10;
            label.margin_bottom = 10;
            row.child = label;
            row.set_data ("entry", entry);
            entry_list.append (row);
        }
    }

    private string entry_label (string entry) {
        if (entry == "VNC Server") {
            return "VNC Server: %s".printf (vnc_running () ? "On" : "Off");
        }
        return entry;
    }

    private bool vnc_running () {
        try {
            string standard_output;
            string standard_error;
            int exit_status;
            Process.spawn_command_line_sync ("pgrep -x x11vnc", out standard_output, out standard_error, out exit_status);
            Process.check_wait_status (exit_status);
            return true;
        } catch (Error e) {
            return false;
        }
    }

    private void navigate (int direction) {
        if (!in_entries) {
            var current = category_list.get_selected_row ();
            int index = current != null ? current.get_index () : 0;
            var next = category_list.get_row_at_index (index + direction);
            if (next != null)
                category_list.select_row (next);
        } else {
            var current = entry_list.get_selected_row ();
            int index = current != null ? current.get_index () : 0;
            var next = entry_list.get_row_at_index (index + direction);
            if (next != null)
                entry_list.select_row (next);
        }
    }

    private void on_enter () {
        if (!in_entries) {
            // Move focus into entries panel
            in_entries = true;
            entry_list.select_row (entry_list.get_row_at_index (0));
            entry_list.add_css_class ("active-panel");
            category_list.remove_css_class ("active-panel");
        } else {
            // Handle entry selection — expand here for actual actions
            var row = entry_list.get_selected_row ();
            if (row == null) return;
            var entry = row.get_data<string> ("entry");
            print ("Selected: %s\n", entry);
            if (entry == "Audio Display") {
                page_requested ("cava");
            };
            if (entry == "Poweroff"){
                try {
                    Process.spawn_command_line_async ("systemctl poweroff");
                } catch (SpawnError e) {
                    warning ("Failed to run command: %s", e.message);
                }
            }
            if (entry == "VNC Server"){
                toggle_vnc ();
            }
        }
    }

    private void toggle_vnc () {
        try {
            if (vnc_running ()) {
                Process.spawn_command_line_async ("pkill x11vnc");
            } else {
                Process.spawn_command_line_async ("x11vnc -display :0 -forever -shared -bg");
            }
        } catch (SpawnError e) {
            warning ("Failed to run command: %s", e.message);
        }

        int index = entry_list.get_selected_row () != null ? entry_list.get_selected_row ().get_index () : 0;
        populate_entries ("Device");
        entry_list.select_row (entry_list.get_row_at_index (index));
    }

    private void on_back () {
        if (in_entries) {
            // Go back to category panel
            in_entries = false;
            entry_list.unselect_all ();
            entry_list.remove_css_class ("active-panel");
            category_list.add_css_class ("active-panel");
        }
    }
}
