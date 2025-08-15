#!/bin/bash
# Charles to HAR Converter for Automator
# Modified version that outputs to the same directory as the input file

set -e

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DOCKER_IMAGE="charles-convert"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE_PATH="$SCRIPT_DIR/Dockerfile"

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

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        osascript -e 'display alert "Docker Required" message "Docker is not installed. Please install Docker from https://docs.docker.com/docker-for-mac/install/" as critical'
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        osascript -e 'display alert "Docker Not Running" message "Please start Docker and try again." as critical'
        exit 1
    fi
    
    print_info "Docker is available and running"
}

check_docker_image() {
    if docker image inspect "$DOCKER_IMAGE" &> /dev/null; then
        print_info "Docker image '$DOCKER_IMAGE' found"
        return 0
    else
        print_warning "Docker image '$DOCKER_IMAGE' not found"
        return 1
    fi
}

build_docker_image() {
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        print_error "Dockerfile not found at $DOCKERFILE_PATH"
        osascript -e 'display alert "Setup Error" message "Dockerfile not found. Make sure the script is in the correct directory." as critical'
        exit 1
    fi
    
    print_info "Building Docker image '$DOCKER_IMAGE'..."
    
    # Change to script directory for building
    cd "$SCRIPT_DIR"
    
    if docker build -t "$DOCKER_IMAGE" -f "$DOCKERFILE_PATH" .; then
        print_success "Docker image built successfully"
    else
        print_error "Failed to build Docker image"
        osascript -e 'display alert "Build Failed" message "Failed to build Docker image. Check your internet connection and try again." as critical'
        exit 1
    fi
}

validate_input_file() {
    local file="$1"
    
    if [ -z "$file" ]; then
        print_error "No input file specified"
        exit 1
    fi
    
    if [ ! -f "$file" ]; then
        print_error "File '$file' does not exist"
        osascript -e "display alert \"File Not Found\" message \"File '$file' does not exist.\" as critical"
        exit 1
    fi
    
    if [ ! -r "$file" ]; then
        print_error "File '$file' is not readable"
        osascript -e "display alert \"File Not Readable\" message \"File '$file' is not readable.\" as critical"
        exit 1
    fi
    
    # Check file extension
    if [[ ! "$file" =~ \.(chls|chrlz)$ ]]; then
        print_warning "File '$file' does not have a .chls or .chrlz extension"
        result=$(osascript -e "display dialog \"File '$file' does not have a .chls or .chrlz extension. Continue anyway?\" buttons {\"Cancel\", \"Continue\"} default button \"Cancel\"" 2>/dev/null || echo "Cancel")
        if [[ "$result" == *"Cancel"* ]]; then
            exit 1
        fi
    fi
    
    print_info "Input file '$file' validated"
}

get_output_filename() {
    local input="$1"
    local input_dir
    local filename_only
    local basename
    
    # Get directory of input file
    input_dir="$(dirname "$input")"
    
    # Get just the filename without path
    filename_only="$(basename "$input")"
    
    # Remove .chls or .chrlz extension and add .har
    if [[ "$filename_only" =~ \.chrlz$ ]]; then
        basename="${filename_only%.chrlz}"
    elif [[ "$filename_only" =~ \.chls$ ]]; then
        basename="${filename_only%.chls}"
    else
        basename="$filename_only"
    fi
    
    # Return full path in the same directory as input
    echo "$input_dir/${basename}.har"
}

convert_file() {
    local input_file="$1"
    local output_file="$2"
    
    print_info "Converting '$input_file' to '$output_file'..."
    
    # Get absolute paths for Docker volume mounting
    local input_dir
    local input_name
    local output_dir
    local output_name
    
    input_dir="$(dirname "$(realpath "$input_file")")"
    input_name="$(basename "$input_file")"
    output_dir="$(dirname "$(realpath "$output_file")")"
    output_name="$(basename "$output_file")"
    
    # Run the Docker container
    if docker run --rm \
        -v "$input_dir:/input" \
        -v "$output_dir:/output" \
        "$DOCKER_IMAGE" \
        convert "/input/$input_name" "/output/$output_name"; then
        
        if [ -f "$output_file" ]; then
            local file_size
            file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "unknown")
            print_success "Conversion completed successfully"
            print_info "Output file: $output_file (${file_size} bytes)"
            osascript -e "display notification \"Conversion completed: $output_name\" with title \"Charles to HAR Converter\""
        else
            print_error "Conversion may have failed - output file not found"
            osascript -e 'display alert "Conversion Failed" message "Output file was not created." as critical'
            exit 1
        fi
    else
        print_error "Docker conversion failed"
        osascript -e 'display alert "Conversion Failed" message "Docker conversion process failed." as critical'
        exit 1
    fi
}

main() {
    local input_file="$1"
    
    print_info "Charles to HAR Converter starting..."
    
    # Validate environment and inputs
    check_docker
    validate_input_file "$input_file"
    
    # Ensure Docker image exists
    if ! check_docker_image; then
        print_info "Building Docker image (this may take a few minutes)..."
        osascript -e 'display notification "Building Docker image..." with title "Charles to HAR Converter"'
        build_docker_image
    fi
    
    # Determine output filename (in same directory as input)
    local output_file
    output_file=$(get_output_filename "$input_file")
    
    # Check if output file already exists
    if [ -f "$output_file" ]; then
        print_warning "Output file '$output_file' already exists"
        result=$(osascript -e "display dialog \"Output file already exists. Overwrite?\" buttons {\"Cancel\", \"Overwrite\"} default button \"Cancel\"" 2>/dev/null || echo "Cancel")
        if [[ "$result" == *"Cancel"* ]]; then
            print_info "Conversion cancelled"
            exit 0
        else
            rm "$output_file"
            print_info "Removed existing file"
        fi
    fi
    
    # Perform conversion
    convert_file "$input_file" "$output_file"
    
    print_success "Conversion process completed!"
}

# Run main function with first argument
main "$1"
