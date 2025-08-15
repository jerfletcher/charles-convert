#!/bin/bash
# Charles to HAR Converter
# Converts Charles Proxy session files (.chls/.chrlz) to HTTP Archive format (.har)
# 
# Usage: ./chls-to-har.sh <file.chls>

set -e

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DOCKER_IMAGE="charles-convert"
DOCKERFILE_PATH="./Dockerfile"

print_usage() {
    echo "Charles to HAR Converter"
    echo ""
    echo "Usage: $0 <charles-file>"
    echo ""
    echo "Arguments:"
    echo "  charles-file    Path to Charles session file (.chls or .chrlz)"
    echo ""
    echo "Examples:"
    echo "  $0 session.chls"
    echo "  $0 session.chrlz"
    echo "  $0 /path/to/session.chls"
    echo ""
}

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
        echo ""
        echo "Please install Docker:"
        echo "  macOS: https://docs.docker.com/docker-for-mac/install/"
        echo "  Linux: https://docs.docker.com/engine/install/"
        echo "  Windows: https://docs.docker.com/docker-for-windows/install/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        echo ""
        echo "Please start Docker and try again."
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
        echo ""
        echo "Make sure you're running this script from the correct directory"
        echo "that contains the Dockerfile."
        exit 1
    fi
    
    print_info "Building Docker image '$DOCKER_IMAGE'..."
    echo ""
    
    if docker build -t "$DOCKER_IMAGE" -f "$DOCKERFILE_PATH" .; then
        print_success "Docker image built successfully"
    else
        print_error "Failed to build Docker image"
        echo ""
        echo "Please check the Dockerfile and try again."
        echo "Make sure you have internet connectivity for downloading dependencies."
        exit 1
    fi
}

validate_input_file() {
    local file="$1"
    
    if [ -z "$file" ]; then
        print_error "No input file specified"
        echo ""
        print_usage
        exit 1
    fi
    
    if [ ! -f "$file" ]; then
        print_error "File '$file' does not exist"
        exit 1
    fi
    
    if [ ! -r "$file" ]; then
        print_error "File '$file' is not readable"
        exit 1
    fi
    
    # Check file extension
    if [[ ! "$file" =~ \.(chls|chrlz)$ ]]; then
        print_warning "File '$file' does not have a .chls or .chrlz extension"
        echo "Continuing anyway, but make sure this is a Charles session file."
    fi
    
    print_info "Input file '$file' validated"
}

get_output_filename() {
    local input="$1"
    local basename
    local filename_only
    
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
    
    # Return filename in current working directory
    echo "${basename}.har"
}

convert_file() {
    local input_file="$1"
    local output_file="$2"
    
    print_info "Converting '$input_file' to '$output_file'..."
    echo ""
    
    # Get absolute paths for Docker volume mounting
    local input_dir
    local input_name
    local current_dir
    input_dir="$(dirname "$(realpath "$input_file")")"
    input_name="$(basename "$input_file")"
    current_dir="$(pwd)"
    
    local output_name
    output_name="$(basename "$output_file")"
    
    # Run the Docker container with both input and output directories mounted
    if docker run --rm \
        -v "$input_dir:/input" \
        -v "$current_dir:/output" \
        "$DOCKER_IMAGE" \
        convert "/input/$input_name" "/output/$output_name"; then
        
        if [ -f "$output_file" ]; then
            local file_size
            file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "unknown")
            print_success "Conversion completed successfully"
            print_info "Output file: $output_file (${file_size} bytes)"
        else
            print_error "Conversion may have failed - output file not found"
            exit 1
        fi
    else
        print_error "Docker conversion failed"
        exit 1
    fi
}

main() {
    # Check arguments
    if [ "$#" -ne 1 ]; then
        print_error "Invalid number of arguments"
        echo ""
        print_usage
        exit 1
    fi
    
    local input_file="$1"
    
    # Handle help flags
    case "$input_file" in
        -h|--help|help)
            print_usage
            exit 0
            ;;
    esac
    
    print_info "Charles to HAR Converter starting..."
    echo ""
    
    # Validate environment and inputs
    check_docker
    validate_input_file "$input_file"
    
    # Ensure Docker image exists
    if ! check_docker_image; then
        echo ""
        print_info "Building Docker image (this may take a few minutes)..."
        build_docker_image
        echo ""
    fi
    
    # Determine output filename
    local output_file
    output_file=$(get_output_filename "$input_file")
    
    # Check if output file already exists
    if [ -f "$output_file" ]; then
        print_warning "Output file '$output_file' already exists"
        read -p "Overwrite? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Conversion cancelled"
            exit 0
        else
            # Remove existing file since user confirmed overwrite
            rm "$output_file"
            print_info "Removed existing file"
        fi
    fi
    
    # Perform conversion
    convert_file "$input_file" "$output_file"
    
    echo ""
    print_success "Conversion process completed!"
    print_info "You can now use '$output_file' with HAR analysis tools"
}

# Run main function
main "$@"
