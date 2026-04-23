import SwiftUI
import UIKit

/// Loading screen with centered logo and animated dots indicating progress.
struct LoadingView: View {
    @State private var dots: Int = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                Group {
                    if UIImage(named: "loadingBackground") != nil {
                        Image("loadingBackground")
                            .resizable()
                            .scaledToFill()
                    } else if UIImage(named: "background") != nil {
                        Image("background")
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.black
                    }
                }
                // Slightly oversize vertically to avoid a 1pt gap above the home indicator after clipping.
                .frame(width: w * 1.12, height: h * 1.02)
                .offset(x: -w * 0.05)
                .frame(width: w, height: h)
                .clipped()

                VStack(spacing: 18) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: min(w * 0.42, 220),
                            height: min(w * 0.42, 220)
                        )

                    Text("Loading" + String(repeating: ".", count: dots))
                        .font(AppTypography.title2)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
                        .onReceive(timer) { _ in
                            dots = (dots + 1) % 4
                        }
                }
                .frame(width: min(w * 0.78, 320))
                .position(x: w / 2, y: h * 0.39)
            }
        }
        .ignoresSafeArea()
    }
}
