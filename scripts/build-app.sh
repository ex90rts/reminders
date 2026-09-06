#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_DIR="$PROJECT_DIR/dist/清醒贴.app"
CONTENTS_DIR="$APP_DIR/Contents"
ARCHIVE_PATH="$PROJECT_DIR/dist/清醒贴-macOS15-arm64.zip"

cd "$PROJECT_DIR"

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
if [[ ! -d "$DEVELOPER_DIR" ]]; then
    print -u2 -- "Xcode developer directory not found: $DEVELOPER_DIR"
    exit 1
fi

export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/swiftpm-module-cache"
export XDG_CACHE_HOME="$PROJECT_DIR/.build/cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE" "$XDG_CACHE_HOME"

if [[ "${1:-}" == "--test" ]]; then
    shift
    xcrun swift test --disable-sandbox "$@"
    exit
fi

RELEASE_VERSION=""
while (( $# > 0 )); do
    case "$1" in
        --skip-icons)
            export SKIP_ICON_BUILD=1
            shift
            ;;
        --version)
            if (( $# < 2 )); then
                print -u2 -- "Missing value after --version"
                exit 2
            fi
            RELEASE_VERSION="$2"
            shift 2
            ;;
        *)
            print -u2 -- "Usage: ./scripts/build-app.sh [--test [swift-test-options...] | [--version x.y.z] [--skip-icons]]"
            exit 2
            ;;
    esac
done

CURRENT_RELEASE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PROJECT_DIR/Info.plist")
if [[ ! "$CURRENT_RELEASE_VERSION" == <->.<->.<-> ]]; then
    print -u2 -- "Invalid current app version '$CURRENT_RELEASE_VERSION'; expected x.y.z"
    exit 2
fi

if [[ -z "$RELEASE_VERSION" ]]; then
    CURRENT_PATCH_VERSION=${CURRENT_RELEASE_VERSION##*.}
    RELEASE_VERSION="${CURRENT_RELEASE_VERSION%.*}.$((CURRENT_PATCH_VERSION + 1))"
    print -r -- "Incrementing app version $CURRENT_RELEASE_VERSION -> $RELEASE_VERSION"
fi
if [[ ! "$RELEASE_VERSION" == <->.<->.<-> ]]; then
    print -u2 -- "Invalid app version '$RELEASE_VERSION'; expected x.y.z"
    exit 2
fi

if [[ "${SKIP_ICON_BUILD:-0}" != "1" ]]; then
    zsh "$PROJECT_DIR/scripts/build-icons.sh"
fi

SDK_VERSION=$(xcrun --sdk macosx --show-sdk-version)
MINIMUM_SYSTEM_VERSION=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$PROJECT_DIR/Info.plist")
BUILD_ARGUMENTS=(
    --configuration release
    --disable-sandbox
    -Xswiftc -gnone
    -Xlinker -platform_version
    -Xlinker macos
    -Xlinker "$MINIMUM_SYSTEM_VERSION"
    -Xlinker "$SDK_VERSION"
)

xcrun swift build "${BUILD_ARGUMENTS[@]}"
BIN_DIR=$(xcrun swift build "${BUILD_ARGUMENTS[@]}" --show-bin-path)

BUILD_VERSION=$(date +%Y%m%d%H%M%S)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $RELEASE_VERSION" "$PROJECT_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_VERSION" "$PROJECT_DIR/Info.plist"

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/Reminders" "$CONTENTS_DIR/MacOS/Reminders"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Assets/AppIcon.icns" "$CONTENTS_DIR/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Assets/MenuBarIcon.svg" "$CONTENTS_DIR/Resources/MenuBarIcon.svg"
mkdir -p "$CONTENTS_DIR/Resources/AlarmBg"
rsync -a --delete "$PROJECT_DIR/Assets/AlarmBg/" "$CONTENTS_DIR/Resources/AlarmBg/"
codesign --force --deep --sign - "$APP_DIR"
touch "$APP_DIR"

rm -f "$ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"

print -r -- "$APP_DIR"
print -r -- "$ARCHIVE_PATH"
print -r -- "Version $RELEASE_VERSION (build $BUILD_VERSION)"
