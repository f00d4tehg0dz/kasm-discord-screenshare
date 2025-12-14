#!/usr/bin/env bash
### every exit != 0 fails the script
set -e

COMMIT_ID="a69c61013e4c3f9600099cf940a33cab3e21f795"
BRANCH="develop"
COMMIT_ID_SHORT=$(echo "${COMMIT_ID}" | cut -c1-6)

ARCH=$(arch | sed 's/aarch64/arm64/g' | sed 's/x86_64/amd64/g')
mkdir -p $STARTUPDIR/gamepad
wget -qO- https://kasmweb-build-artifacts.s3.amazonaws.com/kasm_gamepad_server/${COMMIT_ID}/kasm_gamepad_server_${ARCH}_${BRANCH}.${COMMIT_ID_SHORT}.tar.gz | tar -xvz -C $STARTUPDIR/gamepad/

SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPT_PATH="$(realpath $SCRIPT_PATH)"

mkdir -p /usr/share/extra/icons/
cp ${SCRIPT_PATH}/gamepad.svg /usr/share/extra/icons/gamepad.svg
echo "${BRANCH}:${COMMIT_ID}" > $STARTUPDIR/gamepad/kasm_gamepad_server.version
