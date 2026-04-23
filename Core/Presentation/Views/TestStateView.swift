import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Diagnostic screen that displays fixed startup stages in tabs.
struct TestStateView: View {
    let diagnostics: StartupDiagnostics

    var body: some View {
        TabView {
            DiagnosticStageView(
                title: "Firebase",
                stage: diagnostics.firebase
            )
            .tabItem { Text("Firebase") }

            DiagnosticStageView(
                title: "AppsFlyer",
                stage: diagnostics.appsFlyer
            )
            .tabItem { Text("AppsFlyer") }

            DiagnosticStageView(
                title: "Server",
                stage: diagnostics.serverRequest
            )
            .tabItem { Text("Server") }

            DiagnosticStageView(
                title: "Final",
                stage: diagnostics.finalState
            )
            .tabItem { Text("Final") }

            MoreDiagnosticsView(more: diagnostics.more)
                .tabItem { Text("More") }
        }
        .onAppear(perform: configureDiagnosticsTabBarAppearance)
    }

    private func configureDiagnosticsTabBarAppearance() {
#if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        AppTypography.applyAppTabBarTitles(appearance: appearance)
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
#endif
    }
}

private struct DiagnosticStageView: View {
    let title: String
    let stage: StartupDiagnosticStage
    @State private var copyHint = "Tap card to copy"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppTypography.title2)

            VStack(alignment: .leading, spacing: 8) {
                Text(statusText)
                    .font(AppTypography.headline)
                    .foregroundStyle(statusColor)
                Text(stage.summary)
                    .font(AppTypography.body)
                if let targetState = stage.targetState {
                    Text("Target state: \(targetState)")
                        .font(AppTypography.body)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture {
                copyDebugText()
            }

            Text(copyHint)
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }

    private var statusText: String {
        switch stage.status {
        case .ok:
            return "OK"
        case .fail:
            return "FAIL"
        }
    }

    private var statusColor: Color {
        switch stage.status {
        case .ok:
            return .green
        case .fail:
            return .red
        }
    }

    private func copyDebugText() {
        var content = "\(title)\nStatus: \(statusText)\nSummary: \(stage.summary)"
        if let targetState = stage.targetState {
            content += "\nTarget state: \(targetState)"
        }
#if canImport(UIKit)
        UIPasteboard.general.string = content
        copyHint = "Copied to clipboard"
#else
        copyHint = "Clipboard is not available on this platform"
#endif
    }
}

private struct MoreDiagnosticsView: View {
    let more: StartupMoreData
    @State private var copyHint = "Tap any data block to copy"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MoreSectionView(
                    title: "FirebaseData",
                    value: more.firebaseData,
                    onCopy: handleCopy
                )
                MoreSectionView(
                    title: "AppsflyerData",
                    value: more.appsFlyerData,
                    onCopy: handleCopy
                )
                MoreSectionView(
                    title: "ServerRequest",
                    value: more.serverRequestData,
                    onCopy: handleCopy
                )
                MoreSectionView(
                    title: "ServerResponse",
                    value: more.serverResponseData,
                    onCopy: handleCopy
                )

                Text(copyHint)
                    .font(AppTypography.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private func handleCopy(_ text: String) {
#if canImport(UIKit)
        UIPasteboard.general.string = text
        copyHint = "Copied to clipboard"
#else
        copyHint = "Clipboard is not available on this platform"
#endif
    }
}

private struct MoreSectionView: View {
    let title: String
    let value: String
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.headline)
            Text(value)
                .font(AppTypography.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
                .onTapGesture {
                    onCopy("\(title)\n\(value)")
                }
        }
    }
}
