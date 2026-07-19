// On-disk cache for album art, so repeat plays of a track skip both the
// metadata lookup (MusicBrainz/iTunes) and the image download. Files live under
// the user cache dir and are keyed by a hash of a stable per-track string.
namespace ArtCache {

    private string cache_dir () {
        return Path.build_filename (Environment.get_user_cache_dir (),
                                    "music-player-ui", "artwork");
    }

    private string file_for (string key) {
        var name = Checksum.compute_for_string (ChecksumType.SHA256, key);
        return Path.build_filename (cache_dir (), name);
    }

    // Cached image bytes for the key, or null if nothing is cached for it.
    public Bytes? load (string key) {
        try {
            uint8[] contents;
            File.new_for_path (file_for (key)).load_contents (null, out contents, null);
            return new Bytes.take ((owned) contents);
        } catch (Error e) {
            return null;   // not cached, or unreadable
        }
    }

    // Persist image bytes for the key, creating the cache directory as needed.
    public void store (string key, Bytes bytes) {
        try {
            var dir = File.new_for_path (cache_dir ());
            if (!dir.query_exists ())
                dir.make_directory_with_parents ();
            File.new_for_path (file_for (key)).replace_contents (
                bytes.get_data (), null, false,
                FileCreateFlags.REPLACE_DESTINATION, null, null);
        } catch (Error e) {
            warning ("Failed to cache artwork: %s", e.message);
        }
    }
}
