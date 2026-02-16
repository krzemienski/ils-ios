# Build stage
FROM swift:6.0-jammy AS builder
WORKDIR /app
COPY Package.swift Package.resolved ./
COPY Sources/ Sources/
RUN swift build -c release --static-swift-stdlib

# Runtime stage
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libxml2 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/.build/release/ILSBackend .
COPY --from=builder /app/.build/release/*.resources ./

ENV PORT=9999
EXPOSE 9999

ENTRYPOINT ["./ILSBackend"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "9999"]
