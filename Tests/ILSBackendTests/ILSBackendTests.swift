import XCTest
import XCTVapor
@testable import ILSBackend

// ILSBackend Test Suite
//
// This module contains comprehensive integration tests for the ILSBackend package.
// Tests are organized by functionality:
//
// Services:
//   - FileSystemServiceTests.swift: Tests for FileSystemService including skill
//     scanning/parsing/CRUD, MCP server operations, config read/write, session
//     scanning, YAML frontmatter parsing, and caching behavior
//
// Controllers:
//   - ProjectsControllerTests.swift: Tests for ProjectsController endpoints
//     (index, create, show, update, delete, getSessions) with success cases,
//     error handling, validation, and edge cases
//
// To run all ILSBackend tests:
//   swift test --filter ILSBackendTests
//
// To run a specific test suite:
//   swift test --filter ILSBackendTests.FileSystemServiceTests
//   swift test --filter ILSBackendTests.ProjectsControllerTests

final class ILSBackendTests: XCTestCase {
    // This file serves as documentation for the ILSBackend test suite.
    // See the test files listed above for actual test implementations.
}
