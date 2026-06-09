//
//  ContentView.swift
//  Arturiablue
//
//  Created by 原田摩利奈 on 2026/06/09.
//

import SwiftUI
import Combine
import HealthKit
import CoreMotion

@MainActor
final class HeartRateViewModel: ObservableObject {
    @Published var currentHeartRate: Double?
    @Published var latestSampleDate: Date?
    @Published var authorizationStatus: String = "未確認"
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = "HealthKit は利用できません"
            return
        }

        guard let heartRateType else {
            authorizationStatus = "心拍データ型が取得できません"
            return
        }

        isLoading = true
        errorMessage = nil

        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.authorizationStatus = "許可エラー"
                    self.errorMessage = error.localizedDescription
                    return
                }

                self.authorizationStatus = success ? "許可済み" : "未許可"
                if success {
                    self.fetchLatestHeartRate()
                }
            }
        }
    }

    func fetchLatestHeartRate() {
        guard let heartRateType else {
            errorMessage = "心拍データ型が取得できません"
            return
        }

        isLoading = true
        errorMessage = nil

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    self.currentHeartRate = nil
                    self.latestSampleDate = nil
                    self.errorMessage = "心拍データがまだありません"
                    return
                }

                self.currentHeartRate = sample.quantity.doubleValue(
                    for: HKUnit.count().unitDivided(by: HKUnit.minute())
                )
                self.latestSampleDate = sample.endDate
            }
        }

        healthStore.execute(query)
    }

    func formattedHeartRate() -> String {
        guard let currentHeartRate else { return "--" }
        return String(format: "%.0f", currentHeartRate)
    }
}

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

        motionManager.accelerometerUpdateInterval = 1.0 / 30.0
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
                x: self.smoothedAcceleration.x * 0.72 + rawX * 0.28,
                y: self.smoothedAcceleration.y * 0.72 + rawY * 0.28,
                z: self.smoothedAcceleration.z * 0.72 + rawZ * 0.28
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
    @StateObject private var viewModel = HeartRateViewModel()
    @StateObject private var motionViewModel = MotionViewModel()
    @State private var isHighHeartRateTestActive = false
    @State private var highHeartRateTestTask: Task<Void, Never>?
    @State private var fallbackTiltX: Double = 0
    @State private var fallbackTiltY: Double = 0
    @State private var sensitivity: Double = 1.05
    @State private var heartRateThreshold: Double = 100.0

    private var isHighHeartRatePresent: Bool {
        isHighHeartRateTestActive || (viewModel.currentHeartRate ?? 0) >= heartRateThreshold
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
        isHighHeartRatePresent ? Color(red: 1.0, green: 0.51, blue: 0.88) : Color(hue: clamp(0.45 + tiltX * 0.10 - tiltY * 0.04, 0.36, 0.56), saturation: 0.94, brightness: clamp(0.78 + shimmer * 0.18, 0.78, 1.0))
    }

    private var gemDeepColor: Color {
        isHighHeartRatePresent ? Color(red: 0.49, green: 0.17, blue: 0.94) : Color(hue: clamp(0.57 + tiltX * 0.06 + tiltY * 0.04, 0.50, 0.66), saturation: 0.88, brightness: clamp(0.55 + tiltY * 0.10 + shimmer * 0.05, 0.44, 0.78))
    }

    private var gemVioletColor: Color {
        isHighHeartRatePresent ? Color(red: 1.0, green: 0.47, blue: 0.87) : Color(hue: clamp(0.72 + tiltX * 0.08 - tiltY * 0.04, 0.64, 0.80), saturation: 0.90, brightness: clamp(0.78 + shimmer * 0.16, 0.76, 0.98))
    }

    private var gemLimeColor: Color {
        isHighHeartRatePresent ? Color(red: 1.0, green: 0.76, blue: 0.98) : Color(hue: clamp(0.37 - tiltY * 0.08 + tiltX * 0.03, 0.30, 0.44), saturation: 0.84, brightness: clamp(0.80 + shimmer * 0.20, 0.80, 1.0))
    }

    private var gemAquaColor: Color {
        isHighHeartRatePresent ? Color(red: 1.0, green: 0.62, blue: 0.95) : Color(hue: clamp(0.51 + tiltX * 0.09 - tiltY * 0.03, 0.44, 0.60), saturation: 0.94, brightness: clamp(0.84 + shimmer * 0.16, 0.84, 1.0))
    }

    private var hueText: String {
        isHighHeartRatePresent ? "#ff82f0" : "#63dde0"
    }

    private var motionBadgeText: String {
        if isHighHeartRatePresent {
            return "heart alert"
        }

        return motionViewModel.isLive ? "motion ready" : "motion standby"
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 14) {
                    topBar
                    alertStrip
                    gemStage
                        .frame(maxWidth: .infinity)
                    dashboardPanel
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            motionViewModel.start()
            if viewModel.isHealthDataAvailable {
                viewModel.requestAuthorization()
            }
        }
        .onDisappear {
            motionViewModel.stop()
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ESEKAI MONOGATARI")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color(red: 0.62, green: 0.74, blue: 0.88))

                Text("幻の青を、角度で見つける")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Circle()
                    .fill(isHighHeartRatePresent ? Color(red: 1.0, green: 0.55, blue: 0.55) : Color(red: 0.44, green: 0.92, blue: 0.78))
                    .frame(width: 8, height: 8)
                    .shadow(color: .white.opacity(0.22), radius: 8)

                Text(motionBadgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.black.opacity(0.34), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var alertStrip: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("HEART TEST")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color(red: 0.72, green: 0.64, blue: 0.83))
                Text("心拍が高い時のボタン")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                triggerHighHeartRateTest()
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(.white.opacity(isHighHeartRateTestActive ? 0.95 : 0.88))
                        .frame(width: 14, height: 14)
                        .shadow(color: Color(red: 1.0, green: 0.44, blue: 0.82).opacity(isHighHeartRateTestActive ? 0.90 : 0), radius: 12)

                    Text("押して赤紫に光らせる")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.18).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .foregroundStyle(.white)
            .frame(maxWidth: 194)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.04, blue: 0.20).opacity(0.82),
                            Color(red: 0.10, green: 0.04, blue: 0.16).opacity(0.72)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color(red: 0.78, green: 0.20, blue: 0.88).opacity(0.28), lineWidth: 1)
                )
        )
    }

    private func triggerHighHeartRateTest() {
        highHeartRateTestTask?.cancel()
        isHighHeartRateTestActive = true

        highHeartRateTestTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            isHighHeartRateTestActive = false
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
        .frame(height: 394)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if motionViewModel.isLive {
                        return
                    }
                    fallbackTiltX = clamp(value.translation.width / 160.0, -1, 1)
                    fallbackTiltY = clamp(value.translation.height / 160.0, -1, 1)
                }
        )
    }

    private var dashboardPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            metersGrid
            controlsPanel
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var metersGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                meterTile(label: "tilt x", value: String(format: "%.2f", tiltX), subtitle: "left / right")
                meterTile(label: "tilt y", value: String(format: "%.2f", tiltY), subtitle: "up / down")
                meterTile(label: "heart", value: viewModel.currentHeartRate == nil ? "--" : viewModel.formattedHeartRate(), subtitle: "threshold \(Int(heartRateThreshold)) bpm")
            }

            GridRow {
                meterTile(label: "tone", value: hueText, subtitle: "current blue")
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
        }
    }

    private func meterTile(label: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1))
        )
    }

    private var controlsPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    motionViewModel.start()
                } label: {
                    Label(motionViewModel.isLive ? "センサーを再接続" : "センサーを有効にする", systemImage: "circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HeartButtonStyle(accent: .blue))

                Button {
                    fallbackTiltX = 0
                    fallbackTiltY = 0
                } label: {
                    Label("中央に戻す", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HeartButtonStyle(accent: .cyan))
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.fetchLatestHeartRate()
                } label: {
                    Label("更新", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HeartButtonStyle(accent: .blue))

                Button {
                    viewModel.requestAuthorization()
                } label: {
                    Label("許可", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HeartButtonStyle(accent: .pink))
            }

            VStack(spacing: 10) {
                VStack(spacing: 8) {
                    sliderRow(title: "threshold", value: "\(Int(heartRateThreshold)) bpm")
                        Slider(value: $heartRateThreshold, in: 60...180, step: 1)
                            .tint(.pink)
                    sliderRow(title: "sensitivity", value: "\(Int(sensitivity * 100))%")
                    Slider(value: $sensitivity, in: 0.25...1.35, step: 0.01)
                        .tint(.cyan)
                }

            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1))
            )
        }
    }

    private func sliderRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isLoading ? Color.yellow : Color.green)
                    .frame(width: 10, height: 10)

                Text(viewModel.isLoading ? "読み込み中" : viewModel.authorizationStatus)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("端末を少し傾けると、石の青さが変わります。")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(
                isHighHeartRatePresent
                ? "heart rate high"
                : motionViewModel.isLive
                ? "sensor live"
                : "drag to preview"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.06, blue: 0.10)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.12, blue: 0.18).opacity(0.86),
                    Color(red: 0.02, green: 0.04, blue: 0.09),
                    Color.black.opacity(0.88)
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
                center: .init(x: 0.50, y: 0.34),
                startRadius: 0,
                endRadius: 360
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

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.82, 322)
            let height = width * 1.06
            let rotation = Angle(degrees: tiltX * 7)
            let blobCorner = width * 0.30
            let lightX = tiltX * width * 0.16
            let lightY = tiltY * height * 0.13

            ZStack {
                Ellipse()
                    .fill(glowColor.opacity(alertActive ? 0.34 : 0.20))
                    .frame(width: width * 1.10, height: height * 0.32)
                    .blur(radius: 26)
                    .offset(y: height * 0.39)

                RoundedRectangle(cornerRadius: blobCorner, style: .continuous)
                    .fill(Color(red: 0.03, green: 0.08, blue: 0.16).opacity(0.62))
                    .frame(width: width, height: height)
                    .shadow(color: Color.black.opacity(0.62), radius: 28, x: 0, y: 28)

                RoundedRectangle(cornerRadius: blobCorner, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.56),
                                Color.white.opacity(0.10),
                                coreColor.opacity(0.40),
                                deepColor.opacity(0.78),
                                Color(red: 0.01, green: 0.03, blue: 0.09).opacity(0.96)
                            ],
                            center: .init(x: 0.48 + tiltX * 0.18, y: 0.18 + tiltY * 0.10),
                            startRadius: 2,
                            endRadius: width * 0.72
                        )
                    )
                    .frame(width: width, height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: blobCorner, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.20),
                                        Color.white.opacity(0.04),
                                        Color.clear,
                                        Color.black.opacity(0.26)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: blobCorner, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1.4)
                    )
                    .shadow(color: glowColor.opacity(alertActive ? 0.42 : 0.28), radius: (alertActive ? 30 : 26) + shimmer * 12, x: tiltX * 8, y: tiltY * 8)
                    .rotationEffect(rotation)

                GemShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                limeColor.opacity(0.92),
                                aquaColor.opacity(0.88),
                                coreColor.opacity(0.82),
                                deepColor.opacity(0.62),
                                violetColor.opacity(0.40)
                            ],
                            center: .init(x: 0.50 + tiltX * 0.18, y: 0.40 + tiltY * 0.14),
                            startRadius: 0,
                            endRadius: width * 0.44
                        )
                    )
                    .frame(width: width * 0.58, height: height * 0.58)
                    .blur(radius: 0.4)
                    .opacity(0.78 + shimmer * 0.22)
                    .rotationEffect(rotation)
                    .offset(x: lightX * 0.36, y: lightY * 0.48)
                    .blendMode(.screen)

                GemFacetShape(kind: .primary)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                aquaColor.opacity(0.46),
                                deepColor.opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: width * 0.64, height: height * 0.64)
                    .rotationEffect(rotation)
                    .offset(x: lightX * 0.52, y: lightY * 0.56)
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
                    .offset(x: width * 0.27 - lightX * 0.7, y: -height * 0.30 + lightY * 0.7)

                Circle()
                    .fill(limeColor.opacity(0.50))
                    .frame(width: width * 0.28, height: width * 0.28)
                    .blur(radius: 12)
                    .blendMode(.screen)
                    .offset(x: -width * 0.18 + lightX * 0.70, y: -height * 0.02 + lightY * 0.64)

                Circle()
                    .fill(violetColor.opacity(alertActive ? 0.64 : 0.42))
                    .frame(width: width * 0.24, height: width * 0.24)
                    .blur(radius: 8)
                    .blendMode(.screen)
                    .offset(x: width * 0.22 - lightX * 0.62, y: height * 0.10 - lightY * 0.58)

                Circle()
                    .fill(aquaColor.opacity(0.48))
                    .frame(width: width * 0.14, height: width * 0.14)
                    .blur(radius: 5)
                    .blendMode(.screen)
                    .offset(x: width * 0.11 + lightX * 0.52, y: -height * 0.05 + lightY * 0.52)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
