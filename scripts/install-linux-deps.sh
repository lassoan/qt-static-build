#!/usr/bin/env bash
#
# Install the packages needed to build static qtbase (including the xcb
# platform plugin) in a manylinux_2_28 (AlmaLinux 8) container.
#
set -euo pipefail

dnf install -y epel-release
dnf install -y \
  fontconfig-devel \
  freetype-devel \
  libX11-devel \
  libXext-devel \
  libXrender-devel \
  libxcb-devel \
  libxkbcommon-devel \
  libxkbcommon-x11-devel \
  xcb-util-cursor-devel \
  xcb-util-devel \
  xcb-util-image-devel \
  xcb-util-keysyms-devel \
  xcb-util-renderutil-devel \
  xcb-util-wm-devel \
  xz

command -v ninja > /dev/null || pipx install ninja
