---
type: component-spec
source: ILSApp/ILSApp/ViewModels/ProjectsViewModel.swift
hash: 134b015a
category: service
indexed: 2026-02-05T21:40:00Z
---

# ProjectsViewModel

## Purpose
SwiftUI ObservableObject managing projects with CRUD operations.

## Exports
- class ProjectsViewModel: ObservableObject
- struct CreateProjectRequest
- struct UpdateProjectRequest

## Methods
- init()
- func configure(client: APIClient)
- func loadProjects() async
- func retryLoadProjects() async
- func createProject(name: String, path: String, defaultModel: String, description: String?) async -> Project?
- func updateProject(_ project: Project, name: String?, defaultModel: String?, description: String?) async -> Project?
- func deleteProject(_ project: Project) async

## Dependencies
- import Foundation
- import ILSShared

## Keywords
service projectsviewmodel projects crud viewmodel
