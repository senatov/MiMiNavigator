#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cmake_bin=/opt/homebrew/bin/cmake
if [[ ! -x "$cmake_bin" ]]; then cmake_bin=/usr/local/bin/cmake; fi
if [[ ! -x "$cmake_bin" ]]; then
    print -u2 'CMake is required to build the bundled Telegram rlottie renderer.'
    exit 1
fi
build_dir="${TARGET_TEMP_DIR}/rlottie-renderer"
"$cmake_bin" -S "$project_dir/Vendor/TelegramRlottieRenderer" -B "$build_dir" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="${ARCHS}" -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" >/dev/null
"$cmake_bin" --build "$build_dir" --target mimi-rlottie-render --parallel 4 >/dev/null
helper="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}/mimi-rlottie-render"
/bin/cp "$build_dir/mimi-rlottie-render" "$helper"
if [[ "${CODE_SIGNING_ALLOWED:-NO}" == YES && -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
    /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --options runtime --timestamp "$helper"
fi
