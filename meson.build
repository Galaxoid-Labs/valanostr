project('valanostr', ['c', 'vala'],
  version: '0.1.0',
)

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
json_glib_dep = dependency('json-glib-1.0')

# Build libsecp256k1 from git submodule sources
secp256k1_src = files(
  'deps/secp256k1/src/secp256k1.c',
  'deps/secp256k1/src/precomputed_ecmult.c',
  'deps/secp256k1/src/precomputed_ecmult_gen.c',
)
secp256k1_inc = include_directories(
  'deps/secp256k1/include',
  'deps/secp256k1/src',
)
secp256k1_lib = static_library('secp256k1',
  secp256k1_src,
  include_directories: secp256k1_inc,
  c_args: [
    '-DENABLE_MODULE_SCHNORRSIG=1',
    '-DENABLE_MODULE_EXTRAKEYS=1',
    '-DECMULT_WINDOW_SIZE=15',
    '-DCOMB_BLOCKS=43',
    '-DCOMB_TEETH=6',
  ],
)
secp256k1_dep = declare_dependency(
  link_with: secp256k1_lib,
  include_directories: include_directories('deps/secp256k1/include'),
)

common_deps = [glib_dep, gobject_dep, json_glib_dep, secp256k1_dep]
common_vala_args = ['--vapidir=' + meson.project_source_root() / 'vapi', '--pkg=secp256k1']

valanostr_lib = library('valanostr',
  'src/nostr.vala',
  'src/nip19.vala',
  dependencies: common_deps,
  vala_args: common_vala_args,
  vala_header: 'valanostr.h',
  vala_vapi: 'valanostr.vapi',
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
  'src/nip19.vala',
  dependencies: common_deps,
  vala_args: common_vala_args,
)

test('nostr-tests', test_exe)
