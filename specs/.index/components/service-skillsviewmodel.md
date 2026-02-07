---
type: component-spec
source: ILSApp/ILSApp/ViewModels/SkillsViewModel.swift
hash: 4e958f38
category: service
indexed: 2026-02-05T21:40:00Z
---

# SkillsViewModel

## Purpose
SwiftUI ObservableObject managing Claude Code skills with client-side search filtering across name/description/tags and cache refresh support.

## Exports
- class SkillsViewModel: ObservableObject

## Methods
- init()
- func configure(client: APIClient)
- func loadSkills(refresh: Bool) async
- func refreshSkills() async
- func retryLoadSkills() async
- func createSkill(name: String, description: String?, content: String) async -> SkillItem?
- func updateSkill(_ skill: SkillItem, content: String) async -> SkillItem?
- func deleteSkill(_ skill: SkillItem) async

## Dependencies
- import Foundation
- import ILSShared

## Keywords
service skillsviewmodel skills search tags viewmodel
