#!/bin/sh
# Turn the four built FFmpeg prefixes into dist/*.tar.gz - one tarball each,
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
# Nothing lands in OUT-DIR until all four are packed, so a run that fails leaves
# that directory as it was, checksums included.
#
# gzip, at the fast end, and pigz over it when the machine has pigz: these are
# libraries to be linked, and a hand-over that takes minutes to pack is one
# nobody reruns. Set COMPRESS to pack them differently.
#
# The version in each name is read from the library itself
# (include/libavutil/ffversion.h), not from a recipe or a file name.
#
#   RETROLUNAR           the tool to ask for the closure (default: retrolunar)
#   RETROLUNAR_PACKAGES  the recipe tree (default: the checkout beside this one)
#   RETROLUNAR_NEST      the nest to read (default: the tool's own)
#   COMPRESS             the compressor before the redirect (default: see below)
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
# Fast first: pigz with every core if it is there, plain gzip at level 1 if not.
if [ -z "${COMPRESS:-}" ]; then
    if command -v pigz >/dev/null 2>&1; then
        COMPRESS="pigz -1"
    else
        COMPRESS="gzip -1"
    fi
fi

# The tree: by default none is named, and the tool fetches its own -
# retrolunar2-packages, cloned into $HOME/.cache/retrolunar/packages on first
# use. Nothing here points at a checkout on one machine. RETROLUNAR_PACKAGES
# names a tree when the recipes come from somewhere else.
packages=${RETROLUNAR_PACKAGES:-}

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
    # --refresh-packages: the tree moves forward before the closure is read out
    # of it, once per branch. Offline it is a no-op that still reads the tree it
    # has, so a hand-over never fails for want of a network.
    rc=0
    if [ -n "$packages" ]; then
        "$RL" --refresh-packages --packages "$packages" export --to "$closure" "$p@$sys" \
            >"$work/export-$name.log" 2>&1 || rc=$?
    else
        "$RL" --refresh-packages export --to "$closure" "$p@$sys" \
            >"$work/export-$name.log" 2>&1 || rc=$?
    fi
    if [ "$rc" != 0 ]; then
        echo "$p: retrolunar export failed:"; tail -3 "$work/export-$name.log"; exit 1
    fi
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
    tar -C "$stage" -cf - $members | $COMPRESS > "$work/$name.tar.gz"

    sum=$(sha256sum "$work/$name.tar.gz" | cut -d' ' -f1)
    printf '%s  %s\n' "$sum" "$name.tar.gz" >> "$work/SHA256SUMS"
    printf '%-33s %10s bytes  %4s files  %5s objects in libavcodec.a\n' \
        "$name.tar.gz" "$(stat -c %s "$work/$name.tar.gz")" \
        "$(find "$stage" -type f | wc -l)" "$(ar t "$stage/lib/libavcodec.a" | wc -l)"
done

# All four packed, so now, and only now, they replace what is in OUT-DIR.
mv "$work"/*.tar.gz "$work/SHA256SUMS" "$out/"
rm -rf "$work"

echo
echo "sha256, in $out/SHA256SUMS:"
cat "$out/SHA256SUMS"
