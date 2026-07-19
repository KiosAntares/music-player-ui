using Soup;
using Json;

// Looks up album art from a public API for tracks that carry no cover of their
// own (e.g. Bluetooth/AVRCP, which exposes metadata but no image). Uses the
// iTunes Search API, which needs no key and returns a resizable artwork URL.
public class Artwork {

    // Best-effort cover-art URL for the given track, or null if nothing matches
    // (or on any network/parse error). High resolution (600x600).
    public static async string? lookup (string artist, string album, string title) throws Error {
        string entity;
        string term;
        if (album != "") {
            entity = "album";
            term = "%s %s".printf (artist, album);
        } else if (title != "") {
            entity = "song";
            term = "%s %s".printf (artist, title);
        } else {
            return null;
        }

        var url = "https://itunes.apple.com/search?term=%s&entity=%s&limit=1".printf (
            GLib.Uri.escape_string (term.strip (), null, true), entity);

        var session = new Soup.Session ();
        var msg = new Soup.Message ("GET", url);
        var bytes = yield session.send_and_read_async (msg, Priority.DEFAULT, null);
        if (msg.status_code != 200)
            return null;

        var parser = new Json.Parser ();
        parser.load_from_data ((string) bytes.get_data (), (ssize_t) bytes.get_size ());
        var root = parser.get_root ().get_object ();
        if (root == null || !root.has_member ("results"))
            return null;

        var results = root.get_array_member ("results");
        if (results.get_length () == 0)
            return null;

        var first = results.get_element (0).get_object ();
        var art = first.get_string_member_with_default ("artworkUrl100", "");
        if (art == "")
            return null;

        // The API returns a 100x100 thumbnail; ask for a larger render instead.
        return art.replace ("100x100bb", "600x600bb");
    }
}
