#!/bin/bash
#
# Build script for FloppyKernel (ginkgo).
# Based on build script for Quicksilver, by Ghostrider.
# Copyright (C) 2020-2021 Adithya R. (original version)
# Copyright (C) 2022-2025 Flopster101 (rewrite)

## Variables
# Toolchains
AOSP_REPO="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/refs/heads/master"
AOSP_ARCHIVE="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master"
SD_REPO="https://github.com/ThankYouMario/proprietary_vendor_qcom_sdclang"
SD_BRANCH="14"
PC_REPO="https://github.com/kdrag0n/proton-clang"
LZ_REPO="https://gitlab.com/Jprimero15/lolz_clang.git"
RC_URL="https://github.com/kutemeikito/RastaMod69-Clang/releases/download/RastaMod69-Clang-20.0.0-release/RastaMod69-Clang-20.0.0.tar.gz"
GC_REPO="https://api.github.com/repos/greenforce-project/greenforce_clang/releases/latest"
ZC_REPO="https://raw.githubusercontent.com/ZyCromerZ/Clang/refs/heads/main/Clang-main-link.txt"
RV_REPO="https://api.github.com/repos/Rv-Project/RvClang/releases/latest"
GCC_REPO="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9"
GCC64_REPO="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9"
# AnyKernel3
AK3_URL="https://github.com/malkist01/AnyKernel2"

# Device fragments
GINKGO_FRAGMENT="vendor/ginkgo.config"
LAUREL_FRAGMENT="vendor/laurel_sprout.config"

# Parse device argument
if [[ -z "$1" ]]; then
    echo -e "\nERROR: Please specify device to build!\n"
    exit 1
fi

TARGET_DEVICE="$1"
shift

# Set device-specific variables
case "$TARGET_DEVICE" in
    ginkgo)
        AK3_BRANCH="unified"
        DEVICE="Redmi Note 8/8T"
        CODENAME="ginkgo"
        FRAGMENT="$GINKGO_FRAGMENT"
        ;;
    laurel_sprout)
        AK3_BRANCH="unified"
        DEVICE="Xiaomi Mi A3"
        CODENAME="laurel_sprout"
        FRAGMENT="$LAUREL_FRAGMENT"
        ;;
    mitrinket)
        AK3_BRANCH="unified"
        DEVICE="Redmi Note 8/8T and Xiaomi Mi A3"
        CODENAME="mitrinket"
        FRAGMENT="vendor/unified.config"
        ;;
    *)
        echo -e "\nERROR: Unknown device: $TARGET_DEVICE\n"
        exit 1
        ;;
esac

# Workspace
if [[ -d /workspace ]]; then
    WP="/workspace"
    IS_GP=1
else
    IS_GP=0
fi

if [[ -z "$WP" ]]; then
    echo -e "\nERROR: Environment not Gitpod! Please set the WP env var...\n"
    exit 1
fi

if [[ ! -d drivers ]]; then
    echo -e "\nERROR: Please execute from top-level kernel tree\n"
    exit 1
fi

if [[ "$IS_GP" == "1" ]]; then
    export KBUILD_BUILD_USER="Flopster101"
    export KBUILD_BUILD_HOST="buildbot"
fi

# Other
DEFAULT_DEFCONFIG="vendor/trinket-perf_defconfig"
BASE_FRAGMENT="vendor/xiaomi-trinket.config"
KERNEL_URL="https://github.com/Flopster101/flop_ginkgo_kernel"
SECONDS=0 # builtin bash timer
DATE="$(date '+%Y%m%d-%H%M')"
BUILD_HOST="$USER@$(hostname)"
# Paths
TC_DIR="$WP/toolchains"
SD_DIR="$TC_DIR/sdclang"
AC_DIR="$TC_DIR/aospclang"
PC_DIR="$TC_DIR/protonclang"
RC_DIR="$TC_DIR/rm69clang"
LZ_DIR="$TC_DIR/lolzclang"
GCC_DIR="$TC_DIR/gcc"
GCC64_DIR="$TC_DIR/gcc64"
AK3_DIR="$WP/AnyKernel3"
GC_DIR="$TC_DIR/greenforceclang"
ZC_DIR="$TC_DIR/zycclang"
RV_DIR="$TC_DIR/rvclang"
KDIR="$(readlink -f .)"
USE_GCC_BINUTILS="0"
OUT_IMAGE="out/arch/arm64/boot/Image.gz-dtb"
DTBO_TMP="out/dtbotmp"
OUT_DTBO="$DTBO_TMP/dtbo.img"
# Set OUT_DTB based on device
if [[ "$CODENAME" == "laurel_sprout" ]]; then
    OUT_DTB="out/arch/arm64/boot/dts/xiaomi/laurel_sprout-trinket-base.dtb"
elif [[ "$CODENAME" == "mitrinket" ]]; then
    OUT_DTB_GINKGO="out/arch/arm64/boot/dts/xiaomi/qcom-base/trinket.dtb"
    OUT_DTB_LAUREL="out/arch/arm64/boot/dts/xiaomi/laurel_sprout-trinket-base.dtb"
    # Set OUT_DTB to ginkgo as default for checks
    OUT_DTB="$OUT_DTB_GINKGO"
else
    OUT_DTB="out/arch/arm64/boot/dts/xiaomi/qcom-base/trinket.dtb"
fi

IN_DTBO_GINKGO="out/arch/arm64/boot/dts/xiaomi/ginkgo-trinket-overlay.dtbo"
IN_DTBO_LAUREL="out/arch/arm64/boot/dts/xiaomi/laurel_sprout-trinket-overlay.dtbo"

# Ensure the toolchains directory exists
if [[ ! -d "$TC_DIR" ]]; then
    mkdir -p "$TC_DIR"
fi

# Custom toolchain directory
if [[ -z "$CUST_DIR" ]]; then
    CUST_DIR="$TC_DIR/custom-toolchain"
else
    echo -e "\nINFO: Overriding custom toolchain path..."
fi

## Customizable vars

# FloppyKernel version
FK_VER="v2.0"

# Toggles
USE_CCACHE=1

## Parse arguments
DO_KSU=0
DO_SUKI=0
DO_RKSU=0
DO_CLEAN=0
DO_MENUCONFIG=0
IS_RELEASE=0
DO_TG=0
DO_REGEN=0
DO_ZXZ=0
DO_FLTO=0
for arg in "$@"; do
    if [[ "$arg" == *m* ]]; then
        echo "INFO: menuconfig enabled"
        DO_MENUCONFIG=1
    fi
    if [[ "$arg" == *k* ]]; then
        echo "INFO: KernelSU enabled"
        DO_KSU=1
    fi
    if [[ "$arg" == *s* ]]; then
        echo "INFO: ReSukiSU argument passed"
        DO_SUKI=1
    fi
    if [[ "$arg" == *u* ]]; then
        echo "INFO: RKSU argument passed"
        DO_RKSU=1
    fi
    if [[ "$arg" == *c* ]]; then
        echo "INFO: clean build enabled"
        DO_CLEAN=1
    fi
    if [[ "$arg" == *R* ]]; then
        echo "INFO: Release build enabled"
        IS_RELEASE=1
    fi
    if [[ "$arg" == *t* ]]; then
        echo "INFO: Telegram upload enabled"
        DO_TG=1
    fi
    if [[ "$arg" == *o* ]]; then
        echo "INFO: 0x0.st upload enabled"
        DO_ZXZ=1
    fi
    if [[ "$arg" == *r* ]]; then
        echo "INFO: config regeneration mode"
        DO_REGEN=1
    fi
    if [[ "$arg" == *l* ]]; then
        echo "INFO: Full-LTO enabled"
        echo "WARNING: Full-LTO is VERY resource heavy and may take a long time to compile!"
        DO_FLTO=1
    fi
done

KSU_COUNT=0
[ "$DO_KSU" == "1" ] && KSU_COUNT=$((KSU_COUNT + 1))
[ "$DO_SUKI" == "1" ] && KSU_COUNT=$((KSU_COUNT + 1))
[ "$DO_RKSU" == "1" ] && KSU_COUNT=$((KSU_COUNT + 1))
if [ "$KSU_COUNT" -gt 1 ]; then
    echo "ERROR: KSU variants are mutually exclusive. Please select only one."
    exit 1
fi

DEFCONFIG="$DEFAULT_DEFCONFIG"
if [[ "$IS_RELEASE" == "1" ]]; then
    BUILD_TYPE="Release"
else
    echo "INFO: Build marked as testing"
    BUILD_TYPE="Testing"
fi

TEST_CHANNEL=1
#TEST_BUILD=0

# Upload build log
LOG_UPLOAD=1

# Pick aosp, proton, rm69, lolz, slim, greenforce, zyc, rv, custom
if [[ -z "$CLANG_TYPE" ]]; then
    CLANG_TYPE="zyc"
else
    echo -e "\nINFO: Overriding default toolchain"
fi

## Telegram
CHAT_ID="-1002287610863"
BOT_TOKEN="7868194496:AAGY7WwRRbeCOPYOnczoCPh2psC43Q0F3JI"

## Build type
LINUX_VER=$(make kernelversion 2>/dev/null)

if [[ "$IS_RELEASE" == "1" ]]; then
    BUILD_TYPE="Release"
else
    BUILD_TYPE="Testing"
fi

CK_TYPE=""
CK_TYPE_SHORT=""
if [[ "$DO_KSU" == "1" ]]; then
    CK_TYPE="KSUNext"
    CK_TYPE_SHORT="KN"
elif [ "$DO_SUKI" == "1" ]; then
    CK_TYPE="ReSukiSU"
    CK_TYPE_SHORT="RESKS"
elif [ "$DO_RKSU" == "1" ]; then
    CK_TYPE="RKSU-NOSUS"
    CK_TYPE_SHORT="RKS"
else
    CK_TYPE="Vanilla"
    CK_TYPE_SHORT="V"
fi
ZIP_PATH="$WP/Anjani_$FK_VER-$CK_TYPE-$CODENAME-$DATE.zip"

echo -e "\nINFO: Build info:
- Device: $DEVICE ($CODENAME)
- Addons: $CK_TYPE
- Anjani version: $FK_VER
- Linux version: $LINUX_VER
- Defconfig: $DEFCONFIG
- Build date: $DATE
- Build type: $BUILD_TYPE
- Clean build: $([ "$DO_CLEAN" -eq 1 ] && echo "Yes" || echo "No")
"

install_deps_deb() {
    # Dependencies
    UB_DEPLIST="lz4 brotli flex bc cpio kmod ccache zip libtinfo5 python3"
    if grep -q "Ubuntu" /etc/os-release; then
        sudo apt update -qq
        sudo apt install $UB_DEPLIST -y
    else
        echo "INFO: Your distro is not Ubuntu, skipping dependencies installation..."
        echo "INFO: Make sure you have these dependencies installed before proceeding: $UB_DEPLIST"
    fi
}

get_toolchain() {
    local toolchain_type="$1"
    local toolchain_dir=""

    case "$toolchain_type" in
        aosp)
            toolchain_dir="$AC_DIR"
            USE_GCC_BINUTILS=1
            if [[ ! -d "$toolchain_dir" ]]; then
                echo -e "\nINFO: AOSP Clang not found! Cloning to $toolchain_dir..."
                CURRENT_CLANG=$(curl -s "$AOSP_REPO" | grep -oE "clang-r[0-9a-f]+" | sort -u | tail -n1)
                if ! curl -LSsO "$AOSP_ARCHIVE/$CURRENT_CLANG.tar.gz"; then
                    echo -e "\nERROR: Cloning failed! Aborting..."
                    exit 1
                fi
                mkdir -p "$toolchain_dir" && tar -xf ./*.tar.gz -C "$toolchain_dir" && rm ./*.tar.gz
                touch "$toolchain_dir/bin/aarch64-linux-gnu-elfedit" && chmod +x "$toolchain_dir/bin/aarch64-linux-gnu-elfedit"
                touch "$toolchain_dir/bin/arm-linux-gnueabi-elfedit" && chmod +x "$toolchain_dir/bin/arm-linux-gnueabi-elfedit"
            fi
            ;;
        sdclang)
            toolchain_dir="$SD_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo "INFO: SD Clang not found! Cloning to $toolchain_dir..."
                if ! git clone -q -b "$SD_BRANCH" --depth=1 "$SD_REPO" "$toolchain_dir"; then
                    echo "ERROR: Cloning failed! Aborting..."
                    exit 1
                fi
            fi
            ;;
        proton)
            toolchain_dir="$PC_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo "INFO: Proton Clang not found! Cloning to $toolchain_dir..."
                if ! git clone -q --depth=1 "$PC_REPO" "$toolchain_dir"; then
                    echo "ERROR: Cloning failed! Aborting..."
                    exit 1
                fi
            fi
            ;;
        rm69)
            toolchain_dir="$RC_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo "INFO: RastaMod69 Clang not found! Cloning to $toolchain_dir..."
                wget -q --show-progress "$RC_URL" -O "$WP/RastaMod69-clang.tar.gz"
                if [[ $? -ne 0 ]]; then
                    echo "ERROR: Download failed! Aborting..."
                    rm -f "$WP/RastaMod69-clang.tar.gz"
                    exit 1
                fi
                rm -rf clang && mkdir -p "$toolchain_dir" && tar -xf "$WP/RastaMod69-clang.tar.gz" -C "$toolchain_dir"
                if [[ $? -ne 0 ]]; then
                    echo "ERROR: Extraction failed! Aborting..."
                    rm -f "$WP/RastaMod69-clang.tar.gz"
                    exit 1
                fi
                rm -f "$WP/RastaMod69-clang.tar.gz"
                echo "INFO: RastaMod69 Clang successfully cloned to $toolchain_dir"
            fi
            ;;
        lolz)
            toolchain_dir="$LZ_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo "INFO: Lolz Clang not found! Cloning to $toolchain_dir..."
                if ! git clone -q --depth=1 "$LZ_REPO" "$toolchain_dir"; then
                    echo "ERROR: Cloning failed! Aborting..."
                    exit 1
                fi
            fi
            ;;
        greenforce)
            USE_GCC_BINUTILS=1
            toolchain_dir="$GC_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo -e "\nINFO: Greenforce Clang not found! Cloning to $toolchain_dir..."
                LATEST_RELEASE=$(curl -s $GC_REPO | grep "browser_download_url" | grep ".tar.gz" | cut -d '"' -f 4)
                if [[ -z "$LATEST_RELEASE" ]]; then
                    echo "ERROR: Failed to fetch the latest Greenforce Clang release! Aborting..."
                    exit 1
                fi
                if ! wget -q --show-progress -O "$WP/greenforce-clang.tar.gz" "$LATEST_RELEASE"; then
                    echo "ERROR: Download failed! Aborting..."
                    exit 1
                fi
                mkdir -p "$toolchain_dir"
                tar -xf "$WP/greenforce-clang.tar.gz" -C "$toolchain_dir"
                rm "$WP/greenforce-clang.tar.gz"
            fi
            ;;
        custom)
            toolchain_dir="$CUST_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
                echo -e "\nERROR: Custom toolchain not found! Aborting..."
                echo -e "INFO: Please provide a toolchain at $CUST_DIR or select a different toolchain"
                exit 1
            fi
            ;;
        zyc)
            toolchain_dir="$ZC_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
            echo -e "\nINFO: ZyC Clang not found! Cloning to $toolchain_dir..."
            fi

            # Check and cache the latest version
            ZYC_VERSION_FILE="$WP/zyc-clang-version.txt"
            LATEST_VERSION=$(curl -s "$ZC_REPO" | head -n 1)
            if [[ -z "$LATEST_VERSION" ]]; then
                echo "INFO: Failed to check ZyC Clang version"
            else
                if [[ -f "$ZYC_VERSION_FILE" ]]; then
                    CURRENT_VERSION=$(cat "$ZYC_VERSION_FILE")
                    if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
                        echo "INFO: A new version of ZyC Clang is available: $LATEST_VERSION"
                        echo "$LATEST_VERSION" > "$ZYC_VERSION_FILE"
                    fi
                else
                    echo "$LATEST_VERSION" > "$ZYC_VERSION_FILE"
                fi
            fi

            if [[ ! -d "$toolchain_dir" ]]; then
                if [[ -f "$ZYC_VERSION_FILE" ]]; then
                    echo "$LATEST_VERSION" > "$ZYC_VERSION_FILE"
                fi
                if [[ -z "$LATEST_VERSION" ]]; then
                    echo "ERROR: Failed to fetch the latest ZyC Clang release! Aborting..."
                    exit 1
                fi
                if ! wget -q --show-progress -O "$WP/zyc-clang.tar.gz" "$LATEST_VERSION"; then
                    echo "ERROR: Download failed! Aborting..."
                    rm -f "$ZYC_VERSION_FILE"
                    exit 1
                fi
                mkdir -p "$toolchain_dir"
                if ! tar -xf "$WP/zyc-clang.tar.gz" -C "$toolchain_dir"; then
                    echo "ERROR: Extraction failed! Aborting..."
                    rm -f "$WP/zyc-clang.tar.gz" "$ZYC_VERSION_FILE"
                    exit 1
                fi
                rm "$WP/zyc-clang.tar.gz"
            fi
            ;;
        rv)
            toolchain_dir="$RV_DIR"
            if [[ ! -d "$toolchain_dir" ]]; then
            echo -e "\nINFO: RvClang not found! Fetching the latest version..."
            LATEST_RELEASE=$(curl -s "$RV_REPO" | grep "browser_download_url" | grep ".tar.gz" | cut -d '"' -f 4)
            if [[ -z "$LATEST_RELEASE" ]]; then
                echo "ERROR: Failed to fetch the latest RvClang release! Aborting..."
                exit 1
            fi
            if ! wget -q --show-progress -O "$WP/rvclang.tar.gz" "$LATEST_RELEASE"; then
                echo "ERROR: Download failed! Aborting..."
                exit 1
            fi
            mkdir -p "$toolchain_dir"
            if ! tar -xf "$WP/rvclang.tar.gz" -C "$toolchain_dir"; then
                echo "ERROR: Extraction failed! Aborting..."
                rm -f "$WP/rvclang.tar.gz"
                exit 1
            fi
            rm "$WP/rvclang.tar.gz"
            # Move contents of the inner "RvClang" folder to $RV_DIR
            if [[ -d "$toolchain_dir/RvClang" ]]; then
                mv "$toolchain_dir/RvClang"/* "$toolchain_dir/"
                rmdir "$toolchain_dir/RvClang"
            fi
            fi
            ;;
        *)
            echo -e "\nERROR: Unknown toolchain type: $toolchain_type"
            exit 1
            ;;
    esac

    if [[ "$USE_GCC_BINUTILS" == "1" ]]; then
        if [[ ! -d "$GCC_DIR" ]]; then
            echo "INFO: GCC not found! Cloning to $GCC_DIR..."
            if ! git clone -q -b lineage-19.1 --depth=1 "$GCC_REPO" "$GCC_DIR"; then
                echo "ERROR: Cloning failed! Aborting..."
                exit 1
            fi
        fi
        if [[ ! -d "$GCC64_DIR" ]]; then
            echo "INFO: GCC64 not found! Cloning to $GCC64_DIR..."
            if ! git clone -q -b lineage-19.1 --depth=1 "$GCC64_REPO" "$GCC64_DIR"; then
                echo "ERROR: Cloning failed! Aborting..."
                exit 1
            fi
        fi
    fi
}

prep_toolchain() {
    local toolchain_type="$1"
    local toolchain_dir=""

    case "$toolchain_type" in
        aosp)
            toolchain_dir="$AC_DIR"
            echo "INFO: Toolchain: AOSP Clang"
            ;;
        sdclang)
            toolchain_dir="$SD_DIR/compiler"
            echo "INFO: Toolchain: Snapdragon Clang"
            ;;
        proton)
            toolchain_dir="$PC_DIR"
            echo "INFO: Toolchain: Proton Clang"
            ;;
        rm69)
            toolchain_dir="$RC_DIR"
            echo "INFO: Toolchain: RastaMod69 Clang"
            ;;
        lolz)
            toolchain_dir="$LZ_DIR"
            echo "INFO: Toolchain: Lolz Clang"
            ;;
        greenforce)
            toolchain_dir="$GC_DIR"
            echo "INFO: Toolchain: Greenforce Clang"
            ;;
        zyc)
            toolchain_dir="$ZC_DIR"
            echo "INFO: Toolchain: ZyC Clang"
            ;;
        custom)
            toolchain_dir="$CUST_DIR"
            echo "INFO: Toolchain: Custom toolchain"
            ;;
        rv)
            toolchain_dir="$RV_DIR"
            echo "INFO: Toolchain: RvClang"
            ;;
        *)
            echo -e "\nERROR: Unknown toolchain type: $toolchain_type"
            exit 1
            ;;
    esac

    export PATH="${toolchain_dir}/bin:${PATH}"
    if [[ "$USE_GCC_BINUTILS" == "1" ]]; then
        export PATH="${GCC64_DIR}/bin:${GCC_DIR}/bin:${PATH}"
    fi
    KBUILD_COMPILER_STRING=$("$toolchain_dir/bin/clang" -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')
    export KBUILD_COMPILER_STRING

    if [[ "$USE_GCC_BINUTILS" == "1" ]]; then
        CCARM64_PREFIX="aarch64-linux-androideabi-"
        CCARM_PREFIX="arm-linux-androideabi-"
    else
        CCARM64_PREFIX="aarch64-linux-gnu-"
        CCARM_PREFIX="arm-linux-gnueabi-"
    fi
}

## Pre-build dependencies
install_deps_deb
get_toolchain "$CLANG_TYPE"
prep_toolchain "$CLANG_TYPE"
TC_INFO=$(clang --version | head -n 1)
LLVM_INFO=$(llvm-config --version | head -n 1)g
PHONE="Redmi Note 8/8T"

## Telegram info variables

CAPTION_BUILD="Build info:
*Device*: \`${DEVICE} [${CODENAME}]\`
*Kernel Version*: \`${LINUX_VER}\`
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Build host*: \`${BUILD_HOST}\`
*Commit / Branch*: [($(git rev-parse HEAD | cut -c -7))]($(echo $KERNEL_URL)/commit/$(git rev-parse HEAD)) / \`$(git rev-parse --abbrev-ref HEAD)\`
*Build variant*: \`${CK_TYPE}\` / \`${BUILD_TYPE}$( [ "$DO_CLEAN" -eq 1 ] && echo " (clean)" || echo " (dirty)")\`
*Timestamp*: \`${DATE}\`
"

# Functions to send file(s) via Telegram's BOT api.
tgs() {
    MD5=$(md5sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"${ZIP_PATH}" https://api.telegram.org/bot7868194496:AAGY7WwRRbeCOPYOnczoCPh2psC43Q0F3JI/sendDocument \
        -F chat_id=-1002287610863" \
        -F parse_mode=Markdown" \
        -F caption="Build info:
📱 Device : ${PHONE}
📦 Kernel Name : ${KERNEL_NAME}
🍃 Kernel Version : ${LINUX_VER}

🔧 Toolchain : ${TC_INFO}
⚙️ Llvm Version : ${LLVM_VERSION}

💻 Build host: ${BUILD_HOST}
🛠️ Build variant: ${CK_TYPE}

⌛ Build Time : ${BUILD_TIME}
🕒 Build Date : ${BUILD_DATETIME}
"
}

prep_build() {
    ## Prepare ccache
    if [[ "$USE_CCACHE" == "1" ]]; then
        echo "INFO: ccache enabled"
        if [[ "$IS_GP" == "1" ]]; then
            export CCACHE_DIR="$WP/.ccache"
            ccache -M 10G
        else
            echo "WARNING: Environment is not Gitpod, please make sure you setup your own ccache configuration!"
        fi
    fi

    # Show compiler information
    echo -e "INFO: Compiler: $KBUILD_COMPILER_STRING\n"
}

build() {
    mkdir -p out
    if [[ "$DO_REGEN" = "1" ]]; then
        if [[ "$DO_KSU" = "1" ]] || [[ "$DO_SUKI" = "1" ]]; then
             echo "ERROR: Can't regenerate with KSU or ReSukiSU argument"
             exit 1
        
