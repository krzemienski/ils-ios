#!/usr/bin/env python3
"""Bridge between Swift ClaudeExecutorService and Claude Agent SDK.

Accepts a JSON config via argv[1], runs claude_agent_sdk.query(),
and emits NDJSON lines on stdout matching the CLIMessage format
expected by CLIMessageConverter.swift.

Usage:
    python3 sdk-wrapper.py '{"prompt":"Hello","options":{}}'
"""

import sys
import json
import asyncio


# Non-content event types from the SDK that should be silently skipped.
# These are protocol-level events, not user-facing messages.
SKIP_EVENT_TYPES = frozenset({
    "rate_limit_event",
    "rate_limit",
    "ping",
    "heartbeat",
    "error",
    "content_block_start",
    "content_block_stop",
    "content_block_delta",
    "message_start",
    "message_stop",
    "message_delta",
})


def emit(obj):
    """Write a JSON object as an NDJSON line to stdout."""
    line = json.dumps(obj, separators=(",", ":"))
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


def convert_content_block(block):
    """Convert a Claude Agent SDK content block to CLIMessage-compatible dict.

    The Anthropic SDK uses concrete classes (TextBlock, ThinkingBlock, ToolUseBlock,
    ToolResultBlock) whose .type attribute may not resolve via getattr in all SDK
    versions. Fall back to class name inspection when .type is None.
    """
    block_type = getattr(block, "type", None)

    # Fallback: derive type from class name (e.g., TextBlock -> "text")
    if block_type is None:
        class_name = type(block).__name__.lower()
        if "text" in class_name and "tool" not in class_name:
            block_type = "text"
        elif "thinking" in class_name:
            block_type = "thinking"
        elif "tooluse" in class_name or "tool_use" in class_name:
            block_type = "tool_use"
        elif "toolresult" in class_name or "tool_result" in class_name:
            block_type = "tool_result"

    if block_type == "text":
        return {"type": "text", "text": getattr(block, "text", str(block))}
    elif block_type == "tool_use":
        return {
            "type": "tool_use",
            "id": getattr(block, "id", ""),
            "name": getattr(block, "name", ""),
            "input": getattr(block, "input", {}),
        }
    elif block_type == "tool_result":
        return {
            "type": "tool_result",
            "tool_use_id": getattr(block, "tool_use_id", ""),
            "content": getattr(block, "content", ""),
            "is_error": getattr(block, "is_error", False),
        }
    elif block_type == "thinking":
        return {"type": "thinking", "thinking": getattr(block, "thinking", "")}
    else:
        # Last resort: extract text content if available, otherwise repr
        text = getattr(block, "text", None) or getattr(block, "thinking", None) or str(block)
        return {"type": "text", "text": text}


def build_options(sdk_opts):
    """Build ClaudeAgentOptions from SDK options dict."""
    from claude_agent_sdk import ClaudeAgentOptions

    kwargs = {}

    if sdk_opts.get("model"):
        kwargs["model"] = sdk_opts["model"]
    if sdk_opts.get("max_turns"):
        kwargs["max_turns"] = sdk_opts["max_turns"]
    if sdk_opts.get("allowed_tools"):
        kwargs["allowed_tools"] = sdk_opts["allowed_tools"]
    if sdk_opts.get("disallowed_tools"):
        kwargs["disallowed_tools"] = sdk_opts["disallowed_tools"]
    if sdk_opts.get("permission_mode"):
        kwargs["permission_mode"] = sdk_opts["permission_mode"]
    if sdk_opts.get("system_prompt"):
        kwargs["system_prompt"] = sdk_opts["system_prompt"]
    if sdk_opts.get("append_system_prompt"):
        kwargs["append_system_prompt"] = sdk_opts["append_system_prompt"]
    if sdk_opts.get("resume"):
        kwargs["resume"] = sdk_opts["resume"]
    if sdk_opts.get("continue_conversation"):
        kwargs["continue_conversation"] = sdk_opts["continue_conversation"]
    if sdk_opts.get("fork_session"):
        kwargs["fork_session"] = sdk_opts["fork_session"]
    if sdk_opts.get("session_id"):
        kwargs["session_id"] = sdk_opts["session_id"]
    if sdk_opts.get("cwd"):
        kwargs["cwd"] = sdk_opts["cwd"]
    if sdk_opts.get("include_partial_messages"):
        kwargs["include_partial_messages"] = sdk_opts["include_partial_messages"]
    if sdk_opts.get("max_budget_usd"):
        kwargs["max_budget_usd"] = sdk_opts["max_budget_usd"]

    return ClaudeAgentOptions(**kwargs) if kwargs else ClaudeAgentOptions()


async def run(config):
    """Run a Claude Agent SDK query and emit NDJSON results."""
    from claude_agent_sdk import query

    prompt = config.get("prompt", "")
    sdk_opts = config.get("options", {})
    options = build_options(sdk_opts)

    session_id = sdk_opts.get("session_id", "sdk-session")

    # Emit system init
    emit({
        "type": "system",
        "subtype": "init",
        "data": {"session_id": session_id, "tools": []},
    })

    got_content = False
    got_result = False

    try:
        async for message in query(prompt=prompt, options=options):
            msg_type = getattr(message, "type", None) or type(message).__name__.lower()
            msg_type_lower = msg_type.lower()

            # Skip known non-content protocol events silently
            if msg_type in SKIP_EVENT_TYPES or msg_type_lower in SKIP_EVENT_TYPES:
                continue

            if "assistant" in msg_type_lower:
                content_blocks = []
                if hasattr(message, "content"):
                    for block in message.content:
                        content_blocks.append(convert_content_block(block))

                if content_blocks:
                    got_content = True

                emit({
                    "type": "assistant",
                    "message": {
                        "role": "assistant",
                        "content": content_blocks,
                        "model": getattr(message, "model", None),
                    },
                })

            elif "result" in msg_type_lower:
                got_result = True
                result = {
                    "type": "result",
                    "subtype": "error" if getattr(message, "is_error", False) else "success",
                    "is_error": getattr(message, "is_error", False),
                    "session_id": getattr(message, "session_id", session_id),
                    "total_cost_usd": getattr(message, "total_cost_usd", 0.0) or 0.0,
                }

                if hasattr(message, "usage") and message.usage:
                    usage = message.usage
                    result["usage"] = {
                        "input_tokens": getattr(usage, "input_tokens", 0),
                        "output_tokens": getattr(usage, "output_tokens", 0),
                        "cache_read_input_tokens": getattr(usage, "cache_read_input_tokens", 0),
                        "cache_creation_input_tokens": getattr(usage, "cache_creation_input_tokens", 0),
                    }

                emit(result)

            elif "user" in msg_type_lower:
                content_blocks = []
                if hasattr(message, "content"):
                    for block in message.content:
                        content_blocks.append(convert_content_block(block))

                emit({
                    "type": "user",
                    "message": {"role": "user", "content": content_blocks},
                })

            elif "system" in msg_type_lower:
                pass  # Additional system messages during conversation

            else:
                # Unknown type — log to stderr but don't error out
                print(f"sdk-wrapper: unknown message type: {msg_type}", file=sys.stderr)

    except Exception as e:
        error_msg = str(e).lower()

        # The Claude Agent SDK raises exceptions for unknown message types
        # (e.g. rate_limit_event) during async iteration. If we already
        # received valid content, treat these as benign — emit a synthetic
        # success result instead of an error.
        is_benign = (
            "unknown message type" in error_msg
            or "rate_limit" in error_msg
        )

        if is_benign and got_content:
            print(f"sdk-wrapper: ignoring benign SDK exception: {e}", file=sys.stderr)
            if not got_result:
                emit({
                    "type": "result",
                    "subtype": "success",
                    "is_error": False,
                    "session_id": session_id,
                    "total_cost_usd": 0.0,
                })
        else:
            emit({
                "type": "result",
                "subtype": "error",
                "is_error": True,
                "session_id": session_id,
                "total_cost_usd": 0.0,
                "error": str(e),
            })


def main():
    if len(sys.argv) < 2:
        print("Usage: sdk-wrapper.py '<json-config>'", file=sys.stderr)
        sys.exit(1)

    try:
        config = json.loads(sys.argv[1])
    except json.JSONDecodeError as e:
        emit({
            "type": "result",
            "subtype": "error",
            "is_error": True,
            "total_cost_usd": 0.0,
            "error": f"Invalid JSON config: {e}",
        })
        sys.exit(1)

    asyncio.run(run(config))


if __name__ == "__main__":
    main()
