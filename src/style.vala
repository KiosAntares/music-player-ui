using Gtk;
using Gdk;

namespace Style {
    private const string CSS = """
        * {
            font-family: "CaskaydiaCove Nerd Font";
            font-size: 1.2em;
        }
        window {
            background: radial-gradient(circle at center, #1a1a1e, #000000);
        }
        .play-button {
            -gtk-icon-size: 32px;
            padding: 0;
        }
    """;

    // Installs the application stylesheet on the default display.
    public void apply () {
        var css = new Gtk.CssProvider ();
        css.load_from_data (CSS.data);

        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }
}
