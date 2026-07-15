using Soup;
using Json;

public class Jellyfin {
    private string url;
    private string apikey;
    private string devicename;
    private Soup.Session session;

    public Jellyfin (string url, string apikey, string devicename) {
        this.url = url;
        this.apikey = apikey;
        this.devicename = devicename;
        this.session = new Soup.Session ();
    }

    private Soup.Message make_message (string method, string endpoint) {
        var msg = new Soup.Message (method, @"$(this.url)/$endpoint");
        msg.request_headers.append ("X-Emby-Token", this.apikey);
        return msg;
    }

    public async Json.Node get_request (string endpoint) throws Error {
        var msg = make_message ("GET", endpoint);
        var bytes = yield session.send_and_read_async (msg, Priority.DEFAULT, null);

        if (msg.status_code != 200)
            throw new IOError.FAILED (@"HTTP error: $(msg.status_code)");

        var parser = new Json.Parser ();
        parser.load_from_data ((string) bytes.get_data ());
        return parser.get_root ().copy ();
    }

    public async void post_request (string endpoint, Json.Object payload) throws Error {
        var msg = make_message ("POST", endpoint);
        msg.request_headers.set_content_type ("application/json", null);

        var gen = new Json.Generator ();
        var root = new Json.Node (Json.NodeType.OBJECT);
        root.set_object (payload);
        gen.set_root (root);
        var body = gen.to_data (null);

        msg.set_request_body_from_bytes ("application/json",
            new Bytes (body.data));

        var bytes = yield session.send_and_read_async (msg, Priority.DEFAULT, null);
        print ("%s\n", (string) bytes.get_data ());

        if (msg.status_code != 200 && msg.status_code != 204)
            throw new IOError.FAILED (@"HTTP error: $(msg.status_code)");
    }

    private async Json.Array get_sessions () throws Error {
        var root = yield get_request ("Sessions");
        var all_sessions = root.get_array ();
        var out = new Json.Array ();

        all_sessions.foreach_element ((arr, i, node) => {
            var s = node.get_object ();
            if (!s.has_member ("NowPlayingItem")) return;
            var item = s.get_object_member ("NowPlayingItem");
            if (item.get_string_member_with_default ("MediaType", "") != "Audio") return;
            out.add_element (node.copy ());
        });

        return out;
    }

    public async SessionInfo[] get_metadata () throws Error {
        var sessions = yield get_sessions ();
        SessionInfo[] out = {};

        sessions.foreach_element ((arr, i, node) => {
            var s = node.get_object ();

            var play_state = s.has_member ("PlayState")
                ? s.get_object_member ("PlayState")
                : new Json.Object ();
            var item = s.has_member ("NowPlayingItem")
                ? s.get_object_member ("NowPlayingItem")
                : new Json.Object ();

            var device_name = s.get_string_member_with_default ("DeviceName", "");
            var is_paused = play_state.has_member ("IsPaused")
                && play_state.get_boolean_member ("IsPaused");
            var status = is_paused ? "Paused" : "Playing";

            // .NET ticks are 100 nanoseconds each
            double elapsed = play_state.get_int_member_with_default ("PositionTicks", 0)
                / 10000000.0;
            double length = item.get_int_member_with_default ("RunTimeTicks", 0)
                / 10000000.0;

            var title = item.get_string_member_with_default ("Name", "");
            var artist = item.get_string_member_with_default ("AlbumArtist", "");
            var album = item.get_string_member_with_default ("Album", "");
            var album_id = item.get_string_member_with_default ("AlbumId", "");
            var album_tag = item.get_string_member_with_default ("AlbumPrimaryImageTag", "");
            var track_id = item.get_string_member_with_default ("Id", "");
            var track_number = (int) item.get_int_member_with_default ("IndexNumber", 0);

            string? track_tag = null;
            if (item.has_member ("ImageTags")) {
                var tags = item.get_object_member ("ImageTags");
                if (tags.has_member ("Primary"))
                    track_tag = tags.get_string_member ("Primary");
            }

            string? cover_url = null;
            if (track_id != "" && track_tag != null)
                cover_url = @"$(this.url)/Items/$track_id/Images/Primary";
            else if (album_id != "" && album_tag != "")
                cover_url = @"$(this.url)/Items/$album_id/Images/Primary";

            // Find audio stream
            string codec = "";
            int sample_rate = 0;
            int bit_depth = 0;
            if (item.has_member ("MediaStreams")) {
                item.get_array_member ("MediaStreams").foreach_element ((a, j, stream_node) => {
                    var stream = stream_node.get_object ();
                    if (stream.get_string_member_with_default ("Type", "") == "Audio") {
                        codec = stream.get_string_member_with_default ("DisplayTitle", "");
                        sample_rate = (int) stream.get_int_member_with_default ("SampleRate", 0);
                        bit_depth = (int) stream.get_int_member_with_default ("BitDepth", 0);
                    }
                });
            }

            var info = new SessionInfo () {
                status = status,
                device = device_name,
                duration = length,
                position = elapsed,
                title = title,
                artist = artist,
                album = album,
                track_number = track_number,
                art_url = cover_url,
                codec = codec,
                sample_rate = sample_rate,
                bit_depth = bit_depth,
                session_id = s.get_string_member_with_default ("Id", "")
            };
            out += info;
        });

        return out;
    }

    public async SessionInfo? currently_playing () throws Error {
        var meta = yield get_metadata ();
        return meta.length > 0 ? meta[0] : null;
    }

    public async void next_track () throws Error {
        var current = yield currently_playing ();
        if (current == null) return;
        yield post_request (@"Sessions/$(current.session_id)/Playing/NextTrack", new Json.Object ());
    }

    public async void previous_track () throws Error {
        var current = yield currently_playing ();
        if (current == null) return;
        yield post_request (@"Sessions/$(current.session_id)/Playing/PreviousTrack", new Json.Object ());
    }
}
