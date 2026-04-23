import Foundation
import SwiftUI

/// Protocol for app-level navigation coordination. Used by presentation layer to drive transitions.
protocol AppCoordinatorProtocol: AnyObject {

    /// Current root state that drives which screen is shown.
    var state: AppState { get }

    /// Starts the app flow (e.g. loading, then first launch / web / game).
    func start()
}
