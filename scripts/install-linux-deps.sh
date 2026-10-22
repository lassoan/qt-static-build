#!/usr/bin/env bash
#
# Install the packages needed to build static qtbase (including the xcb
# platform plugin) in a manylinux_2_28 (AlmaLinux 8) container.
#
set -euo pipefail

dnf install -y epel-release

# EPEL (needed for xcb-util-cursor-devel) mirrors are often unreachable or
# mid-sync, so use the primary server and retry.
sed -i \
  -e 's|^metalink=|#metalink=|' \
  -e 's|^#baseurl=.*/epel/|baseurl=https://dl.fedoraproject.org/pub/epel/|' \
  /etc/yum.repos.d/epel.repo

for attempt in 1 2 3; do
  if dnf install -y --setopt=retries=10 \
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
  xz; then
    break
  fi
  if [[ $attempt -eq 3 ]]; then
    exit 1
  fi
  echo "dnf install failed (attempt $attempt), retrying"
  dnf clean metadata
  sleep 30
done

command -v ninja > /dev/null || pipx install ninja
