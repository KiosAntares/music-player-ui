using Vte;

namespace Cava {
    // Builds the terminal that runs the `cava` audio visualizer.
    public Vte.Terminal create_terminal () {
        var terminal = new Vte.Terminal ();
        terminal.spawn_async (
            Vte.PtyFlags.DEFAULT,
            null,                        // working directory
            { "cava" },                  // command + args
            null,                        // environment
            GLib.SpawnFlags.SEARCH_PATH,
            null,                        // child setup
            -1,                          // timeout
            null,                        // cancellable
            (t, pid, error) => {
                if (error != null)
                    warning ("Spawn error: %s", error.message);
            }
        );
        return terminal;
    }
}
