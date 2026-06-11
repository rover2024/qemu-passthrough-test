#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Uncomment if you are in PRC region to speed up the download of packages
#sed -i 's@http://archive.ubuntu.com/ubuntu/@http://mirrors.ustc.edu.cn/ubuntu/@g' /etc/apt/sources.list
#sed -i 's@http://security.ubuntu.com/ubuntu/@http://mirrors.ustc.edu.cn/ubuntu/@g' /etc/apt/sources.list

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

# install llvm
apt-get install -y --no-install-recommends \
    lsb-release \
    software-properties-common \
    gnupg
wget https://apt.llvm.org/llvm.sh -O /tmp/llvm.sh
chmod +x /tmp/llvm.sh
/tmp/llvm.sh 20

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
    libffcall-dev \
    libclang-20-dev \
    libx11-dev \
    libx11-xcb-dev \
    libxext-dev \
    vulkan-tools libvulkan-dev \
    libgl1-mesa-dev libglew-dev libglfw3-dev \
    libzstd-dev \
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
if [ -d /home/user/lorelei-try-patch ]; then
    chown user:user /home/user/lorelei-try-patch || true
fi

echo "[bootstrap] done"
