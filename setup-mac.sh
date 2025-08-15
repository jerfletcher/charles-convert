#!/bin/bash
# macOS Setup Script for Charles to HAR Converter
# This script sets up the converter and creates a drag-and-drop application

set -e

# Colors for output
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Charles to HAR Converter"
DESKTOP_PATH="$HOME/Desktop"

print_header() {
    echo ""
    echo "=================================================="
    echo "    Charles to HAR Converter - macOS Setup"
    echo "=================================================="
    echo ""
}

check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS only"
        exit 1
    fi
    print_info "Running on macOS ✓"
}

check_docker() {
    print_info "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        print_warning "Docker is not installed"
        echo ""
        echo "Please install Docker Desktop for Mac:"
        echo "  https://docs.docker.com/docker-for-mac/install/"
        echo ""
        read -p "Press Enter after installing Docker to continue..."
        
        if ! command -v docker &> /dev/null; then
            print_error "Docker still not found. Please install Docker and try again."
            exit 1
        fi
    fi
    
    if ! docker info &> /dev/null; then
        print_warning "Docker daemon is not running"
        echo ""
        echo "Please start Docker Desktop and try again."
        echo "You should see the Docker whale icon in your menu bar."
        echo ""
        read -p "Press Enter after starting Docker to continue..."
        
        if ! docker info &> /dev/null; then
            print_error "Docker daemon still not running. Please start Docker Desktop."
            exit 1
        fi
    fi
    
    print_success "Docker is installed and running ✓"
}

build_docker_image() {
    print_info "Building Docker image..."
    
    if [ ! -f "$SCRIPT_DIR/Dockerfile" ]; then
        print_error "Dockerfile not found in $SCRIPT_DIR"
        exit 1
    fi
    
    cd "$SCRIPT_DIR"
    
    if docker build -t charles-convert .; then
        print_success "Docker image built successfully ✓"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
}

create_automator_app() {
    print_info "Creating Automator application..."
    
    # Path for the app
    local app_path="$DESKTOP_PATH/$APP_NAME.app"
    
    # Remove existing app if it exists
    if [ -d "$app_path" ]; then
        print_warning "Removing existing application..."
        rm -rf "$app_path"
    fi
    
    # Create the Automator application using AppleScript
    osascript << EOF
tell application "Automator"
    set newWorkflow to make new document with properties {workflow type:application}
    tell newWorkflow
        set newAction to make new Automator action with properties {name:"Run Shell Script"}
        tell newAction
            set value of setting "inputMethod" to "as arguments"
            set value of setting "SHELL" to "/bin/bash"
            set value of setting "source" to "#!/bin/bash
for file in \"\$@\"; do
    if [[ \"\$file\" =~ \\.(chls|chrlz)\$ ]]; then
        \"$SCRIPT_DIR/chls-to-har-automator.sh\" \"\$file\"
    else
        osascript -e \"display alert \\\"Invalid File\\\" message \\\"File '\$file' is not a Charles session file (.chls or .chrlz).\\\" as warning\"
    fi
done"
        end tell
    end tell
    save newWorkflow in "$app_path"
    close newWorkflow
end tell
EOF
    
    if [ -d "$app_path" ]; then
        print_success "Automator application created at: $app_path ✓"
    else
        print_error "Failed to create Automator application"
        return 1
    fi
}

create_command_line_wrapper() {
    print_info "Creating command-line wrapper..."
    
    local wrapper_path="/usr/local/bin/chls-to-har"
    
    # Create wrapper script
    sudo tee "$wrapper_path" > /dev/null << EOF
#!/bin/bash
# Charles to HAR Converter Command Line Wrapper
"$SCRIPT_DIR/chls-to-har.sh" "\$@"
EOF
    
    sudo chmod +x "$wrapper_path"
    
    if [ -f "$wrapper_path" ]; then
        print_success "Command-line wrapper installed ✓"
        print_info "You can now use 'chls-to-har file.chls' from anywhere"
    else
        print_warning "Failed to create command-line wrapper (optional)"
    fi
}

test_conversion() {
    print_info "Testing conversion with sample file..."
    
    # Check if there's a sample .chls file
    local sample_file
    sample_file=$(find "$SCRIPT_DIR" -name "*.chls" -o -name "*.chrlz" | head -n 1)
    
    if [ -n "$sample_file" ]; then
        print_info "Found sample file: $(basename "$sample_file")"
        print_info "Testing conversion..."
        
        if "$SCRIPT_DIR/chls-to-har.sh" "$sample_file"; then
            print_success "Test conversion successful ✓"
        else
            print_warning "Test conversion failed (but setup is complete)"
        fi
    else
        print_info "No sample .chls files found for testing"
    fi
}

show_usage_instructions() {
    echo ""
    echo "=================================================="
    echo "                 Setup Complete!"
    echo "=================================================="
    echo ""
    echo "How to use:"
    echo ""
    echo "1. DRAG AND DROP:"
    echo "   • Drag .chls or .chrlz files onto the '$APP_NAME.app' on your Desktop"
    echo "   • The .har file will be created in the same folder as the original file"
    echo ""
    echo "2. COMMAND LINE:"
    echo "   • Use: chls-to-har your-file.chls"
    echo "   • Or: $SCRIPT_DIR/chls-to-har.sh your-file.chls"
    echo ""
    echo "3. FINDER INTEGRATION:"
    echo "   • Right-click any .chls file → Open With → $APP_NAME"
    echo ""
    echo "The converter will:"
    echo "  ✓ Automatically build Docker image if needed"
    echo "  ✓ Convert Charles session files to HAR format"
    echo "  ✓ Output files to the same directory as input"
    echo "  ✓ Show progress notifications"
    echo ""
    print_success "Ready to convert Charles files to HAR format!"
    echo ""
}

main() {
    print_header
    
    check_macos
    check_docker
    build_docker_image
    
    # Make automator script executable
    chmod +x "$SCRIPT_DIR/chls-to-har-automator.sh"
    
    # Create Automator app
    if create_automator_app; then
        print_success "Drag-and-drop application created successfully"
    else
        print_error "Failed to create Automator application"
        print_info "You can still use the command-line version"
    fi
    
    # Create command-line wrapper (optional, requires sudo)
    echo ""
    read -p "Install command-line wrapper? (requires sudo password) [y/N]: " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_command_line_wrapper
    fi
    
    # Test if possible
    test_conversion
    
    show_usage_instructions
}

# Run main function
main
