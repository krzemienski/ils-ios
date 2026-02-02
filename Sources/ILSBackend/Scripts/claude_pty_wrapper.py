#!/usr/bin/env python3
"""
PTY wrapper for Claude CLI to provide a TTY when running from non-interactive contexts.
This solves the issue where Claude CLI hangs without a TTY even with -p flag.
"""
import os
import sys
import pty
import select
import subprocess

def run_with_pty(args):
    """Run a command with a pseudo-terminal."""
    # Create a pseudo-terminal
    master_fd, slave_fd = pty.openpty()

    # Fork a child process
    pid = os.fork()

    if pid == 0:
        # Child process
        os.close(master_fd)

        # Create a new session and set controlling terminal
        os.setsid()

        # Set the slave as stdin, stdout, stderr
        os.dup2(slave_fd, 0)
        os.dup2(slave_fd, 1)
        os.dup2(slave_fd, 2)

        if slave_fd > 2:
            os.close(slave_fd)

        # Execute claude
        os.execvp(args[0], args)
    else:
        # Parent process
        os.close(slave_fd)

        # Read from master and write to stdout
        try:
            while True:
                ready, _, _ = select.select([master_fd], [], [], 0.1)
                if ready:
                    try:
                        data = os.read(master_fd, 4096)
                        if not data:
                            break
                        sys.stdout.buffer.write(data)
                        sys.stdout.buffer.flush()
                    except OSError:
                        break

                # Check if child is still running
                result = os.waitpid(pid, os.WNOHANG)
                if result[0] != 0:
                    # Child exited, read any remaining data
                    while True:
                        ready, _, _ = select.select([master_fd], [], [], 0.1)
                        if not ready:
                            break
                        try:
                            data = os.read(master_fd, 4096)
                            if not data:
                                break
                            sys.stdout.buffer.write(data)
                            sys.stdout.buffer.flush()
                        except OSError:
                            break
                    break
        finally:
            os.close(master_fd)

        # Get exit status
        _, status = os.waitpid(pid, 0)
        return os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: claude_pty_wrapper.py <claude_path> [args...]", file=sys.stderr)
        sys.exit(1)

    sys.exit(run_with_pty(sys.argv[1:]))
