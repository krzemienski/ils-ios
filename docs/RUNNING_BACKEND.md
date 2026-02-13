# Running the ILS Backend

The ILS backend is a Swift/Vapor server that provides the REST API for the iOS app. This guide covers multiple ways to run it.

## Quick Start (Development)

```bash
cd /path/to/ils-ios
swift run ILSBackend
```

The server starts at `http://localhost:9999`. Press `Ctrl+C` to stop.

---

## Option 1: launchd (macOS Native - Recommended)

Use macOS's built-in service manager for automatic startup.

### Install as User Service

```bash
# Create the plist file
cat > ~/Library/LaunchAgents/com.ils.backend.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ils.backend</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/swift</string>
        <string>run</string>
        <string>ILSBackend</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/YOUR_USERNAME/Desktop/ils-ios</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ils-backend.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ils-backend.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin</string>
    </dict>
</dict>
</plist>
EOF

# Update the path to your actual location
sed -i '' "s|YOUR_USERNAME|$(whoami)|g" ~/Library/LaunchAgents/com.ils.backend.plist
```

### Manage the Service

```bash
# Load and start
launchctl load ~/Library/LaunchAgents/com.ils.backend.plist

# Stop
launchctl unload ~/Library/LaunchAgents/com.ils.backend.plist

# Check status
launchctl list | grep ils

# View logs
tail -f /tmp/ils-backend.log
tail -f /tmp/ils-backend.error.log
```

### Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.ils.backend.plist
rm ~/Library/LaunchAgents/com.ils.backend.plist
```

---

## Option 2: Homebrew Services

If you prefer Homebrew-style service management.

### Create a Homebrew Service Formula (Local)

```bash
# Create local tap
mkdir -p $(brew --prefix)/Homebrew/Library/Taps/local/homebrew-ils
cat > $(brew --prefix)/Homebrew/Library/Taps/local/homebrew-ils/ils-backend.rb << 'EOF'
class IlsBackend < Formula
  desc "ILS Backend Server"
  homepage "https://github.com/your-repo/ils-ios"
  url "file:///dev/null"
  version "1.0.0"

  def install
    # This is a placeholder - the actual code lives in your project
    (bin/"ils-backend").write <<~EOS
      #!/bin/bash
      cd #{ENV['HOME']}/Desktop/ils-ios && swift run ILSBackend
    EOS
  end

  service do
    run [bin/"ils-backend"]
    keep_alive true
    log_path var/"log/ils-backend.log"
    error_log_path var/"log/ils-backend.error.log"
    working_dir ENV['HOME'] + "/Desktop/ils-ios"
  end
end
EOF
```

### Alternative: Simple Wrapper Script

```bash
# Create wrapper script
sudo tee /usr/local/bin/ils-backend << 'EOF'
#!/bin/bash
cd ~/Desktop/ils-ios && swift run ILSBackend
EOF
sudo chmod +x /usr/local/bin/ils-backend

# Use with brew services (requires the formula above) or just run directly
ils-backend
```

---

## Option 3: Docker

Run in a container with volume mounts for configuration access.

### Dockerfile

Create `Dockerfile` in project root:

```dockerfile
# Build stage
FROM swift:5.9-jammy as builder
WORKDIR /app
COPY Package.swift Package.resolved ./
COPY Sources ./Sources
COPY Tests ./Tests
RUN swift build -c release

# Runtime stage
FROM swift:5.9-jammy-slim
WORKDIR /app
COPY --from=builder /app/.build/release/ILSBackend ./

# Volume for database and config
VOLUME ["/app/data"]

EXPOSE 9999

# Run with data directory
CMD ["./ILSBackend"]
```

### docker-compose.yml

```yaml
version: '3.8'
services:
  ils-backend:
    build: .
    ports:
      - "9999:9999"
    volumes:
      # Mount for database persistence
      - ./ils.sqlite:/app/ils.sqlite
      # Mount Claude config for CLI access (if needed)
      - ~/.claude:/root/.claude:ro
      # Mount project directories (for Claude Code execution)
      - ~/Desktop:/root/Desktop:ro
    environment:
      - VAPOR_ENV=production
    restart: unless-stopped
```

### Run with Docker

```bash
# Build and run
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

**Note:** Docker requires volume mounts because the backend needs access to:
- SQLite database (`ils.sqlite`)
- Claude Code CLI configuration (`~/.claude`)
- Project directories for file operations

---

## Option 4: Screen/tmux (Simple Background)

For quick background running without service management.

```bash
# Using screen
screen -dmS ils-backend bash -c 'cd ~/Desktop/ils-ios && swift run ILSBackend'

# Attach to see output
screen -r ils-backend

# Detach: Ctrl+A, then D

# Kill
screen -X -S ils-backend quit
```

```bash
# Using tmux
tmux new-session -d -s ils-backend 'cd ~/Desktop/ils-ios && swift run ILSBackend'

# Attach
tmux attach -t ils-backend

# Detach: Ctrl+B, then D

# Kill
tmux kill-session -t ils-backend
```

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VAPOR_ENV` | `development` | Environment mode |
| `DATABASE_PATH` | `./ils.sqlite` | SQLite database location |
| `PORT` | `9999` | Server port |

### Server Settings

Edit `Sources/ILSBackend/App/configure.swift` to change:
- Port (default: 9999)
- Hostname (default: 0.0.0.0)
- Database path

---

## Verifying It's Running

```bash
# Health check
curl http://localhost:9999/health
# Returns: OK

# Check if process is running
pgrep -f ILSBackend

# Check port
lsof -i :9999
```

---

## Troubleshooting

### Port Already in Use

```bash
# Find what's using port 9999
lsof -i :9999

# Kill the process
kill -9 <PID>
```

### Database Locked

```bash
# Check for zombie processes
ps aux | grep ILSBackend

# Remove stale lock (if safe)
rm -f ils.sqlite-shm ils.sqlite-wal
```

### Swift Build Fails

```bash
# Clean and rebuild
rm -rf .build
swift package resolve
swift build
```
