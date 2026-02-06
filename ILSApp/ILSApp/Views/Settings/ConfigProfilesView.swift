import SwiftUI

struct ConfigProfilesView: View {
    @State private var profiles: [ConfigProfile] = ConfigProfile.defaults
    @State private var showingNewProfile = false
    @State private var profileToEdit: ConfigProfile?
    @State private var profileToDelete: ConfigProfile?

    var body: some View {
        List {
            ForEach(profiles) { profile in
                HStack(spacing: 12) {
                    Image(systemName: profile.isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(profile.isActive ? .green : .gray)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(profile.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                        HStack(spacing: 8) {
                            Label("\(profile.mcpServers.count) servers", systemImage: "server.rack")
                            Label("\(profile.skills.count) skills", systemImage: "star")
                        }
                        .font(.caption2)
                        .foregroundColor(.orange.opacity(0.8))
                    }

                    Spacer()

                    if !profile.isActive {
                        Button("Activate") {
                            activateProfile(profile)
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture { profileToEdit = profile }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        profileToDelete = profile
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button { activateProfile(profile) } label: {
                        Label("Activate", systemImage: "checkmark.circle")
                    }
                    Button { profileToEdit = profile } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) { profileToDelete = profile } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Configuration Profiles")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNewProfile = true } label: {
                    Image(systemName: "plus").foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $showingNewProfile) {
            NavigationStack {
                ConfigProfileFormView(profiles: $profiles)
            }
        }
        .sheet(item: $profileToEdit) { profile in
            NavigationStack {
                ConfigProfileFormView(profiles: $profiles, existingProfile: profile)
            }
        }
        .alert("Delete Profile?", isPresented: .init(
            get: { profileToDelete != nil },
            set: { if !$0 { profileToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { profileToDelete = nil }
            Button("Delete", role: .destructive) {
                if let p = profileToDelete {
                    profiles.removeAll { $0.id == p.id }
                    profileToDelete = nil
                }
            }
        }
    }

    private func activateProfile(_ profile: ConfigProfile) {
        for i in profiles.indices {
            profiles[i].isActive = (profiles[i].id == profile.id)
        }
    }
}

struct ConfigProfileFormView: View {
    @Binding var profiles: [ConfigProfile]
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var mcpServers: String = ""
    @State private var skills: String = ""

    let existingProfile: ConfigProfile?

    init(profiles: Binding<[ConfigProfile]>, existingProfile: ConfigProfile? = nil) {
        self._profiles = profiles
        self.existingProfile = existingProfile
    }

    var body: some View {
        Form {
            Section("Profile Info") {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
            }
            Section("MCP Servers (comma-separated)") {
                TextField("e.g. filesystem, memory", text: $mcpServers)
                    .autocapitalization(.none)
            }
            Section("Skills (comma-separated)") {
                TextField("e.g. code-review, testing", text: $skills)
                    .autocapitalization(.none)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle(existingProfile == nil ? "New Profile" : "Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }.foregroundColor(.orange)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .foregroundColor(.orange)
                    .disabled(name.isEmpty)
            }
        }
        .onAppear {
            if let p = existingProfile {
                name = p.name
                description = p.description
                mcpServers = p.mcpServers.joined(separator: ", ")
                skills = p.skills.joined(separator: ", ")
            }
        }
    }

    private func save() {
        var profile = existingProfile ?? ConfigProfile()
        profile.name = name
        profile.description = description
        profile.mcpServers = mcpServers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        profile.skills = skills.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        profile.updatedAt = Date()

        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        dismiss()
    }
}
