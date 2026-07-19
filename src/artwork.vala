using Soup;
using Json;

// Looks up album art from public APIs for tracks that carry no cover of their
// own (e.g. Bluetooth/AVRCP, which exposes metadata but no image).
//
// Primary source is MusicBrainz + the Cover Art Archive: a community database
// whose coverage includes artists absent from streaming stores (much Japanese
// city pop, non-streaming catalogs like Tatsuro Yamashita), and which matches
// on structured artist+release so it won't return a same-titled cover or
// karaoke version. iTunes is a fallback for anything MusicBrainz lacks art for.
public class Artwork {

    private const string USER_AGENT =
        "music-player-ui/0.1 ( https://github.com/KiosAntares/music-player-ui )";

    // Best-effort cover-art URL for the given track, or null if nothing matches
    // confidently (or on any network/parse error). Roughly 500-1200px.
    public static async string? lookup (string artist, string album, string title) throws Error {
        string release = album != "" ? album : title;
        if (artist == "" && release == "")
            return null;

        var session = new Soup.Session ();
        session.user_agent = USER_AGENT;

        var art = yield musicbrainz (session, artist, release);
        if (art != null)
            return art;

        return yield itunes (session, artist, album, title);
    }

    // ---- MusicBrainz + Cover Art Archive (primary) ----

    private static async string? musicbrainz (Soup.Session session, string artist, string release) throws Error {
        if (release == "")
            return null;

        string query = artist != ""
            ? "artist:\"%s\" AND release:\"%s\"".printf (lucene (artist), lucene (release))
            : "release:\"%s\"".printf (lucene (release));
        var url = "https://musicbrainz.org/ws/2/release?query=%s&fmt=json&limit=5".printf (
            GLib.Uri.escape_string (query, null, true));

        var msg = new Soup.Message ("GET", url);
        var bytes = yield session.send_and_read_async (msg, Priority.DEFAULT, null);
        if (msg.status_code != 200)
            return null;

        var parser = new Json.Parser ();
        parser.load_from_data ((string) bytes.get_data (), (ssize_t) bytes.get_size ());
        var root = parser.get_root ().get_object ();
        if (root == null || !root.has_member ("releases"))
            return null;
        var releases = root.get_array_member ("releases");

        // Results are score-ordered; check the top few confident matches for
        // uploaded cover art and take the first that has some.
        int checked = 0;
        for (uint i = 0; i < releases.get_length () && checked < 3; i++) {
            var r = releases.get_element (i).get_object ();
            if (r.get_int_member_with_default ("score", 0) < 85)
                break;
            if (artist != "" && !credit_matches (r, artist))
                continue;

            var mbid = r.get_string_member_with_default ("id", "");
            if (mbid == "")
                continue;
            checked++;
            var art = yield cover_art (session, mbid);
            if (art != null)
                return art;
        }
        return null;
    }

    private static async string? cover_art (Soup.Session session, string mbid) throws Error {
        var msg = new Soup.Message ("GET", "https://coverartarchive.org/release/%s".printf (mbid));
        var bytes = yield session.send_and_read_async (msg, Priority.DEFAULT, null);
        if (msg.status_code != 200)
            return null;

        var parser = new Json.Parser ();
        parser.load_from_data ((string) bytes.get_data (), (ssize_t) bytes.get_size ());
        var root = parser.get_root ().get_object ();
        if (root == null || !root.has_member ("images"))
            return null;
        var images = root.get_array_member ("images");

        for (uint i = 0; i < images.get_length (); i++) {
            var im = images.get_element (i).get_object ();
            if (!im.get_boolean_member_with_default ("front", false))
                continue;
            if (im.has_member ("thumbnails")) {
                var th = im.get_object_member ("thumbnails");
                foreach (var key in new string[] { "1200", "500", "large" }) {
                    var u = th.get_string_member_with_default (key, "");
                    if (u != "")
                        return u;
                }
            }
            var full = im.get_string_member_with_default ("image", "");
            if (full != "")
                return full;
        }
        return null;
    }

    private static bool credit_matches (Json.Object release, string artist) {
        if (!release.has_member ("artist-credit"))
            return false;
        var ac = release.get_array_member ("artist-credit");
        for (uint i = 0; i < ac.get_length (); i++) {
            var name = ac.get_element (i).get_object ().get_string_member_with_default ("name", "");
            if (matches (name, artist))
                return true;
        }
        return false;
    }

    // Escape the two characters that are special inside a Lucene quoted phrase.
    private static string lucene (string s) {
        return s.replace ("\\", "\\\\").replace ("\"", "\\\"");
    }

    // ---- iTunes Search API (fallback) ----

    private static async string? itunes (Soup.Session session, string artist, string album, string title) throws Error {
        string entity;
        string term;
        string want_primary;
        if (album != "") {
            entity = "album";
            term = "%s %s".printf (artist, album);
            want_primary = album;
        } else if (title != "") {
            entity = "song";
            term = "%s %s".printf (artist, title);
            want_primary = title;
        } else {
            return null;
        }
        term = term.strip ();

        // The iTunes catalog is split per store; the US store has poor coverage
        // of Japanese releases. Route by script, then fall back to the other.
        bool jp = has_japanese (artist) || has_japanese (album) || has_japanese (title);
        var art = yield itunes_store (session, term, entity, jp ? "JP" : "US", want_primary, artist);
        if (art == null)
            art = yield itunes_store (session, term, entity, jp ? "US" : "JP", want_primary, artist);
        return art;
    }

    private static async string? itunes_store (Soup.Session session, string term, string entity,
                                               string country, string want_primary, string want_artist) throws Error {
        var url = "https://itunes.apple.com/search?term=%s&entity=%s&country=%s&limit=5".printf (
            GLib.Uri.escape_string (term, null, true), entity, country);

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

        string? best = null;
        int best_score = 0;
        for (uint i = 0; i < results.get_length (); i++) {
            var o = results.get_element (i).get_object ();
            var art = o.get_string_member_with_default ("artworkUrl100", "");
            if (art == "")
                continue;

            var cand_primary = entity == "album"
                ? o.get_string_member_with_default ("collectionName", "")
                : o.get_string_member_with_default ("trackName", "");
            var cand_artist = o.get_string_member_with_default ("artistName", "");

            // The album/track title must match; the artist is a tie-breaker.
            int score = 0;
            if (matches (cand_primary, want_primary)) score += 2;
            if (want_artist != "" && matches (cand_artist, want_artist)) score += 1;
            if (score > best_score) {
                best_score = score;
                best = art;
            }
        }

        // Require the title itself to match — a mere artist match is not enough
        // to trust the cover, and a wrong cover is worse than none.
        if (best_score < 2 || best == null)
            return null;

        // The API returns a 100x100 thumbnail; ask for a larger render instead.
        return best.replace ("100x100bb", "600x600bb");
    }

    // ---- shared helpers ----

    // Loose equality: normalized (letters/digits only, lowercased) with either
    // string containing the other, to tolerate suffixes like " - Single" or
    // "(Deluxe Edition)" and punctuation/spacing differences.
    private static bool matches (string a, string b) {
        string na = normalize (a);
        string nb = normalize (b);
        if (na == "" || nb == "")
            return false;
        return na.contains (nb) || nb.contains (na);
    }

    private static string normalize (string s) {
        var sb = new StringBuilder ();
        int i = 0;
        unichar c;
        while (s.get_next_char (ref i, out c)) {
            if (c.isalnum ())
                sb.append_unichar (c.tolower ());
        }
        return sb.str;
    }

    // True if the string contains kana or CJK characters, i.e. is (likely)
    // Japanese and should be searched against the JP store.
    private static bool has_japanese (string s) {
        int i = 0;
        unichar c;
        while (s.get_next_char (ref i, out c)) {
            if ((c >= 0x3040 && c <= 0x30FF)    // hiragana + katakana
                || (c >= 0xFF66 && c <= 0xFF9D)  // half-width katakana
                || (c >= 0x4E00 && c <= 0x9FFF)) // CJK unified ideographs (kanji)
                return true;
        }
        return false;
    }
}
