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
  'src/config.vala',
  'src/session-info.vala',
  'src/jellyfin.vala',
  'src/bluetooth-media.vala',
  'src/artwork.vala',
  'src/system-actions.vala',
  'src/cava.vala',
  'src/style.vala',
  'src/menu-page.vala',
  'src/player-page.vala',
  'src/application.vala',
)

executable('player',
  sources,
  dependencies: dependencies,
  install: false)
