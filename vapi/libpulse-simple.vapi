/*
 * Minimal binding for PulseAudio's "simple" API — just the blocking record
 * calls the visualiser needs.
 *
 * Shipped in-tree on purpose: the vapi that upstream PulseAudio installs is not
 * packaged consistently across distributions (Debian in particular splits it
 * out), and this file is small enough that vendoring it is cheaper than making
 * the build depend on where a distro decided to put things. Named after the
 * pkg-config module so meson's `dependency('libpulse-simple')` picks it up, and
 * `--vapidir vapi` makes it win over any system copy.
 */
[CCode (cheader_filename = "pulse/simple.h,pulse/sample.h,pulse/def.h,pulse/error.h")]
namespace PulseSimple {

    [CCode (cname = "pa_sample_format_t", cprefix = "PA_SAMPLE_", has_type_id = false)]
    public enum SampleFormat {
        [CCode (cname = "PA_SAMPLE_FLOAT32NE")]
        FLOAT32NE
    }

    [CCode (cname = "pa_stream_direction_t", cprefix = "PA_STREAM_", has_type_id = false)]
    public enum StreamDirection {
        RECORD
    }

    [CCode (cname = "pa_sample_spec", has_type_id = false)]
    public struct SampleSpec {
        public SampleFormat format;
        public uint32 rate;
        public uint8 channels;
    }

    /* Every field is a "don't care" sentinel unless set; (uint32) -1 asks the
       server to pick a sane default for that one. */
    [CCode (cname = "pa_buffer_attr", has_type_id = false)]
    public struct BufferAttr {
        public uint32 maxlength;
        public uint32 tlength;
        public uint32 prebuf;
        public uint32 minreq;
        public uint32 fragsize;
    }

    [Compact]
    [CCode (cname = "pa_simple", free_function = "pa_simple_free")]
    public class Simple {
        [CCode (cname = "pa_simple_new")]
        public Simple (string? server, string name, StreamDirection dir, string? dev,
                       string stream_name, ref SampleSpec ss, void* map,
                       BufferAttr? attr, out int error = null);

        [CCode (cname = "pa_simple_read")]
        public int read (void* data, size_t bytes, out int error = null);

        [CCode (cname = "pa_simple_flush")]
        public int flush (out int error = null);
    }

    [CCode (cname = "pa_strerror")]
    public unowned string strerror (int error);
}
