import SwiftUI

struct LoadingView: View {
    @State private var dots: Int = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Фон
            Image("loadingBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                Spacer()

                // Лого по центру
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)

                Spacer()

                // Текст Loading с анимацией точек
                Text("Loading" + String(repeating: ".", count: dots))
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.bottom, 60)
                    .onReceive(timer) { _ in
                        dots = (dots + 1) % 4
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
