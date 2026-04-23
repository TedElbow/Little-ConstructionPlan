import SwiftUI
import UserNotifications
import UIKit

/// First launch screen that prompts the user to allow push notifications
/// and provides navigation to the web content if skipped or after permission is granted.
struct FirstLaunchScreen: View {
    let url: URL
    let isAskNotificationsMode: Bool
    @Environment(\.dependencyContainer) private var container
    @State private var navigateToWeb = false

    private var subtitle: String {
        container?.configuration.notificationSubtitle ?? ""
    }

    private var descriptionText: String {
        container?.configuration.notificationDescription ?? ""
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            // Primary CTA uses a wider column; Skip is a separate compact bar (not the same height — avoids huge grey slab).
            let contentWidth = min(
                geometry.size.width * (isLandscape ? 0.62 : 0.84),
                isLandscape ? 420 : 368
            )
            let logoCap: CGFloat = isLandscape ? min(geometry.size.height * 0.22, 80) : 240
            let logoSize = min(geometry.size.width * (isLandscape ? 0.22 : 0.58), logoCap)
            let rawPrimaryH = Self.notificationPrimaryButtonHeight(forWidth: contentWidth)
            // Landscape height is small; avoid capping Yes with height*0.15 or text clips outside the asset.
            let yesMaxH: CGFloat = {
                if isLandscape {
                    // Keep total stack short so Skip stays above safe area without scrolling.
                    return min(contentWidth * 0.38, geometry.size.height * 0.24)
                }
                return min(contentWidth * 0.32, geometry.size.height * 0.15)
            }()
            let yesMinH: CGFloat = isLandscape ? 58 : 54
            let yesButtonHeight = min(max(rawPrimaryH, yesMinH), yesMaxH)
            let skipBarHeight: CGFloat = isLandscape ? 36 : 46
            let horizontalSafe = geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing
            let skipWidth = min(
                contentWidth * 0.62,
                260,
                max(120, geometry.size.width - horizontalSafe - 32)
            )
            let stackSpacing: CGFloat = isLandscape ? 6 : 18
            let textSpacing: CGFloat = isLandscape ? 6 : 14
            let buttonSpacing: CGFloat = isLandscape ? 8 : 12
            let verticalPadding: CGFloat = isLandscape ? 8 : 22

            ZStack {
                if UIImage(named: "notificationBackground") != nil {
                    Image("notificationBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                } else if UIImage(named: "background") != nil {
                    Image("background")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }

                notificationBottomReferenceOverlay(size: geometry.size, isLandscape: isLandscape)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: geometry.size.height * (isLandscape ? 0.02 : 0.16))
                    HStack {
                        Spacer(minLength: 0)
                        notificationContentColumn(
                            contentWidth: contentWidth,
                            logoSize: logoSize,
                            stackSpacing: stackSpacing,
                            textSpacing: textSpacing,
                            buttonSpacing: buttonSpacing,
                            verticalPadding: verticalPadding,
                            yesButtonHeight: yesButtonHeight,
                            skipWidth: skipWidth,
                            skipBarHeight: skipBarHeight,
                            subtitle: subtitle,
                            descriptionText: descriptionText,
                            isLandscape: isLandscape,
                            bottomInset: max(geometry.safeAreaInsets.bottom, 12)
                        )
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: geometry.size.height * (isLandscape ? 0.02 : 0.05))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $navigateToWeb) {
            WebWindow(url: url)
        }
    }

    /// Static layout (no `ScrollView`) so the screen does not scroll.
    @ViewBuilder
    private func notificationContentColumn(
        contentWidth: CGFloat,
        logoSize: CGFloat,
        stackSpacing: CGFloat,
        textSpacing: CGFloat,
        buttonSpacing: CGFloat,
        verticalPadding: CGFloat,
        yesButtonHeight: CGFloat,
        skipWidth: CGFloat,
        skipBarHeight: CGFloat,
        subtitle: String,
        descriptionText: String,
        isLandscape: Bool,
        bottomInset: CGFloat
    ) -> some View {
        VStack(spacing: stackSpacing) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)

            VStack(spacing: textSpacing) {
                Text(subtitle)
                    .font(AppTypography.title2)
                    .foregroundColor(.white)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .lineLimit(isLandscape ? 3 : nil)
                    .minimumScaleFactor(isLandscape ? 0.65 : 0.9)
                    .fixedSize(horizontal: false, vertical: true)

                Text(descriptionText)
                    .font(AppTypography.title3)
                    .foregroundColor(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .lineLimit(isLandscape ? 2 : nil)
                    .minimumScaleFactor(isLandscape ? 0.7 : 0.92)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: contentWidth)

            VStack(spacing: buttonSpacing) {
                Button(action: requestPushPermission) {
                    ZStack {
                        Image("notificationButton")
                            .resizable()
                            .scaledToFit()
                            .frame(width: contentWidth, height: yesButtonHeight)
                        Text("Yes, I Want Bonuses!")
                            .foregroundColor(.white)
                            .font(AppTypography.body)
                            .textCase(.uppercase)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(isLandscape ? 0.68 : 0.78)
                            .lineLimit(3)
                            .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
                    }
                    .frame(width: contentWidth, height: yesButtonHeight)
                }

                HStack {
                    Spacer(minLength: 0)
                    Button(action: handleSkipTap) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.28))
                            Text("Skip")
                                .foregroundColor(.white)
                                .font(AppTypography.subheadline)
                                .textCase(.uppercase)
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                        }
                        .frame(width: skipWidth, height: skipBarHeight)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: contentWidth)
        .padding(.vertical, verticalPadding)
        .padding(.bottom, bottomInset)
    }

    /// Requests push notification permission from the user and navigates to the web screen.
    private func requestPushPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    requestSystemPermission()
                case .denied:
                    AskNotificationsRepeatState.markSkipped()
                    openNotificationSettings()
                    navigateToWeb = true
                case .authorized, .provisional, .ephemeral:
                    AskNotificationsRepeatState.clearPending()
                    navigateToWeb = true
                @unknown default:
                    requestSystemPermission()
                }
            }
        }
    }

    private func requestSystemPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            DispatchQueue.main.async {
                AskNotificationsRepeatState.handleAuthorizationResult(granted: granted)
                navigateToWeb = true
            }
        }
    }

    private func handleSkipTap() {
        AskNotificationsRepeatState.markSkipped()
        navigateToWeb = true
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url)
        else { return }
        UIApplication.shared.open(url)
    }

    /// Bottom band: teal tint from asset (subtle) + strong darkening at bottom edge (not flat teal).
    @ViewBuilder
    private func notificationBottomReferenceOverlay(size: CGSize, isLandscape: Bool) -> some View {
        let width = size.width
        let height = size.height
        if isLandscape {
            ZStack {
                if UIImage(named: "NotificationBottomMask") != nil {
                    Image("NotificationBottomMask")
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .scaleEffect(x: 1, y: -1, anchor: .center)
                        .clipped()
                        .opacity(0.45)
                }
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.05), location: 0),
                        .init(color: Color.black.opacity(0.18), location: 0.4),
                        .init(color: Color.black.opacity(0.45), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.multiply)
            }
            .frame(width: width, height: height)
            .clipped()
        } else {
            let bandHeight = height * 0.55
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack {
                    if UIImage(named: "NotificationBottomMask") != nil {
                        Image("NotificationBottomMask")
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: bandHeight)
                            .scaleEffect(x: 1, y: -1, anchor: .center)
                            .clipped()
                            .opacity(0.38)
                    }
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0), location: 0),
                            .init(color: Color.black.opacity(0.12), location: 0.35),
                            .init(color: Color.black.opacity(0.38), location: 0.72),
                            .init(color: Color.black.opacity(0.62), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.multiply)
                }
                .frame(width: width, height: bandHeight)
            }
            .frame(width: width, height: height, alignment: .bottom)
        }
    }

    /// Matches the rendered height of `notificationButton` at the given width (same as primary CTA).
    private static func notificationPrimaryButtonHeight(forWidth width: CGFloat) -> CGFloat {
        guard let image = UIImage(named: "notificationButton"), image.size.width > 0 else {
            return 52
        }
        return width * (image.size.height / image.size.width)
    }
}
