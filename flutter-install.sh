#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  flutter-cli.sh
#  Flutter Development Environment CLI Tool
#  Version: 1.2.0
# ---------------------------------------------------------------------------
set -eo pipefail

# Version
CLI_VERSION="1.2.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ---------- Banner ----------
show_banner() {
    printf "${CYAN}"
    cat << "EOF"
    ███████╗██╗     ██╗   ██╗████████╗████████╗███████╗██████╗
    ██╔════╝██║     ██║   ██║╚══██╔══╝╚══██╔══╝██╔════╝██╔══██╗
    █████╗  ██║     ██║   ██║   ██║      ██║   █████╗  ██████╔╝
    ██╔══╝  ██║     ██║   ██║   ██║      ██║   ██╔══╝  ██╔══██╗
    ██║     ███████╗╚██████╔╝   ██║      ██║   ███████╗██║  ██║
    ╚═╝     ╚══════╝ ╚═════╝    ╚═╝      ╚═╝   ╚══════╝╚═╝  ╚═╝
EOF
    printf "${RESET}"
    printf "${YELLOW}   Flutter Development Environment CLI${RESET}\n"
    printf "${BLUE}   Version: ${CLI_VERSION}${RESET}\n\n"
}

# ---------- Help ----------
show_help() {
    cat << "EOF"
Usage: flutter-cli [COMMAND] [OPTIONS]
        flutter-cli              (starts interactive menu by default)

Commands:
  menu|m               Select commands with keyboard checkboxes (default)
  install              Install Flutter and Android SDK
  uninstall            Uninstall Flutter and cleanup
  emulator create      Create a new Android emulator
  emulator list        List all emulators
  emulator delete      Delete an emulator
  doctor               Run Flutter doctor
  version              Show CLI version
  help                 Show this help message

Examples:
  flutter-cli          (starts menu by default)
  flutter-cli menu
  flutter-cli install
  flutter-cli emulator create -n Pixel_5_API_34 -k "system-images;android-34;google_apis;x86_64"
  flutter-cli emulator list
  flutter-cli emulator delete -n Pixel_5_API_34

EOF
}

# ---------- Helpers ----------
command_exists() { 
    command -v "$1" &>/dev/null
}

detect_os() {
    local os="$(uname -s)"
    case "$os" in
        Darwin)  echo "macOS" ;;
        Linux)   echo "Linux" ;;
        MINGW*|MSYS*) echo "Windows" ;;
        *)       echo "Unknown" ;;
    esac
}

show_success() {
    printf "${GREEN}✅ $1${RESET}\n"
}

show_error() {
    printf "${RED}❌ $1${RESET}\n"
}

show_warning() {
    printf "${YELLOW}⚠️  $1${RESET}\n"
}

show_info() {
    printf "${BLUE}ℹ️  $1${RESET}\n"
}

# ---------- List Available System Images ----------
list_system_images() {
    if ! command_exists sdkmanager; then
        show_error "sdkmanager not found. Please run 'flutter-cli install' first."
        return 1
    fi
    
    show_info "Fetching available system images..."
    
    # Get list of available images
    local images=($(sdkmanager --list 2>/dev/null | grep "system-images" | awk '{print $1}' | sort -u))
    
    if [[ ${#images[@]} -eq 0 ]]; then
        show_error "No system images found"
        return 1
    fi
    
    printf "${BLUE}Available System Images:${RESET}\n"
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    local i
    for i in "${!images[@]}"; do
        printf "  $(printf "%2d" $((i+1))). ${images[$i]}\n"
    done
    
    printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    printf "${YELLOW}Select image number: ${RESET}"
    read -r img_choice
    
    if [[ ! "$img_choice" =~ ^[0-9]+$ ]] || [[ $img_choice -lt 1 ]] || [[ $img_choice -gt ${#images[@]} ]]; then
        show_error "Invalid selection"
        return 1
    fi
    
    selected_image="${images[$((img_choice-1))]}"
    echo "$selected_image"
}

# ---------- Checkbox Menu Selection ----------
checkbox_menu() {
    local -a options=(
        "install"
        "uninstall"
        "doctor"
        "emulator list"
        "emulator create"
        "emulator delete"
        "exit"
    )
    
    local -a descriptions=(
        "Install Flutter and Android SDK"
        "Uninstall Flutter"
        "Run Flutter doctor"
        "List all emulators"
        "Create a new emulator"
        "Delete an emulator"
        "Exit menu"
    )
    
    local current=0
    local maxitems=${#options[@]}
    
    # Show initial menu
    display_menu() {
        clear
        show_banner
        echo ""
        printf "${BLUE}Select a command:${RESET}\n"
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        
        for i in "${!options[@]}"; do
            if [[ $i -eq $current ]]; then
                printf "${CYAN}➜ $(printf "%2d" $((i+1))). ☑ ${options[$i]} - ${descriptions[$i]}${RESET}\n"
            else
                printf "  $(printf "%2d" $((i+1))). ☐ ${options[$i]} - ${descriptions[$i]}\n"
            fi
        done
        
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        printf "${YELLOW}Use ↑↓ arrows or type number${RESET} | ${YELLOW}SPACE${RESET} to confirm | ${YELLOW}ENTER${RESET} to execute | ${YELLOW}Q${RESET} to quit\n"
    }
    
    display_menu
    
    # Put terminal in raw mode
    local original_tty=$(stty -g 2>/dev/null)
    trap "stty '$original_tty' 2>/dev/null" EXIT
    
    while IFS= read -rsn 1 key; do
        case "$key" in
            # Arrow key sequences
            $'\x1b')
                read -rsn 2 arrow
                case "$arrow" in
                    '[A')  # Up arrow
                        ((current--))
                        [[ $current -lt 0 ]] && current=$((maxitems - 1))
                        display_menu
                        ;;
                    '[B')  # Down arrow
                        ((current++))
                        [[ $current -ge $maxitems ]] && current=0
                        display_menu
                        ;;
                esac
                ;;
            # Number keys 1-7
            [1-7])
                idx=$((key - 1))
                if [[ $idx -lt $maxitems ]]; then
                    current=$idx
                    display_menu
                fi
                ;;
            # Space - confirm selection (just keeps it highlighted)
            ' ')
                display_menu
                ;;
            # Enter - execute selected command
            '')
                stty "$original_tty" 2>/dev/null
                cmd="${options[$current]}"
                
                if [[ "$cmd" == "exit" ]]; then
                    clear
                    show_info "Exiting menu"
                    return
                fi
                
                clear
                show_banner
                show_info "Executing: ${BOLD}${cmd}${RESET}\n"
                
                case "$cmd" in
                    doctor)
                        flutter doctor -v || show_warning "Flutter not installed"
                        ;;
                    "emulator list")
                        show_info "Available emulators:\n"
                        if command_exists flutter; then
                            flutter emulators 2>/dev/null || show_error "No emulators found"
                        elif command_exists avdmanager; then
                            avdmanager list avd 2>/dev/null || show_error "No emulators found"
                        else
                            show_error "Flutter or avdmanager not found"
                        fi
                        ;;
                    "emulator create")
                        printf "${YELLOW}Enter emulator name (e.g., Pixel_5_API_34): ${RESET}"
                        read -r emu_name
                        if [[ -z "$emu_name" ]]; then
                            show_error "Emulator name cannot be empty"
                        else
                            echo ""
                            emu_kernel=$(list_system_images)
                            
                            if [[ -z "$emu_kernel" ]]; then
                                show_error "No system image selected"
                            else
                                printf "${YELLOW}Enter device type (default: pixel_5): ${RESET}"
                                read -r emu_device
                                [[ -z "$emu_device" ]] && emu_device="pixel_5"
                                
                                show_info "Creating emulator: $emu_name with kernel $emu_kernel on device $emu_device\n"
                                
                                if ! command_exists avdmanager; then
                                    show_error "avdmanager not found. Please run 'flutter-cli install' first."
                                else
                                    show_info "Installing system image..."
                                    sdkmanager "$emu_kernel" >/dev/null 2>&1 || true
                                    
                                    show_info "Creating AVD...\n"
                                    avdmanager create avd -n "$emu_name" -k "$emu_kernel" -d "$emu_device" --force >/dev/null 2>&1
                                    
                                    if [[ $? -eq 0 ]]; then
                                        show_success "Emulator '$emu_name' created successfully"
                                    else
                                        show_error "Failed to create emulator"
                                    fi
                                fi
                            fi
                        fi
                        ;;
                    "emulator delete")
                        printf "${YELLOW}Enter emulator name to delete: ${RESET}"
                        read -r emu_name
                        if [[ -z "$emu_name" ]]; then
                            show_error "Emulator name cannot be empty"
                        else
                            show_warning "About to delete emulator: $emu_name"
                            printf "${YELLOW}Are you sure? (y/n): ${RESET}"
                            read -r confirm
                            
                            confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
                            if [[ "$confirm" != "y" ]] && [[ "$confirm" != "yes" ]]; then
                                show_info "Delete cancelled"
                            else
                                if ! command_exists avdmanager; then
                                    show_error "avdmanager not found. Please run 'flutter-cli install' first."
                                else
                                    avdmanager delete avd -n "$emu_name" >/dev/null 2>&1
                                    if [[ $? -eq 0 ]]; then
                                        show_success "Emulator '$emu_name' deleted"
                                    else
                                        show_error "Failed to delete emulator"
                                    fi
                                fi
                            fi
                        fi
                        ;;
                    install)
                        cmd_install
                        ;;
                    uninstall)
                        cmd_uninstall
                        ;;
                    *)
                        show_warning "This command needs additional parameters. Use: flutter-cli interactive"
                        ;;
                esac
                
                echo ""
                read -p "Press ENTER to return to menu..."
                display_menu
                ;;
            # Quit
            q|Q)
                stty "$original_tty" 2>/dev/null
                clear
                show_info "Exiting menu"
                return
                ;;
        esac
    done
}

# ---------- Version Command ----------
cmd_version() {
    show_banner
    printf "CLI Version: ${BOLD}${CLI_VERSION}${RESET}\n"
}

# ---------- Install Flutter ----------
cmd_install() {
    show_banner
    
    OS=$(detect_os)
    show_info "Detected OS: $OS"
    
    if [[ "$OS" == "Unknown" ]]; then
        show_error "Unsupported OS"
        exit 1
    fi
    
    # Check prerequisites
    show_info "Checking prerequisites..."
    for cmd in curl git unzip; do
        if ! command_exists "$cmd"; then
            show_error "'$cmd' is required but not found. Please install it and retry."
            exit 1
        fi
    done
    show_success "All prerequisites available"
    
    # Install Java 17
    install_java_17
    
    # Install Flutter
    install_flutter_sdk
    
    # Install Android SDK
    install_android_sdk
    
    # Accept licenses
    accept_android_licenses
    
    # Setup environment
    setup_environment_vars "$OS"
    
    show_success "Flutter installation complete!"
    show_info "Run 'flutter doctor' to verify setup"
    show_warning "Restart your terminal or source your shell profile to apply environment variables"
}

install_java_17() {
    show_info "Setting up Java 17..."
    
    if command_exists java && java -version 2>&1 | grep -q 'version "17'; then
        show_success "Java 17 already installed"
        return
    fi
    
    OS=$(detect_os)
    case "$OS" in
        macOS)
            if ! command_exists brew; then
                show_info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
            fi
            brew install openjdk@17 >/dev/null 2>&1 || true
            sudo ln -sfn "$(brew --prefix openjdk@17)/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk-17.jdk 2>/dev/null || true
            show_success "Java 17 installed via Homebrew"
            ;;
        Linux)
            if command_exists apt-get; then
                sudo apt-get update -qq >/dev/null 2>&1
                sudo apt-get install -y openjdk-17-jdk >/dev/null 2>&1
            elif command_exists dnf; then
                sudo dnf install -y java-17-openjdk >/dev/null 2>&1
            else
                show_error "Unsupported Linux package manager. Install OpenJDK 17 manually."
                exit 1
            fi
            show_success "Java 17 installed"
            ;;
        Windows)
            if command_exists winget; then
                winget install EclipseAdoptium.Temurin.17.JDK --silent --accept-source-agreements 2>/dev/null || true
            elif command_exists choco; then
                choco install temurin17 -y >/dev/null 2>&1 || true
            else
                show_warning "Please install Java 17 manually from https://adoptium.net/"
            fi
            show_success "Java 17 setup initiated"
            ;;
    esac
}

install_flutter_sdk() {
    show_info "Installing Flutter SDK..."
    
    if command_exists flutter; then
        show_success "Flutter already in PATH"
        return
    fi
    
    FLUTTER_DIR="$HOME/flutter"
    if [[ -d "$FLUTTER_DIR" ]]; then
        show_success "Flutter already downloaded at $FLUTTER_DIR"
    else
        show_info "Cloning Flutter stable branch..."
        git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR" --quiet
        show_success "Flutter SDK installed"
    fi
    
    export PATH="$FLUTTER_DIR/bin:$PATH"
}

install_android_sdk() {
    show_info "Installing Android SDK..."
    
    ANDROID_SDK_ROOT="$HOME/android-sdk"
    CMD_TOOLS_DIR="$ANDROID_SDK_ROOT/cmdline-tools/latest"
    
    if [[ -f "$CMD_TOOLS_DIR/bin/sdkmanager" ]]; then
        show_success "Android SDK already installed"
        export ANDROID_HOME="$ANDROID_SDK_ROOT"
        export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
        export PATH="$CMD_TOOLS_DIR/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
        return
    fi
    
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
    
    OS=$(detect_os)
    case "$OS" in
        macOS)   tools_url="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip" ;;
        Linux)   tools_url="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" ;;
        Windows) tools_url="https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" ;;
    esac
    
    TMP_DIR="${TMPDIR:-/tmp}"
    zip="$TMP_DIR/cmdline-tools.zip"
    
    show_info "Downloading Android command-line tools..."
    curl -L "$tools_url" -o "$zip" --silent --show-error
    unzip -qo "$zip" -d "$ANDROID_SDK_ROOT/cmdline-tools"
    mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$CMD_TOOLS_DIR"
    rm -f "$zip"
    
    export ANDROID_HOME="$ANDROID_SDK_ROOT"
    export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
    export PATH="$CMD_TOOLS_DIR/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
    
    show_success "Android SDK installed"
}

accept_android_licenses() {
    show_info "Accepting Android licenses..."
    yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
    show_success "Licenses accepted"
}

setup_environment_vars() {
    local os="$1"
    
    show_info "Setting up environment variables..."
    
    if [[ "$os" == "macOS" ]] || [[ "$os" == "Linux" ]]; then
        profile_file="$HOME/.bashrc"
        [[ "$SHELL" =~ zsh ]] && profile_file="$HOME/.zshrc"
        
        if [[ "$os" == "Linux" ]]; then
            [[ -f "$HOME/.bashrc" ]] && profile_file="$HOME/.bashrc" || profile_file="$HOME/.profile"
        fi
        
        add_to_profile() {
            local entry="$1"
            if [[ -f "$profile_file" ]] && ! grep -qF "$entry" "$profile_file" 2>/dev/null; then
                echo "$entry" >> "$profile_file"
            fi
        }
        
        add_to_profile "export PATH=\"\$HOME/flutter/bin:\$HOME/android-sdk/cmdline-tools/latest/bin:\$HOME/android-sdk/platform-tools:\$PATH\""
        show_success "Environment variables configured in $profile_file"
    fi
}

# ---------- Uninstall Flutter ----------
cmd_uninstall() {
    show_banner
    show_warning "This will remove Flutter and Android SDK"
    printf "${YELLOW}Are you sure? (yes/no): ${RESET}"
    read -r confirm
    
    if [[ "$confirm" != "yes" ]]; then
        show_info "Uninstall cancelled"
        return
    fi
    
    OS=$(detect_os)
    
    # Remove Flutter
    if [[ -d "$HOME/flutter" ]]; then
        show_info "Removing Flutter SDK..."
        rm -rf "$HOME/flutter"
        show_success "Flutter SDK removed"
    fi
    
    # Remove Android SDK
    if [[ -d "$HOME/android-sdk" ]]; then
        show_info "Removing Android SDK..."
        rm -rf "$HOME/android-sdk"
        show_success "Android SDK removed"
    fi
    
    # Remove from shell profile
    if [[ "$OS" == "macOS" ]] || [[ "$OS" == "Linux" ]]; then
        profile_file="$HOME/.bashrc"
        [[ "$SHELL" =~ zsh ]] && profile_file="$HOME/.zshrc"
        [[ "$OS" == "Linux" ]] && [[ ! -f "$HOME/.bashrc" ]] && profile_file="$HOME/.profile"
        
        if [[ -f "$profile_file" ]]; then
            show_info "Cleaning up $profile_file..."
            grep -v "flutter\|android-sdk" "$profile_file" > "${profile_file}.tmp"
            mv "${profile_file}.tmp" "$profile_file"
            show_success "Shell profile cleaned"
        fi
    fi
    
    show_success "Flutter uninstall complete"
    show_warning "Restart your terminal to apply changes"
}

# ---------- Emulator Commands ----------
cmd_emulator() {
    local subcmd="$1"
    
    case "$subcmd" in
        create)
            shift
            cmd_emulator_create "$@"
            ;;
        list)
            cmd_emulator_list
            ;;
        delete)
            shift
            cmd_emulator_delete "$@"
            ;;
        *)
            show_error "Unknown emulator command: $subcmd"
            echo "Use: flutter-cli emulator [create|list|delete]"
            exit 1
            ;;
    esac
}

cmd_emulator_create() {
    show_banner
    
    local name="" kernel="" device_def="pixel_5"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            -k|--kernel)
                kernel="$2"
                shift 2
                ;;
            -d|--device)
                device_def="$2"
                shift 2
                ;;
            *)
                show_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$name" ]] || [[ -z "$kernel" ]]; then
        show_error "Missing required options: -n (name) and -k (kernel) are required"
        echo "Example: flutter-cli emulator create -n Pixel_5_API_34 -k \"system-images;android-34;google_apis;x86_64\" -d pixel_5"
        exit 1
    fi
    
    show_info "Creating emulator: $name"
    show_info "Kernel: $kernel"
    show_info "Device: $device_def"
    
    if ! command_exists avdmanager; then
        show_error "avdmanager not found. Please run 'flutter-cli install' first."
        exit 1
    fi
    
    # Install system image if needed
    show_info "Installing system image..."
    sdkmanager "$kernel" >/dev/null 2>&1 || true
    
    # Create AVD
    avdmanager create avd -n "$name" -k "$kernel" -d "$device_def" --force >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        show_success "Emulator '$name' created successfully"
    else
        show_error "Failed to create emulator"
        exit 1
    fi
}

cmd_emulator_list() {
    show_banner
    show_info "Available emulators:\n"
    
    if command_exists flutter; then
        flutter emulators || show_error "No emulators found or flutter not installed"
    elif command_exists avdmanager; then
        avdmanager list avd || show_error "No emulators found"
    else
        show_error "Flutter or avdmanager not found. Please run 'flutter-cli install' first."
        exit 1
    fi
}

cmd_emulator_delete() {
    show_banner
    
    local name=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift 2
                ;;
            *)
                show_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$name" ]]; then
        show_error "Missing required option: -n (name)"
        exit 1
    fi
    
    show_warning "About to delete emulator: $name"
    printf "${YELLOW}Are you sure? (yes/no): ${RESET}"
    read -r confirm
    
    if [[ "$confirm" != "yes" ]]; then
        show_info "Delete cancelled"
        return
    fi
    
    if ! command_exists avdmanager; then
        show_error "avdmanager not found. Please run 'flutter-cli install' first."
        exit 1
    fi
    
    avdmanager delete avd -n "$name" >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        show_success "Emulator '$name' deleted"
    else
        show_error "Failed to delete emulator"
        exit 1
    fi
}

# ---------- Doctor Command ----------
cmd_doctor() {
    show_banner
    show_info "Running Flutter doctor...\n"
    flutter doctor -v || show_warning "Flutter not installed. Run 'flutter-cli install'"
}

# ---------- Main ----------
main() {
    clear
    
    if [[ $# -eq 0 ]]; then
        checkbox_menu
        return 0
    fi
    
    local cmd="$1"
    shift
    
    case "$cmd" in
        install)
            cmd_install
            ;;
        uninstall)
            cmd_uninstall
            ;;
        emulator)
            cmd_emulator "$@"
            ;;
        doctor)
            cmd_doctor
            ;;
        version)
            cmd_version
            ;;
        menu|m)
            checkbox_menu
            ;;
        help|-h|--help)
            show_banner
            show_help
            ;;
        *)
            show_error "Unknown command: $cmd"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
