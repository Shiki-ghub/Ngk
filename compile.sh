#!/bin/sh

# Basic build function
BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

# Cleanup
rm -rf out/outputs
mkdir -p out/outputs

# Run every per-device build script found alongside this one
# (so adding a new compile-<device>.sh later doesn't require touching this file)
for device_script in ./compile-*.sh; do
    [ -f "${device_script}" ] || continue
    echo -e "${cyan}Running ${device_script}...${nocol}"
    chmod +x "${device_script}"
    "${device_script}"
done

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$yellow Full build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"
