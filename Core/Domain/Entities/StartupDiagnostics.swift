import Foundation

/// Diagnostic status for a startup pipeline stage.
enum StartupDiagnosticStatus: Equatable {
    case ok
    case fail
}

/// Diagnostic payload for one startup stage.
struct StartupDiagnosticStage: Equatable {
    let status: StartupDiagnosticStatus
    let summary: String
    let targetState: String?
}

/// Extended diagnostic payloads shown in the More tab.
struct StartupMoreData: Equatable {
    let firebaseData: String
    let appsFlyerData: String
    let serverRequestData: String
    let serverResponseData: String
}

/// Full startup diagnostics split by fixed UI tabs.
struct StartupDiagnostics: Equatable {
    let firebase: StartupDiagnosticStage
    let appsFlyer: StartupDiagnosticStage
    let serverRequest: StartupDiagnosticStage
    let finalState: StartupDiagnosticStage
    let more: StartupMoreData

    var hasFailures: Bool {
        firebase.status == .fail ||
        appsFlyer.status == .fail ||
        serverRequest.status == .fail ||
        finalState.status == .fail
    }

    static let empty = StartupDiagnostics(
        firebase: StartupDiagnosticStage(
            status: .fail,
            summary: "Firebase stage was not executed",
            targetState: nil
        ),
        appsFlyer: StartupDiagnosticStage(
            status: .fail,
            summary: "AppsFlyer stage was not executed",
            targetState: nil
        ),
        serverRequest: StartupDiagnosticStage(
            status: .fail,
            summary: "Server request stage was not executed",
            targetState: nil
        ),
        finalState: StartupDiagnosticStage(
            status: .fail,
            summary: "Final state stage was not executed",
            targetState: nil
        ),
        more: StartupMoreData(
            firebaseData: "No Firebase data",
            appsFlyerData: "No AppsFlyer data",
            serverRequestData: "No server request data",
            serverResponseData: "No server response data"
        )
    )
}
