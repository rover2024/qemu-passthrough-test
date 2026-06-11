#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
ARCH="$(dpkg --print-architecture)"
UBUNTU_CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
USE_USTC_MIRROR="${USE_USTC_MIRROR:-0}"
UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu/"

if [ "$USE_USTC_MIRROR" = "1" ]; then
    UBUNTU_MIRROR="http://mirrors.ustc.edu.cn/ubuntu/"
    sed -i 's@http://archive.ubuntu.com/ubuntu/@http://mirrors.ustc.edu.cn/ubuntu/@g' /etc/apt/sources.list
    sed -i 's@http://security.ubuntu.com/ubuntu/@http://mirrors.ustc.edu.cn/ubuntu/@g' /etc/apt/sources.list
    sed -i 's@http://ports.ubuntu.com/ubuntu-ports/@http://mirrors.ustc.edu.cn/ubuntu-ports/@g' /etc/apt/sources.list
fi

if [ "$ARCH" != "amd64" ]; then
    dpkg --add-architecture amd64

    # Ubuntu non-amd64 images commonly use ubuntu-ports. Keep those entries
    # native-arch-only so apt can fetch amd64 packages from the normal archive.
    sed -i -E "/ubuntu-ports/ s/^deb /deb [arch=${ARCH}] /" /etc/apt/sources.list

    cat >/etc/apt/sources.list.d/amd64.list <<EOF
deb [arch=amd64] ${UBUNTU_MIRROR} ${UBUNTU_CODENAME} main restricted universe multiverse
deb [arch=amd64] ${UBUNTU_MIRROR} ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb [arch=amd64] ${UBUNTU_MIRROR} ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF
fi

apt-get clean
apt-get update

# install basic tools
apt-get install -y --no-install-recommends \
    sudo \
    ca-certificates \
    git \
    curl \
    wget \
    vim \
    less \
    file \
    build-essential \
    gcc \
    g++ \
    gdb \
    cmake \
    ninja-build \
    pkg-config \
    python3 \
    python3-pip \
    meson \
    flex \
    bison \
    patchelf

if [ "$ARCH" != "amd64" ]; then
    # Cross compilers run on the native non-x86 host and produce x86_64 binaries. libc6:amd64
    # provides /lib64/ld-linux-x86-64.so.2 for running dynamically linked x64
    # binaries under qemu-x86_64.
    apt-get install -y --no-install-recommends \
        gcc-x86-64-linux-gnu \
        g++-x86-64-linux-gnu \
        libc6:amd64 \
        libstdc++6:amd64 \
        zlib1g:amd64 \
        libminizip1:amd64

    tmpdir="$(mktemp -d)"
    (
        cd "$tmpdir"
        apt-get download minizip:amd64
    )
    rm -rf /opt/minizip-amd64
    dpkg-deb -x "$tmpdir"/minizip_*_amd64.deb /opt/minizip-amd64
    ln -sf /opt/minizip-amd64/usr/bin/minizip /usr/local/bin/minizip-x86_64
    rm -rf "$tmpdir"

    if [ ! -e /lib64/ld-linux-x86-64.so.2 ] && [ -e /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ]; then
        mkdir -p /lib64
        ln -s /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
    fi
fi

# install dependencies for qemu
apt-get install -y --no-install-recommends \
    python3-tomli \
    libglib2.0-dev \
    libpixman-1-dev \
    libfdt-dev \
    zlib1g-dev \
    libslirp-dev \
    libcapstone-dev \
    libffi-dev \
    libelf-dev \
    libssl-dev

# install dependencies for lorelei
apt-get install -y --no-install-recommends \
    libx11-dev \
    libx11-xcb-dev \
    libxext-dev \
    libgl1-mesa-dev libglew-dev libglfw3-dev \
    minizip

# create user
if ! id -u user >/dev/null 2>&1; then
    groupadd --gid 1000 user || true
    useradd --uid 1000 --gid 1000 -m -s /bin/bash user
    echo "user:123456" | chpasswd
    usermod -aG sudo user
    echo "user ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/user
    chmod 0440 /etc/sudoers.d/user
fi

# Fix ownership for interactive demo workflow.
mkdir -p /home/user
chown user:user /home/user
if [ -d /home/user/qemu-passthrough-test ]; then
    chown user:user /home/user/qemu-passthrough-test || true
fi

echo "[bootstrap] done"
