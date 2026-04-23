import SwiftUI
import UIKit

/// Screen displayed when there is no internet connection.
struct NoInternetScreen: View {
    @Environment(\.dependencyContainer) private var container

    private var message: String {
        container?.configuration.noInternetMessage ?? "Please check your internet connection."
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let horizontalInset = geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing
            let usableWidth = max(0, geometry.size.width - horizontalInset)
            let horizontalMargin: CGFloat = 24
            let maxCardByScreen = max(0, usableWidth - horizontalMargin)
            let proportional = usableWidth * (isLandscape ? 0.72 : 0.88)
            let cardWidth = min(340, min(proportional, maxCardByScreen))
            let cardHeight = min(geometry.size.height * (isLandscape ? 0.55 : 0.42), 280)

            ZStack {
                Color.black
                if UIImage(named: "internetBackground") != nil {
                    Image("internetBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                }

                Color.black.opacity(0.35)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        ZStack {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.06, green: 0.18, blue: 0.72).opacity(0.88),
                                            Color(red: 0.06, green: 0.38, blue: 0.94).opacity(0.88)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.yellow.opacity(0.95), Color.orange.opacity(0.9)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 8
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.22), lineWidth: 2)
                                        .padding(7)
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 14, y: 8)

                            contentOverlay(cardInnerWidth: max(0, cardWidth - 32), isLandscape: isLandscape)
                        }
                        .frame(width: cardWidth, height: cardHeight, alignment: .center)
                        .clipped()
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .contain)
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func contentOverlay(cardInnerWidth: CGFloat, isLandscape: Bool) -> some View {
        let textMaxWidth = max(0, cardInnerWidth - 8)

        return VStack(spacing: 14) {
            Image(systemName: "wifi.slash")
                .font(.system(size: isLandscape ? 30 : 34, weight: .bold))
                .foregroundColor(.red)

            Text(message)
                .font(AppTypography.title3)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: textMaxWidth)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: cardInnerWidth)
        .padding(.horizontal, 12)
        .padding(.vertical, 20)
    }
}
