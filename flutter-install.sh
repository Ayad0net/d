#!/usr/bin/env bash
set -eo pipefail

command_exists() { command -v "$1" &>/dev/null; }

# Homebrew prefix
if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

# Detect shell profile
if [[ -n "$ZSH_VERSION" || "$SHELL" =~ zsh ]]; then
    PROFILE="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" || "$SHELL" =~ bash ]]; then
    PROFILE="$HOME/.bashrc"
else
    PROFILE="$HOME/.profile"
fi

echo "✅ Using profile: $PROFILE"

# 1. Install Homebrew
if ! command_exists brew; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(${BREW_PREFIX}/bin/brew shellenv)"
fi

# 2. Install all required packages
echo "📦 Installing packages..."
brew install --cask flutter android-commandlinetools
brew install openjdk@17 android-platform-tools

# 3. Create JDK symlink (requires sudo)
echo "☕ Setting up Java 17 (sudo required)..."
JDK_PATH="$($BREW_PREFIX/bin/brew --prefix openjdk@17)/libexec/openjdk.jdk"
echo "Symlinking $JDK_PATH → /Library/Java/JavaVirtualMachines/openjdk-17.jdk"
sudo ln -sfn "$JDK_PATH" /Library/Java/JavaVirtualMachines/openjdk-17.jdk

# 4. Derive JAVA_HOME dynamically
JAVA_HOME_VAL="$(/usr/libexec/java_home -v 17)"
echo "JAVA_HOME resolved to: $JAVA_HOME_VAL"

# 5. Android SDK root
ANDROID_HOME_VAL="${BREW_PREFIX}/share/android-commandlinetools"
echo "ANDROID_HOME: $ANDROID_HOME_VAL"

# 6. Update shell profile (remove any old JAVA_HOME/ANDROID lines first)
echo "✏️  Cleaning & updating $PROFILE ..."
sed -i.bak '/export JAVA_HOME=/d' "$PROFILE"
sed -i '' '/export ANDROID_HOME=/d' "$PROFILE"
sed -i '' '/export ANDROID_SDK_ROOT=/d' "$PROFILE"

{
  echo ""
  echo "# >>> Flutter / Android settings (auto-generated) <<<"
  echo "export JAVA_HOME=\$(/usr/libexec/java_home -v 17)"
  echo "export ANDROID_HOME=$ANDROID_HOME_VAL"
  echo "export ANDROID_SDK_ROOT=$ANDROID_HOME_VAL"
  echo "export PATH=\"$ANDROID_HOME_VAL/cmdline-tools/latest/bin:\$PATH\""
  echo "export PATH=\"$BREW_PREFIX/bin:\$PATH\""
} >> "$PROFILE"

# 7. Source the profile to use the new settings immediately
set +e
source "$PROFILE" 2>/dev/null
set -e

# 8. Accept licenses
echo "📜 Accepting Android licenses..."
yes | "${ANDROID_HOME_VAL}/cmdline-tools/latest/bin/sdkmanager" --licenses
yes | flutter doctor --android-licenses

# 9. Install essential SDK components
echo "📥 Downloading Android SDK platform & build tools..."
"${ANDROID_HOME_VAL}/cmdline-tools/latest/bin/sdkmanager" --update
"${ANDROID_HOME_VAL}/cmdline-tools/latest/bin/sdkmanager" \
  "platform-tools" "platforms;android-34" "build-tools;34.0.0" "emulator"

# 10. Final check
echo ""
echo "🚀 Running flutter doctor..."
flutter doctor -v

echo ""
echo "🎉 All set! Restart your terminal or run: source $PROFILE"
