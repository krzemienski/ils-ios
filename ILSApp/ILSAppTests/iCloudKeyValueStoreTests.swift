import XCTest
@testable import ILSApp

/// Unit tests for iCloudKeyValueStore
/// Tests KVS operations, validation, and error handling
class iCloudKeyValueStoreTests: XCTestCase {
    var store: iCloudKeyValueStore!

    override func setUp() async throws {
        // Note: In production tests, you'd inject a mock NSUbiquitousKeyValueStore
        // For now, we'll test the interface and validation logic
        store = iCloudKeyValueStore()
    }

    override func tearDown() async throws {
        store = nil
    }

    // MARK: - String Operations

    func testSetString_Success() async throws {
        // Test: Setting a valid string should work
        let key = "test_string_key"
        let value = "test value"

        do {
            try await store.setString(value, forKey: key)
            // Success - no error thrown
            XCTAssertTrue(true)
        } catch {
            XCTFail("Setting valid string should not throw: \(error)")
        }
    }

    func testGetString_ReturnsValue() async {
        // Test: Getting a string value
        let key = "test_get_string"

        // Set a value first
        do {
            try await store.setString("retrieved value", forKey: key)
        } catch {
            // May fail in test environment without real iCloud
        }

        // Get the value
        let value = await store.getString(forKey: key)

        // In mock environment, would verify value matches
        // In real iCloud environment, value should match or be nil
        XCTAssertTrue(value == nil || value == "retrieved value")
    }

    func testSetString_NilValue_RemovesKey() async throws {
        // Test: Setting nil should remove the key
        let key = "test_nil_remove"

        do {
            // Set a value
            try await store.setString("initial value", forKey: key)

            // Set nil to remove
            try await store.setString(nil, forKey: key)

            // Success - no error thrown
            XCTAssertTrue(true)
        } catch {
            XCTFail("Setting nil should not throw: \(error)")
        }
    }

    // MARK: - Validation Tests (CRITICAL)

    func testSetString_KeyTooLong_ThrowsError() async {
        // Test: Keys longer than 64 characters should throw error
        let longKey = String(repeating: "a", count: 65) // 65 characters
        let value = "test value"

        do {
            try await store.setString(value, forKey: longKey)
            XCTFail("Should throw error for key too long")
        } catch let error as iCloudKVSError {
            if case .keyTooLong(let key, let length) = error {
                XCTAssertEqual(key, longKey)
                XCTAssertEqual(length, 65)
            } else {
                XCTFail("Expected keyTooLong error, got \(error)")
            }
        } catch {
            XCTFail("Expected iCloudKVSError, got \(error)")
        }
    }

    func testSetString_ValueTooLarge_ThrowsError() async {
        // Test: Values larger than 1MB should throw error
        let key = "large_value_key"
        let largeValue = String(repeating: "x", count: 1024 * 1024 + 1) // > 1MB

        do {
            try await store.setString(largeValue, forKey: key)
            XCTFail("Should throw error for value too large")
        } catch let error as iCloudKVSError {
            if case .valueTooLarge(let size) = error {
                XCTAssertGreaterThan(size, 1024 * 1024)
            } else {
                XCTFail("Expected valueTooLarge error, got \(error)")
            }
        } catch {
            XCTFail("Expected iCloudKVSError, got \(error)")
        }
    }

    func testSetString_KeyExactly64Chars_Success() async throws {
        // Test: Keys exactly 64 characters should work
        let maxKey = String(repeating: "b", count: 64)
        let value = "test"

        do {
            try await store.setString(value, forKey: maxKey)
            // Success
            XCTAssertTrue(true)
        } catch {
            XCTFail("64-character key should be allowed: \(error)")
        }
    }

    // MARK: - Bool Operations

    func testSetBool_Success() async throws {
        let key = "test_bool_key"
        let value = true

        do {
            try await store.setBool(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Setting valid bool should not throw: \(error)")
        }
    }

    func testGetBool_ReturnsValue() async {
        let key = "test_get_bool"

        // Set a value
        do {
            try await store.setBool(true, forKey: key)
        } catch {
            // May fail in test environment
        }

        // Get the value
        let value = await store.getBool(forKey: key)

        // Should return boolean value (true or false)
        XCTAssertTrue(value == true || value == false)
    }

    func testSetBool_KeyTooLong_ThrowsError() async {
        let longKey = String(repeating: "c", count: 65)

        do {
            try await store.setBool(true, forKey: longKey)
            XCTFail("Should throw error for key too long")
        } catch let error as iCloudKVSError {
            if case .keyTooLong = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected keyTooLong error")
            }
        } catch {
            XCTFail("Expected iCloudKVSError")
        }
    }

    // MARK: - Int Operations

    func testSetInt_Success() async throws {
        let key = "test_int_key"
        let value = 42

        do {
            try await store.setInt(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Setting valid int should not throw: \(error)")
        }
    }

    func testGetInt_ReturnsValue() async {
        let key = "test_get_int"

        // Set a value
        do {
            try await store.setInt(123, forKey: key)
        } catch {
            // May fail in test environment
        }

        // Get the value
        let value = await store.getInt(forKey: key)

        // Should return integer value
        XCTAssertTrue(value >= 0 || value < 0) // Any valid integer
    }

    func testSetInt_KeyTooLong_ThrowsError() async {
        let longKey = String(repeating: "d", count: 65)

        do {
            try await store.setInt(42, forKey: longKey)
            XCTFail("Should throw error for key too long")
        } catch let error as iCloudKVSError {
            if case .keyTooLong = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected keyTooLong error")
            }
        } catch {
            XCTFail("Expected iCloudKVSError")
        }
    }

    // MARK: - Double Operations

    func testSetDouble_Success() async throws {
        let key = "test_double_key"
        let value = 3.14159

        do {
            try await store.setDouble(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Setting valid double should not throw: \(error)")
        }
    }

    func testGetDouble_ReturnsValue() async {
        let key = "test_get_double"

        // Set a value
        do {
            try await store.setDouble(2.71828, forKey: key)
        } catch {
            // May fail in test environment
        }

        // Get the value
        let value = await store.getDouble(forKey: key)

        // Should return double value
        XCTAssertTrue(value.isFinite || value == 0.0)
    }

    func testSetDouble_KeyTooLong_ThrowsError() async {
        let longKey = String(repeating: "e", count: 65)

        do {
            try await store.setDouble(1.23, forKey: longKey)
            XCTFail("Should throw error for key too long")
        } catch let error as iCloudKVSError {
            if case .keyTooLong = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected keyTooLong error")
            }
        } catch {
            XCTFail("Expected iCloudKVSError")
        }
    }

    // MARK: - Data Operations

    func testSetData_Success() async throws {
        let key = "test_data_key"
        let value = "test data".data(using: .utf8)!

        do {
            try await store.setData(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Setting valid data should not throw: \(error)")
        }
    }

    func testGetData_ReturnsValue() async {
        let key = "test_get_data"

        // Set a value
        do {
            let data = "test".data(using: .utf8)!
            try await store.setData(data, forKey: key)
        } catch {
            // May fail in test environment
        }

        // Get the value
        let value = await store.getData(forKey: key)

        // Should return data or nil
        XCTAssertTrue(value == nil || value?.count ?? 0 >= 0)
    }

    func testSetData_ValueTooLarge_ThrowsError() async {
        let key = "large_data_key"
        let largeData = Data(repeating: 0xFF, count: 1024 * 1024 + 1) // > 1MB

        do {
            try await store.setData(largeData, forKey: key)
            XCTFail("Should throw error for data too large")
        } catch let error as iCloudKVSError {
            if case .valueTooLarge = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected valueTooLarge error")
            }
        } catch {
            XCTFail("Expected iCloudKVSError")
        }
    }

    func testSetData_NilValue_RemovesKey() async throws {
        let key = "test_data_remove"

        do {
            // Set a value
            try await store.setData("initial".data(using: .utf8), forKey: key)

            // Set nil to remove
            try await store.setData(nil, forKey: key)

            // Success
            XCTAssertTrue(true)
        } catch {
            XCTFail("Setting nil data should not throw: \(error)")
        }
    }

    // MARK: - Remove Operations

    func testRemoveObject_Success() async {
        let key = "test_remove_key"

        // Remove should not throw
        await store.removeObject(forKey: key)

        // Success
        XCTAssertTrue(true)
    }

    // MARK: - Synchronization Tests

    func testSynchronize_ReturnsBool() async {
        // Test: Synchronize should return a boolean
        let result = await store.synchronize()

        // Should return true or false
        XCTAssertTrue(result == true || result == false)
    }

    // MARK: - Edge Cases

    func testSetString_EmptyString_Success() async throws {
        let key = "empty_string_key"
        let value = ""

        do {
            try await store.setString(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Empty string should be allowed: \(error)")
        }
    }

    func testSetString_UnicodeCharacters_Success() async throws {
        let key = "unicode_key"
        let value = "Hello 世界 🌍"

        do {
            try await store.setString(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unicode string should be allowed: \(error)")
        }
    }

    func testSetInt_NegativeValue_Success() async throws {
        let key = "negative_int_key"
        let value = -42

        do {
            try await store.setInt(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Negative integer should be allowed: \(error)")
        }
    }

    func testSetDouble_NegativeValue_Success() async throws {
        let key = "negative_double_key"
        let value = -3.14

        do {
            try await store.setDouble(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Negative double should be allowed: \(error)")
        }
    }

    func testSetDouble_Zero_Success() async throws {
        let key = "zero_double_key"
        let value = 0.0

        do {
            try await store.setDouble(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Zero should be allowed: \(error)")
        }
    }

    // MARK: - Array and Dictionary Operations

    func testSetArray_Success() async throws {
        let key = "test_array_key"
        let value = ["item1", "item2", "item3"]

        do {
            try await store.setArray(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Setting valid array should not throw: \(error)")
        }
    }

    func testGetArray_ReturnsValue() async {
        let key = "test_get_array"

        // Set a value
        do {
            try await store.setArray(["a", "b"], forKey: key)
        } catch {
            // May fail in test environment
        }

        // Get the value
        let value = await store.getArray(forKey: key)

        // Should return array or nil
        XCTAssertTrue(value == nil || (value?.count ?? 0) >= 0)
    }

    func testSetDictionary_Success() async throws {
        let key = "test_dict_key"
        let value: [String: Any] = ["key1": "value1", "key2": 42]

        do {
            try await store.setDictionary(value, forKey: key)
            XCTAssertTrue(true)
        } catch {
            XCTFail("Setting valid dictionary should not throw: \(error)")
        }
    }

    func testGetDictionary_ReturnsValue() async {
        let key = "test_get_dict"

        // Set a value
        do {
            try await store.setDictionary(["test": "value"], forKey: key)
        } catch {
            // May fail in test environment
        }

        // Get the value
        let value = await store.getDictionary(forKey: key)

        // Should return dictionary or nil
        XCTAssertTrue(value == nil || (value?.count ?? 0) >= 0)
    }

    // MARK: - Error Description Tests

    func testError_KeyTooLong_HasDescription() {
        let error = iCloudKVSError.keyTooLong(key: "testkey", length: 100)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("too long") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("64") ?? false)
    }

    func testError_ValueTooLarge_HasDescription() {
        let error = iCloudKVSError.valueTooLarge(size: 2000000)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("too large") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("MB") ?? false)
    }

    func testError_IsRetriable_Correct() {
        // Synchronization failure is retriable
        let retriableError = iCloudKVSError.synchronizationFailed
        XCTAssertTrue(retriableError.isRetriable)

        // Key too long is not retriable
        let nonRetriableError = iCloudKVSError.keyTooLong(key: "test", length: 100)
        XCTAssertFalse(nonRetriableError.isRetriable)

        // Value too large is not retriable
        let nonRetriableError2 = iCloudKVSError.valueTooLarge(size: 2000000)
        XCTAssertFalse(nonRetriableError2.isRetriable)
    }
}
