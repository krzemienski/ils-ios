import Foundation
import Observation
import ILSShared

@MainActor
@Observable
class ThemesViewModel: BaseViewModel {
    var themes: [CustomTheme] = []

    /// Empty state text for UI display
    var emptyStateText: String {
        if isLoading {
            return "Loading themes..."
        }
        return themes.isEmpty ? "No custom themes yet" : ""
    }

    func loadThemes() async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ListResponse<CustomTheme>> = try await client.get("/themes")
            if let data = response.data {
                themes = data.items

                if ICloudSyncManager.shared.isSyncEnabled {
                    await ICloudSyncManager.shared.syncCustomThemes(themes: themes, apiClient: client)
                    // Reload to surface any themes synced from other devices
                    let refreshed: APIResponse<ListResponse<CustomTheme>> = try await client.get("/themes")
                    if let refreshedData = refreshed.data {
                        themes = refreshedData.items
                    }
                }
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func retryLoadThemes() async {
        await loadThemes()
    }

    func createTheme(
        name: String,
        description: String?,
        author: String?,
        version: String?,
        colors: ColorTokens?,
        typography: TypographyTokens?,
        spacing: SpacingTokens?,
        cornerRadius: CornerRadiusTokens?,
        shadows: ShadowTokens?,
        meshGradient: MeshGradientConfig? = nil
    ) async -> CustomTheme? {
        guard let client else { return nil }
        do {
            let request = CreateCustomThemeRequest(
                name: name,
                description: description,
                author: author,
                version: version,
                colors: colors,
                typography: typography,
                spacing: spacing,
                cornerRadius: cornerRadius,
                shadows: shadows,
                meshGradient: meshGradient
            )
            let response: APIResponse<CustomTheme> = try await client.post("/themes", body: request)
            if let theme = response.data {
                themes.append(theme)
                return theme
            }
        } catch {
            self.error = error
        }
        return nil
    }

    func updateTheme(
        _ theme: CustomTheme,
        name: String?,
        description: String?,
        author: String?,
        version: String?,
        colors: ColorTokens?,
        typography: TypographyTokens?,
        spacing: SpacingTokens?,
        cornerRadius: CornerRadiusTokens?,
        shadows: ShadowTokens?,
        meshGradient: MeshGradientConfig? = nil
    ) async -> CustomTheme? {
        guard let client else { return nil }
        do {
            let request = UpdateCustomThemeRequest(
                name: name,
                description: description,
                author: author,
                version: version,
                colors: colors,
                typography: typography,
                spacing: spacing,
                cornerRadius: cornerRadius,
                shadows: shadows,
                meshGradient: meshGradient
            )
            let response: APIResponse<CustomTheme> = try await client.put("/themes/\(theme.id)", body: request)
            if let updated = response.data {
                if let index = themes.firstIndex(where: { $0.id == theme.id }) {
                    themes[index] = updated
                }
                return updated
            }
        } catch {
            self.error = error
        }
        return nil
    }

    func deleteTheme(_ theme: CustomTheme) async {
        guard let client else { return }
        do {
            let _: APIResponse<DeletedResponse> = try await client.delete("/themes/\(theme.id)")
            themes.removeAll { $0.id == theme.id }
        } catch {
            self.error = error
        }
    }
}
