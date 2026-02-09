// Sources/ILSBackend/Services/CLIMessageConverter.swift

import Foundation
import ILSShared

/// Converts raw CLI messages to iOS-facing StreamMessage types.
enum CLIMessageConverter {

    static func convert(_ cli: CLIMessage) -> StreamMessage? {
        switch cli {
        case .system(let m):
            return .system(SystemMessage(
                type: "system",
                subtype: m.subtype,
                data: SystemData(
                    sessionId: m.sessionId,
                    tools: m.tools,
                    model: m.model,
                    cwd: m.cwd
                ),
                uuid: m.uuid
            ))

        case .assistant(let m):
            let blocks = m.message.content.compactMap { convertContentBlock($0) }
            guard !blocks.isEmpty else { return nil }
            return .assistant(AssistantMessage(
                type: "assistant",
                content: blocks,
                uuid: m.uuid,
                sessionId: m.sessionId
            ))

        case .user(let m):
            let blocks = m.message.content.compactMap { convertContentBlock($0) }
            return .user(UserMessage(
                type: "user",
                uuid: m.uuid,
                sessionId: m.sessionId,
                content: blocks,
                toolUseResult: m.toolUseResult.map {
                    ToolUseResultMeta(
                        filenames: $0.filenames,
                        durationMs: $0.durationMs,
                        numFiles: $0.numFiles,
                        truncated: $0.truncated
                    )
                }
            ))

        case .result(let m):
            return .result(ResultMessage(
                subtype: m.subtype,
                sessionId: m.sessionId ?? "",
                durationMs: m.durationMs,
                durationApiMs: m.durationApiMs,
                isError: m.isError ?? false,
                numTurns: m.numTurns,
                totalCostUSD: m.totalCostUsd,
                usage: m.usage.map { UsageInfo(
                    inputTokens: $0.inputTokens ?? 0,
                    outputTokens: $0.outputTokens ?? 0,
                    cacheReadInputTokens: $0.cacheReadInputTokens,
                    cacheCreationInputTokens: $0.cacheCreationInputTokens
                )},
                result: m.result,
                modelUsage: m.modelUsage?.mapValues { entry in
                    ModelUsageEntry(
                        inputTokens: entry.inputTokens,
                        outputTokens: entry.outputTokens,
                        costUSD: entry.costUSD,
                        contextWindow: entry.contextWindow
                    )
                }
            ))

        case .streamEvent(let m):
            return .streamEvent(StreamEventMessage(
                type: "streamEvent",
                eventType: m.event.type,
                index: m.event.index,
                delta: m.event.delta.map { convertDelta($0) }
            ))

        case .permission(let m):
            return .permission(PermissionRequest(
                requestId: m.requestId ?? UUID().uuidString,
                toolName: m.toolName,
                toolInput: m.toolInput ?? AnyCodable([String: Any]())
            ))
        }
    }

    private static func convertContentBlock(_ cli: CLIContentBlock) -> ContentBlock? {
        switch cli.type {
        case "text":
            guard let text = cli.text else { return nil }
            return .text(TextBlock(text: text))
        case "tool_use":
            guard let id = cli.id, let name = cli.name else { return nil }
            return .toolUse(ToolUseBlock(id: id, name: name, input: cli.input ?? AnyCodable([String: Any]())))
        case "tool_result":
            let content: String
            if let str = cli.content?.value as? String {
                content = str
            } else if let items = cli.content?.value as? [[String: Any]] {
                content = items.compactMap { $0["text"] as? String }.joined(separator: "\n")
            } else {
                content = ""
            }
            return .toolResult(ToolResultBlock(
                toolUseId: cli.toolUseId ?? "",
                content: content,
                isError: cli.isError ?? false
            ))
        case "thinking":
            guard let thinking = cli.thinking else { return nil }
            return .thinking(ThinkingBlock(thinking: thinking))
        default:
            return .text(TextBlock(text: "[unsupported: \(cli.type)]"))
        }
    }

    private static func convertDelta(_ cli: CLIDelta) -> StreamDelta {
        switch cli {
        case .textDelta(let t): return .textDelta(t)
        case .inputJsonDelta(let j): return .inputJsonDelta(j)
        case .thinkingDelta(let t): return .thinkingDelta(t)
        case .unknown: return .textDelta("")
        }
    }
}
