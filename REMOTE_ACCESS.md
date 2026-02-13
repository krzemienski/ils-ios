# ILS Remote Access Setup Guide

Access your ILS backend from anywhere using Cloudflare Tunnel or Tailscale.

## Overview

This guide shows you how to expose your local ILS backend server to the internet, allowing you to access it from your iPhone when away from home.

### Two Options

| Solution | Best For | Setup Time | Cost |
|----------|----------|------------|------|
| **Cloudflare Tunnel** | Quick setup, temporary URLs | 2 minutes | Free |
| **Tailscale** | Permanent, secure network | 5 minutes | Free (up to 100 devices) |

---

## Option 1: Cloudflare Tunnel (Recommended for Quick Setup)

### What is Cloudflare Tunnel?

Cloudflare Tunnel creates a secure connection from your backend to Cloudflare's edge, providing a public HTTPS URL without exposing ports or configuring firewalls.

### Installation

```bash
# macOS
brew install cloudflared

# Or download from:
# https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/
```

### Usage

#### Quick Start (One Command)

```bash
cd <project-root>
./scripts/remote-access/setup-cloudflare-tunnel.sh
```

**That's it!** The script will:
1. ✅ Build the ILS backend
2. ✅ Start the backend on port 9090
3. ✅ Create a Cloudflare tunnel
4. ✅ Give you a public URL (e.g., `https://abc123.trycloudflare.com`)
5. ✅ Monitor both processes

#### What You'll See

```
═══════════════════════════════════════════════════
  ILS Backend Remote Access Active
═══════════════════════════════════════════════════

  Local URL:  http://localhost:9090
  Remote URL: https://abc-def-ghi.trycloudflare.com

═══════════════════════════════════════════════════

Configure your iOS app with:
  https://abc-def-ghi.trycloudflare.com
```

#### Configure iOS App

1. Open ILS app on your iPhone
2. Go to **Settings** → **Server Configuration**
3. Enter the Cloudflare URL: `https://abc-def-ghi.trycloudflare.com`
4. Tap **Save**

Done! You can now access your backend from anywhere.

### Features

✅ **Auto-start backend** - Builds and starts ILS backend automatically
✅ **Public HTTPS URL** - Secure connection with SSL
✅ **No configuration** - Works instantly
✅ **Process monitoring** - Auto-restarts if either process fails
✅ **Health checking** - Monitors backend health

### Limitations

⚠️ **Temporary URLs** - URL changes each time you restart
⚠️ **Session duration** - Free tunnels may have time limits
⚠️ **Performance** - Routes through Cloudflare edge

### Advanced: Named Tunnel (Permanent URL)

For a permanent URL, create a named tunnel:

```bash
# Login to Cloudflare
cloudflared login

# Create named tunnel
cloudflared tunnel create ils-backend

# Get tunnel ID
cloudflared tunnel list

# Configure tunnel
cat > ~/.cloudflared/config.yml << EOF
url: http://localhost:9090
tunnel: YOUR_TUNNEL_ID
credentials-file: /Users/$(whoami)/.cloudflared/YOUR_TUNNEL_ID.json
EOF

# Run tunnel
cloudflared tunnel run ils-backend
```

---

## Option 2: Tailscale (Recommended for Permanent Setup)

### What is Tailscale?

Tailscale creates a secure private network (WireGuard VPN) between your devices. Your iPhone and Mac join the same network, allowing direct access without exposing anything to the public internet.

### Installation

```bash
# macOS
brew install --cask tailscale

# Or download from:
# https://tailscale.com/download
```

### Setup

#### 1. Install on Mac (Server)

```bash
# Install
brew install --cask tailscale

# Start Tailscale
open -a Tailscale

# Authenticate (opens browser)
# Sign in with Google, GitHub, or email
```

#### 2. Install on iPhone

1. Download **Tailscale** from App Store
2. Open app and sign in (same account as Mac)
3. Enable VPN profile when prompted

#### 3. Run Setup Script

```bash
cd <project-root>
./scripts/remote-access/setup-tailscale.sh
```

The script will:
1. ✅ Build the ILS backend
2. ✅ Start the backend on port 9090
3. ✅ Get your Tailscale IP (e.g., `<your-tailscale-ip>`)
4. ✅ Provide connection URL
5. ✅ Monitor the backend process

#### What You'll See

```
═══════════════════════════════════════════════════
  ILS Backend Remote Access Active (Tailscale)
═══════════════════════════════════════════════════

  Local URL:       http://localhost:9090
  Tailscale URL:   http://<your-tailscale-ip>:9090

═══════════════════════════════════════════════════

Configure your iOS app with:
  http://<your-tailscale-ip>:9090

Note: This URL works on any device connected to your Tailscale network
```

#### 4. Configure iOS App

1. Open ILS app on your iPhone
2. Go to **Settings** → **Server Configuration**
3. Enter the Tailscale URL: `http://<your-tailscale-ip>:9090`
4. Tap **Save**

Done! Your iPhone can now access your Mac over Tailscale.

### Features

✅ **Auto-start backend** - Builds and starts ILS backend automatically
✅ **Permanent IP** - Same IP address every time
✅ **Zero configuration** - Works across all your devices
✅ **End-to-end encrypted** - WireGuard VPN
✅ **No public exposure** - Private network only
✅ **Fast** - Direct peer-to-peer when possible
✅ **Cross-platform** - Works on Mac, iPhone, iPad, Windows, Linux, Android

### Advantages

✅ More secure (private network)
✅ Better performance (P2P when possible)
✅ Permanent IP address
✅ Works with all your devices
✅ No URL changes

---

## Comparison

| Feature | Cloudflare Tunnel | Tailscale |
|---------|-------------------|-----------|
| **Setup Time** | 2 minutes | 5 minutes (first time) |
| **Permanent URL** | ❌ (unless named tunnel) | ✅ |
| **Public Access** | ✅ | ❌ (private network) |
| **Security** | HTTPS to Cloudflare | End-to-end encrypted |
| **Performance** | Routes through CF | Direct P2P when possible |
| **Configuration** | None | One-time login |
| **Cost** | Free | Free (up to 100 devices) |
| **Best For** | Quick testing | Production use |

---

## Process Management

### View Logs

```bash
# Backend logs
tail -f .remote-access/backend.log

# Cloudflare tunnel logs
tail -f .remote-access/cloudflare-tunnel.log
```

### Stop Services

Press `Ctrl+C` in the terminal where the script is running. The script will automatically:
- Stop the Cloudflare tunnel (if applicable)
- Stop the ILS backend
- Clean up PID files

### Check Status

```bash
# Check if backend is running
curl http://localhost:9090/health

# Check Tailscale status
tailscale status

# Check Cloudflare tunnel
ps aux | grep cloudflared
```

### Manual Stop

If you need to manually stop processes:

```bash
# Stop backend
kill $(cat .remote-access/backend.pid)

# Stop Cloudflare tunnel
kill $(cat .remote-access/cloudflare-tunnel.pid)
```

---

## Auto-start on System Boot (Optional)

### macOS Launch Agent (Tailscale)

Create `~/Library/LaunchAgents/com.ils.backend.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ils.backend</string>
    <key>ProgramArguments</key>
    <array>
        <string><project-root>/scripts/remote-access/setup-tailscale.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ils-backend.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ils-backend-error.log</string>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.ils.backend.plist
```

---

## Troubleshooting

### Backend Won't Start

**Check logs:**
```bash
tail -f .remote-access/backend.log
```

**Common issues:**
- Port 9090 already in use: Kill existing process
- Build failed: Run `swift build` manually to see errors
- Missing dependencies: Run `swift package resolve`

### Cloudflare Tunnel Issues

**Can't extract URL:**
```bash
# Check tunnel logs
tail -f .remote-access/cloudflare-tunnel.log

# Look for lines containing "trycloudflare.com"
grep "trycloudflare.com" .remote-access/cloudflare-tunnel.log
```

**Tunnel disconnects:**
- Free tunnels may have time limits
- Consider using a named tunnel for stability

### Tailscale Issues

**Can't get IP:**
```bash
# Check Tailscale status
tailscale status

# Try to start Tailscale
open -a Tailscale
```

**iOS app can't connect:**
- Ensure iPhone is connected to Tailscale (VPN icon should show)
- Verify both devices show in `tailscale status`
- Try ping: `ping <tailscale-ip>` from Mac

### Connection Refused from iOS

**Check firewall:**
```bash
# macOS - ensure port 9090 is allowed
# System Preferences → Security & Privacy → Firewall → Firewall Options
```

**Verify backend is listening:**
```bash
lsof -i :9090
```

---

## Security Considerations

### Cloudflare Tunnel
- ✅ HTTPS encryption
- ✅ No open ports
- ⚠️ Public URL (anyone with URL can access)
- 💡 Consider adding authentication to your backend

### Tailscale
- ✅ End-to-end encrypted (WireGuard)
- ✅ Private network only
- ✅ Managed access (you control who joins)
- ✅ No public exposure

### Recommendations

1. **Add authentication** to your ILS backend
2. **Use HTTPS** when possible
3. **Monitor access logs**
4. **Rotate Cloudflare URLs** regularly (if using free tunnel)
5. **Keep Tailscale updated**

---

## iOS App Configuration

The scripts automatically output the connection URL. To configure your iOS app:

### Method 1: Settings UI

1. Open ILS app
2. Tap **Settings** (gear icon in sidebar)
3. Tap **Server Configuration**
4. Enter the URL from script output
5. Tap **Save**

### Method 2: Programmatic (Future Feature)

Add QR code scanning to auto-configure the app:
- Script generates QR code with server URL
- Scan QR code in iOS app
- Auto-configures connection

---

## Advanced: Multiple Backends

Run multiple backends on different ports:

```bash
# Terminal 1: Production on 9090
./scripts/remote-access/setup-tailscale.sh

# Terminal 2: Development on 9091
BACKEND_PORT=9091 ./scripts/remote-access/setup-cloudflare-tunnel.sh
```

---

## FAQ

**Q: Which option should I use?**
A: Use **Cloudflare Tunnel** for quick testing, **Tailscale** for daily use.

**Q: Can I use both at the same time?**
A: Yes! They can run simultaneously.

**Q: Is this secure?**
A: Both are secure. Tailscale is more private (no public exposure).

**Q: What happens if my Mac sleeps?**
A: The backend will stop. Consider disabling sleep or using a dedicated server.

**Q: Can I access from multiple devices?**
A: Yes! Any device with the URL (Cloudflare) or on your Tailscale network can access.

**Q: Does this work on battery?**
A: Yes, but will drain battery faster. Best on AC power.

**Q: Can I use a custom domain?**
A: Yes with Cloudflare named tunnels. Tailscale also supports Magic DNS.

---

## Next Steps

1. ✅ Choose your method (Cloudflare or Tailscale)
2. ✅ Run the setup script
3. ✅ Configure your iOS app
4. ✅ Test the connection
5. ✅ (Optional) Set up auto-start on boot

---

**Created:** 2026-02-06
**For:** ILS iOS Application
**Maintained By:** ILS Development Team
