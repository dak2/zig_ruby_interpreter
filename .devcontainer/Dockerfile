FROM debian:latest

# Install dependencies for Zig
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    unzip \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for VSCode
RUN useradd -ms /bin/bash vscode && \
    mkdir -p /workspace && chown vscode:vscode /workspace

# Install Zig
ENV ZIG_VERSION=0.13.0
RUN curl -L https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz \
    | tar -xJ && \
    mv zig-linux-x86_64-${ZIG_VERSION} /usr/local/zig && \
    chown -R vscode:vscode /usr/local/zig

# Set Zig path globally
ENV PATH="/usr/local/zig:${PATH}"

# Default to non-root user
USER vscode
WORKDIR /workspace

CMD ["/bin/bash"]
