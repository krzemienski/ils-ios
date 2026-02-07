# Remote Access Scripts

Access your ILS backend from anywhere using Cloudflare Tunnel or Tailscale.

## 🚀 Quick Start

```bash
cd /Users/nick/Desktop/ils-ios
./scripts/remote-access/start-remote-access.sh
```

This interactive script will:
1. Show you the options
2. Let you choose Cloudflare Tunnel or Tailscale
3. Automatically start everything

## 📁 Files

| File | Description |
|------|-------------|
| `start-remote-access.sh` | **⭐ Start here** - Interactive menu |
| `setup-cloudflare-tunnel.sh` | Cloudflare Tunnel + backend |
| `setup-tailscale.sh` | Tailscale + backend |

## 🎯 What Each Script Does

### All Scripts Include:

✅ **Backend Management**
- Builds ILS backend (`swift build`)
- Starts backend on port 9090
- Health check monitoring
- Auto-restart on failure
- Clean shutdown on Ctrl+C

✅ **Process Monitoring**
- Watches backend process
- Monitors tunnel/VPN connection
- Auto-restarts failed processes
- Displays status and URLs

✅ **Logging**
- Backend logs: `.remote-access/backend.log`
- Tunnel logs: `.remote-access/cloudflare-tunnel.log`
- PID tracking for clean shutdown

## 📖 Usage

### Option 1: Interactive (Recommended)

```bash
./scripts/remote-access/start-remote-access.sh

# You'll see a menu:
# 1) Cloudflare Tunnel (Quick Setup)
# 2) Tailscale (Recommended)
# 3) View documentation
# 4) Exit
```

### Option 2: Direct Script

```bash
# Cloudflare Tunnel
./scripts/remote-access/setup-cloudflare-tunnel.sh

# Tailscale
./scripts/remote-access/setup-tailscale.sh
```

## 🎨 What You'll See

### Cloudflare Tunnel

```
═══════════════════════════════════════════════════
  ILS Backend Remote Access Active
═══════════════════════════════════════════════════

  Local URL:  http://localhost:9090
  Remote URL: https://abc-def-ghi.trycloudflare.com

═══════════════════════════════════════════════════

Configure your iOS app with:
  https://abc-def-ghi.trycloudflare.com

Press Ctrl+C to stop
```

### Tailscale

```
═══════════════════════════════════════════════════
  ILS Backend Remote Access Active (Tailscale)
═══════════════════════════════════════════════════

  Local URL:       http://localhost:9090
  Tailscale URL:   http://100.101.102.103:9090

═══════════════════════════════════════════════════

Configure your iOS app with:
  http://100.101.102.103:9090

Note: This URL works on any device connected to your Tailscale network
```

## 🔧 Prerequisites

### For Cloudflare Tunnel:

```bash
brew install cloudflared
```

### For Tailscale:

```bash
brew install --cask tailscale
# Then open Tailscale app and sign in
```

## 🛑 Stopping Services

Press `Ctrl+C` in the terminal. The scripts will automatically:
- Stop the backend
- Stop the tunnel
- Clean up PID files

## 📊 Monitoring

### View Logs

```bash
# Backend logs
tail -f .remote-access/backend.log

# Cloudflare tunnel logs (if using)
tail -f .remote-access/cloudflare-tunnel.log
```

### Check Status

```bash
# Backend health
curl http://localhost:9090/health

# Process status
ps aux | grep ILSBackend
ps aux | grep cloudflared

# Tailscale status
tailscale status
```

## 🔍 Process Flow

```
┌─────────────────────────────────────────┐
│  1. Script starts                       │
│  2. Creates .remote-access/ directory   │
│  3. Checks prerequisites installed      │
│  4. Runs: swift build --product ILSBackend
│  5. Starts: swift run ILSBackend       │
│  6. Waits for health check (30s max)   │
│  7. Starts tunnel/gets Tailscale IP    │
│  8. Displays connection URLs            │
│  9. Monitors processes (auto-restart)  │
│  10. Ctrl+C → clean shutdown            │
└─────────────────────────────────────────┘
```

## 📂 Generated Files

```
.remote-access/
├── backend.pid              # Backend process ID
├── backend.log              # Backend output logs
├── cloudflare-tunnel.pid    # Tunnel process ID (CF only)
├── cloudflare-tunnel.log    # Tunnel logs (CF only)
├── cloudflare-config.yml    # Tunnel config (CF only)
├── tunnel-url.txt           # Public URL (CF only)
└── tailscale-ip.txt         # Tailscale IP (TS only)
```

## ⚠️ Troubleshooting

### Port 9090 Already in Use

```bash
# Find and kill process
lsof -ti :9090 | xargs kill -9
```

### Backend Won't Start

```bash
# Check logs
tail -f .remote-access/backend.log

# Try manual build
cd /Users/nick/Desktop/ils-ios
swift build --product ILSBackend
```

### Cloudflare Tunnel Issues

```bash
# Check if cloudflared is installed
which cloudflared

# View tunnel logs
tail -f .remote-access/cloudflare-tunnel.log

# Manual tunnel test
cloudflared tunnel --url http://localhost:9090
```

### Tailscale Issues

```bash
# Check Tailscale status
tailscale status

# Restart Tailscale (macOS)
open -a Tailscale

# Get IP manually
tailscale ip -4
```

## 🔐 Security Notes

- **Cloudflare Tunnel**: Public URL, anyone with link can access
- **Tailscale**: Private network, only your devices can access
- **Recommendation**: Use Tailscale for production, Cloudflare for quick tests

## 📱 iOS App Configuration

After starting the script, configure your iOS app:

1. Open ILS app
2. Settings → Server Configuration
3. Enter the URL from script output
4. Tap Save

Done!

## 🎯 Tips

- **Quick test**: Use Cloudflare Tunnel
- **Daily use**: Use Tailscale
- **Auto-start**: See `REMOTE_ACCESS.md` for launch agent setup
- **Multiple instances**: Run on different ports with `BACKEND_PORT=9091 ./script.sh`

## 📚 Documentation

For complete documentation, see:
- `../../REMOTE_ACCESS.md` - Full guide with comparisons and advanced setup

---

**Need help?** Check the full documentation or open an issue.
