// Reads "now playing" metadata from a connected Bluetooth device over AVRCP,
// which BlueZ exposes as org.bluez.MediaPlayer1 on the system bus. Used so that
// when a phone streams audio to this box (A2DP sink / "bluetooth mode"), the
// main screen shows the phone's track instead of the Jellyfin session.
public class BluetoothMedia {

    // Metadata for the connected Bluetooth player, or null when no Bluetooth
    // media player is present (i.e. no device connected -> not bluetooth mode).
    public static SessionInfo? currently_playing () {
        try {
            var conn = Bus.get_sync (BusType.SYSTEM);
            var reply = conn.call_sync (
                "org.bluez", "/",
                "org.freedesktop.DBus.ObjectManager", "GetManagedObjects",
                null, new VariantType ("(a{oa{sa{sv}}})"),
                DBusCallFlags.NONE, -1);

            var objects = reply.get_child_value (0);
            var iter = new VariantIter (objects);
            string path;
            Variant ifaces;
            while (iter.next ("{o@a{sa{sv}}}", out path, out ifaces)) {
                var props = lookup_interface (ifaces, "org.bluez.MediaPlayer1");
                if (props != null)
                    return build_info (props);
            }
        } catch (Error e) {
            // BlueZ absent or no active session — treat as "not bluetooth mode".
        }
        return null;
    }

    // Return the property dict for the named interface within an object's
    // a{sa{sv}} interface map, or null if the object doesn't implement it.
    private static Variant? lookup_interface (Variant ifaces, string name) {
        var iter = new VariantIter (ifaces);
        string iface;
        Variant props;
        while (iter.next ("{s@a{sv}}", out iface, out props)) {
            if (iface == name)
                return props;
        }
        return null;
    }

    private static SessionInfo build_info (Variant props) {
        string status = get_string (props, "Status");
        double position = get_uint32 (props, "Position") / 1000.0;

        string title = "";
        string artist = "";
        string album = "";
        int track_number = 0;
        double duration = 0;

        var track = props.lookup_value ("Track", new VariantType ("a{sv}"));
        if (track != null) {
            title = get_string (track, "Title");
            artist = get_string (track, "Artist");
            album = get_string (track, "Album");
            track_number = (int) get_uint32 (track, "TrackNumber");
            duration = get_uint32 (track, "Duration") / 1000.0;
        }

        return new SessionInfo () {
            status = status == "paused" ? "Paused" : "Playing",
            device = "Bluetooth",
            duration = duration,
            position = position,
            title = title,
            artist = artist,
            album = album,
            track_number = track_number,
            art_url = null,
            codec = "Bluetooth",
            sample_rate = 0,
            bit_depth = 0,
            session_id = ""
        };
    }

    private static string get_string (Variant dict, string key) {
        var v = dict.lookup_value (key, VariantType.STRING);
        return v != null ? v.get_string () : "";
    }

    private static uint32 get_uint32 (Variant dict, string key) {
        var v = dict.lookup_value (key, VariantType.UINT32);
        return v != null ? v.get_uint32 () : 0;
    }
}
