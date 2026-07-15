{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    glib
    glib-networking
    gobject-introspection
    gtk4
    libsoup_3
    libxslt
    pkg-config
    vala
    json-glib
    vte-gtk4
    cava
    libxml2
    x11vnc

    meson
    ninja
    pkg-config
    gdb
    vala-lint
    vala-language-server
  ];

  GIO_MODULE_DIR = "${pkgs.glib-networking}/lib/gio/modules";
}
