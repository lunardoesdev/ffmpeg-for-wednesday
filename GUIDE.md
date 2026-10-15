# Getting the tarballs

Four tarballs, one per FFmpeg branch - 6.1.6, 7.1.5, 8.1.3, 9.0.2 - built for
**aarch64-android33** with the NDK r29 toolchain. `export.sh` is what makes
them. This is the walk-through; every command below was run as it is written, on
this machine, against the nest those builds live in.

## What you need first

- The four packages already built in a nest. The default is
  `~/.cache/retrolunar/nestdir`; `RETROLUNAR_NEST` points the script at another.
- **retrolunar2**, the tool that packed these builds - from
  <https://github.com/lunardoesdev/retrolunar2>, tag `2.15`. `export.sh` asks it
  (`retrolunar export`) which libraries a branch links against instead of keeping
  its own list of them, and without those dependencies a tarball does not link.
  Installed into `~/.local/bin`, which is on `PATH` here:

```sh
$ git clone https://github.com/lunardoesdev/retrolunar2
$ cd retrolunar2 && git checkout 2.15
$ meson setup builddir -Dprefix=$HOME/.local    # needs meson, ninja, a C compiler
$ ninja -C builddir && meson install -C builddir
$ retrolunar --help
```

  `flock`, `awk`, `tar` and `sha256sum` are wanted at run time. The tag and the
  version string disagree - `2.15` still answers `retrolunar 2.10.0` - so go by
  the tag. A tool that lives somewhere else is named on every call:

```sh
$ RETROLUNAR=/path/to/retrolunar sh export.sh
```

- The recipe tree: `export.sh` names none, so the tool fetches its own -
  retrolunar2-packages, cloned into `~/.cache/retrolunar/packages` on first use
  (2.14 and later). `RETROLUNAR_PACKAGES` names a tree when the recipes come
  from somewhere else.

- Check that the entries are there:

```sh
$ ls -d ~/.cache/retrolunar/nestdir/ffmpeg-*@aarch64-android33
/home/satori/.cache/retrolunar/nestdir/ffmpeg-6@aarch64-android33
/home/satori/.cache/retrolunar/nestdir/ffmpeg-7@aarch64-android33
/home/satori/.cache/retrolunar/nestdir/ffmpeg-8@aarch64-android33
/home/satori/.cache/retrolunar/nestdir/ffmpeg-9@aarch64-android33
```

If one is missing, build it from the recipe tree - a clone of
<https://github.com/lunardoesdev/retrolunar2-packages>, tag `2.14`, beside this
project. `generate -x` writes the build script for one target and its
dependencies, and runs it:

```sh
$ git clone https://github.com/lunardoesdev/retrolunar2-packages ~/ond/git/retrolunar2-packages
$ cd ~/ond/git/ffmpeg-wednesday
$ retrolunar --packages ../retrolunar2-packages generate -x 'ffmpeg-6@aarch64-android33'
```

## Make the tarballs

```sh
$ cd ~/ond/git/ffmpeg-wednesday
$ sh export.sh
ffmpeg-6-6.1.6-aarch64-android33.tar.gz   78249781 bytes   191 files    998 objects in libavcodec.a
ffmpeg-7-7.1.5-aarch64-android33.tar.gz   80617790 bytes   192 files   1030 objects in libavcodec.a
ffmpeg-8-8.1.3-aarch64-android33.tar.gz   84355687 bytes   198 files   1064 objects in libavcodec.a
ffmpeg-9-9.0.2-aarch64-android33.tar.gz   84917329 bytes   199 files   1065 objects in libavcodec.a
```

They land in `dist/` (git-ignored) next to `SHA256SUMS`. The script builds
nothing: it packs what the nest already holds, and then the dependencies, so the
result links on its own. Before it reads a branch's closure it asks the tool to
move the recipe tree forward - `--refresh-packages` - so a hand-over packs
against the tree as it is now, not as it was the first time. gzip at level 1 -
pigz if the machine has it - makes the
four take about three minutes to pack where xz took six, and two to three times
the size; `COMPRESS` packs them differently. Give it a directory to write
somewhere else, and a nest to read from elsewhere:

```sh
$ RETROLUNAR_NEST=/other/nest sh export.sh /tmp/out
```

## Check what came out

```sh
$ sha256sum -c dist/SHA256SUMS
ffmpeg-6-6.1.6-aarch64-android33.tar.gz: OK
ffmpeg-7-7.1.5-aarch64-android33.tar.gz: OK
ffmpeg-8-8.1.3-aarch64-android33.tar.gz: OK
ffmpeg-9-9.0.2-aarch64-android33.tar.gz: OK

$ tar -tzf dist/ffmpeg-9-9.0.2-aarch64-android33.tar.gz | grep -cE '^lib/lib(av|sw)[^/]*\.(a|so)$'
14
$ tar -tzf dist/ffmpeg-9-9.0.2-aarch64-android33.tar.gz | grep -E '^lib/(libbz2|liblzma|libmp3lame|libopus|libvpx|libz)\.' | sort
lib/libbz2.a
lib/liblzma.a
lib/libmp3lame.a
lib/libopus.a
lib/libvpx.a
lib/libz.a
lib/libz.so
lib/libz.so.1
lib/libz.so.1.3.1
```

The version in each name is read from `include/libavutil/ffversion.h` inside the
built prefix, so a tarball cannot claim a version its library does not carry:

```sh
$ tar -xzOf dist/ffmpeg-9-9.0.2-aarch64-android33.tar.gz include/libavutil/ffversion.h |
    grep FFMPEG_VERSION
#define FFMPEG_VERSION "9.0.2"
```

## Use one

```sh
$ tar -C /some/prefix -xf dist/ffmpeg-6-6.1.6-aarch64-android33.tar.gz
```

Each tarball holds `lib/`, `include/` and `share/`: seven `.a` and seven `.so`
per branch, seven `.pc` files, 137 to 145 headers - and, in `lib/`, the libraries
that branch links against.

## Link against one

That last part is the point. With the prefix unpacked anywhere, one include path
and the flags the `.pc` files give are enough:

```sh
$ P=/some/prefix
$ CC=$ANDROID_HOME/ndk/29.0.14206865/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android33-clang
$ $CC -o app main.c -I$P/include \
      $(PKG_CONFIG_LIBDIR=$P/lib/pkgconfig pkg-config --static --libs libavformat) \
      -lmediandk -landroid -llog -lc++ -latomic -pthread
```

`-lmediandk`, `-landroid`, `-llog`, `-lc`, `-lm`, `-ldl` and the rest of
Android's system libraries come from the *toolchain* - the NDK's sysroot carries
them - and from the device at run time. Nothing here ships them, and nothing here
needs to.

Measured, against the built 9.0.2 tarball alone, with a small program that finds
the H.264 and Vorbis decoders and the MP3 encoder:

- packing the prefix without the dependencies gave twenty unresolved references:
  `undefined symbol: inflate`, `lzma_code`, `opus_multistream_decode`,
  `vpx_codec_decode`, `lame_encode_buffer`, `deflateInit_` and the like;
- with them in `lib/`: **no unresolved references**, and a static binary of
  67.9 MB comes out.

A static link wants the `.a` files named outright, because a plain `-lavformat`
picks the `.so` when both are present:

```sh
$ $CC -o app main.c -I$P/include \
      $P/lib/libavformat.a $P/lib/libavcodec.a $P/lib/libavutil.a \
      $P/lib/libswresample.a $P/lib/libswscale.a \
      $P/lib/libbz2.a $P/lib/liblzma.a $P/lib/libmp3lame.a $P/lib/libopus.a \
      $P/lib/libvpx.a $P/lib/libz.a \
      -lmediandk -landroid -llog -lm -lc++ -latomic -pthread
```

## The tool's own export: loose files, not a tarball

`export.sh` makes tarballs; `retrolunar export` (2.13 and later) makes no archive
at all - it copies a named target **and its dependencies** flat into a directory.
That is the same set of libraries this script packs into `lib/`, and it is where
the script gets them: it asks the tool for the closure instead of keeping its own
list of what FFmpeg links against.

```sh
$ RETROLUNAR=~/ond/git/retrolunar2/builddir/retrolunar
$ $RETROLUNAR --packages ../retrolunar2-packages export --to /tmp/ff9 'ffmpeg-9@aarch64-android33'
retrolunar: exported 28 file(s) from 29 package file(s) to /tmp/ff9
retrolunar: provided by the platform or toolchain, not copied: libm.so liblog.so libdl.so libc.so libandroid.so libcamera2ndk.so libmediandk.so
retrolunar: bundle: 28 file(s), 0 unresolved, 0 on the launcher
$ ls /tmp/ff9 | wc -l
23
```

Read the counts with care. The seven `.a` and seven `.so` of the target, plus the
dependencies' libraries - `libbz2.a`, `liblzma.a`, `libmp3lame.a`, `libopus.a`,
`libvpx.a`, `libz.a`, `libz.so`, `libz.so.1`, `libz.so.1.3.1` - make the 23 files
in the directory. The summary says 28 because five more of the files it was asked
for are platform libraries, named and deliberately not copied: `libm.so`,
`liblog.so`, `libdl.so`, `libc.so`, `libandroid.so`. `libcamera2ndk.so` and
`libmediandk.so` are Android system libraries too - the device has them, and the
NDK's sysroot answers `-lmediandk` at link time - so the tool names them as
platform rather than reporting them unresolved (2.14 and later; before that they
came out as `NOT FOUND anywhere in <nest>` and left the bundle counting two
unresolved references).
