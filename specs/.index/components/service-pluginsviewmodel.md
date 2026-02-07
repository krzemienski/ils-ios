---
type: component-spec
source: ILSApp/ILSApp/ViewModels/PluginsViewModel.swift
hash: da944d67
category: service
indexed: 2026-02-05T21:40:00Z
---

# PluginsViewModel

## Purpose
SwiftUI ObservableObject managing Claude Code plugins with install, enable/disable, and uninstall operations.

## Exports
- class PluginsViewModel: ObservableObject
- struct InstallPluginRequest
- struct EnabledResponse

## Methods
- init()
- func configure(client: APIClient)
- func loadPlugins() async
- func retryLoadPlugins() async
- func installPlugin(name: String, marketplace: String) async
- func uninstallPlugin(_ plugin: PluginItem) async
- func enablePlugin(_ plugin: PluginItem) async
- func disablePlugin(_ plugin: PluginItem) async

## Dependencies
- import Foundation
- import ILSShared

## Keywords
service pluginsviewmodel plugins marketplace viewmodel
