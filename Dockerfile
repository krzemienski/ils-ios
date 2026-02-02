# ILS Backend Dockerfile
# Build: docker build -t ils-backend .
# Run: docker run -p 8080:8080 -v $(pwd)/ils.sqlite:/app/ils.sqlite ils-backend

# Build stage
FROM swift:5.9-jammy as builder
WORKDIR /app

# Copy package files first for better caching
COPY Package.swift Package.resolved ./

# Resolve dependencies
RUN swift package resolve

# Copy source code
COPY Sources ./Sources
COPY Tests ./Tests

# Build release binary
RUN swift build -c release --static-swift-stdlib

# Runtime stage - minimal image
FROM ubuntu:22.04
WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libxml2 \
    tzdata \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy built binary
COPY --from=builder /app/.build/release/ILSBackend ./

# Create data directory
RUN mkdir -p /app/data

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run server
ENTRYPOINT ["./ILSBackend"]
