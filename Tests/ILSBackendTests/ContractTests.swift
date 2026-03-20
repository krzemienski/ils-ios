import Testing
import Foundation
@testable import ILSBackend
import ILSShared

@Suite("Contract Validation")
struct ContractTests {

    // MARK: - Pagination Contract

    @Test("PaginatedResponse includes all required contract fields")
    func paginatedResponseHasRequiredFields() throws {
        let response = PaginatedResponse<String>(
            items: ["a", "b", "c"],
            total: 10,
            hasMore: true,
            page: 2,
            limit: 3
        )

        #expect(response.page == 2)
        #expect(response.limit == 3)
        #expect(response.total == 10)
        #expect(response.hasMore == true)
        #expect(response.items == ["a", "b", "c"])
    }

    @Test("PaginatedResponse Codable round-trip preserves all contract fields")
    func paginatedResponseCodableRoundTrip() throws {
        let original = PaginatedResponse<Int>(
            items: [1, 2, 3, 4, 5],
            total: 42,
            hasMore: true,
            page: 3,
            limit: 5
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaginatedResponse<Int>.self, from: data)

        #expect(decoded.page == 3)
        #expect(decoded.limit == 5)
        #expect(decoded.total == 42)
        #expect(decoded.hasMore == true)
        #expect(decoded.items == [1, 2, 3, 4, 5])
    }

    @Test("PaginatedResponse JSON keys match contract schema")
    func paginatedResponseJSONKeys() throws {
        let response = PaginatedResponse<String>(
            items: ["x"],
            total: 1,
            hasMore: false,
            page: 1,
            limit: 50
        )

        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["page"] != nil)
        #expect(json?["limit"] != nil)
        #expect(json?["total"] != nil)
        #expect(json?["hasMore"] != nil)
        #expect(json?["items"] != nil)
        #expect(json?["page"] as? Int == 1)
        #expect(json?["limit"] as? Int == 50)
        #expect(json?["total"] as? Int == 1)
        #expect(json?["hasMore"] as? Bool == false)
    }

    @Test("PaginatedResponse defaults page to 1 and limit to 50")
    func paginatedResponseDefaults() throws {
        let response = PaginatedResponse<String>(
            items: [],
            total: 0,
            hasMore: false
        )

        #expect(response.page == 1)
        #expect(response.limit == 50)
    }

    @Test("PaginatedResponse last page has hasMore false")
    func paginatedResponseLastPage() throws {
        let response = PaginatedResponse<String>(
            items: ["only"],
            total: 1,
            hasMore: false,
            page: 1,
            limit: 50
        )

        #expect(response.hasMore == false)
        #expect(response.total == response.items.count)
    }

    // MARK: - Error Contract

    @Test("Error response includes success false, error.code, error.message")
    func errorResponseHasRequiredFields() throws {
        let apiError = APIError(code: "not_found", message: "Resource not found")
        let response = APIResponse<String>(success: false, data: nil, error: apiError)

        #expect(response.success == false)
        #expect(response.error != nil)
        #expect(response.error?.code == "not_found")
        #expect(response.error?.message == "Resource not found")
        #expect(response.data == nil)
    }

    @Test("Error response Codable round-trip preserves contract fields")
    func errorResponseCodableRoundTrip() throws {
        let apiError = APIError(code: "validation_error", message: "Invalid input")
        let original = APIResponse<String>(success: false, data: nil, error: apiError)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(APIResponse<String>.self, from: data)

        #expect(decoded.success == false)
        #expect(decoded.data == nil)
        #expect(decoded.error?.code == "validation_error")
        #expect(decoded.error?.message == "Invalid input")
    }

    @Test("Error response JSON keys match contract schema")
    func errorResponseJSONKeys() throws {
        let apiError = APIError(code: "unauthorized", message: "Authentication required")
        let response = APIResponse<String>(success: false, data: nil, error: apiError)

        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["success"] as? Bool == false)
        #expect(json?["error"] != nil)

        let errorObj = json?["error"] as? [String: Any]
        #expect(errorObj?["code"] != nil)
        #expect(errorObj?["message"] != nil)
        #expect(errorObj?["code"] as? String == "unauthorized")
        #expect(errorObj?["message"] as? String == "Authentication required")
    }

    @Test("Success response has success true and no error")
    func successResponseContract() throws {
        let response = APIResponse<String>(success: true, data: "ok", error: nil)

        #expect(response.success == true)
        #expect(response.error == nil)
        #expect(response.data == "ok")
    }

    @Test("APIError Codable round-trip preserves code and message")
    func apiErrorCodableRoundTrip() throws {
        let original = APIError(code: "internal_error", message: "Something went wrong", reason: "Disk full")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(APIError.self, from: data)

        #expect(decoded.code == "internal_error")
        #expect(decoded.message == "Something went wrong")
        #expect(decoded.reason == "Disk full")
    }

    @Test("APIError without reason is valid contract")
    func apiErrorWithoutReason() throws {
        let error = APIError(code: "forbidden", message: "Access denied")

        #expect(error.code == "forbidden")
        #expect(error.message == "Access denied")
        #expect(error.reason == nil)
    }

    // MARK: - Combined Contract

    @Test("Paginated success response wraps PaginatedResponse in APIResponse")
    func paginatedSuccessResponseContract() throws {
        let paginated = PaginatedResponse<String>(
            items: ["item1", "item2"],
            total: 100,
            hasMore: true,
            page: 1,
            limit: 2
        )
        let response = APIResponse<PaginatedResponse<String>>(success: true, data: paginated, error: nil)

        #expect(response.success == true)
        #expect(response.error == nil)
        #expect(response.data?.page == 1)
        #expect(response.data?.limit == 2)
        #expect(response.data?.total == 100)
        #expect(response.data?.hasMore == true)
        #expect(response.data?.items.count == 2)
    }

    @Test("Paginated response Codable round-trip inside APIResponse")
    func paginatedInsideAPIResponseRoundTrip() throws {
        let paginated = PaginatedResponse<Int>(
            items: [10, 20, 30],
            total: 300,
            hasMore: true,
            page: 5,
            limit: 3
        )
        let original = APIResponse<PaginatedResponse<Int>>(success: true, data: paginated, error: nil)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(APIResponse<PaginatedResponse<Int>>.self, from: data)

        #expect(decoded.success == true)
        #expect(decoded.data?.page == 5)
        #expect(decoded.data?.limit == 3)
        #expect(decoded.data?.total == 300)
        #expect(decoded.data?.hasMore == true)
        #expect(decoded.data?.items == [10, 20, 30])
    }
}
