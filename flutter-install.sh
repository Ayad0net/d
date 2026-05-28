#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  install_flutter_all_os.sh
#  Cross‑platform Flutter setup (macOS / Linux / Windows Git Bash)
#  Shows banner, installs everything, and always prints an avdmanager cheatsheet.
# ---------------------------------------------------------------------------
set -eo pipefail   # exit on error, but we handle flutter doctor safely

# ---------- Banner ----------
show_banner() {
    echo -e "\033[1;36m"
    cat << "EOF"
    ███████╗██╗     ██╗   ██╗████████╗████████╗███████╗██████╗
    ██╔════╝██║     ██║   ██║╚══██╔══╝╚══██╔══╝██╔════╝██╔══██╗
    █████╗  ██║     ██║   ██║   ██║      ██║   █████╗  ██████╔╝
    ██╔══╝  ██║     ██║   ██║   ██║      ██║   ██╔══╝  ██╔══██╗
    ██║     ███████╗╚██████╔╝   ██║      ██║   ███████╗██║  ██║
    ╚═╝     ╚══════╝ ╚═════╝    ╚═╝      ╚═╝   ╚══════╝╚═╝  ╚═╝
EOF
    echo -e "\033[0m"
    echo -e "\033[1;33m   Flutter Development Environment Setup\033[0m"
    echo ""
}

show_banner
sleep 1

# ---------- helpers ----------
command_exists() { command -v "$1" &>/dev/null; }

os="$(uname -s)"
os_name=""
case "$os" in
    Darwin)  os_name="macOS" ;;
    Linux)   os_name="Linux" ;;
    MINGW*|MSYS*) os_name="Windows" ;;
    *)       echo "❌ Unsupported OS: $os"; exit 1 ;;
esac
echo "🖥️  Detected OS: $os_name"

# ---------- Temporary directory ----------
if [[ -z "$TMPDIR" && "$os_name" != "Windows" ]]; then
    export TMPDIR="/tmp"
fi
if [[ "$os_name" == "Windows" ]]; then
    TMP_DIR="${TEMP:-/tmp}"
else
    TMP_DIR="${TMPDIR:-/tmp}"
fi
echo "📁 Temporary files: $TMP_DIR"

# ---------- Prerequisites ----------
for cmd in curl git unzip; do
    if ! command_exists "$cmd"; then
        echo "❌ '$cmd' is required but not found. Please install it and re‑run."
        exit 1
    fi
done

# ---------- 1. Java 17 ----------
install_java() {
    echo "☕ Checking Java 17..."
    if command_exists java && java -version 2>&1 | grep -q 'version "17'; then
        echo "✅ Java 17 already available."
        return
    fi

    case "$os_name" in
        macOS)
            if ! command_exists brew; then
                echo "🍺 Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
            fi
            brew install openjdk@17
            sudo ln -sfn "$(brew --prefix openjdk@17)/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk-17.jdk
            ;;
        Linux)
            if command_exists apt-get; then
                sudo apt-get update -qq
                sudo apt-get install -y openjdk-17-jdk
            elif command_exists dnf; then
                sudo dnf install -y java-17-openjdk
            else
                echo "❌ Unsupported Linux package manager. Install OpenJDK 17 manually."
                exit 1
            fi
            ;;
        Windows)
            if command_exists winget; then
                winget install EclipseAdoptium.Temurin.17.JDK --silent --accept-source-agreements
            elif command_exists choco; then
                choco install temurin17 -y
            else
                jdk_url="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.12%2B7/OpenJDK17U-jdk_x64_windows_hotspot_17.0.12_7.msi"
                installer="$TMP_DIR/jdk17.msi"
                curl -L "$jdk_url" -o "$installer"
                msiexec //i "$installer" //quiet //norestart
                rm -f "$installer"
            fi
            ;;
    esac

    if ! command_exists java; then
        echo "❌ Java installation failed."
        exit 1
    fi
}
install_java

# Set JAVA_HOME
if [[ "$os_name" == "macOS" ]]; then
    export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
elif [[ "$os_name" == "Windows" ]]; then
    javapath="$(cmd //c "where java" 2>/dev/null | head -1 || true)"
    if [[ -n "$javapath" ]]; then
        javapath="$(cygpath -u "$javapath")"
        export JAVA_HOME="$(dirname "$(dirname "$javapath")")"
    else
        export JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-17.0.12.7-hotspot"
    fi
else
    java_bin="$(readlink -f "$(command -v java)")"
    export JAVA_HOME="$(dirname "$(dirname "$java_bin")")"
fi
echo "JAVA_HOME set to: $JAVA_HOME"

# ---------- 2. Flutter SDK ----------
install_flutter() {
    if command_exists flutter; then
        echo "✅ Flutter already in PATH."
        return
    fi
    FLUTTER_DIR="$HOME/flutter"
    if [[ ! -d "$FLUTTER_DIR" ]]; then
        echo "📥 Downloading Flutter SDK (stable)..."
        git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
    fi
    export PATH="$FLUTTER_DIR/bin:$PATH"
}
install_flutter

# ---------- 3. Android command‑line tools ----------
ANDROID_SDK_ROOT="$HOME/android-sdk"
CMD_TOOLS_DIR="$ANDROID_SDK_ROOT/cmdline-tools/latest"
if [[ ! -f "$CMD_TOOLS_DIR/bin/sdkmanager" ]]; then
    echo "📥 Downloading Android command‑line tools..."
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
    case "$os_name" in
        macOS)   tools_url="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip" ;;
        Linux)   tools_url="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" ;;
        Windows) tools_url="https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" ;;
    esac
    zip="$TMP_DIR/cmdline-tools.zip"
    curl -L "$tools_url" -o "$zip"
    unzip -qo "$zip" -d "$ANDROID_SDK_ROOT/cmdline-tools"
    mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$CMD_TOOLS_DIR"
    rm -f "$zip"
fi
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export PATH="$CMD_TOOLS_DIR/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

# ---------- 4. Licences & SDK packages ----------
echo "📜 Accepting Android licences..."
yes | "$CMD_TOOLS_DIR/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true

echo "📥 Installing Android SDK packages..."
"$CMD_TOOLS_DIR/bin/sdkmanager" --update >/dev/null 2>&1 || true
"$CMD_TOOLS_DIR/bin/sdkmanager" \
    "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator" >/dev/null 2>&1 || true

# ---------- 5. Persistent environment ----------
add_to_path_unless_present() {
    local file="$1" entry="$2"
    if [[ -f "$file" ]] && ! grep -qF "$entry" "$file" 2>/dev/null; then
        echo "$entry" >> "$file"
    fi
}

case "$os_name" in
    macOS|Linux)
        profile_file="$HOME/.bashrc"
        [[ "$SHELL" =~ zsh ]] && profile_file="$HOME/.zshrc"
        if [[ "$os_name" == "Linux" ]]; then
            profile_file="$HOME/.profile"
            [[ -f "$HOME/.bashrc" ]] && profile_file="$HOME/.bashrc"
        fi
        add_to_path_unless_present "$profile_file" "export JAVA_HOME=\"$JAVA_HOME\""
        add_to_path_unless_present "$profile_file" "export ANDROID_HOME=\"$ANDROID_SDK_ROOT\""
        add_to_path_unless_present "$profile_file" "export ANDROID_SDK_ROOT=\"$ANDROID_SDK_ROOT\""
        add_to_path_unless_present "$profile_file" "export PATH=\"\$HOME/flutter/bin:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH\""
        ;;
    Windows)
        win_setx() {
            local var="$1" val="$2"
            local winval="$(cygpath -w "$val")"
            cmd //c "setx $var \"$winval\"" >/dev/null 2>&1 || true
        }
        win_setx JAVA_HOME "$JAVA_HOME"
        win_setx ANDROID_HOME "$ANDROID_SDK_ROOT"
        win_setx ANDROID_SDK_ROOT "$ANDROID_SDK_ROOT"
        powershell -Command \
            "[Environment]::SetEnvironmentVariable('Path', \
             [Environment]::GetEnvironmentVariable('Path', 'User') + ';$HOME\flutter\bin;$ANDROID_SDK_ROOT\cmdline-tools\latest\bin;$ANDROID_SDK_ROOT\platform-tools', \
             'User')" >/dev/null 2>&1 || true
        ;;
esac

# ---------- 6. Run flutter doctor (DO NOT EXIT ON FAIL) ----------
echo ""
echo "🚀 Running flutter doctor (warnings are normal)..."
flutter doctor -v || true   # <--- continue even if doctor reports issues

# ---------- 7. AVD Manager Cheat Sheet (always printed) ----------
echo ""
echo -e "\033[1;36m╔════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;36m║   AVD Manager Cheat Sheet (Android Emulators)  ║\033[0m"
echo -e "\033[1;36m╚════════════════════════════════════════════════╝\033[0m"
echo ""
echo -e "\033[1;33mCommon avdmanager commands:\033[0m"
echo "  avdmanager list avd            – List existing AVDs"
echo "  avdmanager list target         – List available system images"
echo "  avdmanager list device         – List device definitions"
echo "  avdmanager create avd          – Create a new AVD (example below)"
echo "  avdmanager delete avd -n <name>   – Delete an AVD"
echo ""
echo -e "\033[1;33mCreating a new AVD (example):\033[0m"
echo "  avdmanager create avd -n Pixel_5_API_34 \\"
echo "    -k \"system-images;android-34;google_apis;x86_64\" \\"
echo "    -d pixel_5"
echo ""
echo -e "\033[1;33mLaunching emulators from the command line:\033[0m"
echo "  emulator -avd <avd_name>       – Start an AVD"
echo "  emulator -avd <avd_name> -no-snapshot-load   – Cold boot"
echo ""
echo -e "\033[1;33mFlutter emulator commands:\033[0m"
echo "  flutter emulators              – List configured emulators"
echo "  flutter emulators --launch <id>   – Start an emulator"
echo "  flutter emulators --create [name] – Create a new emulator"
echo ""
echo -e "\033[1;33mAdding system images:\033[0m"
echo "  sdkmanager \"system-images;android-34;google_apis;x86_64\""
echo ""
echo "More info: https://developer.android.com/studio/run/managing-avds"

echo ""
echo "🎉 Setup complete!"
if [[ "$os_name" == "Windows" ]]; then
    echo "⚠️  Close and reopen Git Bash to apply new environment variables."
else
    echo "⚠️  Restart your terminal or run: source $profile_file"
fi
