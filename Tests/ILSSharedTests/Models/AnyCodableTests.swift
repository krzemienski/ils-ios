import XCTest
@testable import ILSShared

final class AnyCodableTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // MARK: - Null Tests

    func testEncodeDecodeNull() throws {
        let anyCodable = AnyCodable(NSNull())

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        XCTAssertTrue(decoded.value is NSNull)
    }

    // MARK: - Bool Tests

    func testEncodeDecodeBoolTrue() throws {
        let anyCodable = AnyCodable(true)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? Bool else {
            XCTFail("Expected Bool value")
            return
        }

        XCTAssertTrue(decodedValue)
    }

    func testEncodeDecodeBoolFalse() throws {
        let anyCodable = AnyCodable(false)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? Bool else {
            XCTFail("Expected Bool value")
            return
        }

        XCTAssertFalse(decodedValue)
    }

    // MARK: - Int Tests

    func testEncodeDecodeIntPositive() throws {
        let anyCodable = AnyCodable(42)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? Int else {
            XCTFail("Expected Int value")
            return
        }

        XCTAssertEqual(decodedValue, 42)
    }

    func testEncodeDecodeIntNegative() throws {
        let anyCodable = AnyCodable(-100)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? Int else {
            XCTFail("Expected Int value")
            return
        }

        XCTAssertEqual(decodedValue, -100)
    }

    func testEncodeDecodeIntZero() throws {
        let anyCodable = AnyCodable(0)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? Int else {
            XCTFail("Expected Int value")
            return
        }

        XCTAssertEqual(decodedValue, 0)
    }

    // MARK: - Double Tests

    func testEncodeDecodeDouble() throws {
        let anyCodable = AnyCodable(3.14159)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? Double else {
            XCTFail("Expected Double value")
            return
        }

        XCTAssertEqual(decodedValue, 3.14159, accuracy: 0.00001)
    }

    func testEncodeDecodeDoubleNegative() throws {
        let anyCodable = AnyCodable(-2.71828)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? Double else {
            XCTFail("Expected Double value")
            return
        }

        XCTAssertEqual(decodedValue, -2.71828, accuracy: 0.00001)
    }

    // MARK: - String Tests

    func testEncodeDecodeString() throws {
        let anyCodable = AnyCodable("Hello, World!")

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? String else {
            XCTFail("Expected String value")
            return
        }

        XCTAssertEqual(decodedValue, "Hello, World!")
    }

    func testEncodeDecodeEmptyString() throws {
        let anyCodable = AnyCodable("")

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? String else {
            XCTFail("Expected String value")
            return
        }

        XCTAssertEqual(decodedValue, "")
    }

    func testEncodeDecodeStringWithSpecialCharacters() throws {
        let anyCodable = AnyCodable("Special chars: 🚀 \n \t \"quoted\"")

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? String else {
            XCTFail("Expected String value")
            return
        }

        XCTAssertEqual(decodedValue, "Special chars: 🚀 \n \t \"quoted\"")
    }

    // MARK: - Array Tests

    func testEncodeDecodeEmptyArray() throws {
        let anyCodable = AnyCodable([])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? [Any] else {
            XCTFail("Expected Array value")
            return
        }

        XCTAssertEqual(decodedValue.count, 0)
    }

    func testEncodeDecodeArrayOfInts() throws {
        let anyCodable = AnyCodable([1, 2, 3, 4, 5])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? [Any] else {
            XCTFail("Expected Array value")
            return
        }

        XCTAssertEqual(decodedValue.count, 5)
        XCTAssertEqual(decodedValue[0] as? Int, 1)
        XCTAssertEqual(decodedValue[1] as? Int, 2)
        XCTAssertEqual(decodedValue[2] as? Int, 3)
        XCTAssertEqual(decodedValue[3] as? Int, 4)
        XCTAssertEqual(decodedValue[4] as? Int, 5)
    }

    func testEncodeDecodeArrayOfStrings() throws {
        let anyCodable = AnyCodable(["apple", "banana", "cherry"])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? [Any] else {
            XCTFail("Expected Array value")
            return
        }

        XCTAssertEqual(decodedValue.count, 3)
        XCTAssertEqual(decodedValue[0] as? String, "apple")
        XCTAssertEqual(decodedValue[1] as? String, "banana")
        XCTAssertEqual(decodedValue[2] as? String, "cherry")
    }

    func testEncodeDecodeArrayOfMixedTypes() throws {
        let anyCodable = AnyCodable([1, "two", 3.5, true])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? [Any] else {
            XCTFail("Expected Array value")
            return
        }

        XCTAssertEqual(decodedValue.count, 4)
        XCTAssertEqual(decodedValue[0] as? Int, 1)
        XCTAssertEqual(decodedValue[1] as? String, "two")

        guard let doubleValue = decodedValue[2] as? Double else {
            XCTFail("Expected Double value at index 2")
            return
        }
        XCTAssertEqual(doubleValue, 3.5, accuracy: 0.001)

        XCTAssertEqual(decodedValue[3] as? Bool, true)
    }

    // MARK: - Dictionary Tests

    func testEncodeDecodeEmptyDictionary() throws {
        let anyCodable = AnyCodable([String: Any]())

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? [String: Any] else {
            XCTFail("Expected Dictionary value")
            return
        }

        XCTAssertEqual(decodedValue.count, 0)
    }

    func testEncodeDecodeDictionaryWithStrings() throws {
        let anyCodable = AnyCodable(["name": "John", "city": "New York"])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? [String: Any] else {
            XCTFail("Expected Dictionary value")
            return
        }

        XCTAssertEqual(decodedValue.count, 2)
        XCTAssertEqual(decodedValue["name"] as? String, "John")
        XCTAssertEqual(decodedValue["city"] as? String, "New York")
    }

    func testEncodeDecodeDictionaryWithMixedTypes() throws {
        let anyCodable = AnyCodable([
            "name": "Alice",
            "age": 30,
            "height": 5.6,
            "active": true
        ])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? [String: Any] else {
            XCTFail("Expected Dictionary value")
            return
        }

        XCTAssertEqual(decodedValue.count, 4)
        XCTAssertEqual(decodedValue["name"] as? String, "Alice")
        XCTAssertEqual(decodedValue["age"] as? Int, 30)

        guard let heightValue = decodedValue["height"] as? Double else {
            XCTFail("Expected Double value for height")
            return
        }
        XCTAssertEqual(heightValue, 5.6, accuracy: 0.01)

        XCTAssertEqual(decodedValue["active"] as? Bool, true)
    }

    // MARK: - Nested Structure Tests

    func testEncodeDecodeNestedArray() throws {
        let anyCodable = AnyCodable([[1, 2], [3, 4], [5, 6]])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? [Any] else {
            XCTFail("Expected Array value")
            return
        }

        XCTAssertEqual(decodedValue.count, 3)

        guard let firstNested = decodedValue[0] as? [Any] else {
            XCTFail("Expected nested array")
            return
        }

        XCTAssertEqual(firstNested.count, 2)
        XCTAssertEqual(firstNested[0] as? Int, 1)
        XCTAssertEqual(firstNested[1] as? Int, 2)
    }

    func testEncodeDecodeNestedDictionary() throws {
        let anyCodable = AnyCodable([
            "person": [
                "name": "Bob",
                "age": 25
            ],
            "location": [
                "city": "Paris",
                "country": "France"
            ]
        ])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? [String: Any] else {
            XCTFail("Expected Dictionary value")
            return
        }

        XCTAssertEqual(decodedValue.count, 2)

        guard let person = decodedValue["person"] as? [String: Any] else {
            XCTFail("Expected nested dictionary for person")
            return
        }

        XCTAssertEqual(person["name"] as? String, "Bob")
        XCTAssertEqual(person["age"] as? Int, 25)

        guard let location = decodedValue["location"] as? [String: Any] else {
            XCTFail("Expected nested dictionary for location")
            return
        }

        XCTAssertEqual(location["city"] as? String, "Paris")
        XCTAssertEqual(location["country"] as? String, "France")
    }

    func testEncodeDecodeComplexNestedStructure() throws {
        let anyCodable = AnyCodable([
            "users": [
                ["name": "Alice", "scores": [95, 87, 92]],
                ["name": "Bob", "scores": [78, 85, 88]]
            ],
            "metadata": [
                "total": 2,
                "verified": true
            ]
        ])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let decodedValue = decoded.value as? [String: Any] else {
            XCTFail("Expected Dictionary value")
            return
        }

        guard let users = decodedValue["users"] as? [Any] else {
            XCTFail("Expected users array")
            return
        }

        XCTAssertEqual(users.count, 2)

        guard let firstUser = users[0] as? [String: Any] else {
            XCTFail("Expected user dictionary")
            return
        }

        XCTAssertEqual(firstUser["name"] as? String, "Alice")

        guard let scores = firstUser["scores"] as? [Any] else {
            XCTFail("Expected scores array")
            return
        }

        XCTAssertEqual(scores.count, 3)
        XCTAssertEqual(scores[0] as? Int, 95)
        XCTAssertEqual(scores[1] as? Int, 87)
        XCTAssertEqual(scores[2] as? Int, 92)

        guard let metadata = decodedValue["metadata"] as? [String: Any] else {
            XCTFail("Expected metadata dictionary")
            return
        }

        XCTAssertEqual(metadata["total"] as? Int, 2)
        XCTAssertEqual(metadata["verified"] as? Bool, true)
    }

    // MARK: - Error Tests

    func testEncodeUnsupportedTypeThrowsError() throws {
        struct UnsupportedType {}
        let anyCodable = AnyCodable(UnsupportedType())

        XCTAssertThrowsError(try encoder.encode(anyCodable)) { error in
            guard case EncodingError.invalidValue = error else {
                XCTFail("Expected EncodingError.invalidValue")
                return
            }
        }
    }

    // MARK: - JSON Roundtrip Tests

    func testJSONRoundtripWithToolUseBlock() throws {
        let toolInput = AnyCodable([
            "command": "git status",
            "timeout": 5000,
            "dangerous": false
        ])

        let toolUseBlock = ToolUseBlock(
            id: "tool-123",
            name: "bash",
            input: toolInput
        )

        let encoded = try encoder.encode(toolUseBlock)
        let decoded = try decoder.decode(ToolUseBlock.self, from: encoded)

        XCTAssertEqual(decoded.id, "tool-123")
        XCTAssertEqual(decoded.name, "bash")

        guard let decodedInput = decoded.input.value as? [String: Any] else {
            XCTFail("Expected Dictionary input")
            return
        }

        XCTAssertEqual(decodedInput["command"] as? String, "git status")
        XCTAssertEqual(decodedInput["timeout"] as? Int, 5000)
        XCTAssertEqual(decodedInput["dangerous"] as? Bool, false)
    }

    func testJSONStringDecoding() throws {
        let jsonString = """
        {
            "name": "test",
            "value": 42,
            "enabled": true,
            "tags": ["swift", "testing"]
        }
        """

        let jsonData = jsonString.data(using: .utf8)!
        let decoded = try decoder.decode(AnyCodable.self, from: jsonData)

        guard let decodedValue = decoded.value as? [String: Any] else {
            XCTFail("Expected Dictionary value")
            return
        }

        XCTAssertEqual(decodedValue["name"] as? String, "test")
        XCTAssertEqual(decodedValue["value"] as? Int, 42)
        XCTAssertEqual(decodedValue["enabled"] as? Bool, true)

        guard let tags = decodedValue["tags"] as? [Any] else {
            XCTFail("Expected tags array")
            return
        }

        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(tags[0] as? String, "swift")
        XCTAssertEqual(tags[1] as? String, "testing")
    }
}
