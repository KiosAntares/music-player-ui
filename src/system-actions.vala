// Centralized wrappers around system shell commands, so the UI code never
// touches GLib.Process directly and error handling stays consistent.
public class SystemActions {

    private static void run (string command) {
        try {
            GLib.Process.spawn_command_line_async (command);
        } catch (SpawnError e) {
            warning ("Failed to run '%s': %s", command, e.message);
        }
    }

    public static void poweroff () {
        run ("systemctl poweroff");
    }

    public static void reboot () {
        run ("systemctl reboot");
    }

    public static void start_vnc () {
        run ("x11vnc -display :0 -forever -shared -bg");
    }

    public static void stop_vnc () {
        run ("pkill x11vnc");
    }

    public static bool vnc_running () {
        try {
            string standard_output;
            string standard_error;
            int exit_status;
            GLib.Process.spawn_command_line_sync ("pgrep -x x11vnc",
                out standard_output, out standard_error, out exit_status);
            GLib.Process.check_wait_status (exit_status);
            return true;
        } catch (Error e) {
            return false;
        }
    }

    public static void change_volume (int delta) {
        string sign = delta > 0 ? "+" : "-";
        run ("pactl set-sink-volume @DEFAULT_SINK@ %s%d%%".printf (sign, delta.abs ()));
    }
}
