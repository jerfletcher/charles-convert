FROM alpine:latest

RUN apk add --no-cache openjdk21-jre-headless wget bash coreutils

# Detect architecture and download appropriate Charles version
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        CHARLES_ARCH="x86_64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        CHARLES_ARCH="aarch64"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    echo "Downloading Charles for architecture: $CHARLES_ARCH" && \
    wget -O /tmp/charles.tar.gz "https://www.charlesproxy.com/assets/release/5.0.2/charles-proxy-5.0.2_${CHARLES_ARCH}.tar.gz?k=24f6db854f" && \
    mkdir -p /opt/charles && \
    tar -xzf /tmp/charles.tar.gz -C /opt/charles --strip-components=1 && \
    rm /tmp/charles.tar.gz

# Create a wrapper script for Charles
RUN printf '#!/bin/bash\nCHARLES_LIB="/opt/charles/lib"\nJAVA_CMD="java"\nexec $JAVA_CMD -Xmx1024M -Dcharles.config="/tmp/.charles.config" -cp "$CHARLES_LIB/charles.jar:$CHARLES_LIB/*" com.charlesproxy.main.MainWithClassLoader "$@"\n' > /usr/local/bin/charles && \
    chmod +x /usr/local/bin/charles

ENV CHARLES_LIB="/opt/charles/lib"
WORKDIR /data
ENTRYPOINT ["charles"]
CMD ["--help"]