# Task: Create ClaudeExecutorService

## Description
Create the service that executes Claude Code CLI commands using Swift's Process API. This is the core integration point that spawns claude processes and captures their streaming JSON output.

## Background
The backend executes Claude Code via the CLI using `--output-format stream-json`. The service needs to handle process lifecycle, capture stdout/stderr, and parse streaming JSON lines in real-time.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Additional References:**
- .sop/planning/research/claude-code-features.md (for CLI flags and output format)

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create ClaudeExecutorService actor for thread-safe execution
2. Detect Claude CLI path (check common locations: /usr/local/bin, ~/.claude/local, etc.)
3. Implement execute() method that spawns Process with arguments
4. Support --output-format stream-json, --model, --permission-mode flags
5. Support --resume for continuing sessions
6. Implement real-time stdout line reading with AsyncSequence
7. Parse each line as JSON and decode to StreamMessage
8. Handle process termination and error conditions
9. Support working directory (--cwd) for project context

## Dependencies
- ILSShared StreamMessage models
- Foundation Process API

## Implementation Approach
1. Create Sources/ILSBackend/Services/ClaudeExecutorService.swift
2. Define actor with claude CLI path property
3. Implement path detection checking multiple locations
4. Create ExecutionOptions struct for configuration
5. Implement execute() returning AsyncThrowingStream<StreamMessage, Error>
6. Set up Process with correct arguments and environment
7. Create pipe for stdout and read lines asynchronously
8. Parse each line as StreamMessage, yielding to stream
9. Handle stderr for error reporting
10. Verify compilation

## Acceptance Criteria

1. **CLI Path Detection**
   - Given the ClaudeExecutorService
   - When initialized
   - Then it locates the claude CLI or throws descriptive error

2. **Process Arguments**
   - Given execution options with model and permission mode
   - When building process arguments
   - Then correct flags are included (--output-format, --model, --permission-mode)

3. **Streaming Output**
   - Given a running claude process
   - When stdout produces JSON lines
   - Then each line is parsed and yielded as StreamMessage

4. **Session Resume**
   - Given a sessionId in options
   - When executing
   - Then --resume flag is included with session ID

5. **Compilation Success**
   - Given the ClaudeExecutorService
   - When running `swift build --target ILSBackend`
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: High
- **Labels**: Backend, Vapor, Services, Process, Streaming, Claude CLI
- **Required Skills**: Swift Process API, AsyncSequence, JSON parsing, Error handling
