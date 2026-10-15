# Getting the tarballs

Four tarballs, one per FFmpeg branch - 6.1.6, 7.1.5, 8.1.3, 9.0.2 - built for
**aarch64-android33** with the NDK r29 toolchain. `export.sh` is what makes
them. This is the walk-through; every command below was run as it is written,
on this machine, against the nest those builds live in.

## What you need first

- The four packages already built in a nest. The default is
  `~/.cache/retrolunar/nestdir`; `RETROLUNAR_NEST` points the script at another.
- Check that the entries are there:

```sh
$ ls -d ~/.cache/retrolunar/nestdir/ffmpeg-*@aarch64-android33
/home/satori/.cache/retrolunar/nestdir/ffmpeg-6@aarch64-android33
/home/satori/.cache/retrolunar/nestdir/ffmpeg-7@aarch64-android33
/home/satori/.cache/retrolunar/nestdir/ffmpeg-8@aarch64-android33
/home/satori/.cache/retrolunar/nestdir/ffmpeg-9@aarch64-android33
```

If one is missing, build it - this is the manifest's own build, which brings the
four in and nothing else:

```sh
$ cd ~/ond/git/ffmpeg-wednesday
$ retrolunar --no-default-repo run true
```

## Make the tarballs

```sh
$ cd ~/ond/git/ffmpeg-wednesday
$ sh export.sh
ffmpeg-6-6.1.6-aarch64-android33.tar.xz   33826544 bytes    998 objects in libavcodec.a
ffmpeg-7-7.1.5-aarch64-android33.tar.xz   35700036 bytes   1030 objects in libavcodec.a
ffmpeg-8-8.1.3-aarch64-android33.tar.xz   36935244 bytes   1064 objects in libavcodec.a
ffmpeg-9-9.0.2-aarch64-android33.tar.xz   37346800 bytes   1065 objects in libavcodec.a
```

They land in `dist/` (git-ignored) next to `SHA256SUMS`. The script builds
nothing and writes nothing else: it packs what the nest already holds. Give it a
directory to write somewhere else, and a nest to read from elsewhere:

```sh
$ RETROLUNAR_NEST=/other/nest sh export.sh /tmp/out
```

## Check what came out

```sh
$ cd ~/ond/git/ffmpeg-wednesday
$ sha256sum -c dist/SHA256SUMS
ffmpeg-6-6.1.6-aarch64-android33.tar.xz: OK
ffmpeg-7-7.1.5-aarch64-android33.tar.xz: OK
ffmpeg-8-8.1.3-aarch64-android33.tar.xz: OK
ffmpeg-9-9.0.2-aarch64-android33.tar.xz: OK

$ tar -tJf dist/ffmpeg-9-9.0.2-aarch64-android33.tar.xz | grep -cE '^lib/[^/]*\.(a|so)$'
14
```

The version in each name is read from `include/libavutil/ffversion.h` inside the
built prefix, so a tarball cannot claim a version its library does not carry:

```sh
$ tar -xJOf dist/ffmpeg-9-9.0.2-aarch64-android33.tar.xz include/libavutil/ffversion.h |
    grep FFMPEG_VERSION
#define FFMPEG_VERSION "9.0.2"
```

## Use one

```sh
$ tar -C /some/prefix -xf dist/ffmpeg-6-6.1.6-aarch64-android33.tar.xz
```

Each tarball holds `lib/`, `include/` and `share/`: seven `.a` and seven `.so`
per branch, seven `.pc` files, and 137 to 145 headers. What is *not* in them - no
programs, and the shared libraries needing `libz.so.1` beside them - is written
down in [README.md](README.md).

## The tool's own export: loose files, not a tarball

These are not two ways of getting the same thing, and it is worth being exact
about it: `export.sh` makes *tarballs* of the four prefixes, while
`retrolunar export` (2.13 and later) makes no archive at all - it copies a named
target **and its dependencies** flat into a directory, which is what a link
needs. Take the tarball when you are handing over an installable prefix; take the
flat directory when you are pointing a linker at it.

```sh
$ retrolunar --packages ../retrolunar2-packages export --to /tmp/ff9 'ffmpeg-9@aarch64-android33'
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
`libmediandk.so` are Android system libraries too - the device has them - and the
tool names them as platform rather than reporting them unresolved (2.14 and
later; before that they came out as `NOT FOUND anywhere in <nest>`).

If you want that flat set as one archive anyway:

```sh
$ tar -C /tmp/ff9 -cJf ffmpeg-9-aarch64-android33-linkable.tar.xz .
```

Those 23 loose files (seven `.a`, seven `.so`, and the dependencies' libraries)
and the one tarball come from the same nest entries; take whichever fits the
machine you are handing over to.
