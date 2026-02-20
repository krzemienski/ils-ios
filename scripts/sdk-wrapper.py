#!/usr/bin/env python3
"""
SDK Wrapper for ILS Backend Claude Execution (Python Agent SDK)

Spawned by ClaudeExecutorService (Swift) as:
    python3 scripts/sdk-wrapper.py '<json-config>'

Uses claude-agent-sdk (pip) which wraps the Claude CLI, inheriting
OAuth auth from the host environment. No ANTHROPIC_API_KEY needed.

Outputs NDJSON to stdout matching the CLIMessage format:
- System:    {"type":"system","subtype":"init","session_id":"...","model":"...","tools":[]}
- Delta:     {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"..."}}
- Assistant: {"type":"assistant","message":{...}}
- Result:    {"type":"result","subtype":"success","session_id":"...","total_cost_usd":0.01,"usage":{...}}
- Error:     {"type":"error","error":{"message":"...","type":"..."}}
"""

import asyncio
import json
import sys
import uuid

import claude_agent_sdk
from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ResultMessage,
    SystemMessage,
    TextBlock,
    ThinkingBlock,
    ToolResultBlock,
    ToolUseBlock,
)


def emit(obj: dict) -> None:
    """Write a single NDJSON line to stdout."""
    sys.stdout.write(json.dumps(obj, default=str) + "\n")
    sys.stdout.flush()


def emit_error(message: str, error_type: str = "sdk_error") -> None:
    """Emit an error message and exit."""
    emit({"type": "error", "error": {"message": message, "type": error_type}})
    sys.exit(1)


async def run(config: dict) -> None:
    """Execute a Claude query using the Agent SDK and stream NDJSON output."""
    prompt = config.get("prompt", "")
    opts = config.get("options", {})

    session_id = opts.get("sessionId", str(uuid.uuid4()))
    model = opts.get("model")
    system_prompt = opts.get("systemPrompt")
    cwd = opts.get("cwd")
    max_turns = opts.get("maxTurns", 1)

    # Build Agent SDK options
    agent_options = ClaudeAgentOptions(
        permission_mode="bypassPermissions",
        max_turns=max_turns,
        include_partial_messages=True,
    )

    if model:
        agent_options.model = model
    if system_prompt:
        agent_options.system_prompt = system_prompt
    if cwd:
        agent_options.cwd = cwd

    # Track accumulated text for the assistant message
    full_text = ""
    actual_model = model or "unknown"

    try:
        async for message in claude_agent_sdk.query(
            prompt=prompt,
            options=agent_options,
        ):
            if isinstance(message, SystemMessage):
                # Emit system init message
                actual_model = getattr(message, "model", actual_model) or actual_model
                sdk_session_id = getattr(message, "session_id", session_id) or session_id

                # Extract data fields if available
                data = getattr(message, "data", {}) or {}
                emit({
                    "type": "system",
                    "subtype": "init",
                    "session_id": sdk_session_id,
                    "model": data.get("model", actual_model),
                    "tools": data.get("tools", []),
                    "mcp_servers": data.get("mcp_servers", []),
                    "cwd": data.get("cwd", cwd or ""),
                })

            elif isinstance(message, AssistantMessage):
                # Extract model info
                msg_model = getattr(message, "model", None)
                if msg_model:
                    actual_model = msg_model

                # NOTE: Do NOT emit content_block_delta here — StreamEvent
                # (from include_partial_messages=True) already streams deltas
                # in real-time. This handler only emits the final assistant message.

                # Emit the full assistant message
                content_blocks = []
                for block in message.content:
                    if isinstance(block, TextBlock):
                        content_blocks.append({"type": "text", "text": block.text})
                    elif isinstance(block, ThinkingBlock):
                        content_blocks.append({"type": "thinking", "thinking": block.thinking})
                    elif isinstance(block, ToolUseBlock):
                        content_blocks.append({
                            "type": "tool_use",
                            "id": getattr(block, "id", ""),
                            "name": getattr(block, "name", ""),
                            "input": getattr(block, "input", {}),
                        })
                    elif isinstance(block, ToolResultBlock):
                        content_blocks.append({
                            "type": "tool_result",
                            "tool_use_id": getattr(block, "tool_use_id", ""),
                            "content": getattr(block, "content", ""),
                        })

                emit({
                    "type": "assistant",
                    "message": {
                        "id": str(uuid.uuid4()),
                        "type": "message",
                        "role": "assistant",
                        "content": content_blocks,
                        "model": actual_model,
                    },
                })

            elif isinstance(message, ResultMessage):
                # Emit result with cost and usage
                cost = getattr(message, "total_cost_usd", 0) or 0
                is_error = getattr(message, "is_error", False)
                result_session = getattr(message, "session_id", session_id) or session_id
                subtype = getattr(message, "subtype", "success")
                duration_ms = getattr(message, "duration_ms", 0) or 0
                duration_api_ms = getattr(message, "duration_api_ms", 0) or 0

                # Extract usage if available
                usage = getattr(message, "usage", None)
                usage_dict = {}
                if usage and isinstance(usage, dict):
                    usage_dict = usage
                elif usage:
                    usage_dict = {
                        "input_tokens": getattr(usage, "input_tokens", 0),
                        "output_tokens": getattr(usage, "output_tokens", 0),
                    }

                emit({
                    "type": "result",
                    "subtype": subtype,
                    "session_id": result_session,
                    "total_cost_usd": cost,
                    "is_error": is_error,
                    "duration_ms": duration_ms,
                    "duration_api_ms": duration_api_ms,
                    "usage": usage_dict,
                })

            else:
                # StreamEvent or unknown message type — check for partial content
                # StreamEvent has an 'event' attribute with raw API events
                event_data = getattr(message, "event", None)
                if event_data and isinstance(event_data, dict):
                    event_type = event_data.get("type", "")
                    if event_type == "content_block_delta":
                        delta = event_data.get("delta", {})
                        if delta.get("type") == "text_delta":
                            text = delta.get("text", "")
                            full_text += text
                            emit({
                                "type": "content_block_delta",
                                "index": event_data.get("index", 0),
                                "delta": {"type": "text_delta", "text": text},
                            })

    except Exception as exc:
        emit_error(str(exc))


def main() -> None:
    """Parse config from CLI argument and run the query."""
    if len(sys.argv) < 2:
        emit_error(
            "No config argument provided. Usage: python3 sdk-wrapper.py '<json>'",
            "invalid_request",
        )

    try:
        config = json.loads(sys.argv[1])
    except json.JSONDecodeError as exc:
        emit_error(f"Failed to parse config JSON: {exc}", "invalid_request")
        return  # unreachable but satisfies type checker

    asyncio.run(run(config))


if __name__ == "__main__":
    main()
