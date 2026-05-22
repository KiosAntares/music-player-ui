project('player', 'vala', 'c',
  version: '0.1.0',
  meson_version: '>= 0.59.0')

dependencies = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gtk4'),
  dependency('libsoup-3.0'),
  dependency('json-glib-1.0'),
  dependency('vte-2.91-gtk4'),
]

sources = files(
  'src/jellyfin.vala',
  'src/menu.vala',
  'src/player.vala',
)

executable('player',
  sources,
  dependencies: dependencies,
  install: false)
