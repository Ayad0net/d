#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  install_flutter_all_os.sh
#  Cross‑platform Flutter environment setup (macOS / Linux / Windows Git Bash)
#  Requirements: bash, curl, git, unzip
# ---------------------------------------------------------------------------
set -eo pipefail

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

# ---------- Check prerequisites ----------
for cmd in curl git unzip; do
    if ! command_exists "$cmd"; then
        echo "❌ '$cmd' is required but not found. Please install it and re‑run."
        exit 1
    fi
done

# ---------- 1. Install Java 17 ----------
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
            # Attempt winget / chocolatey / direct download
            if command_exists winget; then
                echo "Using winget to install Eclipse Temurin JDK 17..."
                winget install EclipseAdoptium.Temurin.17.JDK --silent --accept-source-agreements
            elif command_exists choco; then
                echo "Using Chocolatey to install Temurin JDK 17..."
                choco install temurin17 -y
            else
                echo "Downloading Eclipse Temurin JDK 17 installer..."
                jdk_url="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.12%2B7/OpenJDK17U-jdk_x64_windows_hotspot_17.0.12_7.msi"
                installer="$TEMP/jdk17.msi"
                curl -L "$jdk_url" -o "$installer"
                echo "Running installer (admin privileges required)..."
                msiexec //i "$installer" //quiet //norestart
                rm -f "$installer"
            fi
            ;;
    esac

    # Verify Java
    if ! command_exists java; then
        echo "❌ Java installation failed. Please install Java 17 manually."
        exit 1
    fi
}
install_java

# Set JAVA_HOME
if [[ "$os_name" == "macOS" ]]; then
    export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
elif [[ "$os_name" == "Windows" ]]; then
    # On Windows, find Java home from registry or program files
    javapath="$(cmd //c "where java" 2>/dev/null | head -1 || true)"
    if [[ -n "$javapath" ]]; then
        # Convert from e.g. C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot\bin\java.exe
        javapath="$(cygpath -u "$javapath")"
        export JAVA_HOME="$(dirname "$(dirname "$javapath")")"
    else
        # fallback
        export JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-17.0.12.7-hotspot"
    fi
else
    # Linux: use readlink
    java_bin="$(readlink -f "$(command -v java)")"
    export JAVA_HOME="$(dirname "$(dirname "$java_bin")")"
fi
echo "JAVA_HOME set to: $JAVA_HOME"

# ---------- 2. Install Flutter SDK ----------
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
    echo "Flutter installed at $FLUTTER_DIR"
}
install_flutter

# ---------- 3. Android Command‑line Tools ----------
ANDROID_SDK_ROOT="$HOME/android-sdk"
CMD_TOOLS_DIR="$ANDROID_SDK_ROOT/cmdline-tools/latest"
if [[ ! -f "$CMD_TOOLS_DIR/bin/sdkmanager" ]]; then
    echo "📥 Downloading Android command‑line tools..."
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
    case "$os_name" in
        macOS)     tools_url="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip" ;;
        Linux)     tools_url="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" ;;
        Windows)   tools_url="https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" ;;
    esac
    zip="$TEMP/cmdline-tools.zip"
    curl -L "$tools_url" -o "$zip"
    unzip -qo "$zip" -d "$ANDROID_SDK_ROOT/cmdline-tools"
    mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$CMD_TOOLS_DIR"
    rm -f "$zip"
fi
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export PATH="$CMD_TOOLS_DIR/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

# ---------- 4. Accept licences & install SDK packages ----------
echo "📜 Accepting Android licences..."
yes | "$CMD_TOOLS_DIR/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true

echo "📥 Installing Android SDK packages (platform‑tools, platform, build‑tools, emulator)..."
"$CMD_TOOLS_DIR/bin/sdkmanager" --update >/dev/null 2>&1 || true
"$CMD_TOOLS_DIR/bin/sdkmanager" \
    "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator" >/dev/null 2>&1 || true

# ---------- 5. Permanent environment setup ----------
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
        # Permanent system/user variables using setx
        function win_setx {
            local var="$1" val="$2"
            # Convert Unix path to Windows
            local winval
            winval=$(cygpath -w "$val")
            cmd //c "setx $var \"$winval\"" >/dev/null 2>&1 || true
        }
        win_setx JAVA_HOME "$JAVA_HOME"
        win_setx ANDROID_HOME "$ANDROID_SDK_ROOT"
        win_setx ANDROID_SDK_ROOT "$ANDROID_SDK_ROOT"
        # Add to user PATH (using PowerShell for reliability)
        powershell -Command \
            "[Environment]::SetEnvironmentVariable('Path', \
            [Environment]::GetEnvironmentVariable('Path', 'User') + ';$HOME\flutter\bin;$ANDROID_SDK_ROOT\cmdline-tools\latest\bin;$ANDROID_SDK_ROOT\platform-tools', \
            'User')" >/dev/null 2>&1 || true
        ;;
esac

# ---------- 6. Final check ----------
echo ""
echo "🚀 Running flutter doctor..."
flutter doctor -v

echo ""
echo "🎉 Setup complete!"
if [[ "$os_name" == "Windows" ]]; then
    echo "⚠️  Please close and reopen Git Bash to apply the new environment variables."
else
    echo "⚠️  Restart your terminal or run: source $profile_file"
fi
