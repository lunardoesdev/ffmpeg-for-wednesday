#!/bin/sh
# Turn the four built FFmpeg prefixes into dist/*.tar.xz - one tarball each,
# with the dependencies inside, so a tarball can be linked against on its own.
#
#   sh export.sh [OUT-DIR]        (default: ./dist)
#
# Each tarball holds an installed prefix - lib/, include/, share/ - and its lib/
# carries the dependencies of that branch too: libbz2.a, liblzma.a, libmp3lame.a,
# libopus.a, libvpx.a and libz.a/libz.so*. They have to be there. An FFmpeg
# archive names their symbols, so packing the prefix alone links like this:
#
#   ld.lld: error: undefined symbol: inflate
#   ld.lld: error: undefined symbol: lzma_code
#   ld.lld: error: undefined symbol: opus_multistream_decode
#   ld.lld: error: undefined symbol: vpx_codec_decode
#   ld.lld: error: undefined symbol: lame_encode_buffer
#   ... twenty of them, measured
#
# With the dependencies inside, one -L and the -l list the .pc files give is all
# a linker needs; the .pc files are rewritten to point at that lib/ rather than
# the nest, so they answer for a tarball unpacked anywhere.
#
# The version in each name is read from the library itself
# (include/libavutil/ffversion.h), not from a recipe or a file name.
#
#   RETROLUNAR       the tool to ask for the closure (default: retrolunar)
#   RETROLUNAR_NEST  the nest to read (default: the tool's own)
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RL=${RETROLUNAR:-retrolunar}
RETROLUNAR_NEST=${RETROLUNAR_NEST:-$HOME/.cache/retrolunar/nestdir}
export RETROLUNAR_NEST
nest=$RETROLUNAR_NEST
out=${1:-$here/dist}
sys=aarch64-android33
targets="ffmpeg-6 ffmpeg-7 ffmpeg-8 ffmpeg-9"
work=$out/.staging
# xz on ~150 MB of archives is the slow part; two threads instead of one keeps
# it honest without eating the machine.
XZ_OPT=${XZ_OPT:--T2}
export XZ_OPT

mkdir -p "$out"
: > "$out/SHA256SUMS"
rm -rf "$work"
mkdir -p "$work"

for p in $targets; do
    entry=$nest/$p@$sys
    if [ ! -e "$entry" ]; then
        echo "$p: not built in $nest - build it with: retrolunar shell" >&2
        exit 1
    fi
    entry=$(readlink -f "$entry")

    ver=$(sed -n 's/.*FFMPEG_VERSION "\([^"]*\)".*/\1/p' "$entry/include/libavutil/ffversion.h")
    if [ -z "$ver" ]; then
        echo "$p: no ffversion.h under $entry - not an FFmpeg prefix" >&2
        exit 1
    fi

    name=$p-$ver-$sys
    stage=$work/$name
    closure=$work/closure-$name
    mkdir -p "$stage"

    cp -a "$entry/lib" "$entry/include" "$stage/"
    [ -d "$entry/share" ] && cp -a "$entry/share" "$stage/"

    # The tool knows the closure; ask it, and let its libraries join lib/. A name
    # the prefix already carries wins - that is the same build, not a second one.
    "$RL" export --to "$closure" "$p@$sys" >"$work/export-$name.log" 2>&1 || {
        echo "$p: retrolunar export failed:"; tail -3 "$work/export-$name.log"; exit 1; }
    for f in "$closure"/*; do
        b=$(basename "$f")
        [ -e "$stage/lib/$b" ] || cp -a "$f" "$stage/lib/"
    done

    # The .pc files then describe the prefix that ships.
    for pc in "$stage"/lib/pkgconfig/*.pc; do
        [ -f "$pc" ] || continue
        sed -i "s|-L[^ ]*@$sys/lib/pkgconfig/\.\./\.\./lib|-L\${libdir}|g
                s|-L[^ ]*@$sys/share/pkgconfig/\.\./\.\./lib|-L\${libdir}|g" "$pc"
    done

    members="lib include"
    [ -d "$stage/share" ] && members="$members share"
    # shellcheck disable=SC2086
    tar -C "$stage" -cJf "$out/$name.tar.xz" $members

    sum=$(sha256sum "$out/$name.tar.xz" | cut -d' ' -f1)
    printf '%s  %s\n' "$sum" "$name.tar.xz" >> "$out/SHA256SUMS"
    printf '%-33s %10s bytes  %4s files  %5s objects in libavcodec.a\n' \
        "$name.tar.xz" "$(stat -c %s "$out/$name.tar.xz")" \
        "$(find "$stage" -type f | wc -l)" "$(ar t "$stage/lib/libavcodec.a" | wc -l)"
done

rm -rf "$work"

echo
echo "sha256, in $out/SHA256SUMS:"
cat "$out/SHA256SUMS"
