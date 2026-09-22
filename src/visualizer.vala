using Gtk;
using Gdk;

// The visual styles the audio display can cycle through.
public enum VisualizerStyle {
    BARS,
    MIRROR,
    WAVE,
    SCOPE,
    RADIAL;

    public const int COUNT = 5;

    public string label () {
        switch (this) {
            case BARS:   return "Bars";
            case MIRROR: return "Mirror";
            case WAVE:   return "Wave";
            case SCOPE:  return "Scope";
            case RADIAL: return "Radial";
            default:     return "Bars";
        }
    }

    public VisualizerStyle next () {
        return (VisualizerStyle) (((int) this + 1) % COUNT);
    }
}

// Native replacement for the `cava`-in-a-terminal audio display.
//
// Draws straight into the widget's render node tree (no Cairo surface, no
// terminal emulator, no child process), which is what makes it cheap enough for
// the Orange Pi: bars are plain coloured rectangles and the curve styles are
// single GskPath nodes, all of which the GL renderer handles on the GPU.
//
// Every style is built from render nodes -- coloured rects, gradients and
// transforms. Nothing goes through append_cairo, and nothing uses GskPath.
//
// That is not stylistic. GskPath needs GTK 4.14 and the player box ships 4.8,
// and measuring the Cairo fallback on that box gave 8.6 fps against 56 for the
// rect-based styles: append_cairo rasterises the full 1920x480 on the CPU and
// uploads a 3.7 MB texture every frame, which the A55 cannot feed. Curves are
// therefore drawn as adjacent columns (VIS_CURVE_COLUMNS of them) and the
// radial bands as rotated rects, all of which the GPU handles.
//
// Analysis only runs while the widget is mapped — GtkStack unmaps the pages you
// cannot see, so sitting on the player page costs nothing.
public class Visualizer : Gtk.Widget {

    private Spectrum spectrum;

    private Gdk.RGBA color_low;
    private Gdk.RGBA color_mid;
    private Gdk.RGBA color_high;

    private uint tick_id = 0;
    private int64 last_frame_us = 0;
    private int64 next_frame_due_us = 0;

    // Frame pacing readout, for checking a style actually holds up on the
    // player box. Enable with PLAYER_VIS_STATS=1.
    private bool stats = GLib.Environment.get_variable ("PLAYER_VIS_STATS") != null;
    private int64 stats_since_us = 0;
    private int stats_frames = 0;
    private double stats_worst_ms = 0.0;

    // Wall-clock time the current style was selected, used to flash its name.
    private int64 style_changed_us = 0;

    private VisualizerStyle _style = VisualizerStyle.BARS;
    public VisualizerStyle style {
        get { return _style; }
        set {
            _style = value;
            style_changed_us = GLib.get_monotonic_time ();
            queue_draw ();
        }
    }

    construct {
        hexpand = true;
        vexpand = true;

        spectrum = new Spectrum (Config.VIS_BANDS);

        color_low.parse (Config.VIS_COLOR_LOW);
        color_mid.parse (Config.VIS_COLOR_MID);
        color_high.parse (Config.VIS_COLOR_HIGH);
    }

    public override void map () {
        base.map ();

        spectrum.start ();
        last_frame_us = 0;
        next_frame_due_us = 0;
        tick_id = add_tick_callback ((widget, clock) => {
            on_tick (clock);
            return GLib.Source.CONTINUE;
        });
    }

    public override void unmap () {
        if (tick_id != 0) {
            remove_tick_callback (tick_id);
            tick_id = 0;
        }
        base.unmap ();
    }

    public override void measure (Gtk.Orientation orientation, int for_size,
                                  out int minimum, out int natural,
                                  out int minimum_baseline, out int natural_baseline) {
        minimum = 0;
        natural = orientation == Gtk.Orientation.HORIZONTAL ? 640 : 240;
        minimum_baseline = -1;
        natural_baseline = -1;
    }

    private void on_tick (Gdk.FrameClock clock) {
        int64 now = clock.get_frame_time ();
        if (last_frame_us == 0) {
            last_frame_us = now;
            next_frame_due_us = now;
            return;
        }

        // Budget the frame rate against a running deadline rather than against
        // the gap since the last frame. We can only ever draw on a vsync, so a
        // plain "has one interval elapsed?" test quantises the result to a
        // divisor of the refresh rate -- a 60 fps cap on this 75 Hz monitor
        // skipped every other vsync and rendered 37 fps. Advancing a deadline
        // instead lets us drop only the frames we actually need to.
        int64 interval_us = 1000000 / Config.VIS_MAX_FPS;
        if (now + 1000 < next_frame_due_us)
            return;
        next_frame_due_us = int64.max (now + 1000, next_frame_due_us + interval_us);

        double dt = (now - last_frame_us) / 1000000.0;
        last_frame_us = now;

        spectrum.update (double.min (dt, 0.2));   // clamp after e.g. a page switch
        queue_draw ();

        if (stats)
            report_stats (now, dt);
    }

    private void report_stats (int64 now, double dt) {
        if (stats_since_us == 0) {
            stats_since_us = now;
            return;
        }

        stats_frames++;
        stats_worst_ms = double.max (stats_worst_ms, dt * 1000.0);

        double elapsed = (now - stats_since_us) / 1000000.0;
        if (elapsed >= 2.0) {
            message ("visualizer[%s]: %.1f fps, worst frame %.1f ms",
                _style.label (), stats_frames / elapsed, stats_worst_ms);
            stats_since_us = now;
            stats_frames = 0;
            stats_worst_ms = 0.0;
        }
    }

    public override void snapshot (Gtk.Snapshot snapshot) {
        float w = get_width ();
        float h = get_height ();
        if (w <= 0.0f || h <= 0.0f)
            return;

        switch (_style) {
            case VisualizerStyle.BARS:   draw_bars (snapshot, w, h);   break;
            case VisualizerStyle.MIRROR: draw_mirror (snapshot, w, h); break;
            case VisualizerStyle.WAVE:   draw_wave (snapshot, w, h);   break;
            case VisualizerStyle.SCOPE:  draw_scope (snapshot, w, h);  break;
            case VisualizerStyle.RADIAL: draw_radial (snapshot, w, h); break;
        }

        draw_style_flash (snapshot, w, h);
    }

    // --- Styles ------------------------------------------------------------

    // Classic cava look: one bar per band, growing from the baseline, with a
    // vertical gradient shared across the whole widget so the colour of a bar
    // depends on how loud it is rather than on where it sits.
    private void draw_bars (Gtk.Snapshot snapshot, float w, float h) {
        int n = spectrum.bands;
        float slot = w / n;
        float gap = float.max (1.0f, slot * (float) Config.VIS_BAR_GAP);
        float bar_w = float.max (1.0f, slot - gap);
        var stops = vertical_stops ();

        for (int i = 0; i < n; i++) {
            float level = (float) spectrum.levels[i];
            float bar_h = float.max (2.0f, level * h);
            float x = i * slot + gap * 0.5f;
            var bounds = rect (x, h - bar_h, bar_w, bar_h);

            fill_gradient (snapshot, bounds, point (0.0f, h), point (0.0f, 0.0f), stops,
                           (float) Config.VIS_BAR_RADIUS);

            if (Config.VIS_SHOW_PEAKS) {
                float peak_y = h - float.max (3.0f, (float) spectrum.peaks[i] * h);
                snapshot.append_color (color_high, rect (x, peak_y, bar_w, 2.0f));
            }
        }
    }

    // Bars grown symmetrically out of the centre line, coloured by frequency
    // (left to right) rather than by level, so it reads differently from BARS.
    private void draw_mirror (Gtk.Snapshot snapshot, float w, float h) {
        int n = spectrum.bands;
        float slot = w / n;
        float gap = float.max (1.0f, slot * (float) Config.VIS_BAR_GAP);
        float bar_w = float.max (1.0f, slot - gap);
        float center = h * 0.5f;
        var stops = vertical_stops ();

        for (int i = 0; i < n; i++) {
            float half = float.max (1.5f, (float) spectrum.levels[i] * h * 0.47f);
            float x = i * slot + gap * 0.5f;
            var bounds = rect (x, center - half, bar_w, half * 2.0f);

            fill_gradient (snapshot, bounds, point (0.0f, 0.0f), point (w, 0.0f), stops,
                           (float) Config.VIS_BAR_RADIUS);
        }

        snapshot.append_color (fade (color_mid, 0.25f), rect (0.0f, center - 0.5f, w, 1.0f));
    }

    // The spectrum as a filled silhouette. Sampled into adjacent columns with
    // a Catmull-Rom interpolation between bands, which reads as a smooth curve
    // at this column width while staying plain render nodes.
    private void draw_wave (Gtk.Snapshot snapshot, float w, float h) {
        int cols = Config.VIS_CURVE_COLUMNS;
        float col_w = w / cols;
        var stops = vertical_stops ();

        for (int c = 0; c < cols; c++) {
            double level = level_at ((double) c / (cols - 1)).clamp (0.0, 1.0);
            float bar_h = float.max (2.0f, (float) level * h * 0.94f);

            // Gradient endpoints are in widget space, so every column samples
            // the same vertical ramp and the whole silhouette reads as one
            // shape. Colouring each column by its own height instead made the
            // fill look striped and lost the base-to-tip gradient.
            snapshot.append_linear_gradient (
                rect (c * col_w, h - bar_h, col_w + 0.5f, bar_h),
                point (0.0f, h), point (0.0f, 0.0f), stops);
        }
    }

    // Oscilloscope over the raw (zero-crossing aligned) waveform, drawn as a
    // min/max envelope per column.
    private void draw_scope (Gtk.Snapshot snapshot, float w, float h) {
        unowned float[] samples = spectrum.wave;
        int n = samples.length;
        int cols = Config.VIS_CURVE_COLUMNS;
        float col_w = w / cols;
        float mid = h * 0.5f;

        snapshot.append_color (fade (color_mid, 0.18f), rect (0.0f, mid - 0.5f, w, 1.0f));

        var lo = new float[cols];
        var hi = new float[cols];
        for (int c = 0; c < cols; c++) {
            int i0 = c * n / cols;
            int i1 = int.max (int.min (((c + 1) * n) / cols, n), i0 + 1);

            float mn = samples[i0];
            float mx = samples[i0];
            for (int i = i0 + 1; i < i1; i++) {
                mn = float.min (mn, samples[i]);
                mx = float.max (mx, samples[i]);
            }
            lo[c] = mn;
            hi[c] = mx;
        }

        for (int c = 0; c < cols; c++) {
            int next = int.min (c + 1, cols - 1);

            // Union each column with the next one so consecutive columns always
            // overlap. Drawn independently they break into dashes wherever the
            // signal travels further between columns than it spans within one.
            float mn = float.min (lo[c], lo[next]);
            float mx = float.max (hi[c], hi[next]);

            float y0 = mid - mx * h * 0.45f;
            float y1 = mid - mn * h * 0.45f;
            float bar_h = float.max (2.0f, y1 - y0);

            // Keep a floor under the brightness: colouring purely by amplitude
            // put a quiet signal at the dark end of the palette, where it was
            // invisible against the background.
            double t = double.max (Math.fabs (mn), Math.fabs (mx)).clamp (0.0, 1.0);
            snapshot.append_color (palette_at (0.30 + 0.70 * t),
                rect (c * col_w, y0, col_w + 0.5f, bar_h));
        }
    }

    // Bands radiating from the centre. Each one is a plain rect pushed out
    // along its own rotated coordinate space, so the whole thing stays on the
    // GPU path -- no polygon paths, no per-frame rasterisation.
    private void draw_radial (Gtk.Snapshot snapshot, float w, float h) {
        int n = spectrum.bands;
        float cx = w * 0.5f;
        float cy = h * 0.5f;
        float inner = float.min (w, h) * 0.17f;
        float outer = float.min (w, h) * 0.47f;

        // Width taken at the mid radius, so the ring looks evenly filled
        // rather than sparse at the outside or crowded at the inside.
        float band_w = float.max (2.0f,
            (float) (2.0 * Math.PI * ((inner + outer) * 0.5f) / n) * 0.7f);

        for (int i = 0; i < n; i++) {
            float length = float.max (2.0f,
                (float) spectrum.levels[i] * (outer - inner));

            snapshot.save ();
            snapshot.translate (point (cx, cy));
            snapshot.rotate (-90.0f + 360.0f * i / n);
            snapshot.append_color (palette_at ((double) i / (n - 1)),
                rect (inner, -band_w * 0.5f, length, band_w));
            snapshot.restore ();
        }

        // Faint ring so the centre does not look like a hole when it is quiet.
        // A rounded rect whose radius is half its side is a circle.
        float r = inner - 4.0f;
        var ring = Gsk.RoundedRect ();
        ring.init_from_rect (rect (cx - r, cy - r, r * 2.0f, r * 2.0f), r);
        float[] widths = { 1.5f, 1.5f, 1.5f, 1.5f };
        var ring_color = fade (color_mid, 0.30f);
        Gdk.RGBA[] colors = { ring_color, ring_color, ring_color, ring_color };
        snapshot.append_border (ring, widths, colors);
    }

    // --- Style name flash --------------------------------------------------

    private void draw_style_flash (Gtk.Snapshot snapshot, float w, float h) {
        if (style_changed_us == 0)
            return;

        double age = (GLib.get_monotonic_time () - style_changed_us) / 1000000.0;
        if (age > Config.VIS_LABEL_SECONDS)
            return;

        double fade = double.min (1.0, (Config.VIS_LABEL_SECONDS - age) / 0.5);

        var layout = create_pango_layout (_style.label ());
        var attrs = new Pango.AttrList ();
        attrs.insert (Pango.attr_scale_new (1.6));
        layout.set_attributes (attrs);

        int text_w;
        int text_h;
        layout.get_pixel_size (out text_w, out text_h);

        var color = color_high;
        color.alpha = (float) fade;

        snapshot.save ();
        snapshot.translate (point (w - text_w - 24.0f, h - text_h - 16.0f));
        snapshot.append_layout (layout, color);
        snapshot.restore ();
    }

    // --- Drawing helpers ---------------------------------------------------

    private void fill_gradient (Gtk.Snapshot snapshot, Graphene.Rect bounds,
                                Graphene.Point start, Graphene.Point end,
                                Gsk.ColorStop[] stops, float radius) {
        bool rounded = radius > 0.0f && bounds.size.width > radius * 2.0f;
        if (rounded) {
            var rounded_rect = Gsk.RoundedRect ();
            rounded_rect.init_from_rect (bounds, radius);
            snapshot.push_rounded_clip (rounded_rect);
        }

        snapshot.append_linear_gradient (bounds, start, end, stops);

        if (rounded)
            snapshot.pop ();
    }

    private Gsk.ColorStop[] vertical_stops (float alpha = 1.0f) {
        var low = color_low;
        var mid = color_mid;
        var high = color_high;
        low.alpha = alpha;
        mid.alpha = alpha < 1.0f ? alpha + (1.0f - alpha) * 0.5f : 1.0f;
        high.alpha = 1.0f;

        return {
            Gsk.ColorStop () { offset = 0.0f,  color = low },
            Gsk.ColorStop () { offset = 0.55f, color = mid },
            Gsk.ColorStop () { offset = 1.0f,  color = high }
        };
    }

    // Palette sampled at 0..1: low -> mid -> high.
    private Gdk.RGBA palette_at (double t) {
        t = t.clamp (0.0, 1.0);
        if (t < 0.5)
            return mix (color_low, color_mid, t * 2.0);
        return mix (color_mid, color_high, (t - 0.5) * 2.0);
    }

    private static Gdk.RGBA mix (Gdk.RGBA a, Gdk.RGBA b, double t) {
        return Gdk.RGBA () {
            red   = (float) (a.red   + (b.red   - a.red)   * t),
            green = (float) (a.green + (b.green - a.green) * t),
            blue  = (float) (a.blue  + (b.blue  - a.blue)  * t),
            alpha = 1.0f
        };
    }

    // Band level at a normalised position across the spectrum, interpolated
    // with Catmull-Rom so the column silhouette curves instead of stepping.
    private double level_at (double t) {
        int n = spectrum.bands;
        double p = t.clamp (0.0, 1.0) * (n - 1);
        int i = (int) p;
        double f = p - i;

        double p0 = spectrum.levels[int.max (i - 1, 0)];
        double p1 = spectrum.levels[i.clamp (0, n - 1)];
        double p2 = spectrum.levels[int.min (i + 1, n - 1)];
        double p3 = spectrum.levels[int.min (i + 2, n - 1)];

        return 0.5 * ((2.0 * p1)
                    + (-p0 + p2) * f
                    + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
                    + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f);
    }

    private static Gdk.RGBA fade (Gdk.RGBA color, float alpha) {
        var result = color;
        result.alpha = alpha;
        return result;
    }

    private static Graphene.Point point (float x, float y) {
        return Graphene.Point () { x = x, y = y };
    }

    private static Graphene.Rect rect (float x, float y, float w, float h) {
        return Graphene.Rect () {
            origin = Graphene.Point () { x = x, y = y },
            size = Graphene.Size () { width = w, height = h }
        };
    }
}
