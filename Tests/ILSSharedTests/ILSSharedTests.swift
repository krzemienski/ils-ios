import XCTest
@testable import ILSShared

// ILSShared Test Suite
//
// This module contains comprehensive unit tests for the ILSShared package.
// Tests are organized by functionality:
//
// Models:
//   - StreamMessageTests.swift: Tests for StreamMessage Codable implementation,
//     including all message types (system, assistant, result, permission, error)
//     and ContentBlock variants (text, toolUse, toolResult, thinking)
//   - AnyCodableTests.swift: Tests for AnyCodable type erasure, covering
//     primitives, collections, nested structures, and edge cases
//
// DTOs:
//   - RequestsTests.swift: Tests for all DTO and request models including
//     APIResponse, project/session/chat requests, and WebSocket messages
//
// To run all ILSShared tests:
//   swift test --filter ILSSharedTests
//
// To run a specific test suite:
//   swift test --filter ILSSharedTests.StreamMessageTests
//   swift test --filter ILSSharedTests.AnyCodableTests
//   swift test --filter ILSSharedTests.RequestsTests

final class ILSSharedTests: XCTestCase {
    // This file serves as documentation for the ILSShared test suite.
    // See the test files listed above for actual test implementations.
}
