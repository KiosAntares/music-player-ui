// Turns captured audio into the numbers a visualiser draws: a log-spaced band
// spectrum with cava-style smoothing, plus a trigger-aligned waveform for the
// oscilloscope style.
//
// Analysis runs on the UI thread, once per rendered frame, so band smoothing is
// naturally frame-rate correct and there is no second set of shared state to
// keep locked. The only cross-thread handoff is AudioMonitor's ring buffer.
public class Spectrum : GLib.Object {

    // 4096 @ 44.1 kHz is ~93 ms of audio and ~10.8 Hz per bin: enough bass
    // resolution to keep the low bands from collapsing into each other, while
    // still reacting fast enough to look like it is following the music.
    public const int FFT_SIZE = 4096;
    public const int WAVE_POINTS = 1024;

    // Smoothed band levels, 0..1, low frequency first.
    public double[] levels;
    // Falling peak markers, same indexing as `levels`.
    public double[] peaks;
    // Most recent waveform, aligned to a rising zero crossing so the scope
    // style does not jitter horizontally, and normalised the same way the
    // bands are so it stays legible at any playback volume. Clamped to -1..1.
    public float[] wave;

    public int bands { get; private set; }

    private AudioMonitor monitor = new AudioMonitor ();
    private Fft.Plan plan;

    private double[] window;
    private double[] re;
    private double[] im;
    private float[] pcm;
    private double[] raw;
    private double[] spread;
    private double[] peak_velocity;

    // Bins covered by each band. `bin_hi < bin_lo` means the band is narrower
    // than one bin, and is sampled by interpolating at `bin_center` instead.
    private int[] bin_lo;
    private int[] bin_hi;
    private double[] bin_center;
    private double[] tilt_db;

    private double gain = 1.0;
    private double gain_peak = 0.0;
    private double wave_gain = 1.0;
    private double wave_peak = 0.0;

    // Neighbour bleed, applied outwards from each band. Gives the "liquid"
    // look cava calls monstercat smoothing without an O(n^2) pow() sweep.
    private const double[] SPREAD_WEIGHTS = { 1.0, 0.62, 0.32, 0.14 };

    public Spectrum (int bands) {
        this.bands = bands;

        plan = new Fft.Plan (FFT_SIZE);

        window = new double[FFT_SIZE];
        for (int i = 0; i < FFT_SIZE; i++)   // Hann
            window[i] = 0.5 * (1.0 - Math.cos (2.0 * Math.PI * i / (FFT_SIZE - 1)));

        re = new double[FFT_SIZE];
        im = new double[FFT_SIZE];
        pcm = new float[FFT_SIZE];
        wave = new float[WAVE_POINTS];

        levels = new double[bands];
        peaks = new double[bands];
        raw = new double[bands];
        spread = new double[bands];
        peak_velocity = new double[bands];

        bin_lo = new int[bands];
        bin_hi = new int[bands];
        bin_center = new double[bands];
        tilt_db = new double[bands];

        build_bands ();
    }

    public void start () {
        monitor.start ();
    }

    // Advances the analysis by `dt` seconds of wall clock.
    public void update (double dt) {
        if (!monitor.snapshot (pcm)) {
            for (int i = 0; i < bands; i++)
                raw[i] = 0.0;
        } else {
            build_wave (dt);
            analyse ();
        }

        apply_spread ();
        apply_gain (dt);
        apply_smoothing (dt);
        apply_peaks (dt);
    }

    // --- Band layout -------------------------------------------------------

    private void build_bands () {
        double bin_per_hz = (double) FFT_SIZE / AudioMonitor.SAMPLE_RATE;
        double ratio = Math.log (Config.VIS_FREQ_HIGH / Config.VIS_FREQ_LOW);
        int max_bin = FFT_SIZE / 2 - 1;

        for (int i = 0; i < bands; i++) {
            double f_lo = Config.VIS_FREQ_LOW * Math.exp (ratio * i / bands);
            double f_hi = Config.VIS_FREQ_LOW * Math.exp (ratio * (i + 1) / bands);

            double b_lo = f_lo * bin_per_hz;
            double b_hi = f_hi * bin_per_hz;

            bin_center[i] = (b_lo + b_hi).clamp (2.0, 2.0 * max_bin) * 0.5;
            bin_lo[i] = ((int) Math.ceil (b_lo)).clamp (1, max_bin);
            bin_hi[i] = ((int) Math.floor (b_hi)).clamp (1, max_bin);

            // Music loses energy with frequency; without a tilt the top half of
            // the display barely moves. Ramped in dB so it reads as a constant
            // slope rather than crushing the treble into clipping.
            tilt_db[i] = Config.VIS_TILT_DB * i / (bands - 1.0);
        }
    }

    // --- Per-frame analysis ------------------------------------------------

    private void analyse () {
        for (int i = 0; i < FFT_SIZE; i++) {
            re[i] = pcm[i] * window[i];
            im[i] = 0.0;
        }

        plan.forward (re, im);

        // Hann has a coherent gain of 0.5, so a full-scale sine lands at
        // FFT_SIZE/4 in one bin; scaling by 4/N puts that at 1.0 == 0 dBFS.
        double scale = 4.0 / FFT_SIZE;
        double span = Config.VIS_TOP_DB - Config.VIS_FLOOR_DB;

        for (int i = 0; i < bands; i++) {
            double mag;
            if (bin_hi[i] >= bin_lo[i]) {
                mag = 0.0;
                for (int k = bin_lo[i]; k <= bin_hi[i]; k++)
                    mag = double.max (mag, magnitude (k));
            } else {
                // Narrower than a bin: interpolate so the bass bands differ
                // from one another instead of all reporting the same bin.
                double c = bin_center[i];
                int k = (int) c;
                double f = c - k;
                mag = magnitude (k) * (1.0 - f) + magnitude (k + 1) * f;
            }

            double db = 20.0 * Math.log10 (mag * scale + 1e-10) + tilt_db[i];
            raw[i] = ((db - Config.VIS_FLOOR_DB) / span).clamp (0.0, 1.0);
        }
    }

    private inline double magnitude (int k) {
        return Math.sqrt (re[k] * re[k] + im[k] * im[k]);
    }

    // Copies out a window of PCM starting at a rising zero crossing, so a
    // steady tone renders as a stationary wave rather than a scrolling one.
    //
    // The window is scaled to fill the display. Monitor sources are captured
    // after the volume control, so without this the scope would flatten into a
    // line at anything but full volume, while the bands (which have their own
    // sensitivity control) carried on looking fine.
    private void build_wave (double dt) {
        int search = FFT_SIZE - WAVE_POINTS;
        int start = 0;
        for (int i = 1; i < search; i++) {
            if (pcm[i - 1] <= 0.0f && pcm[i] > 0.0f) {
                start = i;
                break;
            }
        }

        double peak = 0.0;
        for (int i = 0; i < WAVE_POINTS; i++)
            peak = double.max (peak, Math.fabs (pcm[start + i]));

        if (Config.VIS_AUTO_GAIN) {
            wave_peak = double.max (peak, wave_peak - dt * Config.VIS_GAIN_DECAY);
            wave_gain = (0.85 / double.max (wave_peak, 0.02))
                .clamp (1.0, Config.VIS_WAVE_GAIN_MAX);
        } else {
            wave_gain = 1.0;
        }

        for (int i = 0; i < WAVE_POINTS; i++)
            wave[i] = (float) ((pcm[start + i] * wave_gain).clamp (-1.0, 1.0));
    }

    private void apply_spread () {
        if (!Config.VIS_SPREAD) {
            for (int i = 0; i < bands; i++)
                spread[i] = raw[i];
            return;
        }

        for (int i = 0; i < bands; i++)
            spread[i] = 0.0;

        int radius = SPREAD_WEIGHTS.length - 1;
        for (int i = 0; i < bands; i++) {
            for (int d = -radius; d <= radius; d++) {
                int j = i + d;
                if (j < 0 || j >= bands)
                    continue;
                double v = raw[i] * SPREAD_WEIGHTS[d.abs ()];
                if (v > spread[j])
                    spread[j] = v;
            }
        }
    }

    // Slow automatic sensitivity, so quiet passages still fill the display and
    // loud ones do not sit pinned at the top. The peak decays over seconds,
    // which keeps the gain from pumping on individual drum hits.
    private void apply_gain (double dt) {
        if (!Config.VIS_AUTO_GAIN) {
            gain = 1.0;
            return;
        }

        double frame_peak = 0.0;
        for (int i = 0; i < bands; i++)
            frame_peak = double.max (frame_peak, spread[i]);

        gain_peak = double.max (frame_peak, gain_peak - dt * Config.VIS_GAIN_DECAY);
        gain = (0.92 / double.max (gain_peak, 0.12)).clamp (1.0, Config.VIS_GAIN_MAX);
    }

    private void apply_smoothing (double dt) {
        // Exponential approach expressed as a time constant, so the look stays
        // the same whether we are running at 60 fps or dropping frames.
        double attack = 1.0 - Math.exp (-dt / Config.VIS_ATTACK_SECONDS);
        double decay = 1.0 - Math.exp (-dt / Config.VIS_DECAY_SECONDS);

        for (int i = 0; i < bands; i++) {
            double target = (spread[i] * gain).clamp (0.0, 1.0);
            double rate = target > levels[i] ? attack : decay;
            levels[i] += (target - levels[i]) * rate;
        }
    }

    private void apply_peaks (double dt) {
        for (int i = 0; i < bands; i++) {
            if (levels[i] >= peaks[i]) {
                peaks[i] = levels[i];
                peak_velocity[i] = 0.0;
            } else {
                peak_velocity[i] += Config.VIS_PEAK_GRAVITY * dt;
                peaks[i] = double.max (levels[i], peaks[i] - peak_velocity[i] * dt);
            }
        }
    }
}
