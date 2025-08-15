# Charles to HAR Converter

Convert Charles Proxy session files (`.chls` and `.chrlz`) to HTTP Archive format (`.har`) using a containerized approach.

## Quick Start

1. **Clone and run:**
   ```bash
   git clone <repository-url>
   cd charles-convert
   ./chls-to-har.sh your-session-file.chls
   ```

That's it! The script will automatically check for Docker, build the conversion image if needed, and convert your file.

## Prerequisites

- **Docker** - The conversion runs in a containerized environment
  - macOS: [Install Docker Desktop](https://docs.docker.com/docker-for-mac/install/)
  - Linux: [Install Docker Engine](https://docs.docker.com/engine/install/)
  - Windows: [Install Docker Desktop](https://docs.docker.com/docker-for-windows/install/)

## Usage

### Basic Usage

```bash
./chls-to-har.sh session.chls
```

### Supported File Types

- `.chls` files (Charles session files)
- `.chrlz` files (Charles compressed session files)

### Examples

```bash
# Convert a local session file
./chls-to-har.sh my-session.chls

# Convert a file with full path
./chls-to-har.sh /path/to/session.chrlz

# Get help
./chls-to-har.sh --help
```

## What the Script Does

1. **Environment Check**: Verifies Docker is installed and running
2. **Input Validation**: Checks if the input file exists and is readable
3. **Image Management**: Automatically builds the Docker image if not present
4. **File Conversion**: Converts Charles files to HAR format using Charles Proxy CLI
5. **Output Validation**: Confirms the conversion was successful

## Output

The script creates a `.har` file in the same directory as your input file:
- `session.chls` → `session.har`
- `session.chrlz` → `session.har`

## Docker Image Details

The conversion uses a custom Docker image based on Alpine Linux that includes:
- **Charles Proxy 5.0.2** - For file conversion
- **OpenJDK 21** - Runtime environment
- **Multi-architecture support** - Works on both ARM64 and x86_64

### Manual Docker Operations

If you need to work with Docker directly:

```bash
# Build the image manually
docker build -t charles-convert .

# Run conversion manually
docker run --rm -v $(pwd):/data charles-convert convert session.chls session.har

# Check if image exists
docker image inspect charles-convert
```

## File Structure

```
charles-convert/
├── Dockerfile              # Container definition
├── chls-to-har.sh         # Main conversion script
├── convert-chls-to-har.sh  # Alternative script name
└── README.md              # This file
```

## Architecture Support

The Docker image automatically detects your system architecture and downloads the appropriate Charles Proxy binary:
- **ARM64** (Apple Silicon Macs, ARM servers)
- **x86_64** (Intel/AMD processors)

## Troubleshooting

### Docker Issues

**Docker not found:**
```
Error: Docker is not installed or not in PATH
```
Install Docker from the official website for your platform.

**Docker daemon not running:**
```
Error: Docker daemon is not running
```
Start Docker Desktop or the Docker service.

### File Issues

**File not found:**
```
Error: File 'session.chls' does not exist
```
Check the file path and ensure the file exists.

**Permission denied:**
```
Error: File 'session.chls' is not readable
```
Check file permissions: `chmod 644 session.chls`

### Build Issues

**Dockerfile missing:**
```
Error: Dockerfile not found at ./Dockerfile
```
Ensure you're running the script from the project root directory.

**Build failed:**
```
Error: Failed to build Docker image
```
Check your internet connection and Docker configuration.

## Advanced Usage

### Environment Variables

You can customize the behavior using environment variables:

```bash
# Use a different Docker image name
DOCKER_IMAGE=my-charles-converter ./chls-to-har.sh session.chls

# Use a different Dockerfile path
DOCKERFILE_PATH=./custom.Dockerfile ./chls-to-har.sh session.chls
```

### Batch Processing

Convert multiple files:

```bash
# Convert all .chls files in current directory
for file in *.chls; do
    ./chls-to-har.sh "$file"
done

# Convert all .chrlz files with error handling
for file in *.chrlz; do
    if ./chls-to-har.sh "$file"; then
        echo "Successfully converted $file"
    else
        echo "Failed to convert $file"
    fi
done
```

## HAR File Usage

The generated `.har` files can be used with:

- **Browser DevTools**: Import in Chrome/Firefox Network tab
- **HAR Analyzers**: Online tools like HAR Analyzer, GTmetrix
- **Performance Tools**: WebPageTest, Lighthouse
- **Custom Scripts**: Parse with JSON libraries in any language

### HAR File Structure

HAR files contain:
- HTTP request/response data
- Timing information
- Headers and body content
- Cache information
- Network performance metrics

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add some improvement'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Create a Pull Request

## License

This project is open source. See LICENSE file for details.

## Technical Notes

### Charles Proxy Integration

The conversion uses Charles Proxy's command-line interface:
```bash
/opt/charles-proxy/bin/charles convert input.chls output.har
```

### Docker Image Layers

The image is optimized with:
- Alpine Linux base (minimal size)
- Multi-stage builds where applicable
- Automatic cleanup of package caches
- Architecture-specific binaries

### Security Considerations

- The script runs Docker containers with minimal privileges
- No sensitive data is retained in the container
- Volume mounts are read-write only for the working directory
- Containers are automatically removed after conversion

## Version History

- **v1.0** - Initial release with basic conversion
- **v2.0** - Added comprehensive error handling and Docker management
- **Current** - Multi-architecture support and enhanced user experience
