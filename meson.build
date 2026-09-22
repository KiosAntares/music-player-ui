project('player', 'vala', 'c',
  version: '0.1.0',
  meson_version: '>= 0.59.0')

# Our own libpulse-simple.vapi lives here and must win over any system copy.
add_project_arguments(['--vapidir', meson.current_source_dir() / 'vapi'],
  language: 'vala')

cc = meson.get_compiler('c')

dependencies = [
  cc.find_library('m'),          # the FFT and band mapping need libm
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gtk4'),
  dependency('libsoup-3.0'),
  dependency('json-glib-1.0'),
  dependency('libpulse-simple'),
]

sources = files(
  'src/config.vala',
  'src/session-info.vala',
  'src/jellyfin.vala',
  'src/bluetooth-media.vala',
  'src/artwork.vala',
  'src/art-cache.vala',
  'src/system-actions.vala',
  'src/fft.vala',
  'src/audio-monitor.vala',
  'src/spectrum.vala',
  'src/visualizer.vala',
  'src/style.vala',
  'src/menu-page.vala',
  'src/player-page.vala',
  'src/application.vala',
)

executable('player',
  sources,
  dependencies: dependencies,
  install: false)
