# ffmpeg-wednesday

Four FFmpeg branches - 6, 7, 8 and 9 - cross-built for **aarch64-android33**
with the NDK r29 toolchain through [retrolunar](https://github.com/lunardoesdev/retrolunar2),
handed over as one tarball each.

Built and exported with retrolunar 2.10.0 against the `retrolunar2-packages`
recipes in the checkout next to this one (see `retrolunar.toml`).

## What is here

- `retrolunar.toml` - the manifest: the four targets, where the recipes come
  from, and a `build` that packs the result. The project is the hand-over, so
  its "build" is the export.
- `export.sh` - writes one `*.tar.xz` per version plus `SHA256SUMS`.
- `dist/` - where `sh export.sh` writes (produced, not committed).

## Two ways to get the tarballs

**Through the tool** (the manifest is the project):

```sh
cd ~/ond/git/ffmpeg-wednesday
retrolunar --no-default-repo build    # builds the four deps, then packs them
```

`--no-default-repo` matters here: this manifest names a repository, and the
default tree the tool keeps also carries `system@aarch64-android33`. With both
in play the system directory came out as a two-element list joined by a colon
(`/home/satori/ond/git/retrolunar2-packages:/home/satori/.cache/retrolunar/repos/default/system@aarch64-android33`,
measured) and CMake refused it as a toolchain file path; with one tree the
system directory is one directory again.

The tarballs land in this project's own entry under the nest, at
`<nest>/ffmpeg-wednesday@clang-native/share/ffmpeg-wednesday/`, and the entry's
name is the hash of its inputs, so a rebuild never lands on top of the old one.

**With the script alone** (packs what the nest already holds, builds nothing):

```sh
sh export.sh              # -> dist/ffmpeg-<version>-aarch64-android33.tar.xz
RETROLUNAR_NEST=/other/nest sh export.sh /tmp/out   # a nest elsewhere
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
- `lib/pkgconfig/libav*.pc` - seven `.pc` files
- `include/libav*/*.h` - 137 to 145 headers, depending on the branch

```sh
tar -C /some/prefix -xf dist/ffmpeg-9.0.2-aarch64-android33.tar.xz
```

## What is not in them

- **No programs.** The recipes pass `--disable-programs`, so there is no
  `ffmpeg`, `ffprobe` or `ffplay` binary: these are libraries only. A *static*
  prefix is what the tool's own hand-over has to carry for an Android target,
  because a shipped binary would load its libraries from the application's own
  directory and a bundle cannot relocate it.
- **No dependencies.** zlib, bzip2, xz, opus, libvpx and lame are separate
  entries. For a self-contained hand-over use the tool's cache format, which
  carries the whole closure:

  ```sh
  retrolunar cache push --cache dist/cache ffmpeg-6@aarch64-android33
  ```

- **The `.pc` files name the build machine.** Their `prefix` is relative to the
  file (`${pcfiledir}/../..`) and `Libs:` is just the library itself, but
  `Libs.private:` - what a static link needs - carries absolute `-L` paths to
  the dependencies as they were built in the nest, so `pkg-config --static`
  wants those prefixes present.
- **Both kinds of library**, and the external libraries compiled in are exactly
  six: `zlib`, `bzlib`, `lzma`, `libopus`, `libvpx`, `libmp3lame`. The static
  archives are linked into an application. The shared ones carry bzlib, lzma,
  libopus, libvpx and libmp3lame inside them (the nest builds those static-only)
  but **not zlib**: `readelf -d lib/libavcodec.so` lists
  `NEEDED libz.so.1`, so a dynamic consumer needs that library next to them -
  it comes from the nest's `zlib@aarch64-android33` entry,
  `retrolunar cache push --cache dist/cache zlib@aarch64-android33`. The system
  libraries (`libc`, `libm`, `liblog`) are on every Android. Enable more by
  adding recipes and rebuilding with the matching `--enable-*`.

## Checking

```sh
sha256sum -c dist/SHA256SUMS
tar -tJf dist/ffmpeg-6.1.6-aarch64-android33.tar.xz | head
ar t <extract>/lib/libavcodec.a | head        # members are ELF64 / AArch64
```
