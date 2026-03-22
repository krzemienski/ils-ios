import SwiftUI
import ILSShared

// MARK: - AddBackendView

/// Sheet for adding a new backend connection.
///
/// Collects a name, URL, optional API key, and color label, then lets the user
/// validate the connection via "Test Connection" before saving.
struct AddBackendView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    var viewModel: BackendConnectionsViewModel

    // MARK: - Form State

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var apiKey: String = ""
    @State private var selectedColorHex: String = BackendConnectionsViewModel.colorPresets[0]

    // MARK: - Test Connection State

    @State private var isTesting = false
    @State private var testResult: TestResult?

    // MARK: - Save State

    @State private var isSaving = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, url, apiKey
    }

    private enum TestResult {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSaving
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingLG) {
                    connectionSection
                    colorSection
                    testConnectionSection
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
            }
            .background(theme.bgPrimary)
            .navigationTitle("Add Backend")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(canSave ? theme.accent : theme.textTertiary)
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Connection")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                fieldGroup(label: "Name") {
                    TextField("e.g. Home Mac, Work Server", text: $name)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .autocapitalization(.words)
                        #endif
                        .foregroundStyle(theme.textPrimary)
                        .padding(theme.spacingSM)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        .focusRing(isFocused: focusedField == .name, cornerRadius: theme.cornerRadiusSmall)
                        .focused($focusedField, equals: .name)
                        .accessibilityLabel("Backend name")
                        .onSubmit { focusedField = .url }
                }

                fieldGroup(label: "URL") {
                    TextField("http://192.168.1.10:9999", text: $url)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .textContentType(.URL)
                        #if os(iOS)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()
                        .foregroundStyle(theme.textPrimary)
                        .padding(theme.spacingSM)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        .focusRing(isFocused: focusedField == .url, cornerRadius: theme.cornerRadiusSmall)
                        .focused($focusedField, equals: .url)
                        .accessibilityLabel("Backend URL")
                        .onChange(of: url) { _, _ in testResult = nil }
                        .onSubmit { focusedField = .apiKey }
                }

                fieldGroup(label: "API Key (optional)") {
                    SecureField("Bearer token or API key", text: $apiKey)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .foregroundStyle(theme.textPrimary)
                        .padding(theme.spacingSM)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        .focusRing(isFocused: focusedField == .apiKey, cornerRadius: theme.cornerRadiusSmall)
                        .focused($focusedField, equals: .apiKey)
                        .accessibilityLabel("API key, optional")
                        .onSubmit { focusedField = nil }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Enter the full URL of your ILS backend instance.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Color Section

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Color Label")

            HStack(spacing: theme.spacingMD) {
                ForEach(BackendConnectionsViewModel.colorPresets, id: \.self) { hex in
                    colorSwatch(hex: hex)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Choose a color to visually identify this backend.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Test Connection Section

    private var testConnectionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Verify")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                AccentButton(
                    "Test Connection",
                    icon: "bolt.fill",
                    isLoading: isTesting
                ) {
                    Task { await testConnection() }
                }
                .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)

                if let result = testResult {
                    testResultBanner(result)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Test the connection before saving to confirm the backend is reachable.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Color Swatch

    @ViewBuilder
    private func colorSwatch(hex: String) -> some View {
        let isSelected = hex == selectedColorHex
        Button {
            selectedColorHex = hex
            HapticManager.selection()
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(theme.textPrimary.opacity(isSelected ? 0.8 : 0), lineWidth: 2)
                        .padding(2)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: theme.fontCaption, weight: .bold))
                        .foregroundStyle(theme.textOnAccent)
                        .opacity(isSelected ? 1 : 0)
                )
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color \(hex)\(isSelected ? ", selected" : "")")
    }

    // MARK: - Test Result Banner

    @ViewBuilder
    private func testResultBanner(_ result: TestResult) -> some View {
        HStack(spacing: theme.spacingSM) {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.success)
                Text("Connected successfully")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.success)
            case .failure(let message):
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(theme.error)
                Text(message)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.error)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(theme.spacingSM)
        .background(
            (result.isSuccess ? theme.success : theme.error).opacity(0.1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Field Group

    @ViewBuilder
    private func fieldGroup<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            content()
        }
    }

    // MARK: - Section Label

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    // MARK: - Actions

    private func testConnection() async {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }

        isTesting = true
        testResult = nil
        defer { isTesting = false }

        do {
            let client = APIClient(baseURL: trimmedURL)
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                await client.setAPIKey(trimmedKey)
            }
            _ = try await client.healthCheck()
            testResult = .success
            HapticManager.notification(.success)
        } catch {
            testResult = .failure(error.localizedDescription)
            HapticManager.notification(.error)
        }
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedURL.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        await viewModel.addBackend(
            name: trimmedName,
            url: trimmedURL,
            apiKey: trimmedKey.isEmpty ? nil : trimmedKey,
            colorHex: selectedColorHex
        )
        HapticManager.notification(.success)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AddBackendView(viewModel: BackendConnectionsViewModel())
}
