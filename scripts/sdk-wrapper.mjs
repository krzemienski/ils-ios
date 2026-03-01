#!/usr/bin/env node
/**
 * sdk-wrapper.mjs — Agent SDK bridge for ILS backend
 *
 * Spawned by ClaudeExecutorService.executeWithSDK() as:
 *   node scripts/sdk-wrapper.mjs '<json-config>'
 *
 * Accepts a JSON configuration object, runs Claude via the Agent SDK,
 * and streams NDJSON to stdout in the same format as
 * `claude -p --output-format stream-json` (snake_case keys).
 *
 * Config shape:
 *   {
 *     prompt: string,
 *     options?: {
 *       model?, maxTurns?, systemPrompt?, appendSystemPrompt?,
 *       allowedTools?, disallowedTools?, permissionMode?,
 *       resume?, continueConversation?, forkSession?,
 *       sessionId?, cwd?, includePartialMessages?
 *     },
 *     images?: Array<{ mediaType: string, data: string }>  // base64
 *   }
 *
 * Dependencies:
 *   npm install @anthropic-ai/claude-agent-sdk
 *   (installed globally alongside Claude Code, or in project node_modules)
 */

// --- Verify SDK is available ------------------------------------------------
let query;
try {
  ({ query } = await import("@anthropic-ai/claude-agent-sdk"));
} catch (err) {
  process.stderr.write(
    "sdk-wrapper: @anthropic-ai/claude-agent-sdk not found.\n" +
      "Install it with: npm install -g @anthropic-ai/claude-agent-sdk\n" +
      `Detail: ${err.message}\n`
  );
  process.exit(1);
}

// --- Parse JSON config argument ---------------------------------------------
const configArg = process.argv[2];
if (!configArg) {
  process.stderr.write("sdk-wrapper: missing JSON config argument\n");
  process.exit(1);
}

let config;
try {
  config = JSON.parse(configArg);
} catch (err) {
  process.stderr.write(
    `sdk-wrapper: failed to parse config JSON: ${err.message}\n`
  );
  process.exit(1);
}

const { prompt = "", options = {}, images } = config;

// --- Build prompt content ---------------------------------------------------
// Plain string when no images; content-block array when images are attached.
let content;
if (Array.isArray(images) && images.length > 0) {
  content = [
    { type: "text", text: prompt },
    ...images.map((img) => ({
      type: "image",
      source: {
        type: "base64",
        media_type: img.mediaType,
        data: img.data,
      },
    })),
  ];
} else {
  content = prompt;
}

// --- Map SDK options --------------------------------------------------------
const sdkOptions = {};
if (options.model != null)                sdkOptions.model = options.model;
if (options.maxTurns != null)             sdkOptions.maxTurns = options.maxTurns;
if (options.systemPrompt)                 sdkOptions.systemPrompt = options.systemPrompt;
if (options.appendSystemPrompt)           sdkOptions.appendSystemPrompt = options.appendSystemPrompt;
if (options.allowedTools != null)         sdkOptions.allowedTools = options.allowedTools;
if (options.disallowedTools != null)      sdkOptions.disallowedTools = options.disallowedTools;
if (options.permissionMode)               sdkOptions.permissionMode = options.permissionMode;
if (options.resume)                       sdkOptions.resume = options.resume;
if (options.continueConversation != null) sdkOptions.continueConversation = options.continueConversation;
if (options.forkSession != null)          sdkOptions.forkSession = options.forkSession;
if (options.sessionId)                    sdkOptions.sessionId = options.sessionId;
if (options.cwd)                          sdkOptions.cwd = options.cwd;
if (options.includePartialMessages != null) sdkOptions.includePartialMessages = options.includePartialMessages;

// --- Signal handling --------------------------------------------------------
let stopping = false;
const stop = () => {
  stopping = true;
};
process.on("SIGINT", stop);
process.on("SIGTERM", stop);

// --- Run Claude and stream NDJSON -------------------------------------------
try {
  for await (const message of query({ prompt: content, options: sdkOptions })) {
    if (stopping) break;
    // Each message is already a plain object in CLI NDJSON format (snake_case).
    process.stdout.write(JSON.stringify(message) + "\n");
  }
} catch (err) {
  process.stderr.write(`sdk-wrapper: query error: ${err.message}\n`);
  process.exit(1);
}
