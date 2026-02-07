# Remote Access Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  User's Mac (Home Server)                               │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  start-remote-access.sh (Interactive Menu)       │  │
│  │  - Choose Cloudflare or Tailscale                │  │
│  └────────┬───────────────────────┬─────────────────┘  │
│           │                       │                     │
│           ▼                       ▼                     │
│  ┌─────────────────────┐  ┌─────────────────────────┐ │
│  │  Cloudflare Tunnel  │  │  Tailscale              │ │
│  │  Script             │  │  Script                 │ │
│  └─────────┬───────────┘  └─────────┬───────────────┘ │
│            │                         │                  │
│            └────────┬────────────────┘                  │
│                     ▼                                   │
│          ┌──────────────────────┐                      │
│          │  Backend Startup     │                      │
│          │  swift build         │                      │
│          │  swift run ILSBackend│                      │
│          └─────────┬────────────┘                      │
│                    ▼                                    │
│          ┌──────────────────────┐                      │
│          │  ILS Backend         │                      │
│          │  Port: 9090          │                      │
│          │  Health: /health     │                      │
│          └─────────┬────────────┘                      │
│                    │                                    │
└────────────────────┼────────────────────────────────────┘
                     │
                     │
        ┌────────────┴──────────────┐
        │                           │
        ▼                           ▼
┌───────────────────┐      ┌────────────────────┐
│  Cloudflare Edge  │      │  Tailscale Network │
│  Public HTTPS URL │      │  Private VPN       │
│  (Temporary)      │      │  (Permanent IP)    │
└────────┬──────────┘      └────────┬───────────┘
         │                          │
         │                          │
         └────────┬─────────────────┘
                  │
                  ▼
         ┌────────────────┐
         │  iOS Device    │
         │  ILS App       │
         │  Configure URL │
         └────────────────┘
```

## Script Execution Flow

### Cloudflare Tunnel

```
./setup-cloudflare-tunnel.sh
           │
           ├─── Check Prerequisites
           │    └─── Is cloudflared installed?
           │
           ├─── Build Backend
           │    └─── swift build --product ILSBackend
           │
           ├─── Start Backend
           │    ├─── Kill existing on port 9090
           │    ├─── swift run ILSBackend &
           │    ├─── Save PID → .remote-access/backend.pid
           │    └─── Log to → .remote-access/backend.log
           │
           ├─── Wait for Backend
           │    └─── curl http://localhost:9090/health
           │         (30s timeout, check every 1s)
           │
           ├─── Start Tunnel
           │    ├─── Create config.yml
           │    ├─── cloudflared tunnel --url http://localhost:9090 &
           │    ├─── Save PID → .remote-access/cloudflare-tunnel.pid
           │    └─── Log to → .remote-access/cloudflare-tunnel.log
           │
           ├─── Extract URL
           │    ├─── Parse logs for "https://...trycloudflare.com"
           │    └─── Save to → .remote-access/tunnel-url.txt
           │
           ├─── Display Info
           │    ├─── Local URL: http://localhost:9090
           │    └─── Remote URL: https://abc-def-ghi.trycloudflare.com
           │
           └─── Monitor Loop (every 10s)
                ├─── Check backend alive
                ├─── Check tunnel alive
                ├─── Run health check
                ├─── Auto-restart if failed
                └─── Loop until Ctrl+C
```

### Tailscale

```
./setup-tailscale.sh
           │
           ├─── Check Prerequisites
           │    ├─── Is tailscale installed?
           │    └─── Is tailscale running?
           │
           ├─── Get Tailscale IP
           │    ├─── tailscale ip -4
           │    └─── Save to → .remote-access/tailscale-ip.txt
           │
           ├─── Build Backend
           │    └─── swift build --product ILSBackend
           │
           ├─── Start Backend
           │    ├─── Kill existing on port 9090
           │    ├─── swift run ILSBackend &
           │    ├─── Save PID → .remote-access/backend.pid
           │    └─── Log to → .remote-access/backend.log
           │
           ├─── Wait for Backend
           │    └─── curl http://localhost:9090/health
           │         (30s timeout, check every 1s)
           │
           ├─── Display Info
           │    ├─── Local URL: http://localhost:9090
           │    ├─── Tailscale URL: http://<tailscale-ip>:9090
           │    └─── Tailscale status
           │
           └─── Monitor Loop (every 10s)
                ├─── Check backend alive
                ├─── Check tailscale connected
                ├─── Run health check
                ├─── Auto-restart if failed
                └─── Loop until Ctrl+C
```

## Data Flow

### Cloudflare Tunnel Path

```
iPhone (anywhere)
    │
    │ HTTPS Request
    │ GET https://abc-def-ghi.trycloudflare.com/api/v1/sessions
    │
    ▼
Cloudflare Edge (nearest datacenter)
    │
    │ TLS Termination
    │ DDoS Protection
    │
    ▼
Cloudflare Tunnel (cloudflared on Mac)
    │
    │ HTTP (local)
    │ GET http://localhost:9090/api/v1/sessions
    │
    ▼
ILS Backend (Port 9090)
    │
    │ Process request
    │ Query SQLite database
    │
    ▼
Response back through tunnel
```

### Tailscale Path

```
iPhone (on Tailscale network)
    │
    │ HTTP Request (WireGuard encrypted)
    │ GET http://100.101.102.103:9090/api/v1/sessions
    │
    ▼
Tailscale Network (P2P or relay)
    │
    │ Direct connection when possible
    │ DERP relay when NAT traversal fails
    │
    ▼
Mac (Tailscale IP: 100.101.102.103)
    │
    │ HTTP (local after decryption)
    │ GET http://localhost:9090/api/v1/sessions
    │
    ▼
ILS Backend (Port 9090)
    │
    │ Process request
    │ Query SQLite database
    │
    ▼
Response back through Tailscale
```

## Process Management

### Backend Process

```
swift run ILSBackend
    │
    ├─── Process ID saved to .remote-access/backend.pid
    │
    ├─── stdout/stderr → .remote-access/backend.log
    │
    ├─── Listens on port 9090
    │
    ├─── Health endpoint: GET /health
    │
    └─── Monitored by parent script
         ├─── Health check every 10s
         ├─── Auto-restart if dies
         └─── SIGTERM on Ctrl+C
```

### Tunnel Process (Cloudflare)

```
cloudflared tunnel --url http://localhost:9090
    │
    ├─── Process ID saved to .remote-access/cloudflare-tunnel.pid
    │
    ├─── stdout/stderr → .remote-access/cloudflare-tunnel.log
    │
    ├─── Connects to Cloudflare edge
    │
    ├─── Gets random subdomain: abc-def-ghi.trycloudflare.com
    │
    └─── Monitored by parent script
         ├─── Process check every 10s
         ├─── Auto-restart if dies
         └─── SIGTERM on Ctrl+C
```

## File System Layout

```
/Users/nick/Desktop/ils-ios/
│
├── scripts/
│   └── remote-access/
│       ├── start-remote-access.sh       ⭐ Entry point
│       ├── setup-cloudflare-tunnel.sh
│       ├── setup-tailscale.sh
│       ├── README.md
│       └── ARCHITECTURE.md             (this file)
│
├── .remote-access/                      Created by scripts
│   ├── backend.pid                      Backend process ID
│   ├── backend.log                      Backend stdout/stderr
│   ├── cloudflare-tunnel.pid            Tunnel PID (CF only)
│   ├── cloudflare-tunnel.log            Tunnel logs (CF only)
│   ├── cloudflare-config.yml            Tunnel config (CF only)
│   ├── tunnel-url.txt                   Public URL (CF only)
│   └── tailscale-ip.txt                 Tailscale IP (TS only)
│
├── REMOTE_ACCESS.md                     Full documentation
└── REMOTE_ACCESS_SUMMARY.md             Quick summary
```

## Monitoring Architecture

```
Monitor Loop (runs every 10 seconds)
    │
    ├─── Backend Check
    │    ├─── ps -p <backend-pid>
    │    ├─── If dead → restart backend
    │    └─── curl http://localhost:9090/health
    │         └─── If fails → log warning
    │
    ├─── Tunnel/VPN Check (Cloudflare)
    │    ├─── ps -p <tunnel-pid>
    │    └─── If dead → restart tunnel
    │
    └─── Tailscale Check
         ├─── tailscale status
         └─── If disconnected → log warning
```

## Shutdown Sequence

```
User presses Ctrl+C
    │
    ├─── trap EXIT INT TERM caught
    │
    ├─── cleanup() function called
    │
    ├─── Stop Tunnel (if Cloudflare)
    │    ├─── Read PID from cloudflare-tunnel.pid
    │    ├─── kill <tunnel-pid>
    │    ├─── Wait 2 seconds
    │    ├─── kill -9 <tunnel-pid> (force)
    │    └─── rm cloudflare-tunnel.pid
    │
    ├─── Stop Backend
    │    ├─── Read PID from backend.pid
    │    ├─── kill <backend-pid>
    │    ├─── Wait 2 seconds
    │    ├─── kill -9 <backend-pid> (force)
    │    └─── rm backend.pid
    │
    └─── Exit script
```

## Security Architecture

### Cloudflare Tunnel

```
iPhone
  │
  │ ✅ HTTPS (TLS 1.3)
  │ ✅ Encrypted in transit
  │
  ▼
Cloudflare Edge
  │
  │ ⚠️ TLS terminated here
  │ ⚠️ Cloudflare can see plaintext
  │ ✅ DDoS protection
  │
  ▼
Cloudflare Tunnel
  │
  │ ⚠️ Unencrypted localhost
  │ ✅ No open firewall ports
  │
  ▼
Backend (localhost:9090)
```

### Tailscale

```
iPhone
  │
  │ ✅ WireGuard encryption
  │ ✅ End-to-end encrypted
  │ ✅ No intermediary can decrypt
  │
  ▼
Tailscale Network
  │
  │ ✅ P2P when possible
  │ ✅ DERP relay when needed
  │ ✅ Zero-trust network
  │
  ▼
Mac
  │
  │ ✅ Unencrypted localhost
  │ ✅ No open firewall ports
  │ ✅ Private network only
  │
  ▼
Backend (localhost:9090)
```

## Comparison: Architectural Differences

| Aspect | Cloudflare | Tailscale |
|--------|------------|-----------|
| **Path** | iPhone → CF Edge → Tunnel → Backend | iPhone → TS Network → Mac → Backend |
| **Hops** | 3-4 | 1-2 (often P2P) |
| **Encryption** | HTTPS (TLS) | WireGuard (end-to-end) |
| **Latency** | Routes through CF | Direct when P2P |
| **Visibility** | CF sees traffic | Zero visibility |
| **Public Access** | Yes (URL) | No (private network) |
| **Firewall** | Not needed | Not needed |

---

This architecture enables:
- ✅ Zero-configuration setup
- ✅ Automatic backend management
- ✅ Process monitoring and recovery
- ✅ Clean shutdown handling
- ✅ Secure remote access
- ✅ Flexible deployment options
