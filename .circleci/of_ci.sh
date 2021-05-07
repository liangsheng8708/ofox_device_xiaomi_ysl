#!/bin/bash
#
# Copyright (C) 2020 ItsVixano
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# TWRP Compiler for ci/cd services by @itsVixano (pru af)
# Modified for OrangeFox by @immat0x1

# User DIR
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

# Colors
yellow='\033[0;33m'
white='\033[0m'
red='\033[0;31m'
green='\e[0;32m'

# Telegram variables
CHATID="$chat"
BOT_TOKEN="$token"

# Device/Codename variables
VENDOR="xiaomi"
DEVICE="Redmi S2/Y2"
CODENAME="ysl"

# DT variables
DEVICE_BRANCH="$dt_branch"
DEVICE_TREE="https://github.com/immat0x1/ofox_device_xiaomi_ysl"

# Manifest branch
OF_MANIFEST="fox_9.0"

# Telegram Vars, Functions
export BOT_MSG_URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$BOT_TOKEN/sendDocument"

tg_post_msg() {
        curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
        -d "parse_mode=html" \
        -d text="$1"
}

tg_post_build() {
        #Post MD5Checksum alongwith for easeness
        MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

        #Show the Checksum alongwith caption
        curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$2" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$3 <b>Build time: </b><code>$(($Diff / 60)):$(($Diff % 60))</code>
<b>MD5 Checksum: </b><code>$MD5CHECK</code>
<b>Version: </b><code>$FOX_VERSION</code>
<b>Build Type: </b><code>$FOX_BUILD_TYPE</code>"
}

tg_error() {
        curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$2" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$3Failed to build OrangeFox-$FOX_VERSION-$FOX_BUILD_TYPE, check <code>error.log</code>"
}

# Preparing build env
build_of() {
Start=$(date +"%s")
. build/envsetup.sh && lunch omni_"$CODENAME"-eng
export FOX_VERSION="$of_version"
export FOX_BUILD_TYPE="$build_type"
mka -j16 recoveryimage | tee error.log
End=$(date +"%s")
Diff=$(($End - $Start))
}

# Syncing OF-repo
cd $MY_DIR
mkdir ofox && cd ofox
tg_post_msg "Syncing OrangeFox Repo..." "$CHATID"
repo init -u https://gitlab.com/OrangeFox/Manifest.git -b "$OF_MANIFEST"
repo sync -j10 --force-sync

# Clone DT
git clone "$DEVICE_TREE" -b "$DEVICE_BRANCH" device/"$VENDOR"/"$CODENAME"

# Build
tg_post_msg "Building OrangeFox for $DEVICE ($CODENAME)..." "$CHATID"
build_of || error=true
DATE=$(date +"%Y%m%d-%H%M%S")

export IMG="$MY_DIR"/ofox/out/target/product/"$CODENAME"/recovery.img

# Upload
if [ -f "$IMG" ]; then
		echo -e "$green << Build completed in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds >> \n $white"
		export OF_PATH="$MY_DIR"/ofox/out/target/product/"$CODENAME"
		mkdir upload
		mv "$OF_PATH"/OrangeFox*.zip upload
		cd upload
		tg_post_build *.zip "$CHATID"
		exit
else
		echo -e "$red << Failed to compile OrangeFox, Check up error.log >>$white"
		tg_error "error.log" "$CHATID"
		rm -rf out
		rm -rf error.log
		exit 1
fi

