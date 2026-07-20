#!/bin/sh

# Many parts of this script were taken from @REIGNZ, @idkwhoiam322 and @raphielscape . Huge thanks to them.

# Some general variables
PHONE="beryllium"
ARCH="arm64"
SUBARCH="arm64"
DEFCONFIG=nogravity_defconfig
#DEFCONFIG=beryllium_defconfig
COMPILER=clang
LINKER=""
COMPILERDIR="${COMPILERDIR:-$(pwd)/clang}"
ANYKERNEL_DIR="${ANYKERNEL_DIR:-$(pwd)/AnyKernel3}"

# Fetch the toolchain / AnyKernel3 if they aren't already present.
# GitHub Actions clones both ahead of time (see main.yml); this is just a
# fallback so the script also works standalone / on a local machine.
if [ ! -d "${COMPILERDIR}" ]; then
    echo "Proton-Clang not found, cloning..."
    git clone --depth=1 https://github.com/kdrag0n/proton-clang.git "${COMPILERDIR}"
fi

if [ ! -d "${ANYKERNEL_DIR}" ]; then
    echo "AnyKernel3 not found, cloning..."
    # This fork is already pre-configured for beryllium/dipper
    # (device.name1/2, block=.../by-name/boot, kernel.string, etc.)
    git clone --depth=1 https://github.com/Shiki-ghub/AnyKernel3.git "${ANYKERNEL_DIR}"
fi

# Outputs
mkdir -p out/outputs/${PHONE}/9.1.24-SE
mkdir -p out/outputs/${PHONE}/9.1.24-NSE
mkdir -p out/outputs/${PHONE}/10.3.7-SE
mkdir -p out/outputs/${PHONE}/10.3.7-NSE

# Export shits
export KBUILD_BUILD_USER=Pierre2324
export KBUILD_BUILD_HOST=bokir

# Make `uname -v` / `uname -a` show WIB (Asia/Jakarta) instead of the
# build runner's default UTC time
export KBUILD_BUILD_TIMESTAMP="$(TZ='Asia/Jakarta' date)"

# Speed up build process
MAKE="./makeparallel"

# Basic build function
BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

Build () {
PATH="${COMPILERDIR}/bin:${PATH}" \
make -j$(nproc --all) O=out \
ARCH=${ARCH} \
CC=${COMPILER} \
CROSS_COMPILE=${COMPILERDIR}/bin/aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=${COMPILERDIR}/bin/arm-linux-gnueabi- \
LD_LIBRARY_PATH=${COMPILERDIR}/lib
}

Build_lld () {
PATH="${COMPILERDIR}/bin:${PATH}" \
make -j$(nproc --all) O=out \
ARCH=${ARCH} \
CC=${COMPILER} \
CROSS_COMPILE=${COMPILERDIR}/bin/aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=${COMPILERDIR}/bin/arm-linux-gnueabi- \
LD=ld.${LINKER} \
AR=llvm-ar \
NM=llvm-nm \
OBJCOPY=llvm-objcopy \
OBJDUMP=llvm-objdump \
STRIP=llvm-strip \
ld-name=${LINKER} \
KBUILD_COMPILER_STRING="Proton Clang"
}

# Package the freshly built Image.gz-dtb into a flashable AnyKernel3 zip
Package () {
VARIANT=$1
cp out/arch/arm64/boot/Image.gz-dtb "${ANYKERNEL_DIR}/Image.gz-dtb"
ZIPNAME="${PHONE}-${VARIANT}-$(date +'%Y%m%d-%H%M').zip"
(
    cd "${ANYKERNEL_DIR}" || exit 1
    zip -r9 "../out/outputs/${PHONE}/${VARIANT}/${ZIPNAME}" . -x ".git/*" ".github/*" "README.md"
)
rm -f "${ANYKERNEL_DIR}/Image.gz-dtb"
echo -e "${cyan}Packaged out/outputs/${PHONE}/${VARIANT}/${ZIPNAME}${nocol}"
}

# Make defconfig

make O=out ARCH=${ARCH} ${DEFCONFIG}
if [ $? -ne 0 ]
then
    echo "Build failed"
else
    echo "Made ${DEFCONFIG}"
fi

# Build starts here
if [ -z ${LINKER} ]
then
    #Start with 9.1.24-SE
    cp firmware/touch_fw_variant/9.1.24/* firmware/
    cp arch/arm64/boot/dts/qcom/SE_NSE/SE/* arch/arm64/boot/dts/qcom/
    Build
else
    Build_lld
fi

if [ $? -ne 0 ]
then
    echo "Build failed"
    rm -rf out/outputs/${PHONE}/*
else
    echo "Build succesful"
    cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/9.1.24-SE/Image.gz-dtb
    Package "9.1.24-SE"

    #9.1.24-NSE
    cp arch/arm64/boot/dts/qcom/SE_NSE/NSE/* arch/arm64/boot/dts/qcom/
    Build
    if [ $? -ne 0 ]
    then
        echo "Build failed"
        rm -rf out/outputs/${PHONE}/9.1.24-NSE/*
    else
        echo "Build succesful"
        cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/9.1.24-NSE/Image.gz-dtb
        Package "9.1.24-NSE"

        #10.3.7-SE
        cp firmware/touch_fw_variant/10.3.7/* firmware/
        cp arch/arm64/boot/dts/qcom/SE_NSE/SE/* arch/arm64/boot/dts/qcom/
        Build
        if [ $? -ne 0 ]
        then
            echo "Build failed"
            rm -rf out/outputs/${PHONE}/10.3.7-SE/*
        else
            echo "Build succesful"
            cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/10.3.7-SE/Image.gz-dtb
            Package "10.3.7-SE"

            #10.3.7-NSE
            cp arch/arm64/boot/dts/qcom/SE_NSE/NSE/* arch/arm64/boot/dts/qcom/
            Build
            if [ $? -ne 0 ]
            then
                echo "Build failed"
                rm -rf out/outputs/${PHONE}/10.3.7-NSE/*
            else
                echo "Build succesful"
                cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/10.3.7-NSE/Image.gz-dtb
                Package "10.3.7-NSE"
            fi
        fi
    fi
fi

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$yellow Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
