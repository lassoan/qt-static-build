#!/usr/bin/env bash
#
# Build a static qtbase on Linux or macOS and package it as <name>.tar.xz.
#
# Usage:
#
#   build-qt6.sh <qt-version> <name> <output-dir> [extra configure args...]
#
# The archive contains a single top-level <name> directory holding the Qt
# install tree. A smoke test project is built against it before packaging.
#
set -euo pipefail

qt_version=$1
name=$2
output_dir=$(mkdir -p "$3" && cd "$3" && pwd)
shift 3

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work_dir=${QT_WORK_DIR:-$PWD/_work}
src_dir=$work_dir/src
build_dir=$work_dir/build
prefix=$work_dir/$name

qt_minor=${qt_version%.*}
archive=qtbase-everywhere-src-$qt_version.tar.xz
url=https://download.qt.io/archive/qt/$qt_minor/$qt_version/submodules/$archive

mkdir -p "$work_dir" "$src_dir" "$build_dir"
cd "$work_dir"

echo "Downloading $url"
curl -fsSL -o "$archive" "$url"
expected_sha256=$(curl -fsSL "$url.sha256" | cut -d' ' -f1)
if command -v sha256sum > /dev/null; then
  actual_sha256=$(sha256sum "$archive" | cut -d' ' -f1)
else
  actual_sha256=$(shasum -a 256 "$archive" | cut -d' ' -f1)
fi
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  echo "SHA256 mismatch for $archive: expected $expected_sha256, got $actual_sha256" >&2
  exit 1
fi
tar -xf "$archive" -C "$src_dir" --strip-components=1

cd "$build_dir"
"$src_dir/configure" \
  -prefix "$prefix" \
  -release \
  -static \
  -nomake examples \
  -nomake tests \
  -no-opengl \
  -no-dbus \
  -no-icu \
  -no-openssl \
  -qt-zlib \
  -qt-libpng \
  -qt-libjpeg \
  -qt-pcre \
  -qt-harfbuzz \
  "$@"
cmake --build . --parallel
cmake --install .

cmake \
  -S "$script_dir/../tests/smoke" \
  -B "$work_dir/smoke" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE:STRING=Release \
  -DCMAKE_PREFIX_PATH:PATH="$prefix"
cmake --build "$work_dir/smoke"

cd "$work_dir"
tar -cJf "$output_dir/$name.tar.xz" "$name"
echo "Created $output_dir/$name.tar.xz"
