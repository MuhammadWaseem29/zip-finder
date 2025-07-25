#!/bin/bash

#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     BackupFinder Universal Installer                        ║
# ║                        Created by MuhammadWaseem                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Configuration
TOOL_NAME="backupfinder"
VERSION="2.0.0"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect installation type
if [ "$EUID" -eq 0 ]; then
    # Root installation
    INSTALL_DIR="/opt/backupfinder"
    BIN_DIR="/usr/local/bin"
    INSTALL_TYPE="system"
else
    # User installation
    INSTALL_DIR="$HOME/.local/share/backupfinder"
    BIN_DIR="$HOME/.local/bin"
    INSTALL_TYPE="user"
fi

# Print colored output
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}$message${RESET}"
}

# Show banner
show_banner() {
    print_color "$CYAN" "╔══════════════════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║                     BackupFinder Universal Installer                        ║"
    print_color "$CYAN" "║                              Version $VERSION                                ║"
    print_color "$CYAN" "║                        Created by MuhammadWaseem                            ║"
    print_color "$CYAN" "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Check and auto-install dependencies
check_requirements() {
    print_color "$BLUE" "🔍 Checking system requirements..."
    
    local required_commands=("curl" "sort" "uniq" "wc" "bash")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_color "$YELLOW" "⚠️  Missing: ${missing_commands[*]}"
        
        if [ "$INSTALL_TYPE" = "system" ]; then
            print_color "$BLUE" "🔧 Auto-installing dependencies..."
            
            if command -v apt-get &> /dev/null; then
                apt-get update -qq && apt-get install -y curl coreutils bash
            elif command -v yum &> /dev/null; then
                yum install -y curl coreutils bash
            elif command -v pacman &> /dev/null; then
                pacman -S --noconfirm curl coreutils bash
            elif command -v brew &> /dev/null; then
                brew install curl coreutils bash
            else
                print_color "$RED" "❌ Please install: ${missing_commands[*]}"
                exit 1
            fi
        else
            print_color "$YELLOW" "💡 Please install: ${missing_commands[*]}"
            exit 1
        fi
    fi
    
    print_color "$GREEN" "✅ All dependencies ready"
}

# Install everything
install_all() {
    print_color "$BLUE" "📁 Creating directories..."
    mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/assets" "$BIN_DIR"
    
    print_color "$BLUE" "📋 Installing files..."
    
    # Copy main script
    if [ -f "$CURRENT_DIR/backupfinder.sh" ]; then
        cp "$CURRENT_DIR/backupfinder.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/backupfinder.sh"
    else
        print_color "$RED" "❌ backupfinder.sh not found"
        exit 1
    fi
    
    # Copy assets
    if [ -d "$CURRENT_DIR/assets" ]; then
        cp -r "$CURRENT_DIR/assets/"* "$INSTALL_DIR/assets/"
    else
        print_color "$RED" "❌ assets directory not found"
        exit 1
    fi
    
    # Update script paths
    sed -i "s|SCRIPT_DIR=".*"|SCRIPT_DIR="$INSTALL_DIR"|g" "$INSTALL_DIR/backupfinder.sh"
    
    # Create global command
    cat > "$BIN_DIR/$TOOL_NAME" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
exec "$INSTALL_DIR/backupfinder.sh" "\$@"
EOF
    chmod +x "$BIN_DIR/$TOOL_NAME"
    
    # Create uninstaller
    cat > "$INSTALL_DIR/uninstall.sh" << EOF
#!/bin/bash
echo "Removing BackupFinder..."
rm -f "$BIN_DIR/backupfinder"
rm -rf "$INSTALL_DIR"
echo "✅ BackupFinder removed successfully"
EOF
    chmod +x "$INSTALL_DIR/uninstall.sh"
    
    print_color "$GREEN" "✅ Installation complete!"
}

# Test installation
test_install() {
    if [ "$INSTALL_TYPE" = "user" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        print_color "$YELLOW" "💡 Add to ~/.bashrc: export PATH="\$HOME/.local/bin:\$PATH""
    fi
    
    if command -v backupfinder &> /dev/null; then
        print_color "$GREEN" "✅ Test successful!"
    else
        print_color "$RED" "❌ Installation failed"
        exit 1
    fi
}

# Show completion
show_completion() {
    echo ""
    print_color "$GREEN" "🎉 BackupFinder ready!"
    echo ""
    print_color "$WHITE" "Usage: backupfinder -u example.com"
    print_color "$WHITE" "Help:  backupfinder -help"
    echo ""
    print_color "$YELLOW" "Uninstall: $INSTALL_DIR/uninstall.sh"
    echo ""
}

# Main installation
main() {
    show_banner
    
    if [ "$INSTALL_TYPE" = "system" ]; then
        print_color "$CYAN" "🔧 System-wide installation (sudo detected)"
    else
        print_color "$CYAN" "👤 User installation (no sudo)"
    fi
    echo ""
    
    check_requirements
    install_all
    test_install
    show_completion
}

# Run installer
main "$@"

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Configuration
TOOL_NAME="backupfinder"
VERSION="2.0.0"
INSTALL_DIR="/opt/backupfinder"
BIN_DIR="/usr/local/bin"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print colored output
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}$message${RESET}"
}

# Print banner
show_banner() {
    print_color "$CYAN" "╔══════════════════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║                     BackupFinder Professional Installer                     ║"
    print_color "$CYAN" "║                              Version $VERSION                                ║"
    print_color "$CYAN" "║                        Created by MuhammadWaseem                            ║"
    print_color "$CYAN" "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_color "$RED" "❌ Error: This installer must be run as root (use sudo)"
        print_color "$YELLOW" "💡 Usage: sudo ./install.sh"
        exit 1
    fi
}

# Check and install system requirements
check_requirements() {
    print_color "$BLUE" "🔍 Checking system requirements..."
    
    local required_commands=("curl" "sort" "uniq" "wc" "date" "bash")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_color "$YELLOW" "⚠️  Missing required commands: ${missing_commands[*]}"
        print_color "$BLUE" "� Auto-installing missing dependencies..."
        
        # Detect package manager and install dependencies
        if command -v apt-get &> /dev/null; then
            print_color "$CYAN" "📦 Using apt-get package manager..."
            apt-get update -qq
            for cmd in "${missing_commands[@]}"; do
                case "$cmd" in
                    "curl") apt-get install -y curl ;;
                    "sort"|"uniq"|"wc") apt-get install -y coreutils ;;
                    "date") apt-get install -y coreutils ;;
                    "bash") apt-get install -y bash ;;
                esac
            done
        elif command -v yum &> /dev/null; then
            print_color "$CYAN" "📦 Using yum package manager..."
            for cmd in "${missing_commands[@]}"; do
                case "$cmd" in
                    "curl") yum install -y curl ;;
                    "sort"|"uniq"|"wc"|"date") yum install -y coreutils ;;
                    "bash") yum install -y bash ;;
                esac
            done
        elif command -v pacman &> /dev/null; then
            print_color "$CYAN" "📦 Using pacman package manager..."
            for cmd in "${missing_commands[@]}"; do
                case "$cmd" in
                    "curl") pacman -S --noconfirm curl ;;
                    "sort"|"uniq"|"wc"|"date") pacman -S --noconfirm coreutils ;;
                    "bash") pacman -S --noconfirm bash ;;
                esac
            done
        elif command -v brew &> /dev/null; then
            print_color "$CYAN" "📦 Using homebrew package manager..."
            for cmd in "${missing_commands[@]}"; do
                case "$cmd" in
                    "curl") brew install curl ;;
                    "sort"|"uniq"|"wc"|"date") brew install coreutils ;;
                    "bash") brew install bash ;;
                esac
            done
        else
            print_color "$RED" "❌ No supported package manager found"
            print_color "$YELLOW" "💡 Please manually install: ${missing_commands[*]}"
            exit 1
        fi
        
        print_color "$GREEN" "✅ Dependencies installed successfully"
    else
        print_color "$GREEN" "✅ All requirements satisfied"
    fi
}

# Create installation directory
create_install_dir() {
    print_color "$BLUE" "📁 Creating installation directory..."
    
    if [ -d "$INSTALL_DIR" ]; then
        print_color "$YELLOW" "⚠️  Existing installation found. Backing up..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/assets"
    
    print_color "$GREEN" "✅ Installation directory created: $INSTALL_DIR"
}

# Copy files
install_files() {
    print_color "$BLUE" "📋 Installing BackupFinder files..."
    
    # Copy main script
    if [ -f "$CURRENT_DIR/backupfinder.sh" ]; then
        cp "$CURRENT_DIR/backupfinder.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/backupfinder.sh"
    else
        print_color "$RED" "❌ Error: backupfinder.sh not found in current directory"
        exit 1
    fi
    
    # Copy assets
    if [ -d "$CURRENT_DIR/assets" ]; then
        cp -r "$CURRENT_DIR/assets/"* "$INSTALL_DIR/assets/"
    else
        print_color "$RED" "❌ Error: assets directory not found"
        exit 1
    fi
    
    # Copy documentation
    [ -f "$CURRENT_DIR/README.md" ] && cp "$CURRENT_DIR/README.md" "$INSTALL_DIR/"
    
    print_color "$GREEN" "✅ Files installed successfully"
}

# Create global executable
create_global_command() {
    print_color "$BLUE" "🔗 Creating global command..."
    
    cat > "$BIN_DIR/$TOOL_NAME" << EOF
#!/bin/bash
# BackupFinder Global Launcher
# Automatically generated by installer

# Set the installation directory
BACKUPFINDER_HOME="$INSTALL_DIR"

# Export path for assets
export BACKUPFINDER_ASSETS="\$BACKUPFINDER_HOME/assets"

# Change to installation directory to ensure relative paths work
cd "\$BACKUPFINDER_HOME"

# Execute the main script with all arguments
exec "\$BACKUPFINDER_HOME/backupfinder.sh" "\$@"
EOF
    
    chmod +x "$BIN_DIR/$TOOL_NAME"
    
    print_color "$GREEN" "✅ Global command created: $TOOL_NAME"
}

# Update script to use installation paths
update_script_paths() {
    print_color "$BLUE" "🔧 Updating script configuration..."
    
    # Update the script to use installation directory paths
    sed -i "s|SCRIPT_DIR=\".*\"|SCRIPT_DIR=\"$INSTALL_DIR\"|g" "$INSTALL_DIR/backupfinder.sh"
    
    print_color "$GREEN" "✅ Script paths updated"
}

# Create uninstaller
create_uninstaller() {
    print_color "$BLUE" "🗑️  Creating uninstaller..."
    
    cat > "$INSTALL_DIR/uninstall.sh" << 'EOF'
#!/bin/bash
# BackupFinder Uninstaller

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

echo -e "${YELLOW}🗑️  BackupFinder Uninstaller${RESET}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Error: Uninstaller must be run as root (use sudo)${RESET}"
    exit 1
fi

read -p "Are you sure you want to uninstall BackupFinder? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing BackupFinder...${RESET}"
    
    # Remove global command
    rm -f "/usr/local/bin/backupfinder"
    
    # Remove installation directory
    rm -rf "/opt/backupfinder"
    
    echo -e "${GREEN}✅ BackupFinder uninstalled successfully${RESET}"
else
    echo -e "${YELLOW}Uninstallation cancelled${RESET}"
fi
EOF
    
    chmod +x "$INSTALL_DIR/uninstall.sh"
    
    print_color "$GREEN" "✅ Uninstaller created"
}

# Test installation
test_installation() {
    print_color "$BLUE" "🧪 Testing installation..."
    
    if command -v "$TOOL_NAME" &> /dev/null; then
        print_color "$GREEN" "✅ Global command available"
        
        # Test version
        if "$TOOL_NAME" -version &> /dev/null; then
            print_color "$GREEN" "✅ Tool executes successfully"
        else
            print_color "$YELLOW" "⚠️  Tool installed but may have issues"
        fi
    else
        print_color "$RED" "❌ Global command not available"
        exit 1
    fi
}

# Show completion message
show_completion() {
    echo ""
    print_color "$GREEN" "🎉 BackupFinder installed successfully!"
    echo ""
    print_color "$CYAN" "📖 Usage Examples:"
    print_color "$WHITE" "   $TOOL_NAME -u example.com"
    print_color "$WHITE" "   $TOOL_NAME -u example.com -w"
    print_color "$WHITE" "   $TOOL_NAME -l targets.txt -je results.json"
    print_color "$WHITE" "   $TOOL_NAME -help"
    echo ""
    print_color "$CYAN" "📁 Installation Details:"
    print_color "$WHITE" "   Tool Directory: $INSTALL_DIR"
    print_color "$WHITE" "   Global Command: $BIN_DIR/$TOOL_NAME"
    print_color "$WHITE" "   Assets: $INSTALL_DIR/assets/"
    echo ""
    print_color "$YELLOW" "🗑️  To uninstall: sudo $INSTALL_DIR/uninstall.sh"
    echo ""
}

# Main installation process
main() {
    show_banner
    
    print_color "$BLUE" "🚀 Starting BackupFinder installation..."
    echo ""
    
    check_root
    check_requirements
    create_install_dir
    install_files
    update_script_paths
    create_global_command
    create_uninstaller
    test_installation
    
    show_completion
}

# Handle interruption
trap 'print_color "$RED" "\n❌ Installation interrupted"; exit 1' INT TERM

# Run main function
main "$@"
