# Onboarding & First Launch

**Type:** Sequence Diagram
**Last Updated:** 2026-03-18
**Related Files:**
- `ILSApp/ILSApp/Views/Onboarding/`
- `ILSApp/ILSApp/ViewModels/OnboardingViewModel.swift`
- `ILSApp/ILSApp/ViewModels/SetupViewModel.swift`
- `ILSApp/ILSApp/Views/Settings/ServerSetupSheet.swift`
- `ILSApp/ILSApp/AppState.swift`

## Purpose

Guides a first-time user from app launch to a connected, functional ILS experience — including backend setup instructions, server connection, and initial data load so they see value within 60 seconds.

## Diagram

```mermaid
graph TD
    subgraph "Front-Stage (User Experience)"
        Launch[User Launches ILS ⚡] --> Welcome[Welcome Screen 🎯 What ILS does]
        Welcome --> Setup[Setup Instructions ✅ Step-by-step]
        Setup --> Connect[Enter Server URL ⚡ Default localhost:9999]
        Connect --> Verify[Connection Test ⏱️ Spinner]
        Verify -->|Success| Dashboard[Dashboard Loaded 🎯 Sessions + stats]
        Dashboard --> User[User Starts Using ILS ✅]
    end

    subgraph "Back-Stage (Implementation)"
        Welcome --> OnboardingVM[OnboardingViewModel 💾 Track completion]
        Setup --> BackendInstructions[Show Terminal Commands 🎯]

        Connect --> URLValidation[URL Validation ✅ Format + reachability]
        URLValidation --> HealthCheck[GET /health 🛡️ Verify backend]

        HealthCheck -->|200 OK| SaveURL[Save to UserDefaults 💾]
        SaveURL --> InitialLoad[Parallel Data Fetch ⚡]
        InitialLoad --> FetchSessions[GET /sessions 📊]
        InitialLoad --> FetchStats[GET /stats 📊]
        InitialLoad --> FetchProjects[GET /projects 📊]

        OnboardingVM --> OnboardingComplete[Mark Onboarded 💾 Never show again]
    end

    HealthCheck -->|Connection refused| Instructions[Show Backend Start Command 🔄]
    Instructions --> RetryButton[Retry Connection ⏱️]
    RetryButton --> HealthCheck

    URLValidation -->|Invalid URL| URLError[Highlight Error 🔄 Fix and retry]

    HealthCheck -->|Wrong backend| WrongBinary[Binary Mismatch Warning 🛡️]
    WrongBinary --> Instructions
```

## Key Insights

- **60-Second Goal**: User should see their data within a minute of first launch
- **Zero-Config Default**: `localhost:9999` pre-filled — local users just tap Connect
- **Clear Instructions**: Shows exact terminal commands to start the backend
- **Binary Mismatch Detection**: Warns if old backend (wrong path) is running
- **Parallel Loading**: Sessions, stats, and projects fetched simultaneously after connection
- **One-Time Only**: Onboarding marked complete in UserDefaults — never shown again

## Change History

- **2026-03-18:** Initial creation
