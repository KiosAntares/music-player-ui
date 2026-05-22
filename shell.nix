{ pkgs ? import <nixpkgs> {} }:
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

    meson
    ninja
    pkg-config
  ];

  GIO_MODULE_DIR = "${pkgs.glib-networking}/lib/gio/modules";
}
