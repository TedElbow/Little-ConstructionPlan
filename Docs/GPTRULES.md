# GPT Rules — BaseProject (iOS)

This document contains rules and context for AI assistants (e.g. ChatGPT, Cursor) so they can start working with the project and its architecture immediately. Follow these rules when generating or modifying code.

---

## 1. Project identity and tech stack

- **Project:** BaseProject — iOS base app template with Clean Architecture.
- **Language:** Swift.
- **UI:** SwiftUI.
- **Minimum iOS:** 16.0 (see Podfile).
- **Dependencies:** CocoaPods (AppsFlyer, Firebase Core/Messaging/RemoteConfig). Use `bundle exec pod install` from project root.
- **Targets:** Two targets — main app (first in TARGETS, name can be renamed from BaseProject) and **notifications** (Notification Service Extension). Both share the same Pods; Podfile resolves main target by name dynamically.
- **Build configs:** Debug, Staging, Release (see `BuildConfiguration.current` and Xcode schemes).

---

## 2. Architecture: Clean Architecture (dependency rule)

The app uses **Clean Architecture**. Dependencies point **inward**: outer layers depend on inner layers; inner layers do **not** know about outer layers.

```
Presentation (Views, ViewModels)  →  depends only on Domain (protocols, use cases)
         ↓
Domain (Entities, Use Case protocols, Repository protocols)  →  no UIKit/SwiftUI, no Data/Infrastructure types
         ↓
Data (Repository implementations, Data Sources)  →  implements Domain protocols; may use Infrastructure (config, logging)
         ↓
Infrastructure (Configuration, DI, Logging)  →  wires everything; no business logic
```

### Import rules (strict)

| Layer          | May import                    | Must NOT import                          |
|----------------|-------------------------------|------------------------------------------|
| **Domain**     | Foundation, Swift, other Domain | UIKit, SwiftUI, concrete Data/Infrastructure |
| **Data**       | Domain, Infrastructure (protocols only) | Presentation                           |
| **Presentation** | Domain, SwiftUI             | Concrete Data/Infrastructure types       |
| **Infrastructure** | All (for wiring only)    | —                                        |

- **Domain:** Entities, repository/service protocols, use case protocols. No UI, no concrete implementations.
- **Data:** Implements repository protocols; contains data sources, DTOs, API clients. Depends only on Domain (+ config/logger via protocols).
- **Presentation:** ViewModels and Views. Depend **only on protocols** (use cases, repositories) provided via DI. Never reference `DefaultDependencyContainer` or concrete repository classes.
- **Infrastructure:** `AppConfiguration`/`AppConfigurationProtocol`, `DependencyContainer`, `DefaultDependencyContainer`, logging. Only assembly and cross-cutting concerns.

---

## 3. Folder structure and where to put things

```
App/                          # Entry point: @main, AppDelegate, BuildConfiguration, AppDependencies
Core/
  Domain/                     # Shared entities, repository protocols, use case protocols
    Entities/
    Repositories/             # Protocols only
    UseCases/
  Data/                       # Shared repository implementations, data sources
    Repositories/
    DataSources/
  Presentation/               # Shared ViewModels, Views, coordinators
    ViewModels/
    Views/
Features/
  <FeatureName>/              # e.g. Analytics, AppInitialization, Networking, Notifications, WebView
    Domain/                   # Feature-specific entities, protocols
    Data/                     # Feature-specific repository/data source implementations
    Presentation/             # Feature-specific ViewModels and Views (if any)
Infrastructure/
  Configuration/              # AppConfiguration, AppConfigurationProtocol
  DI/                         # DependencyContainer, DefaultDependencyContainer, EnvironmentKeys
  Logging/                    # Logging protocol, DefaultLogger, LogStore
  OrientationLock.swift
Resources/
  Assets.xcassets/
  Preview Content/
Docs/                         # ARCHITECTURE.md, EXTENDING.md, GPTRULES.md, TROUBLESHOOTING.md
```

### Quick reference: where to add what

| What you add                         | Where to put it |
|--------------------------------------|------------------|
| New business entity (model)          | `Features/<Feature>/Domain/Entities/` or `Core/Domain/Entities/` |
| Repository / use case **protocol**   | `Features/<Feature>/Domain/` or `Core/Domain/` |
| Repository **implementation**, API/DB| `Features/<Feature>/Data/` or `Core/Data/` |
| ViewModel, SwiftUI screen             | `Features/<Feature>/Presentation/` or `Core/Presentation/` |
| DI registration                       | `Infrastructure/DI/DependencyContainer.swift` and `App/AppDependencies.swift` |
| Config keys, URLs, feature flags      | `Infrastructure/Configuration/` (`StartupDefaultsConfiguration`, `AppConfiguration`) |

New Swift files must be added to the **BaseProject** (main app) target in Xcode; add to **notifications** target only if that extension needs them.

---

## 4. Dependency injection (DI)

- **Single assembly point:** `AppDependencies.makeDefaultContainer()` builds the production container. Called from `AppDelegate.didFinishLaunching` (or `containerForTesting` is used if set).
- **Container type:** `DependencyContainer` (protocol) and `DefaultDependencyContainer` (implementation). All dependencies are exposed as **protocols** (e.g. `AnalyticsRepositoryProtocol`, `AppInitializerUseCaseProtocol`).
- **Where container lives:** Created in AppDelegate; passed into SwiftUI via `BaseProject`: `.environment(\.dependencyContainer, container)`. No global singleton; views read `@Environment(\.dependencyContainer) private var container`.
- **Container is optional in Environment:** `DependencyContainer?` — always unwrap (e.g. `guard let container else { return AnyView(EmptyView()) }`) before using.
- **Adding a new dependency:**  
  1. Add property to protocol `DependencyContainer` (e.g. `var myUseCase: MyUseCaseProtocol { get }`).  
  2. Add same property and `init` parameter to `DefaultDependencyContainer`.  
  3. In `AppDependencies.makeDefaultContainer()`, instantiate the implementation and pass it into `DefaultDependencyContainer(...)`.  
  4. In Views/ViewModels, get it from `container.myUseCase` and pass into ViewModel `init`; do not instantiate repositories or use cases inside Views.
- **Testing:** Implement a mock `DependencyContainer` (or mock individual protocols) and call `AppDependencies.setContainerForTesting(mockContainer)` before the app runs. Do not rely on singletons in business logic.

---

## 5. App entry and navigation flow

- **Entry:** `@main struct BaseProject: App` with `@UIApplicationDelegateAdaptor(AppDelegate.self)`. AppDelegate creates the container in `didFinishLaunching` and assigns it to `AppDependencies.setLaunchContainer(_:)`; BaseProject reads `AppDependencies.launchContainer` to build `AppViewModelHolder`, which holds the container and creates `AppViewModel`.
- **Root UI:** `RootView` is the root. It uses `@EnvironmentObject var appVM: AppViewModel` and switches on `appVM.state` (type `AppState`).
- **AppState (Core/Domain/Entities/AppState.swift):**  
  `loading` | `firstLaunch(URL)` | `native` | `testState` | `web(URL)` | `askNotifications(URL)` | `error(String)` | `noInternet`.  
  This single enum drives which screen is shown (LoadingView, FirstLaunchScreen, MainTabView, WebWindow, error text, NoInternetScreen, etc.).
- **AppViewModel:** Depends only on `AppInitializerUseCaseProtocol` and `PushTokenProviderProtocol`. `start()` calls the use case and updates `state`; RootView reacts to `state`.
- **Native shell (`AppState.native`):** RootView shows `MainTabView()`. The template uses a system grouped background only; catalog images such as `gameBackground` are intended for a later design/theme agent pass and are not wired in `MainTabView` until then. When you add themed tabs, use a ZStack background per screen if needed; for lists: `.scrollContentBackground(.hidden)` and `.listRowBackground(Color.clear)` so a custom background shows through.

---

## 6. Configuration and debug flags

- **AppConfiguration** (`Infrastructure/Configuration/AppConfiguration.swift`): Reads server URL, store ID, Firebase project ID, AppsFlyer dev key from Bundle (Info.plist) when keys exist; otherwise uses defaults from `StartupDefaultsConfiguration.swift`. Optional plist overrides can still be supplied via Xcode Build Settings / `INFOPLIST_KEY_*`.
- **Debug / feature flags** (used by `InitializeAppUseCase` and UI):  
  `isDebug`, `isGameOnly`, `isWebOnly`, `isNoNetwork`, `isAskNotifications`, `isInfinityLoading`.  
  Set in `AppConfiguration` init (defaults in code); can override for debugging (e.g. force only game, only WebView, only no-internet screen, only notifications screen, infinite loading).
- **BuildConfiguration** (`App/BuildConfiguration.swift`): Resolves `.debug` / `.staging` / `.release` from `SWIFT_ACTIVE_COMPILATION_CONDITIONS` (DEBUG, STAGING). `AppDependencies.makeDefaultContainer()` uses `BuildConfiguration.current` when building `AppConfiguration(isDebug: buildConfig.isDebug)`.

---

## 7. Adding a new feature (checklist)

1. **Domain** (`Features/<Feature>/Domain/`):  
   - Entities (if needed).  
   - Repository/use case **protocols** (e.g. `MyRepositoryProtocol`, `DoSomethingUseCaseProtocol`).
2. **Data** (`Features/<Feature>/Data/`):  
   - Implement repository and/or data sources.  
   - Implement use case classes conforming to Domain protocols (use case can live in Data when it orchestrates repositories).
3. **Presentation** (if UI):  
   - ViewModel: `init` receives **protocols** only (e.g. use case protocol).  
   - View: receives ViewModel (or creates it from container in parent). Use `@StateObject private var viewModel` with `init(viewModel:)` that wraps in `StateObject(wrappedValue:)`.
4. **DI:**  
   - Add to `DependencyContainer` and `DefaultDependencyContainer`: e.g. `var myRepository: MyRepositoryProtocol { get }`, `var doSomethingUseCase: DoSomethingUseCaseProtocol { get }`.  
   - In `AppDependencies.makeDefaultContainer()`: create concrete types and pass into `DefaultDependencyContainer(...)`.
5. **Navigation:** In the place that should show the new screen (e.g. `MainTabView`), get `container` from `@Environment(\.dependencyContainer)`, unwrap it, get use case/repository from container, create ViewModel, then present the View with that ViewModel.

Never let Presentation depend on concrete Data or Infrastructure types; only on protocols provided by the container.

---

## 8. Adding a new use case

1. **Domain:** In the appropriate feature (or Core), define a protocol, e.g. `DoSomethingUseCaseProtocol` with `func execute(...) async throws -> ResultType`.
2. **Data:** Create a class that conforms to the protocol, depending only on repository/service protocols; implement `execute` (call repos, map to domain entities).
3. **DI:** Add `var doSomethingUseCase: DoSomethingUseCaseProtocol { get }` to `DependencyContainer` and `DefaultDependencyContainer`; in `makeDefaultContainer()` create the use case and pass it in.
4. **Presentation:** Inject `DoSomethingUseCaseProtocol` into the ViewModel and call it; do not inject the repository directly if the screen’s public API should be the use case.

---

## 9. Adding a new screen (no new feature)

If the screen belongs to an existing feature (e.g. WebView, AppInitialization):  
- Put ViewModel and View in `Core/Presentation/` or `Features/<ExistingFeature>/Presentation/`.  
- Get dependencies from the container (use case or repository) and pass them into the ViewModel in the parent (e.g. in MainTabView or RootView). Do not create repositories or use cases inside the View.

---

## 10. Code style and conventions

- **Comments:** Always in **English**.
- **Reusable types:** Always introduce a **protocol (interface)** for reusable classes/functions that may be swapped or tested (repositories, use cases, data sources, configuration). Views and ViewModels depend on these protocols, not concrete types.
- **ViewModels:** `@MainActor`, `ObservableObject`, dependencies via `init`. Use `@Published` for state that drives the UI.
- **Views:** Prefer taking ViewModel in `init` and storing with `@StateObject(wrappedValue:)`; get container from Environment only in the parent that composes the screen.
- **Async:** Use `async/await` and `Task { @MainActor in ... }` when updating UI from async work.

---

## 11. Targets and signing

- **Two targets:** Main app (e.g. BaseProject) and **notifications** (Notification Service Extension). Both need **Signing & Capabilities** (Team, Bundle Identifier). Notifications bundle ID must be a **sub-domain** of the main app (e.g. `com.company.app.notifications`).
- After **renaming** project or main target: run `bundle exec pod install` from project root and open `.xcworkspace` (not `.xcodeproj`) to avoid "sandbox is not in sync with Podfile.lock". See EXTENDING.md for full rename steps.

---

## 12. Common pitfalls

- **"Cannot find type X in scope"** — Ensure the file that defines X is in the same target (BaseProject) as the file that uses it.
- **Circular dependencies** — Domain must not import Data or Presentation. Data must not import Presentation.
- **Container is nil** — Use `guard let container else { ... }` when reading `@Environment(\.dependencyContainer)`; container is set only at root in BaseProject.
- **Custom background not visible in lists** — Use `.scrollContentBackground(.hidden)` and `.listRowBackground(Color.clear)` and draw the background in the same view (e.g. ZStack with your image or color).

---

## 13. Testing

- **Unit tests:** Mock `DependencyContainer` or individual protocols (e.g. `AppInitializerUseCaseProtocol`, `NetworkRepositoryProtocol`) and inject into ViewModels or use cases. Use `AppDependencies.setContainerForTesting(mockContainer)` for integration-style tests before UI runs.
- **No business logic in singletons** — Keep logic behind protocols so tests can substitute implementations.

---

## 14. References

- **Architecture details:** `Docs/ARCHITECTURE.md`
- **Step-by-step extending (features, DI, screens, rename, signing):** `Docs/EXTENDING.md`
- **Troubleshooting (environment, Xcode, CocoaPods):** `Docs/TROUBLESHOOTING.md`

When in doubt, prefer protocols over concrete types, keep Domain free of UI and infrastructure, and wire new dependencies only in `DependencyContainer` and `AppDependencies.makeDefaultContainer()`.
