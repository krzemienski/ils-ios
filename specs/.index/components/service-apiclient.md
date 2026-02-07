---
type: component-spec
source: ILSApp/ILSApp/Services/APIClient.swift
hash: 9a0a8e3b
category: service
indexed: 2026-02-05T21:40:00Z
---

# APIClient

## Purpose
Actor-based HTTP API client for ILS backend communication with generic CRUD methods, ISO8601 date handling, and comprehensive error types with retry logic.

## Exports
- actor APIClient
- struct APIResponse<T>
- struct APIErrorResponse
- struct ListResponse<T>
- struct HealthResponse
- enum APIError

## Methods
- init(baseURL: String)
- func healthCheck() async throws -> String
- func getHealth() async throws -> HealthResponse
- func get<T: Decodable>(_ path: String) async throws -> T
- func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T
- func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T
- func delete<T: Decodable>(_ path: String) async throws -> T

## Dependencies
- import Foundation

## Keywords
service apiclient http networking actor api rest
