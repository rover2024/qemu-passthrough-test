#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
ARCH="$(dpkg --print-architecture)"
UBUNTU_CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
USE_USTC_MIRROR="${USE_USTC_MIRROR:-0}"
# Mirror used for amd64 packages (the x86_64 runtime libs and, on riscv64, the
# debootstrap sysroot). Overridable from the environment; defaults below.
UBUNTU_MIRROR="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu/}"

# The guest is always x86_64. On a non-amd64 host we therefore need an x86_64
# toolchain, and how we obtain it depends on the host arch:
#
#   - arm64  : Ubuntu ships the gcc-x86-64-linux-gnu cross compiler, so a plain
#              `apt install` is enough.
#   - riscv64: the riscv64 archive does NOT contain an x86_64 cross compiler
#              (no gcc-x86-64-linux-gnu candidate at all), so instead we unpack
#              an amd64 sysroot and drive its native gcc through qemu-user.
#
# Everything else the guest needs at *run* time (libc6/libstdc++6/zlib/minizip
# for amd64, plus the /lib64 loader symlink) is identical for every non-amd64
# host and is handled by setup_x86_64_runtime_libs().
GUEST_SYSROOT=/opt/amd64
# A *stable* qemu-user is needed to run the amd64 build tools (gcc/cc1/as/ld)
# on a riscv64 host. jammy's own qemu is 6.2, too old to run glibc-2.35 x86_64
# binaries (they segfault), and a fresh git QEMU is unreliable under heavy
# compiler workloads (cc1 heap corruption / ICEs), so we pull the stable 8.x
# qemu-user-static from noble. The demo itself still runs under the project's
# own QEMU (bootstrap-qemu.sh), which is the one carrying the passthrough plugin.
BUILD_QEMU=/opt/qemu-build/usr/bin/qemu-x86_64-static

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
    patchelf \
    debootstrap

# ---------------------------------------------------------------------------
# x86_64 guest toolchain helpers (non-amd64 hosts only)
# ---------------------------------------------------------------------------

# x86_64 *runtime* libraries + the minizip tool. Shared by every non-amd64
# host: these are amd64 packages pulled from the normal archive, so they
# install the same way on arm64 and riscv64. They give the guest a system-wide
# /lib64/ld-linux-x86-64.so.2 and libc, so run.sh works without QEMU_LD_PREFIX.
setup_x86_64_runtime_libs() {
    apt-get install -y --no-install-recommends \
        libc6:amd64 \
        libstdc++6:amd64 \
        zlib1g:amd64 \
        libminizip1:amd64

    local tmpdir
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
}

# arm64 host: the cross compiler exists in the archive, just install it.
setup_x86_64_cross_apt() {
    apt-get install -y --no-install-recommends \
        gcc-x86-64-linux-gnu \
        g++-x86-64-linux-gnu
}

# riscv64 host: no x86_64 cross compiler in the archive. Build an amd64 sysroot
# and expose x86_64-linux-gnu-gcc/g++ wrappers (the names build.sh expects)
# that run the sysroot's gcc under qemu-user. gcc's subprograms
# (cc1/as/collect2/ld) are routed back through qemu explicitly so that nothing
# falls through to whatever other binfmt handler the host may have registered.
setup_x86_64_sysroot_qemu() {
    echo "[bootstrap] no x86_64 cross compiler for ${ARCH}; building amd64 sysroot at ${GUEST_SYSROOT}"

    # 0. A stable qemu-user to run the amd64 build tools (see BUILD_QEMU above).
    #    Pulled from noble without installing it into the host system; we only
    #    need the static qemu-x86_64 binary out of the .deb.
    local ports_mirror tmpd
    ports_mirror="$(grep -oE 'https?://[^ ]+/ubuntu-ports/?' /etc/apt/sources.list | head -1)"
    ports_mirror="${ports_mirror:-http://ports.ubuntu.com/ubuntu-ports/}"
    echo "deb [arch=${ARCH}] ${ports_mirror} noble universe" >/etc/apt/sources.list.d/noble-qemu.list
    apt-get update
    tmpd="$(mktemp -d)"
    ( cd "$tmpd" && apt-get download qemu-user-static )
    rm -rf /opt/qemu-build
    dpkg-deb -x "$tmpd"/qemu-user-static_*.deb /opt/qemu-build
    rm -rf "$tmpd" /etc/apt/sources.list.d/noble-qemu.list
    apt-get update

    # 1. Unpack an amd64 toolchain into the sysroot WITHOUT executing any amd64
    #    code: `debootstrap --foreign` downloads + unpacks the base and caches
    #    the --include debs; we extract those ourselves with dpkg-deb (the
    #    normal second stage would need to run amd64 maintainer scripts).
    # Retry: one transient mirror/proxy download blip makes debootstrap abort
    # the whole bootstrap (e.g. "E: Couldn't download packages: libmagic1"), so
    # give it a few clean attempts before giving up.
    for attempt in 1 2 3; do
        rm -rf "$GUEST_SYSROOT"
        if debootstrap --foreign --arch=amd64 --variant=minbase \
                --components=main,universe \
                --include=build-essential,libc6-dev,zlib1g-dev,libminizip-dev,minizip \
                "$UBUNTU_CODENAME" "$GUEST_SYSROOT" "$UBUNTU_MIRROR"; then
            break
        fi
        echo "[bootstrap] debootstrap attempt ${attempt}/3 failed; retrying" >&2
        [ "$attempt" = 3 ] && { echo "[bootstrap] debootstrap failed after 3 attempts" >&2; exit 1; }
        sleep 5
    done
    for deb in "$GUEST_SYSROOT"/var/cache/apt/archives/*.deb; do
        dpkg-deb -x "$deb" "$GUEST_SYSROOT"
    done

    # 2. The ELF loader is shipped as an *absolute* symlink (-> /lib/x86_64-...)
    #    that escapes the sysroot once qemu prepends its -L prefix. Replace it
    #    with the real file so qemu can actually load the interpreter.
    local real_ld
    real_ld="$(find "$GUEST_SYSROOT" -name ld-linux-x86-64.so.2 -type f | head -1)"
    cp -f "$real_ld" "$GUEST_SYSROOT/lib64/ld-linux-x86-64.so.2"

    # 3. Unversioned tool symlinks the (unconfigured) packages would normally
    #    create via update-alternatives.
    local gcc_bin gpp_bin
    gcc_bin="$(basename "$(ls "$GUEST_SYSROOT"/usr/bin/x86_64-linux-gnu-gcc-* | grep -E 'gcc-[0-9]+$' | sort -V | tail -1)")"
    gpp_bin="$(basename "$(ls "$GUEST_SYSROOT"/usr/bin/x86_64-linux-gnu-g++-* | grep -E 'g\+\+-[0-9]+$' | sort -V | tail -1)")"
    (
        cd "$GUEST_SYSROOT/usr/bin"
        ln -sf "$gcc_bin" x86_64-linux-gnu-gcc
        ln -sf "$gpp_bin" x86_64-linux-gnu-g++
        ln -sf "$gcc_bin" gcc
        ln -sf "$gpp_bin" g++
        ln -sf x86_64-linux-gnu-as as
        ln -sf x86_64-linux-gnu-ld ld
    )

    # 4. Native ld shims. collect2 invokes the linker itself and does NOT honour
    #    gcc's -wrapper, so `ld` must be wrapped here, found via gcc's -B path.
    mkdir -p /opt/xtools
    local name
    for name in ld x86_64-linux-gnu-ld real-ld; do
        cat >/opt/xtools/"$name" <<EOF
#!/bin/bash
export QEMU_LD_PREFIX=${GUEST_SYSROOT}
exec ${BUILD_QEMU} ${GUEST_SYSROOT}/usr/bin/x86_64-linux-gnu-ld "\$@"
EOF
        chmod +x /opt/xtools/"$name"
    done

    # 5. -wrapper helper: gcc hands each subprogram (cc1/as/collect2) to this
    #    script to execute. Resolve bare names against the sysroot, then run
    #    the real x86_64 binary under qemu.
    cat >/usr/local/bin/qemu-x86_64-cc-wrapper <<EOF
#!/bin/bash
export QEMU_LD_PREFIX=${GUEST_SYSROOT}
prog="\$1"; shift
if [[ "\$prog" != /* ]]; then
    prog="\$(PATH=${GUEST_SYSROOT}/usr/bin:/opt/xtools:\$PATH command -v "\$prog")"
fi
exec ${BUILD_QEMU} "\$prog" "\$@"
EOF
    chmod +x /usr/local/bin/qemu-x86_64-cc-wrapper

    # 6. The x86_64-linux-gnu-gcc / -g++ front ends that build.sh invokes.
    local tool
    for tool in gcc g++; do
        cat >/usr/local/bin/x86_64-linux-gnu-"$tool" <<EOF
#!/bin/bash
export QEMU_LD_PREFIX=${GUEST_SYSROOT}
exec ${BUILD_QEMU} ${GUEST_SYSROOT}/usr/bin/x86_64-linux-gnu-${tool} \\
    --sysroot=${GUEST_SYSROOT} -B/opt/xtools \\
    -wrapper /usr/local/bin/qemu-x86_64-cc-wrapper "\$@"
EOF
        chmod +x /usr/local/bin/x86_64-linux-gnu-"$tool"
    done
}

case "$ARCH" in
    amd64)
        : # host is x86_64; build.sh uses the native gcc/g++, nothing to add.
        ;;
    arm64)
        setup_x86_64_runtime_libs
        setup_x86_64_cross_apt
        ;;
    riscv64)
        setup_x86_64_runtime_libs
        setup_x86_64_sysroot_qemu
        ;;
    *)
        echo "[bootstrap] unsupported host arch: ${ARCH} (expected amd64, arm64 or riscv64)" >&2
        exit 1
        ;;
esac

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
