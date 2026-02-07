---
type: component-spec
source: ILSApp/ILSApp/ViewModels/DashboardViewModel.swift
hash: 9c40f0f8
category: service
indexed: 2026-02-05T21:40:00Z
---

# DashboardViewModel

## Purpose
SwiftUI ObservableObject for dashboard statistics and recent activity with retry logic.

## Exports
- class DashboardViewModel: ObservableObject

## Methods
- init()
- func configure(client: APIClient)
- func loadAll() async
- func loadStats() async
- func loadRecentActivity() async
- func retryLoad() async

## Dependencies
- import Foundation
- import ILSShared

## Keywords
service dashboardviewmodel dashboard stats viewmodel
