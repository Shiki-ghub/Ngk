#!/bin/bash

set -e

# ============================================
# ARGUMEN
# ============================================
DEFCONFIG=${1:-beryllium_defconfig}
KERNEL_DIR=${2:-$(pwd)}
PROTON_DIR=${3:-$HOME/proton-clang}
ANYKERNEL_DIR=${4:-$HOME/AnyKernel3}

# ============================================
# KONFIGURASI
# ============================================
DEVICE=${DEVICE:-beryllium}
JOBS=$(nproc --all)
OUT_DIR="$KERNEL_DIR/out"
BUILD_LOG="$OUT_DIR/build.log"

mkdir -p "$OUT_DIR"
touch "$BUILD_LOG"

# ============================================
# EXPORT TOOLCHAIN
# ============================================
export PATH="$PROTON_DIR/bin:$PATH"

export ARCH=arm64
export SUBARCH=arm64

# Compiler flags
export CC="ccache clang"
export CXX="ccache clang++"
export AR="llvm-ar"
export NM="llvm-nm"
export OBJCOPY="llvm-objcopy"
export OBJDUMP="llvm-objdump"
export STRIP="llvm-strip"

# Linker
export LD="ld.lld"

# Cross compile
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"

# Build info
export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-builder}
export KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-proton-build}

# CCache
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache"
ccache -M 10G >/dev/null 2>&1

cd "$KERNEL_DIR"

# ============================================
# CLEANUP (opsional)
# ============================================
# make O="$OUT_DIR" clean
# make O="$OUT_DIR" mrproper

# ============================================
# BUILD KERNEL
# ============================================
echo "========================================"
echo "  Device    : $DEVICE"
echo "  Defconfig : $DEFCONFIG"
echo "  Jobs      : $JOBS"
echo "  Clang     : $(clang --version | head -1)"
echo "  Out Dir   : $OUT_DIR"
echo "========================================"

# Generate .config
make O="$OUT_DIR" ARCH=arm64 "$DEFCONFIG"

# Compile
make -j"$JOBS" O="$OUT_DIR" \
    ARCH=arm64 \
    CC="$CC" \
    CXX="$CXX" \
    AR="$AR" \
    NM="$NM" \
    LD="$LD" \
    OBJCOPY="$OBJCOPY" \
    OBJDUMP="$OBJDUMP" \
    STRIP="$STRIP" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
    2>&1 | tee -a "$BUILD_LOG"

# ============================================
# VERIFIKASI OUTPUT
# ============================================
KERNEL_IMAGE="$OUT_DIR/arch/arm64/boot/Image.gz-dtb"
KERNEL_IMAGE_GZ="$OUT_DIR/arch/arm64/boot/Image.gz"
KERNEL_IMAGE_RAW="$OUT_DIR/arch/arm64/boot/Image"
DTB_DIR="$OUT_DIR/arch/arm64/boot/dts/qcom"

echo ""
echo "========================================"
echo "  Build Selesai!"
echo "========================================"

if [ -f "$KERNEL_IMAGE" ]; then
    echo "✓ Output: $KERNEL_IMAGE"
    FINAL_IMAGE="$KERNEL_IMAGE"
elif [ -f "$KERNEL_IMAGE_GZ" ]; then
    echo "✓ Output: $KERNEL_IMAGE_GZ"
    FINAL_IMAGE="$KERNEL_IMAGE_GZ"
elif [ -f "$KERNEL_IMAGE_RAW" ]; then
    echo "✓ Output: $KERNEL_IMAGE_RAW"
    FINAL_IMAGE="$KERNEL_IMAGE_RAW"
else
    echo "✗ Kernel image tidak ditemukan!"
    exit 1
fi

# ============================================
# PACKING ANYKERNEL3
# ============================================
if [ -d "$ANYKERNEL_DIR" ]; then
    echo ""
    echo "========================================"
    echo "  Packing AnyKernel3..."
    echo "========================================"
    
    cd "$ANYKERNEL_DIR"
    
    # Bersihkan file lama
    rm -f Image* *.dtb dtb dtbo.img
    
    # Copy kernel image
    cp "$FINAL_IMAGE" .
    
    # Copy DTB (SDM845 - Poco F1)
    if ls "$DTB_DIR"/sdm845-beryllium.dtb 1> /dev/null 2>&1; then
        cp "$DTB_DIR"/sdm845-beryllium.dtb .
        echo "✓ DTB: sdm845-beryllium.dtb"
    elif ls "$DTB_DIR"/*.dtb 1> /dev/null 2>&1; then
        cp "$DTB_DIR"/*.dtb .
        echo "✓ DTB files copied"
    fi
    
    # Copy DTBO jika ada
    if [ -f "$OUT_DIR/arch/arm64/boot/dtbo.img" ]; then
        cp "$OUT_DIR/arch/arm64/boot/dtbo.img" .
        echo "✓ DTBO copied"
    fi
    
    # Update anykernel.sh (device name)
    sed -i "s/^device.name1=.*/device.name1=$DEVICE/" anykernel.sh 2>/dev/null || true
    
    # Buat zip
    ZIP_NAME="ProtonKernel-${DEVICE}-$(date +%Y%m%d-%H%M).zip"
    zip -r9 "$OUT_DIR/$ZIP_NAME" * -x .git README.md *placeholder .gitignore
    
    echo ""
    echo "========================================"
    echo "  Flashable Zip: $ZIP_NAME"
    echo "========================================"
    
    cd "$KERNEL_DIR"
else
    echo "⚠ AnyKernel3 directory tidak ditemukan, skip packing."
fi

echo ""
echo "Done! Output ada di: $OUT_DIR"
