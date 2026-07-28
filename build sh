#!/bin/bash

# ============================================
# ARGUMEN
# ============================================
DEFCONFIG=${1:-beryllium_defconfig}
KERNEL_DIR=${2:-$(pwd)}
PROTON_DIR=${3:-$HOME/proton-clang}
ANYKERNEL_DIR=${4:-$HOME/AnyKernel3}
KSU_ENABLE=${5:-N}
PHONE=${6:-beryllium}

# ============================================
# KONFIGURASI
# ============================================
JOBS=$(nproc --all)
OUT_DIR="$KERNEL_DIR/out"
BUILD_LOG="$OUT_DIR/build.log"
OUTPUT_BASE="$OUT_DIR/outputs/$PHONE"

mkdir -p "$OUT_DIR"
mkdir -p "$OUTPUT_BASE/9.1.24-SE"
mkdir -p "$OUTPUT_BASE/9.1.24-NSE"
touch "$BUILD_LOG"

# ============================================
# EXPORT TOOLCHAIN
# ============================================
export PATH="$PROTON_DIR/bin:$PATH"

export ARCH=arm64
export SUBARCH=arm64

export CC="ccache clang"
export CXX="ccache clang++"
export AR="llvm-ar"
export NM="llvm-nm"
export OBJCOPY="llvm-objcopy"
export OBJDUMP="llvm-objdump"
export STRIP="llvm-strip"

export LD="ld.lld"

export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_ARM32="arm-linux-gnueabi-"

export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-builder}
export KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-proton-build}

# CCache
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_DIR="$HOME/.ccache"
ccache -M 10G >/dev/null 2>&1

cd "$KERNEL_DIR"

# ============================================
# KERNELSU-NEXT INTEGRATION (Y = JALANKAN)
# ============================================
if [ "$KSU_ENABLE" = "Y" ] || [ "$KSU_ENABLE" = "y" ]; then
    echo ""
    echo "========================================"
    echo "  KernelSU-Next: ENABLED"
    echo "  Applying manual hooks for kernel 4.9"
    echo "========================================"
    
    # Clone KernelSU-Next (legacy branch untuk kernel < 4.14)
    if [ ! -d "KernelSU-Next" ] && [ ! -d "KernelSU" ]; then
        curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s legacy
    fi
    
    # Enable CONFIG_KSU di defconfig
    if ! grep -q "CONFIG_KSU=y" arch/arm64/configs/$DEFCONFIG; then
        echo "CONFIG_KSU=y" >> arch/arm64/configs/$DEFCONFIG
        echo "✓ CONFIG_KSU=y added to defconfig"
    fi
    
    # --- Manual Hook: fs/exec.c ---
    if ! grep -q "ksu_handle_execveat" fs/exec.c; then
        sed -i '/^int do_execve(struct filename \*filename,$/i\
#ifdef CONFIG_KSU\
__attribute__((hot))\
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv, void *envp, int *flags);\
#endif
' fs/exec.c
        
        sed -i '/struct user_arg_ptr argv = { .ptr.native = __argv };/a\
#ifdef CONFIG_KSU\
\tksu_handle_execveat((int *)AT_FDCWD, \&filename, \&argv, \&envp, 0);\
#endif
' fs/exec.c
        echo "✓ Hook applied: fs/exec.c"
    fi
    
    # --- Manual Hook: fs/open.c ---
    if ! grep -q "ksu_handle_faccessat" fs/open.c; then
        sed -i '/^SYSCALL_DEFINE3(faccessat, int, dfd, const char __user \*, filename, int, mode)$/i\
#ifdef CONFIG_KSU\
__attribute__((hot))\
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode, int *flags);\
#endif
' fs/open.c
        
        sed -i '/unsigned int lookup_flags = LOOKUP_FOLLOW;/a\
#ifdef CONFIG_KSU\
\tksu_handle_faccessat(\&dfd, \&filename, \&mode, NULL);\
#endif
' fs/open.c
        echo "✓ Hook applied: fs/open.c"
    fi
    
    # --- Manual Hook: fs/read_write.c ---
    if ! grep -q "ksu_handle_sys_read" fs/read_write.c; then
        sed -i '/^SYSCALL_DEFINE3(read, unsigned int, fd, char __user \*, buf, size_t, count)$/i\
#ifdef CONFIG_KSU\
extern bool ksu_vfs_read_hook __read_mostly;\
extern __attribute__((cold)) int ksu_handle_sys_read(unsigned int fd, char __user **buf_ptr, size_t *count_ptr);\
#endif
' fs/read_write.c
        
        sed -i '/struct fd f = fdget_pos(fd);/a\
#ifdef CONFIG_KSU\
\tif (unlikely(ksu_vfs_read_hook))\
\t\tksu_handle_sys_read(fd, \&buf, \&count);\
#endif
' fs/read_write.c
        echo "✓ Hook applied: fs/read_write.c"
    fi
    
    # --- Manual Hook: fs/stat.c ---
    if ! grep -q "ksu_handle_stat" fs/stat.c; then
        sed -i '/^SYSCALL_DEFINE4(newfstatat, int, dfd, const char __user \*, filename,$/i\
#ifdef CONFIG_KSU\
__attribute__((hot))\
extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\
#endif
' fs/stat.c
        
        sed -i '/int error;/a\
#ifdef CONFIG_KSU\
\tksu_handle_stat(\&dfd, \&filename, \&flag);\
#endif
' fs/stat.c
        echo "✓ Hook applied: fs/stat.c"
    fi
    
    # --- Manual Hook: kernel/reboot.c ---
    if ! grep -q "ksu_handle_sys_reboot" kernel/reboot.c; then
        sed -i '/^SYSCALL_DEFINE4(reboot, int, magic1, int, magic2, unsigned int, cmd,$/i\
#ifdef CONFIG_KSU\
extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);\
#endif
' kernel/reboot.c
        
        sed -i '/int ret = 0;/a\
#ifdef CONFIG_KSU\
\tksu_handle_sys_reboot(magic1, magic2, cmd, \&arg);\
#endif
' kernel/reboot.c
        echo "✓ Hook applied: kernel/reboot.c"
    fi
    
    echo "========================================"
    echo "  KernelSU-Next integration complete!"
    echo "========================================"
else
    echo ""
    echo "========================================"
    echo "  KernelSU-Next: SKIPPED"
    echo "========================================"
fi

# ============================================
# BUILD FUNCTIONS
# ============================================
Build() {
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
        >> "$BUILD_LOG" 2>&1
    return $?
}

Build_lld() {
    make -j"$JOBS" O="$OUT_DIR" \
        ARCH=arm64 \
        CC="$CC" \
        CXX="$CXX" \
        AR="$AR" \
        NM="$NM" \
        LD="$LINKER" \
        OBJCOPY="$OBJCOPY" \
        OBJDUMP="$OBJDUMP" \
        STRIP="$STRIP" \
        CROSS_COMPILE="$CROSS_COMPILE" \
        CROSS_COMPILE_ARM32="$CROSS_COMPILE_ARM32" \
        >> "$BUILD_LOG" 2>&1
    return $?
}

Package() {
    local VARIANT=$1
    if [ -d "$ANYKERNEL_DIR" ]; then
        cd "$ANYKERNEL_DIR"
        
        # Bersihkan file lama
        rm -f Image* *.dtb dtbo.img
        
        # Copy kernel image
        if [ -f "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" ]; then
            cp "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" .
        elif [ -f "$OUT_DIR/arch/arm64/boot/Image.gz" ]; then
            cp "$OUT_DIR/arch/arm64/boot/Image.gz" .
        elif [ -f "$OUT_DIR/arch/arm64/boot/Image" ]; then
            cp "$OUT_DIR/arch/arm64/boot/Image" .
        fi
        
        # Copy DTB
        local DTB_DIR="$OUT_DIR/arch/arm64/boot/dts/qcom"
        if ls "$DTB_DIR"/*.dtb 1>/dev/null 2>&1; then
            cp "$DTB_DIR"/*.dtb .
        fi
        
        # Copy DTBO
        if [ -f "$OUT_DIR/arch/arm64/boot/dtbo.img" ]; then
            cp "$OUT_DIR/arch/arm64/boot/dtbo.img" .
        fi
        
        # Update device name di anykernel.sh
        sed -i "s/^device.name1=.*/device.name1=$PHONE/" anykernel.sh 2>/dev/null || true
        
        # Nama zip
        local ZIP_NAME="ProtonKernel-${PHONE}-${VARIANT}-$(date +%Y%m%d-%H%M).zip"
        if [ "$KSU_ENABLE" = "Y" ] || [ "$KSU_ENABLE" = "y" ]; then
            ZIP_NAME="ProtonKernel-${PHONE}-${VARIANT}-KSU-$(date +%Y%m%d-%H%M).zip"
        fi
        
        zip -r9 "$OUT_DIR/$ZIP_NAME" * -x .git README.md *placeholder .gitignore >/dev/null
        echo "✓ Packaged: $ZIP_NAME"
        
        cd "$KERNEL_DIR"
    fi
}

# ============================================
# GENERATE CONFIG
# ============================================
echo ""
echo "========================================"
echo "  Generating kernel config..."
echo "========================================"
make O="$OUT_DIR" ARCH=arm64 "$DEFCONFIG"

# ============================================
# BUILD 9.1.24-SE
# ============================================
echo ""
echo "========================================"
echo "  Building 9.1.24-SE..."
echo "========================================"

# Copy firmware SE
cp -f firmware/touch_fw_variant/9.1.24/* firmware/ 2>/dev/null || true

# Copy DTS SE
cp -f arch/arm64/boot/dts/qcom/SE_NSE/SE/* arch/arm64/boot/dts/qcom/ 2>/dev/null || true

if [ -z "${LINKER}" ]; then
    Build
else
    Build_lld
fi

if [ $? -ne 0 ]; then
    echo "❌ Build failed: 9.1.24-SE"
    rm -rf "$OUTPUT_BASE/9.1.24-SE"/*
    exit 1
else
    echo "✅ Build successful: 9.1.24-SE"
    cp "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" "$OUTPUT_BASE/9.1.24-SE/" 2>/dev/null || \
    cp "$OUT_DIR/arch/arm64/boot/Image.gz" "$OUTPUT_BASE/9.1.24-SE/" 2>/dev/null || \
    cp "$OUT_DIR/arch/arm64/boot/Image" "$OUTPUT_BASE/9.1.24-SE/" 2>/dev/null || true
    Package "9.1.24-SE"
fi

# ============================================
# BUILD 9.1.24-NSE
# ============================================
echo ""
echo "========================================"
echo "  Building 9.1.24-NSE..."
echo "========================================"

mkdir -p "$OUTPUT_BASE/9.1.24-NSE"

# Copy firmware NSE jika ada folder terpisah
if [ -d "firmware/touch_fw_variant/9.1.24-NSE" ]; then
    cp -f firmware/touch_fw_variant/9.1.24-NSE/* firmware/ 2>/dev/null || true
fi

# Copy DTS NSE
cp -f arch/arm64/boot/dts/qcom/SE_NSE/NSE/* arch/arm64/boot/dts/qcom/ 2>/dev/null || true

# Re-generate config untuk memastikan DTS terdeteksi ulang
make O="$OUT_DIR" ARCH=arm64 "$DEFCONFIG" >/dev/null 2>&1

if [ -z "${LINKER}" ]; then
    Build
else
    Build_lld
fi

if [ $? -ne 0 ]; then
    echo "❌ Build failed: 9.1.24-NSE"
    rm -rf "$OUTPUT_BASE/9.1.24-NSE"/*
    exit 1
else
    echo "✅ Build successful: 9.1.24-NSE"
    cp "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" "$OUTPUT_BASE/9.1.24-NSE/" 2>/dev/null || \
    cp "$OUT_DIR/arch/arm64/boot/Image.gz" "$OUTPUT_BASE/9.1.24-NSE/" 2>/dev/null || \
    cp "$OUT_DIR/arch/arm64/boot/Image" "$OUTPUT_BASE/9.1.24-NSE/" 2>/dev/null || true
    Package "9.1.24-NSE"
fi

# ============================================
# SELESAI
# ============================================
echo ""
echo "========================================"
echo "  ALL BUILDS COMPLETE!"
echo "========================================"
echo "  Device : $PHONE"
echo "  KSU    : $KSU_ENABLE"
echo "  Output : $OUTPUT_BASE"
echo "  Zips   : $OUT_DIR/ProtonKernel-*.zip"
echo "========================================"
