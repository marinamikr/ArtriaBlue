//
//  ContentView.swift
//  Arturiablue
//
//  Created by 原田摩利奈 on 2026/06/09.
//

import SwiftUI
import Combine
import CoreMotion

@MainActor
final class MotionViewModel: ObservableObject {
    @Published var x: Double = 0
    @Published var y: Double = 0
    @Published var z: Double = 0
    @Published var statusText: String = "ドラッグでプレビュー"
    @Published var isLive = false

    private let motionManager = CMMotionManager()
    private var smoothedAcceleration = (x: 0.0, y: 0.0, z: 0.0)

    var isSupported: Bool {
        motionManager.isAccelerometerAvailable
    }

    func start() {
        guard motionManager.isAccelerometerAvailable else {
            statusText = "加速度センサー未対応"
            isLive = false
            return
        }

        motionManager.accelerometerUpdateInterval = 1.0 / 60.0
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self else { return }

            if let error {
                self.statusText = error.localizedDescription
                self.isLive = false
                return
            }

            guard let data else {
                self.statusText = "センサー待機中"
                self.isLive = false
                return
            }

            let rawX = clamp(data.acceleration.x, -1, 1)
            let rawY = clamp(data.acceleration.y, -1, 1)
            let rawZ = clamp(data.acceleration.z, -1, 1)
            let next = (
                x: self.smoothedAcceleration.x * 0.68 + rawX * 0.32,
                y: self.smoothedAcceleration.y * 0.68 + rawY * 0.32,
                z: self.smoothedAcceleration.z * 0.68 + rawZ * 0.32
            )

            self.smoothedAcceleration = next
            self.x = next.x
            self.y = next.y
            self.z = next.z
            self.isLive = true
            self.statusText = "accelerometer live"
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
        isLive = false
    }
}

struct ContentView: View {
    @StateObject private var motionViewModel = MotionViewModel()
    @State private var fallbackTiltX: Double = 0
    @State private var fallbackTiltY: Double = 0
    @State private var sensitivity: Double = 1.05
    @State private var isDemoAlertActive = false

    private var isHighHeartRatePresent: Bool {
        isDemoAlertActive
    }

    private var heartResponse: Double {
        isDemoAlertActive ? 1 : 0
    }

    private var activeTiltX: Double {
        motionViewModel.isLive ? motionViewModel.x : fallbackTiltX
    }

    private var activeTiltY: Double {
        motionViewModel.isLive ? motionViewModel.y : fallbackTiltY
    }

    private var tiltX: Double {
        clamp(activeTiltX * sensitivity * 1.34, -1, 1)
    }

    private var tiltY: Double {
        clamp(activeTiltY * sensitivity * 1.34, -1, 1)
    }

    private var shimmer: Double {
        clamp((abs(tiltX) + abs(tiltY)) * 0.72 + 0.22, 0.22, 1)
    }

    private var gemCoreColor: Color {
        isHighHeartRatePresent
            ? Color(red: 1.0, green: 0.51, blue: 0.88)
            : Color(
                red: clamp(0.22 - tiltX * 0.10 + tiltY * 0.04, 0.12, 0.34),
                green: clamp(0.58 + tiltX * 0.24 - tiltY * 0.08, 0.38, 0.84),
                blue: clamp(0.96 - tiltX * 0.06 + tiltY * 0.03, 0.88, 1.0)
            )
    }

    private var gemDeepColor: Color {
        isHighHeartRatePresent
            ? Color(red: 0.49, green: 0.17, blue: 0.94)
            : Color(
                red: clamp(0.08 - tiltX * 0.04 + heartResponse * 0.14, 0.04, 0.20),
                green: clamp(0.34 + tiltX * 0.17 - tiltY * 0.08, 0.20, 0.56),
                blue: clamp(0.72 + tiltY * 0.08 + heartResponse * 0.14, 0.62, 0.86)
            )
    }

    private var gemVioletColor: Color {
        isHighHeartRatePresent
            ? Color(red: 1.0, green: 0.47, blue: 0.87)
            : Color(
                red: clamp(0.36 - tiltX * 0.16 + heartResponse * 0.22, 0.20, 0.58),
                green: clamp(0.34 + tiltX * 0.08 - heartResponse * 0.08, 0.24, 0.46),
                blue: clamp(0.88 + shimmer * 0.05, 0.82, 0.96)
            )
    }

    private var gemLimeColor: Color {
        isHighHeartRatePresent
            ? Color(red: 1.0, green: 0.76, blue: 0.98)
            : Color(
                red: clamp(0.13 - tiltX * 0.04, 0.08, 0.20),
                green: clamp(0.88 + tiltX * 0.09, 0.80, 0.98),
                blue: clamp(0.76 - tiltX * 0.08, 0.66, 0.84)
            )
    }

    private var gemAquaColor: Color {
        isHighHeartRatePresent
            ? Color(red: 1.0, green: 0.62, blue: 0.95)
            : Color(
                red: clamp(0.18 + tiltY * 0.04, 0.12, 0.24),
                green: clamp(0.82 - tiltY * 0.10, 0.70, 0.94),
                blue: clamp(0.98 + shimmer * 0.02, 0.94, 1.0)
            )
    }

    var body: some View {
        ZStack {
            AppBackground()

            gemStage
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)

            topBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.horizontal, 18)
                .padding(.top, 18)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.75)) {
                isDemoAlertActive.toggle()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            motionViewModel.start()
            isDemoAlertActive = false
        }
        .onDisappear {
            motionViewModel.stop()
        }
    }

    private var topBar: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("ESEKAI MONOGATARI")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(Color(red: 0.62, green: 0.74, blue: 0.88))

            Text("Arturia")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }


    private var gemStage: some View {
        GemScene(
            tiltX: tiltX,
            tiltY: tiltY,
            shimmer: shimmer,
            alertActive: isHighHeartRatePresent,
            coreColor: gemCoreColor,
            deepColor: gemDeepColor,
            violetColor: gemVioletColor,
            limeColor: gemLimeColor,
            aquaColor: gemAquaColor
        )
        .frame(height: 520)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    if motionViewModel.isLive {
                        return
                    }
                    fallbackTiltX = clamp(value.translation.width / 160.0, -1, 1)
                    fallbackTiltY = clamp(value.translation.height / 160.0, -1, 1)
                }
        )
    }

}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.10, blue: 0.16)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.15, blue: 0.22).opacity(0.92),
                    Color(red: 0.02, green: 0.10, blue: 0.17),
                    Color(red: 0.015, green: 0.075, blue: 0.13)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.14, green: 0.72, blue: 0.94).opacity(0.20),
                    Color.clear
                ],
                center: .init(x: 0.50, y: 0.42),
                startRadius: 0,
                endRadius: 440
            )
            .ignoresSafeArea()

            GridPattern()
                .stroke(Color.white.opacity(0.035), lineWidth: 0.7)
                .ignoresSafeArea()
        }
    }
}

private struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 18

        stride(from: rect.minX, through: rect.maxX, by: step).forEach { x in
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        stride(from: rect.minY, through: rect.maxY, by: step).forEach { y in
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}

private struct GemScene: View {
    let tiltX: Double
    let tiltY: Double
    let shimmer: Double
    let alertActive: Bool
    let coreColor: Color
    let deepColor: Color
    let violetColor: Color
    let limeColor: Color
    let aquaColor: Color

    private var glowColor: Color {
        alertActive ? Color(red: 1.0, green: 0.35, blue: 0.78) : Color(red: 0.37, green: 0.86, blue: 0.96)
    }

    private var emeraldStrength: Double {
        alertActive ? 0 : clamp(0.32 + tiltX * 0.34 - tiltY * 0.08, 0.08, 0.68)
    }

    private var violetStrength: Double {
        alertActive ? 0 : clamp(0.24 - tiltX * 0.28 + tiltY * 0.08, 0.06, 0.58)
    }

    private var aquaStrength: Double {
        alertActive ? 0 : clamp(0.34 - tiltY * 0.30 + abs(tiltX) * 0.06, 0.10, 0.66)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.82, 322)
            let height = width * 1.06
            let rotation = Angle(degrees: tiltX * 7)
            let lightX = tiltX * width * 0.16
            let lightY = tiltY * height * 0.13

            ZStack {
                Ellipse()
                    .fill(glowColor.opacity(alertActive ? 0.34 : 0.20))
                    .frame(width: width * 1.10, height: height * 0.32)
                    .blur(radius: 26)
                    .offset(y: height * 0.39)

                MineralShape()
                    .fill(alertActive ? Color(red: 0.22, green: 0.05, blue: 0.28).opacity(0.66) : Color(red: 0.02, green: 0.25, blue: 0.40).opacity(0.72))
                    .frame(width: width, height: height)
                    .shadow(color: glowColor.opacity(0.28), radius: 30, x: 0, y: 20)

                MineralShape()
                    .fill(
                        RadialGradient(
                            colors: alertActive
                                ? [
                                    Color.white.opacity(0.54),
                                    Color.white.opacity(0.08),
                                    coreColor.opacity(0.44),
                                    aquaColor.opacity(0.54),
                                    deepColor.opacity(0.82),
                                    Color(red: 0.12, green: 0.02, blue: 0.20).opacity(0.92)
                                ]
                                : [
                                    Color.white.opacity(0.54),
                                    Color.white.opacity(0.08),
                                    aquaColor.opacity(0.42 + aquaStrength * 0.16),
                                    coreColor.opacity(0.78),
                                    coreColor.opacity(0.86),
                                    deepColor.opacity(0.76),
                                    violetColor.opacity(0.10 + violetStrength * 0.16),
                                    deepColor.opacity(0.90)
                                ],
                            center: .init(x: 0.48 + tiltX * 0.18, y: 0.18 + tiltY * 0.10),
                            startRadius: 2,
                            endRadius: width * 0.72
                        )
                    )
                    .frame(width: width, height: height)
                    .overlay(
                        MineralShape()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.24), aquaColor.opacity(0.08), deepColor.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    )
                    .overlay(
                        MineralShape()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1.4)
                    )
                    .shadow(color: glowColor.opacity(alertActive ? 0.42 : 0.28), radius: (alertActive ? 30 : 26) + shimmer * 12, x: tiltX * 8, y: tiltY * 8)
                    .rotationEffect(rotation)

                GemShape()
                    .fill(
                        RadialGradient(
                            colors: alertActive
                                ? [
                                    coreColor.opacity(0.94),
                                    aquaColor.opacity(0.70),
                                    deepColor.opacity(0.58),
                                    violetColor.opacity(0.34)
                                ]
                                : [
                                    coreColor.opacity(0.82),
                                    aquaColor.opacity(0.30 + aquaStrength * 0.16),
                                    deepColor.opacity(0.52),
                                    violetColor.opacity(0.05 + violetStrength * 0.10)
                                ],
                            center: .init(x: 0.50 + tiltX * 0.16, y: 0.40 + tiltY * 0.12),
                            startRadius: 0,
                            endRadius: width * 0.46
                        )
                    )
                    .frame(width: width * 0.58, height: height * 0.58)
                    .opacity(alertActive ? 0.92 : 0.68 + shimmer * 0.10)
                    .rotationEffect(rotation)
                    .offset(x: lightX * 0.30, y: lightY * 0.40)
                    .blendMode(.screen)

                Circle()
                    .fill(Color.white.opacity(0.86))
                    .frame(width: width * 0.20, height: width * 0.20)
                    .blur(radius: 8)
                    .blendMode(.screen)
                    .offset(x: -width * 0.22 + lightX, y: -height * 0.31 + lightY)

                Circle()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: width * 0.18, height: width * 0.18)
                    .blur(radius: 13)
                    .blendMode(.screen)
                    .offset(x: width * 0.27 - lightX * 0.70, y: -height * 0.30 + lightY * 0.70)

                Circle()
                    .fill(limeColor.opacity(alertActive ? 0 : 0.08 + emeraldStrength * 0.42))
                    .frame(width: width * 0.34, height: width * 0.34)
                    .blur(radius: 16)
                    .blendMode(.screen)
                    .offset(x: -width * 0.10 + lightX * 0.86, y: -height * 0.01 + lightY * 0.70)

                Circle()
                    .fill(violetColor.opacity(alertActive ? 0.64 : 0.06 + violetStrength * 0.40))
                    .frame(width: width * 0.30, height: width * 0.30)
                    .blur(radius: 13)
                    .blendMode(.screen)
                    .offset(x: width * 0.10 - lightX * 0.82, y: height * 0.08 - lightY * 0.62)

                Circle()
                    .fill(aquaColor.opacity(alertActive ? 0.34 : 0.08 + aquaStrength * 0.42))
                    .frame(width: width * 0.28, height: width * 0.28)
                    .blur(radius: 12)
                    .blendMode(.screen)
                    .offset(x: width * 0.04 + lightX * 0.58, y: -height * 0.02 + lightY * 0.82)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct MineralShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.31, y: h * 0.05))
        path.addCurve(
            to: CGPoint(x: w * 0.70, y: h * 0.07),
            control1: CGPoint(x: w * 0.42, y: h * 0.01),
            control2: CGPoint(x: w * 0.60, y: h * 0.04)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.32),
            control1: CGPoint(x: w * 0.84, y: h * 0.10),
            control2: CGPoint(x: w * 0.93, y: h * 0.20)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.91, y: h * 0.70),
            control1: CGPoint(x: w * 0.98, y: h * 0.45),
            control2: CGPoint(x: w * 0.96, y: h * 0.60)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.64, y: h * 0.94),
            control1: CGPoint(x: w * 0.86, y: h * 0.84),
            control2: CGPoint(x: w * 0.76, y: h * 0.92)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.29, y: h * 0.91),
            control1: CGPoint(x: w * 0.52, y: h * 0.99),
            control2: CGPoint(x: w * 0.39, y: h * 0.95)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.07, y: h * 0.67),
            control1: CGPoint(x: w * 0.17, y: h * 0.88),
            control2: CGPoint(x: w * 0.09, y: h * 0.78)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.09, y: h * 0.31),
            control1: CGPoint(x: w * 0.03, y: h * 0.55),
            control2: CGPoint(x: w * 0.04, y: h * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.31, y: h * 0.05),
            control1: CGPoint(x: w * 0.13, y: h * 0.17),
            control2: CGPoint(x: w * 0.21, y: h * 0.08)
        )
        path.closeSubpath()
        return path
    }
}

private struct GemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.50, y: 0))
        path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.09))
        path.addLine(to: CGPoint(x: w * 1.00, y: h * 0.42))
        path.addLine(to: CGPoint(x: w * 0.87, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 1.00))
        path.addLine(to: CGPoint(x: w * 0.13, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.00, y: h * 0.42))
        path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.09))
        path.closeSubpath()
        return path
    }
}

private struct GemFacetShape: Shape {
    enum Kind {
        case primary
        case secondary
        case tertiary
    }

    let kind: Kind

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        switch kind {
        case .primary:
            path.move(to: CGPoint(x: w * 0.22, y: h * 0.12))
            path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.26))
            path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.12))
            path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.48))
            path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.52))
            path.closeSubpath()
        case .secondary:
            path.move(to: CGPoint(x: w * 0.24, y: h * 0.56))
            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.38))
            path.addLine(to: CGPoint(x: w * 0.77, y: h * 0.58))
            path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.92))
            path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.88))
            path.closeSubpath()
        case .tertiary:
            path.move(to: CGPoint(x: w * 0.12, y: h * 0.25))
            path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.32))
            path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.68))
            path.addLine(to: CGPoint(x: w * 0.08, y: h * 0.50))
            path.closeSubpath()
        }

        return path
    }
}

private struct HeartButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(configuration.isPressed ? 0.95 : 0.78),
                                accent.opacity(configuration.isPressed ? 0.55 : 0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: accent.opacity(configuration.isPressed ? 0.32 : 0.18), radius: 14, x: 0, y: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
    Swift.min(Swift.max(value, minValue), maxValue)
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
