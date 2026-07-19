#!/bin/sh

# Many parts of this script were taken from @REIGNZ, @idkwhoiam322 and @raphielscape . Huge thanks to them.

PHONE="beryllium"
ARCH="arm64"
SUBARCH="arm64"
DEFCONFIG=nogravity_defconfig
COMPILERDIR="${COMPILERDIR:-$(pwd)/clang}"
ANYKERNEL_DIR="${ANYKERNEL_DIR:-$(pwd)/AnyKernel3}"
LINKER=""

[ -d "${COMPILERDIR}" ] || git clone --depth=1 https://github.com/kdrag0n/proton-clang.git "${COMPILERDIR}"
[ -d "${ANYKERNEL_DIR}" ] || git clone --depth=1 https://github.com/PainKiller3/AnyKernel3.git "${ANYKERNEL_DIR}"

mkdir -p out/outputs/${PHONE}/9.1.24-SE
mkdir -p out/outputs/${PHONE}/9.1.24-NSE
mkdir -p out/outputs/${PHONE}/10.3.7-SE
mkdir -p out/outputs/${PHONE}/10.3.7-NSE

export KBUILD_BUILD_USER=Pierre2324
export KBUILD_BUILD_HOST=bokir

BUILD_START=$(date +"%s")
cyan='\033[0;36m'
yellow='\033[0;33m'
nocol='\033[0m'

MAKE_ARGS="-j$(nproc --all) O=out ARCH=${ARCH} \
CC=${COMPILERDIR}/bin/clang \
HOSTCC=${COMPILERDIR}/bin/clang \
HOSTCXX=${COMPILERDIR}/bin/clang++ \
CROSS_COMPILE=${COMPILERDIR}/bin/aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=${COMPILERDIR}/bin/arm-linux-gnueabi- \
AR=${COMPILERDIR}/bin/ar \
NM=${COMPILERDIR}/bin/nm \
OBJCOPY=${COMPILERDIR}/bin/llvm-objcopy \
OBJDUMP=${COMPILERDIR}/bin/llvm-objdump \
READELF=${COMPILERDIR}/bin/llvm-readelf \
OBJSIZE=${COMPILERDIR}/bin/llvm-size \
STRIP=${COMPILERDIR}/bin/llvm-strip \
LLVM_AR=${COMPILERDIR}/bin/llvm-ar \
LLVM_DIS=${COMPILERDIR}/bin/llvm-dis \
KBUILD_COMPILER_STRING=Proton-Clang"

Build() {
    make ${MAKE_ARGS}
}

Package() {
    VARIANT=$1
    cp out/arch/arm64/boot/Image.gz-dtb "${ANYKERNEL_DIR}/Image.gz-dtb"
    ZIPNAME="${PHONE}-${VARIANT}-$(date +'%Y%m%d-%H%M').zip"
    (cd "${ANYKERNEL_DIR}" && zip -r9 "../out/outputs/${PHONE}/${VARIANT}/${ZIPNAME}" . -x ".git/*" ".github/*" "README.md")
    rm -f "${ANYKERNEL_DIR}/Image.gz-dtb"
    echo -e "${cyan}Packaged ${ZIPNAME}${nocol}"
}

make O=out ARCH=${ARCH} ${DEFCONFIG} || exit 1

for V in 9.1.24-SE 9.1.24-NSE 10.3.7-SE 10.3.7-NSE; do
    case "$V" in
      9.1.24-SE) cp firmware/touch_fw_variant/9.1.24/* firmware/; cp arch/arm64/boot/dts/qcom/SE_NSE/SE/* arch/arm64/boot/dts/qcom/;;
      9.1.24-NSE) cp arch/arm64/boot/dts/qcom/SE_NSE/NSE/* arch/arm64/boot/dts/qcom/;;
      10.3.7-SE) cp firmware/touch_fw_variant/10.3.7/* firmware/; cp arch/arm64/boot/dts/qcom/SE_NSE/SE/* arch/arm64/boot/dts/qcom/;;
      10.3.7-NSE) cp arch/arm64/boot/dts/qcom/SE_NSE/NSE/* arch/arm64/boot/dts/qcom/;;
    esac
    Build || exit 1
    cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/${V}/Image.gz-dtb
    Package "${V}"
done

BUILD_END=$(date +"%s")
DIFF=$((BUILD_END-BUILD_START))
echo -e "$yellow Build completed in $((DIFF/60)) minute(s) and $((DIFF%60)) seconds.$nocol"
