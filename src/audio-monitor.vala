// Captures whatever the box is currently playing, by recording from the default
// sink's monitor source.
//
// The box runs PipeWire, so this goes through pipewire-pulse: libpulse's simple
// API is a complete client of it, and `pactl` (already used for volume) tells us
// which sink is current. Recording the *monitor* rather than a capture device is
// what makes this work identically for Jellyfin playback and for a phone
// streaming in over Bluetooth A2DP — both end up on the same sink.
//
// A single worker thread does blocking reads into a lock-protected ring buffer.
// Analysis happens on the UI thread (see Spectrum), so this class deliberately
// knows nothing about FFTs — it only ever hands out the most recent N samples.
public class AudioMonitor : GLib.Object {

    // Matches PipeWire's usual graph rate, so pipewire-pulse hands us samples
    // straight through instead of spinning up a resampler for our benefit.
    public const int SAMPLE_RATE = 48000;

    private const int CHANNELS = 2;
    private const int CHUNK_FRAMES = 512;       // ~11.6 ms per read
    private const int RING_SAMPLES = 16384;     // mono samples, power of two

    // How often to notice that the default sink changed underneath us (e.g. a
    // Bluetooth device connecting). Cheap enough at this interval; only runs
    // while the capture loop is otherwise idle-waiting on audio anyway.
    private const int64 DEVICE_RECHECK_US = 5000000;

    private float[] ring = new float[RING_SAMPLES];
    private int write_pos = 0;
    private uint64 written = 0;
    private GLib.Mutex mutex = GLib.Mutex ();

    private bool started = false;

    // Starts the capture thread on first use. The thread then runs for the
    // lifetime of the process: `pa_simple_read` is an uninterruptible blocking
    // call, so there is no way to reliably stop it, and a monitor stream that
    // sits there consuming silence costs far less than the risk of wedging on
    // shutdown. Callers simply stop asking for snapshots.
    public void start () {
        if (started)
            return;
        started = true;

        try {
            new GLib.Thread<void*>.try ("audio-monitor", capture_loop);
        } catch (Error e) {
            warning ("Could not start audio capture thread: %s", e.message);
            started = false;
        }
    }

    // Copies the most recent `dest.length` mono samples into `dest`, oldest
    // first. Returns false until enough audio has been captured to fill it.
    public bool snapshot (float[] dest) {
        bool ok;

        mutex.lock ();
        ok = written >= (uint64) dest.length;
        if (ok) {
            int start = ((write_pos - dest.length) % RING_SAMPLES + RING_SAMPLES) % RING_SAMPLES;
            for (int i = 0; i < dest.length; i++)
                dest[i] = ring[(start + i) % RING_SAMPLES];
        }
        mutex.unlock ();

        return ok;
    }

    private void* capture_loop () {
        var spec = PulseSimple.SampleSpec () {
            format = PulseSimple.SampleFormat.FLOAT32NE,
            rate = SAMPLE_RATE,
            channels = (uint8) CHANNELS
        };

        // Only fragsize matters for a record stream; the rest ask the server for
        // its default. A small fragment keeps the visualiser tight to the audio.
        var attr = PulseSimple.BufferAttr () {
            maxlength = uint32.MAX,
            tlength = uint32.MAX,
            prebuf = uint32.MAX,
            minreq = uint32.MAX,
            fragsize = CHUNK_FRAMES * CHANNELS * (uint32) sizeof (float)
        };

        var interleaved = new float[CHUNK_FRAMES * CHANNELS];
        var mono = new float[CHUNK_FRAMES];

        PulseSimple.Simple? pa = null;
        string? device = null;
        int64 last_device_check = 0;

        while (true) {
            if (pa == null) {
                device = default_monitor ();
                int error = 0;
                pa = new PulseSimple.Simple (null, "player",
                    PulseSimple.StreamDirection.RECORD, device, "visualizer",
                    ref spec, null, attr, out error);

                if (pa == null) {
                    warning ("Audio monitor: cannot open '%s': %s",
                        device ?? "(default source)", PulseSimple.strerror (error));
                    GLib.Thread.usleep (1000000);
                    continue;
                }
                last_device_check = GLib.get_monotonic_time ();
            }

            int error = 0;
            if (pa.read ((void*) interleaved,
                         (size_t) interleaved.length * sizeof (float), out error) < 0) {
                warning ("Audio monitor: read failed: %s", PulseSimple.strerror (error));
                pa = null;
                GLib.Thread.usleep (500000);
                continue;
            }

            for (int i = 0; i < CHUNK_FRAMES; i++)
                mono[i] = (interleaved[i * CHANNELS] + interleaved[i * CHANNELS + 1]) * 0.5f;

            mutex.lock ();
            for (int i = 0; i < CHUNK_FRAMES; i++) {
                ring[write_pos] = mono[i];
                write_pos = (write_pos + 1) % RING_SAMPLES;
            }
            written += CHUNK_FRAMES;
            mutex.unlock ();

            int64 now = GLib.get_monotonic_time ();
            if (now - last_device_check >= DEVICE_RECHECK_US) {
                last_device_check = now;
                if (default_monitor () != device)
                    pa = null;   // reopen against the new sink on the next pass
            }
        }
    }

    // Monitor source name for the current default sink, or null to fall back to
    // the server's default source.
    private static string? default_monitor () {
        if (Config.VIS_MONITOR_SOURCE != "")
            return Config.VIS_MONITOR_SOURCE;

        try {
            string stdout_text;
            string stderr_text;
            int status;
            GLib.Process.spawn_command_line_sync ("pactl get-default-sink",
                out stdout_text, out stderr_text, out status);
            GLib.Process.check_wait_status (status);

            var sink = stdout_text.strip ();
            if (sink == "")
                return null;
            return sink.has_suffix (".monitor") ? sink : sink + ".monitor";
        } catch (Error e) {
            return null;
        }
    }
}
