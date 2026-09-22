namespace Config {
    // --- Jellyfin connection ---
    public const string JELLYFIN_URL = "https://jf.kios.ovh";
    public const string JELLYFIN_KEY = "d761990c50a949e4811df7fcad6edfe4";
    public const string JELLYFIN_DEVICE = "test-device";

    // --- Polling ---
    public const uint POLL_INTERVAL_SECONDS = 1;

    // --- Window ---
    public const int WINDOW_WIDTH = 1920;
    public const int WINDOW_HEIGHT = 480;

    // --- Audio visualizer ---
    // Which source to visualise. Empty means "monitor of whatever `pactl
    // get-default-sink` reports", which follows the sink around automatically.
    // Set it explicitly to pin one source -- useful with EasyEffects in the
    // chain, where you may want the processed output rather than the raw sink
    // (`pactl list short sources` lists the candidates).
    public const string VIS_MONITOR_SOURCE = "";

    // Number of frequency bands drawn. 64 fills a 1920px display nicely; drop
    // it if you want fatter bars, not for performance (the FFT cost is fixed).
    public const int VIS_BANDS = 64;
    // Frame budget cap. The Orange Pi 4 holds 60 comfortably at 1920x480; lower
    // this to 30 if you ever run the UI on something weaker.
    public const int VIS_MAX_FPS = 60;

    // Frequency range spread across the bands, in Hz.
    public const double VIS_FREQ_LOW = 35.0;
    public const double VIS_FREQ_HIGH = 16000.0;

    // Level mapping. Everything below FLOOR is silence, TOP is full scale, and
    // TILT lifts the treble end to compensate for music's natural rolloff.
    public const double VIS_FLOOR_DB = -60.0;
    public const double VIS_TOP_DB = 0.0;
    public const double VIS_TILT_DB = 12.0;

    // Automatic sensitivity, so quiet tracks still fill the display.
    public const bool VIS_AUTO_GAIN = true;
    public const double VIS_GAIN_MAX = 4.0;
    public const double VIS_WAVE_GAIN_MAX = 12.0;   // scope needs more headroom
    public const double VIS_GAIN_DECAY = 0.25;   // peak units per second

    // Motion. Attack is how fast a band rises, decay how slowly it falls.
    public const double VIS_ATTACK_SECONDS = 0.025;
    public const double VIS_DECAY_SECONDS = 0.16;
    public const bool VIS_SPREAD = true;         // bleed into neighbouring bands
    public const bool VIS_SHOW_PEAKS = true;
    public const double VIS_PEAK_GRAVITY = 1.1;

    // Appearance.
    // Columns used by the Wave and Scope styles. Each is one render node, so
    // this trades silhouette smoothness against nodes per frame; 256 holds
    // 55+ fps on the player box.
    public const int VIS_CURVE_COLUMNS = 256;
    public const double VIS_BAR_GAP = 0.26;      // fraction of each bar's slot
    public const double VIS_BAR_RADIUS = 3.0;
    public const string VIS_COLOR_LOW = "#1d4ed8";
    public const string VIS_COLOR_MID = "#a855f7";
    public const string VIS_COLOR_HIGH = "#f9a8d4";
    public const double VIS_LABEL_SECONDS = 1.8; // style name flash on switch
}
