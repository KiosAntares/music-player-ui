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
// Analysis only runs while the widget is mapped — GtkStack unmaps the pages you
// cannot see, so sitting on the player page costs nothing.
public class Visualizer : Gtk.Widget {

    private Spectrum spectrum;

    private Gdk.RGBA color_low;
    private Gdk.RGBA color_mid;
    private Gdk.RGBA color_high;

    private uint tick_id = 0;
    private int64 last_frame_us = 0;

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
            return;
        }

        double dt = (now - last_frame_us) / 1000000.0;
        if (dt < 1.0 / Config.VIS_MAX_FPS)
            return;                       // frame budget cap, not a vsync skip
        last_frame_us = now;

        spectrum.update (double.min (dt, 0.2));   // clamp after e.g. a page switch
        queue_draw ();
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

        var line = color_mid;
        line.alpha = 0.25f;
        snapshot.append_color (line, rect (0.0f, center - 0.5f, w, 1.0f));
    }

    // The spectrum as one smooth filled curve, with a brighter stroke along the
    // top edge.
    private void draw_wave (Gtk.Snapshot snapshot, float w, float h) {
        float[] xs;
        float[] ys;
        curve_points (w, h, out xs, out ys);

        var fill_stops = vertical_stops (0.15f);
        snapshot.push_fill (curve_path (xs, ys, w, h, true), Gsk.FillRule.WINDING);
        snapshot.append_linear_gradient (rect (0.0f, 0.0f, w, h),
            point (0.0f, h), point (0.0f, 0.0f), fill_stops);
        snapshot.pop ();

        var stroke = new Gsk.Stroke (2.5f);
        stroke.set_line_join (Gsk.LineJoin.ROUND);
        stroke.set_line_cap (Gsk.LineCap.ROUND);
        snapshot.append_stroke (curve_path (xs, ys, w, h, false), stroke, color_high);
    }

    // Oscilloscope over the raw (zero-crossing aligned) waveform.
    private void draw_scope (Gtk.Snapshot snapshot, float w, float h) {
        unowned float[] samples = spectrum.wave;
        int n = samples.length;

        var builder = new Gsk.PathBuilder ();
        for (int i = 0; i < n; i++) {
            float x = i * w / (n - 1);
            float y = h * 0.5f - samples[i] * h * 0.45f;
            if (i == 0)
                builder.move_to (x, y);
            else
                builder.line_to (x, y);
        }
        var path = builder.to_path ();

        var axis = color_mid;
        axis.alpha = 0.18f;
        snapshot.append_color (axis, rect (0.0f, h * 0.5f - 0.5f, w, 1.0f));

        // Wide translucent pass underneath the sharp one reads as a glow
        // without needing a blur node (which is the expensive one on Mali).
        var glow_color = color_mid;
        glow_color.alpha = 0.22f;
        var glow = new Gsk.Stroke (7.0f);
        glow.set_line_join (Gsk.LineJoin.ROUND);
        glow.set_line_cap (Gsk.LineCap.ROUND);
        snapshot.append_stroke (path, glow, glow_color);

        var line = new Gsk.Stroke (2.0f);
        line.set_line_join (Gsk.LineJoin.ROUND);
        line.set_line_cap (Gsk.LineCap.ROUND);
        snapshot.append_stroke (path, line, color_high);
    }

    // Bands radiating from the centre, coloured by angle via a conic gradient.
    private void draw_radial (Gtk.Snapshot snapshot, float w, float h) {
        int n = spectrum.bands;
        float cx = w * 0.5f;
        float cy = h * 0.5f;
        float inner = float.min (w, h) * 0.17f;
        float outer = float.min (w, h) * 0.47f;
        float step = (float) (2.0 * Math.PI / n);
        float half_width = step * 0.36f;

        var builder = new Gsk.PathBuilder ();
        for (int i = 0; i < n; i++) {
            float angle = (float) (-Math.PI * 0.5) + step * i;
            float r_out = inner + (float) spectrum.levels[i] * (outer - inner);
            r_out = float.max (r_out, inner + 2.0f);

            float a0 = angle - half_width;
            float a1 = angle + half_width;

            builder.move_to (cx + inner * Math.cosf (a0), cy + inner * Math.sinf (a0));
            builder.line_to (cx + r_out * Math.cosf (a0), cy + r_out * Math.sinf (a0));
            builder.line_to (cx + r_out * Math.cosf (a1), cy + r_out * Math.sinf (a1));
            builder.line_to (cx + inner * Math.cosf (a1), cy + inner * Math.sinf (a1));
            builder.close ();
        }

        snapshot.push_fill (builder.to_path (), Gsk.FillRule.WINDING);
        snapshot.append_conic_gradient (rect (0.0f, 0.0f, w, h), point (cx, cy), 0.0f,
                                        conic_stops ());
        snapshot.pop ();

        // Faint ring so the centre does not look like a hole when it is quiet.
        var ring_color = color_mid;
        ring_color.alpha = 0.30f;
        var ring = new Gsk.PathBuilder ();
        ring.add_circle (point (cx, cy), inner - 4.0f);
        snapshot.append_stroke (ring.to_path (), new Gsk.Stroke (1.5f), ring_color);
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

    // Symmetric around the seam so the circle has no visible discontinuity.
    private Gsk.ColorStop[] conic_stops () {
        return {
            Gsk.ColorStop () { offset = 0.0f,  color = color_low },
            Gsk.ColorStop () { offset = 0.25f, color = color_mid },
            Gsk.ColorStop () { offset = 0.5f,  color = color_high },
            Gsk.ColorStop () { offset = 0.75f, color = color_mid },
            Gsk.ColorStop () { offset = 1.0f,  color = color_low }
        };
    }

    private void curve_points (float w, float h, out float[] xs, out float[] ys) {
        int n = spectrum.bands;
        xs = new float[n + 2];
        ys = new float[n + 2];

        for (int i = 0; i < n; i++) {
            xs[i + 1] = (i + 0.5f) * w / n;
            ys[i + 1] = h - (float) spectrum.levels[i] * h * 0.94f;
        }
        // Anchor the ends at the edges so the fill reaches the widget borders.
        xs[0] = 0.0f;
        ys[0] = ys[1];
        xs[n + 1] = w;
        ys[n + 1] = ys[n];
    }

    // Catmull-Rom through the band tops, emitted as cubic Beziers.
    private Gsk.Path curve_path (float[] xs, float[] ys, float w, float h, bool closed) {
        var builder = new Gsk.PathBuilder ();
        int m = xs.length;

        builder.move_to (xs[0], ys[0]);
        for (int i = 0; i < m - 1; i++) {
            int prev = int.max (i - 1, 0);
            int next = int.min (i + 2, m - 1);

            float c1x = xs[i] + (xs[i + 1] - xs[prev]) / 6.0f;
            float c1y = ys[i] + (ys[i + 1] - ys[prev]) / 6.0f;
            float c2x = xs[i + 1] - (xs[next] - xs[i]) / 6.0f;
            float c2y = ys[i + 1] - (ys[next] - ys[i]) / 6.0f;

            builder.cubic_to (c1x, c1y, c2x, c2y, xs[i + 1], ys[i + 1]);
        }

        if (closed) {
            builder.line_to (w, h);
            builder.line_to (0.0f, h);
            builder.close ();
        }
        return builder.to_path ();
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
