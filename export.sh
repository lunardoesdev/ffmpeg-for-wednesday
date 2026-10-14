#!/bin/sh
# Turn the four built FFmpeg prefixes into dist/*.tar.xz - one tarball each.
#
#   sh export.sh [OUT-DIR]        (default: ./dist)
#
# Each tarball holds an installed prefix - lib/, include/, share/ - so a
# consumer untars it into a prefix and links against it:
#
#   tar -C /some/prefix -xf dist/ffmpeg-6.1.6-aarch64-android33.tar.xz
#
# The version in the name is read from the library itself
# (include/libavutil/ffversion.h), not from a recipe or a file name, so the
# tarball says what it really is.
#
# The nest defaults to the tool's own; set RETROLUNAR_NEST to point elsewhere.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
nest=${RETROLUNAR_NEST:-$HOME/.cache/retrolunar/nestdir}
out=${1:-$here/dist}
sys=aarch64-android33
targets="ffmpeg-6 ffmpeg-7 ffmpeg-8 ffmpeg-9"
# xz on ~150 MB of archives is the slow part; two threads instead of one keeps
# it honest without eating the machine.
XZ_OPT=${XZ_OPT:--T2}
export XZ_OPT

mkdir -p "$out"
: > "$out/SHA256SUMS"

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
    members="lib include"
    [ -d "$entry/share" ] && members="$members share"
    # shellcheck disable=SC2086
    tar -C "$entry" -cJf "$out/$name.tar.xz" $members

    sum=$(sha256sum "$out/$name.tar.xz" | cut -d' ' -f1)
    printf '%s  %s\n' "$sum" "$name.tar.xz" >> "$out/SHA256SUMS"
    printf '%-33s %10s bytes  %5s objects in libavcodec.a\n' \
        "$name.tar.xz" "$(stat -c %s "$out/$name.tar.xz")" "$(ar t "$entry/lib/libavcodec.a" | wc -l)"
done

echo
echo "sha256, in $out/SHA256SUMS:"
cat "$out/SHA256SUMS"
