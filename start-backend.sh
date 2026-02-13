#!/bin/bash

# Start backend server for macOS app E2E testing
# Usage: ./start-backend.sh

set -e

echo "🚀 Starting ILS Backend Server for macOS App Testing"
echo ""

# Change to project root
cd /Users/nick/Desktop/ils-ios

# Verify we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Package.swift not found. Are you in the project root?"
    exit 1
fi

# Check if port 9999 is already in use
if lsof -i :9999 > /dev/null 2>&1; then
    echo "⚠️  Port 9999 is already in use:"
    lsof -i :9999
    echo ""
    read -p "Kill existing process and restart? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        PID=$(lsof -t -i :9999)
        echo "🔪 Killing process $PID..."
        kill -9 $PID
        sleep 1
    else
        echo "❌ Aborted. Please stop the existing process manually."
        exit 1
    fi
fi

# Verify database exists
if [ ! -f "ils.sqlite" ]; then
    echo "⚠️  Warning: ils.sqlite not found in project root"
    echo "   Backend will create new empty database"
fi

# Start backend server
echo "📡 Starting backend on port 9999..."
echo "   (Press Ctrl+C to stop)"
echo ""

PORT=9999 swift run ILSBackend

# This line only runs if swift run is interrupted
echo ""
echo "👋 Backend server stopped"
