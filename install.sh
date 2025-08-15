#!/bin/bash
# Charles to HAR Converter Installation Script
# Installs chls-to-har script globally on the user's system

set -e

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

print_info() {
    echo -e "${BLUE}Info:${NC} $1"
}

print_success() {
    echo -e "${GREEN}Success:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

# Default installation directory
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="chls-to-har"

print_usage() {
    echo "Charles to HAR Converter Installation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --install-dir DIR    Install directory (default: ~/.local/bin)"
    echo "  --system             Install system-wide to /usr/local/bin (requires sudo)"
    echo "  --uninstall         Uninstall the script"
    echo "  -h, --help          Show this help message"
    echo ""
}

check_requirements() {
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is required but not found"
        echo "Please install Docker before installing chls-to-har:"
        echo "  macOS: https://docs.docker.com/docker-for-mac/install/"
        echo "  Linux: https://docs.docker.com/engine/install/"
        echo "  Windows: https://docs.docker.com/docker-for-windows/install/"
        exit 1
    fi
    
    print_info "Docker found: $(docker --version)"
}

check_permissions() {
    if [ ! -w "$INSTALL_DIR" ]; then
        # Try to create the directory if it doesn't exist
        if [ ! -d "$INSTALL_DIR" ]; then
            print_info "Creating directory $INSTALL_DIR"
            mkdir -p "$INSTALL_DIR" 2>/dev/null || {
                print_error "Cannot create directory $INSTALL_DIR"
                echo "Please check permissions or choose a different location"
                exit 1
            }
        else
            print_error "No write permission to $INSTALL_DIR"
            echo "Please check directory permissions or choose a different location"
            exit 1
        fi
    fi
}

install_script() {
    local source_script="$(realpath ./chls-to-har.sh)"
    local target_script="$INSTALL_DIR/$SCRIPT_NAME"
    
    # Check if source script exists
    if [ ! -f "$source_script" ]; then
        print_error "Source script './chls-to-har.sh' not found"
        echo "Please run this installer from the charles-convert directory"
        exit 1
    fi
    
    # Ensure source script is executable
    if [ ! -x "$source_script" ]; then
        print_info "Making source script executable"
        chmod +x "$source_script"
    fi
    
    print_info "Creating symlink from $target_script to $source_script"
    
    # Remove existing file/link if it exists
    if [ -e "$target_script" ] || [ -L "$target_script" ]; then
        rm "$target_script"
    fi
    
    # Create symlink
    ln -s "$source_script" "$target_script"
    
    print_success "Installation completed successfully!"
    print_info "You can now run 'chls-to-har' from anywhere"
    print_info "Changes to the source script will be reflected immediately"
    
    # Check if install directory is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        print_warning "Warning: $INSTALL_DIR is not in your PATH"
        echo "Add this line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
        echo "Then reload your shell or run: source ~/.bashrc (or ~/.zshrc)"
    fi
}

uninstall_script() {
    local target_script="$INSTALL_DIR/$SCRIPT_NAME"
    
    if [ -f "$target_script" ]; then
        print_info "Removing $target_script"
        rm "$target_script"
        print_success "chls-to-har uninstalled successfully"
    else
        print_warning "chls-to-har is not installed at $target_script"
    fi
}

main() {
    local action="install"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --system)
                INSTALL_DIR="/usr/local/bin"
                shift
                ;;
            --uninstall)
                action="uninstall"
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Create install directory if it doesn't exist
    if [ "$action" = "install" ]; then
        mkdir -p "$INSTALL_DIR" 2>/dev/null || true
    fi
    
    # Check permissions
    check_permissions
    
    case "$action" in
        install)
            check_requirements
            install_script
            ;;
        uninstall)
            uninstall_script
            ;;
    esac
}

main "$@"
