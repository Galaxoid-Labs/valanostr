project('valanostr', ['c', 'vala'],
  version: '0.1.0',
)

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
json_glib_dep = dependency('json-glib-1.0')

cc = meson.get_compiler('c')
secp256k1_inc = include_directories('lib/include')
secp256k1_lib = cc.find_library('secp256k1',
  dirs: [meson.project_source_root() / 'lib' / host_machine.cpu_family()],
  static: true,
)

common_deps = [glib_dep, gobject_dep, json_glib_dep, secp256k1_lib]
common_vala_args = ['--vapidir=' + meson.project_source_root() / 'vapi', '--pkg=secp256k1']

valanostr_lib = library('valanostr',
  'src/nostr.vala',
  dependencies: common_deps,
  vala_args: common_vala_args,
  vala_header: 'valanostr.h',
  vala_vapi: 'valanostr.vapi',
  include_directories: secp256k1_inc,
  install: true,
  install_dir: [
    get_option('libdir'),
    get_option('includedir') / 'valanostr',
    get_option('datadir') / 'vala' / 'vapi',
  ],
)

# pkg-config file for dependency('valanostr') in consumer projects
pkg = import('pkgconfig')
pkg.generate(valanostr_lib,
  name: 'valanostr',
  description: 'Nostr protocol library for Vala',
  requires: [glib_dep, gobject_dep, json_glib_dep],
  subdirs: ['valanostr'],
  # secp256k1 is statically linked into libvalanostr, so consumers don't need it
  libraries_private: [],
)

# Meson subproject dependency (for wrap/subproject usage)
valanostr_dep = declare_dependency(
  link_with: valanostr_lib,
  include_directories: include_directories('.'),
  dependencies: [glib_dep, gobject_dep, json_glib_dep],
)

test_exe = executable('test_nostr',
  'tests/test_nostr.vala',
  'src/nostr.vala',
  dependencies: common_deps,
  vala_args: common_vala_args,
  include_directories: secp256k1_inc,
)

test('nostr-tests', test_exe)
