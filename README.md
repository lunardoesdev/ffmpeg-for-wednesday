# ffmpeg-wednesday

Four FFmpeg branches - 6, 7, 8 and 9 - cross-built for **aarch64-android33**
with the NDK r29 toolchain through [retrolunar2](https://github.com/lunardoesdev/retrolunar2),
handed over as one tarball each.

Built and exported with **retrolunar2** -
<https://github.com/lunardoesdev/retrolunar2>, tag `2.14`; its `--version` still
answers `2.10.0`, so go by the tag. `meson setup builddir && ninja -C builddir`
is the whole build of it, and it has to be installed for anything here: the
export asks it for each branch's dependencies. The recipes come from the
`retrolunar2-packages` checkout next to this one.

## What is here

- `export.sh` - writes one `*.tar.xz` per version plus `SHA256SUMS`.
- `GUIDE.md` - the walk-through, command by command.
- `dist/` - where `sh export.sh` writes (produced, not committed).

## Getting the tarballs

Step by step, the commands and what they print, is in [GUIDE.md](GUIDE.md).

```sh
sh export.sh              # -> dist/ffmpeg-<version>-aarch64-android33.tar.xz
RETROLUNAR=~/ond/git/retrolunar2/builddir/retrolunar sh export.sh   # tool elsewhere
RETROLUNAR_NEST=/other/nest sh export.sh /tmp/out                   # a nest elsewhere
```

The script builds nothing: it packs the four entries the nest already holds, and
asks the tool which libraries each branch's tarball has to carry. Those entries
came from retrolunar2 built against the recipes in the `retrolunar2-packages`
checkout next to this one - <https://github.com/lunardoesdev/retrolunar2-packages>,
tag `2.14` - one branch at a time:

```sh
retrolunar --packages ../retrolunar2-packages generate -x 'ffmpeg-9@aarch64-android33'
```

## The tarballs

| tarball | version |
|---|---|
| `ffmpeg-6.1.6-aarch64-android33.tar.xz` | 6.1.6 |
| `ffmpeg-7.1.5-aarch64-android33.tar.xz` | 7.1.5 |
| `ffmpeg-8.1.3-aarch64-android33.tar.xz` | 8.1.3 |
| `ffmpeg-9.0.2-aarch64-android33.tar.xz` | 9.0.2 |

The version in the name is read from `include/libavutil/ffversion.h` inside the
built prefix, so it cannot disagree with the library it names.

Each holds an installed prefix, flat - `lib/`, `include/`, `share/`:

- `lib/libav*.a` - seven static libraries: `libavcodec.a`, `libavformat.a`,
  `libavfilter.a`, `libavutil.a`, `libswscale.a`, `libswresample.a`,
  `libavdevice.a`
- `lib/libav*.so` - the same seven as shared libraries, built with
  `--enable-shared` next to `--enable-static`. They are ordinary files, not
  symlinks: FFmpeg's Android target installs them unversioned, which is how
  Bionic's loader expects to find them (there is no `libavcodec.so.N` and
  nothing to point at one).
- `lib/pkgconfig/libav*.pc` - seven `.pc` files, whose dependency links
  `export.sh` rewrites to `${libdir}`, so they answer for a tarball unpacked
  anywhere
- `lib/libbz2.a`, `lib/liblzma.a`, `lib/libmp3lame.a`, `lib/libopus.a`,
  `lib/libvpx.a`, `lib/libz.a`, `lib/libz.so*` - the libraries the branch links
  against, packed in so the tarball links on its own
- `include/libav*/*.h` - 137 to 145 headers, depending on the branch

```sh
tar -C /some/prefix -xf dist/ffmpeg-9.0.2-aarch64-android33.tar.xz
```

How to link against one, with what the missing-symbols failure and its fix
measured, is the "Link against one" section of [GUIDE.md](GUIDE.md).

## What is not in them

- **No programs.** The recipes pass `--disable-programs`, so there is no
  `ffmpeg`, `ffprobe` or `ffplay` binary: these are libraries only. A *static*
  prefix is what the tool's own hand-over has to carry for an Android target,
  because a shipped binary would load its libraries from the application's own
  directory and a bundle cannot relocate it.
- **No Android system libraries.** `libc`, `libm`, `liblog`, `libdl`,
  `libandroid`, `libmediandk`, `libcamera2ndk` and the rest are on the device,
  and the NDK's sysroot answers their `-l` flags at link time; the tool calls
  them platform libraries and leaves them out on purpose. Nothing has to ship
  them.
- **Both kinds of library**, and the external libraries compiled in are exactly
  six: `zlib`, `bzlib`, `lzma`, `libopus`, `libvpx`, `libmp3lame`. The static
  archives are linked into an application. The shared ones carry bzlib, lzma,
  libopus, libvpx and libmp3lame inside them (the nest builds those static-only),
  and zlib stays a separate `libz.so.1` - `readelf -d lib/libavcodec.so` lists
  `NEEDED libz.so.1` - which now travels inside the same `lib/`, so a dynamic
  consumer finds it beside the libraries that want it. Enable more by adding
  recipes and rebuilding with the matching `--enable-*`.

## Checking

```sh
sha256sum -c dist/SHA256SUMS
tar -tJf dist/ffmpeg-6.1.6-aarch64-android33.tar.xz | head
ar t <extract>/lib/libavcodec.a | head        # members are ELF64 / AArch64
```
