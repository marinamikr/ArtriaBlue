//
//  ContentView.swift
//  Arturiablue
//
//  Created by 原田摩利奈 on 2026/06/09.
//

import SwiftUI
import Combine
import CoreMotion
import SceneKit
import UIKit

// MARK: - Motion

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

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var motionViewModel = MotionViewModel()

    @State private var fallbackTiltX: Double = 0
    @State private var fallbackTiltY: Double = 0
    @State private var sensitivity: Double = 1.05
    @State private var isEyePulseActive = false
    @State private var swipeRotationX: Double = -0.95
    @State private var swipeRotationY: Double = 0.0
    @State private var swipeAnchorRotationX: Double?
    @State private var swipeAnchorRotationY: Double?
    @State private var zoomScale: Double = 1.0
    @State private var zoomAnchorScale: Double?
    @State private var gemIsFloating = false
    @State private var characterIsFloating = false

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

    var body: some View {
        ZStack {
            AppBackground()

            PippoEyeScene(
                tiltX: tiltX,
                tiltY: tiltY,
                shimmer: shimmer,
                alertActive: isEyePulseActive,
                rotationX: swipeRotationX,
                rotationY: swipeRotationY,
                zoomScale: zoomScale
            )
            .frame(height: 520)
            .padding(.horizontal, 16)
            .offset(y: characterIsFloating ? 68 : 78)
            .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: characterIsFloating)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        if swipeAnchorRotationX == nil {
                            swipeAnchorRotationX = swipeRotationX
                            swipeAnchorRotationY = swipeRotationY
                        }

                        let anchorX = swipeAnchorRotationX ?? swipeRotationX
                        let anchorY = swipeAnchorRotationY ?? swipeRotationY

                        swipeRotationX = clamp(anchorX + value.translation.height / 220.0, -1.75, 1.25)
                        swipeRotationY = anchorY + value.translation.width / 200.0
                    }
                    .onEnded { _ in
                        swipeAnchorRotationX = nil
                        swipeAnchorRotationY = nil
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        if zoomAnchorScale == nil {
                            zoomAnchorScale = zoomScale
                        }

                        let anchor = zoomAnchorScale ?? zoomScale
                        zoomScale = clamp(anchor * value, 0.78, 2.25)
                    }
                    .onEnded { _ in
                        zoomAnchorScale = nil
                    }
            )

            ArturiaBlueGemView(
                tiltX: tiltX,
                tiltY: tiltY,
                shimmer: shimmer,
                alertActive: isEyePulseActive
            )
            .frame(width: 180, height: 204)
            .offset(y: gemIsFloating ? -195 : -175)
            .compositingGroup()
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: gemIsFloating)

            topBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.horizontal, 18)
                .padding(.top, 18)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.45)) {
                isEyePulseActive.toggle()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            motionViewModel.start()
            isEyePulseActive = false
            gemIsFloating = true
            characterIsFloating = true
        }
        .onDisappear {
            motionViewModel.stop()
            gemIsFloating = false
            characterIsFloating = false
        }
    }

    private var topBar: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Pippo")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(Color(red: 0.30, green: 0.42, blue: 0.56))

            Text("Arturia")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.18))
        }
    }
}

// MARK: - Background

private struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.99, blue: 1.0)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.99, blue: 1.0).opacity(1.0),
                    Color(red: 0.92, green: 0.97, blue: 1.0).opacity(0.92),
                    Color(red: 0.88, green: 0.94, blue: 0.99).opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.40, green: 0.78, blue: 1.0).opacity(0.12),
                    Color.clear
                ],
                center: .init(x: 0.50, y: 0.42),
                startRadius: 0,
                endRadius: 440
            )
            .ignoresSafeArea()

            GridPattern()
                .stroke(Color(red: 0.62, green: 0.74, blue: 0.86).opacity(0.12), lineWidth: 0.7)
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

// MARK: - Arturia Blue Gem

private struct ArturiaBlueGemView: View {
    let tiltX: Double
    let tiltY: Double
    let shimmer: Double
    let alertActive: Bool

    private var coreColor: Color {
        alertActive
            ? Color(red: 1.0, green: 0.51, blue: 0.88)
            : Color(
                red: clamp(0.22 - tiltX * 0.10 + tiltY * 0.04, 0.12, 0.34),
                green: clamp(0.58 + tiltX * 0.24 - tiltY * 0.08, 0.38, 0.84),
                blue: clamp(0.96 - tiltX * 0.06 + tiltY * 0.03, 0.88, 1.0)
            )
    }

    private var deepColor: Color {
        alertActive
            ? Color(red: 0.49, green: 0.17, blue: 0.94)
            : Color(
                red: clamp(0.08 - tiltX * 0.04, 0.04, 0.20),
                green: clamp(0.34 + tiltX * 0.17 - tiltY * 0.08, 0.20, 0.56),
                blue: clamp(0.72 + tiltY * 0.08, 0.62, 0.86)
            )
    }

    private var violetColor: Color {
        alertActive
            ? Color(red: 1.0, green: 0.47, blue: 0.87)
            : Color(
                red: clamp(0.36 - tiltX * 0.16, 0.20, 0.58),
                green: clamp(0.34 + tiltX * 0.08, 0.24, 0.46),
                blue: clamp(0.88 + shimmer * 0.05, 0.82, 0.96)
            )
    }

    private var limeColor: Color {
        alertActive
            ? Color(red: 1.0, green: 0.76, blue: 0.98)
            : Color(
                red: clamp(0.13 - tiltX * 0.04, 0.08, 0.20),
                green: clamp(0.88 + tiltX * 0.09, 0.80, 0.98),
                blue: clamp(0.76 - tiltX * 0.08, 0.66, 0.84)
            )
    }

    private var aquaColor: Color {
        alertActive
            ? Color(red: 1.0, green: 0.62, blue: 0.95)
            : Color(
                red: clamp(0.18 + tiltY * 0.04, 0.12, 0.24),
                green: clamp(0.82 - tiltY * 0.10, 0.70, 0.94),
                blue: clamp(0.98 + shimmer * 0.02, 0.94, 1.0)
            )
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

    private var glowColor: Color {
        alertActive ? Color(red: 1.0, green: 0.35, blue: 0.78) : Color(red: 0.37, green: 0.86, blue: 0.96)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.92, proxy.size.height * 0.86)
            let height = width * 1.08
            let rotation = Angle(degrees: tiltX * 7)
            let lightX = tiltX * width * 0.16
            let lightY = tiltY * height * 0.13

            ZStack {
                Ellipse()
                    .fill(glowColor.opacity(alertActive ? 0.10 : 0.06))
                    .frame(width: width * 0.90, height: height * 0.20)
                    .blur(radius: 18)
                    .offset(y: height * 0.38)

                ArturiaMineralShape()
                    .fill(alertActive ? Color(red: 0.22, green: 0.05, blue: 0.28).opacity(0.66) : Color(red: 0.02, green: 0.25, blue: 0.40).opacity(0.72))
                    .frame(width: width, height: height)
                    .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 14)

                ArturiaMineralShape()
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
                        ArturiaMineralShape()
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
                        ArturiaMineralShape()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1.4)
                    )
                    .shadow(color: glowColor.opacity(alertActive ? 0.16 : 0.08), radius: (alertActive ? 18 : 14) + shimmer * 5, x: tiltX * 4, y: tiltY * 4)
                    .rotationEffect(rotation)

                ArturiaGemShape()
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

private struct ArturiaMineralShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.31, y: h * 0.05))
        path.addCurve(to: CGPoint(x: w * 0.70, y: h * 0.07), control1: CGPoint(x: w * 0.42, y: h * 0.01), control2: CGPoint(x: w * 0.60, y: h * 0.04))
        path.addCurve(to: CGPoint(x: w * 0.94, y: h * 0.32), control1: CGPoint(x: w * 0.84, y: h * 0.10), control2: CGPoint(x: w * 0.93, y: h * 0.20))
        path.addCurve(to: CGPoint(x: w * 0.91, y: h * 0.70), control1: CGPoint(x: w * 0.98, y: h * 0.45), control2: CGPoint(x: w * 0.96, y: h * 0.60))
        path.addCurve(to: CGPoint(x: w * 0.64, y: h * 0.94), control1: CGPoint(x: w * 0.86, y: h * 0.84), control2: CGPoint(x: w * 0.76, y: h * 0.92))
        path.addCurve(to: CGPoint(x: w * 0.29, y: h * 0.91), control1: CGPoint(x: w * 0.52, y: h * 0.99), control2: CGPoint(x: w * 0.39, y: h * 0.95))
        path.addCurve(to: CGPoint(x: w * 0.07, y: h * 0.67), control1: CGPoint(x: w * 0.17, y: h * 0.88), control2: CGPoint(x: w * 0.09, y: h * 0.78))
        path.addCurve(to: CGPoint(x: w * 0.09, y: h * 0.31), control1: CGPoint(x: w * 0.03, y: h * 0.55), control2: CGPoint(x: w * 0.04, y: h * 0.42))
        path.addCurve(to: CGPoint(x: w * 0.31, y: h * 0.05), control1: CGPoint(x: w * 0.13, y: h * 0.17), control2: CGPoint(x: w * 0.21, y: h * 0.08))
        path.closeSubpath()
        return path
    }
}

private struct ArturiaGemShape: Shape {
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

// MARK: - SceneKit View

private struct PippoEyeScene: UIViewRepresentable {
    let tiltX: Double
    let tiltY: Double
    let shimmer: Double
    let alertActive: Bool
    let rotationX: Double
    let rotationY: Double
    let zoomScale: Double

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false

        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.isPlaying = true

        view.scene = context.coordinator.prepareScene()
        view.pointOfView = context.coordinator.cameraNode

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.update(
            tiltX: tiltX,
            tiltY: tiltY,
            shimmer: shimmer,
            alertActive: alertActive,
            rotationX: rotationX,
            rotationY: rotationY,
            zoomScale: zoomScale
        )
    }

    final class Coordinator {
        let scene = SCNScene()
        let cameraNode = SCNNode()

        private let contentRootNode = SCNNode()
        private let ambientLightNode = SCNNode()
        private let keyLightNode = SCNNode()
        private let fillLightNode = SCNNode()

        private var eyeMaterials: [(material: SCNMaterial, side: String)] = []
        private struct EyeGem {
            let rootNode: SCNNode
            let coreMaterial: SCNMaterial
            let glowMaterial: SCNMaterial
        }
        private var eyeGems: [String: EyeGem] = [:]
        private var didPrepare = false

        func prepareScene() -> SCNScene {
            guard !didPrepare else { return scene }
            didPrepare = true

            loadModel()
            configureCamera()
            configureLights()

            update(
                tiltX: 0,
                tiltY: 0,
                shimmer: 0.25,
                alertActive: false,
                rotationX: -0.95,
                rotationY: 0.0,
                zoomScale: 1.0
            )


            return scene
        }

        func update(tiltX: Double, tiltY: Double, shimmer: Double, alertActive: Bool, rotationX: Double, rotationY: Double, zoomScale: Double) {
            if !didPrepare {
                _ = prepareScene()
            }

            let swipePitch = clamp(rotationX, -1.75, 1.25)
            let swipeYaw = rotationY

            contentRootNode.eulerAngles = SCNVector3(
                Float(swipePitch),
                Float(swipeYaw),
                0
            )

            contentRootNode.position = SCNVector3(0, 0, 0)

            cameraNode.position = SCNVector3(0, 0, Float(8.5 / clamp(zoomScale, 0.78, 2.25)))

            updateEyeMaterials(alertActive: alertActive, shimmer: shimmer)

            ambientLightNode.light?.intensity = 900
            keyLightNode.light?.intensity = 260
            fillLightNode.light?.intensity = 190
        }

        private func loadModel() {
            let modelURL = Bundle.main.url(forResource: "pippo_eye_custom", withExtension: "usdz")
                ?? Bundle.main.url(forResource: "pippo_eye_custom", withExtension: "glb")

            guard let url = modelURL else {
                print("❌ モデルファイルが見つかりません。fallback を表示します。")
                scene.rootNode.addChildNode(makeFallbackNode())
                return
            }

            do {
                let importedScene = try SCNScene(url: url, options: nil)
                addImportedNodes(from: importedScene)
                fitContentRoot()
                applyMatteMaterials()

                collectEyeMaterials()
            } catch {
                print("❌ モデル読み込み失敗:", error)
                scene.rootNode.addChildNode(makeFallbackNode())
            }
        }

        private func addImportedNodes(from importedScene: SCNScene) {
            for node in importedScene.rootNode.childNodes {
                if node.camera == nil && node.light == nil {
                    contentRootNode.addChildNode(node)
                } else {
                    scene.rootNode.addChildNode(node)
                }
            }

            scene.rootNode.addChildNode(contentRootNode)
        }

        // MARK: - Fit

        private func fitContentRoot() {
            let bounds = contentRootNode.boundingBox
            let minBounds = bounds.min
            let maxBounds = bounds.max

            guard minBounds.x.isFinite, minBounds.y.isFinite, minBounds.z.isFinite,
                  maxBounds.x.isFinite, maxBounds.y.isFinite, maxBounds.z.isFinite else {
                contentRootNode.scale = SCNVector3(1, 1, 1)
                return
            }

            let size = SCNVector3(
                maxBounds.x - minBounds.x,
                maxBounds.y - minBounds.y,
                maxBounds.z - minBounds.z
            )

            let maxDimension = max(size.x, max(size.y, size.z))

            guard maxDimension > 0 else {
                contentRootNode.scale = SCNVector3(1, 1, 1)
                return
            }

            let scale = Float(4.4 / maxDimension)

            contentRootNode.scale = SCNVector3(scale, scale, scale)
            contentRootNode.position = SCNVector3(
                -((minBounds.x + maxBounds.x) * 0.5) * scale,
                -((minBounds.y + maxBounds.y) * 0.5) * scale,
                -((minBounds.z + maxBounds.z) * 0.5) * scale
            )

            print("✅ model fitted")
            print("scale:", scale)
            print("bounds min:", minBounds)
            print("bounds max:", maxBounds)
        }

        // MARK: - Eye Materials

        private func collectEyeMaterials() {
            eyeMaterials.removeAll()
            eyeGems.removeAll()

            contentRootNode.enumerateChildNodes { node, _ in
                let normalizedName = node.name?.lowercased() ?? ""

                if normalizedName.contains("eye_l") {
                    collectEyeMaterials(in: node, eyeSide: "eye_L", eyeRootNode: node)
                } else if normalizedName.contains("eye_r") {
                    collectEyeMaterials(in: node, eyeSide: "eye_R", eyeRootNode: node)
                }
            }

            if eyeMaterials.isEmpty {
                print("⚠️ Eye_L / Eye_R が見つかりませんでした")
                print("Blender側のオブジェクト名が Eye_L / Eye_R になっているか確認してください")
            }
        }

        private func collectEyeMaterials(in node: SCNNode, eyeSide: String, eyeRootNode: SCNNode) {
            if let geometry = node.geometry {
                let material = geometry.firstMaterial ?? SCNMaterial()
                material.isDoubleSided = true
                material.lightingModel = .lambert
                material.roughness.contents = 1.0
                material.metalness.contents = 0.0
                material.specular.contents = UIColor.black
                material.transparency = 1.0

                geometry.firstMaterial = material
                eyeMaterials.append((material: material, side: eyeSide))

                print("✅ eye material found:", eyeSide, "->", node.name ?? "no name")
            }

            for child in node.childNodes {
                collectEyeMaterials(in: child, eyeSide: eyeSide, eyeRootNode: eyeRootNode)
            }
        }

        private func updateEyeMaterials(alertActive: Bool, shimmer: Double) {
            guard !eyeMaterials.isEmpty else { return }

            for (material, _) in eyeMaterials {
                material.diffuse.contents = alertActive
                    ? UIColor(red: 1.0, green: 0.96, blue: 0.96, alpha: 1.0)
                    : UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1.0)
                material.emission.contents = UIColor.black
                material.specular.contents = UIColor.black
                material.roughness.contents = 1.0
                material.metalness.contents = 0.0
                material.transparency = 1.0
            }
        }

        private func applyMatteMaterials() {
            contentRootNode.enumerateChildNodes { node, _ in
                guard let geometry = node.geometry else { return }

                for material in geometry.materials {
                    material.lightingModel = .lambert
                    material.diffuse.contents = material.diffuse.contents ?? UIColor.white
                    material.specular.contents = UIColor.black
                    material.roughness.contents = 1.0
                    material.metalness.contents = 0.0
                    material.reflective.contents = UIColor.black
                    material.emission.contents = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
                }
            }
        }

        private func attachEyeGem(to eyeRootNode: SCNNode, side: String) {
            guard eyeGems[side] == nil else { return }

            let gemRoot = SCNNode()
            gemRoot.position = SCNVector3(0, 0, 0.12)
            gemRoot.scale = SCNVector3(1, 1, 1)

            let glowGeometry = SCNSphere(radius: 0.12)
            glowGeometry.segmentCount = 24
            let glowMaterial = SCNMaterial()
            glowMaterial.lightingModel = .constant
            glowMaterial.diffuse.contents = UIColor(red: 0.28, green: 0.84, blue: 1.0, alpha: 0.18)
            glowMaterial.emission.contents = UIColor(red: 0.28, green: 0.84, blue: 1.0, alpha: 0.75)
            glowMaterial.transparency = 0.22
            glowMaterial.isDoubleSided = true
            glowGeometry.firstMaterial = glowMaterial

            let coreGeometry = SCNSphere(radius: 0.045)
            coreGeometry.segmentCount = 18
            let coreMaterial = SCNMaterial()
            coreMaterial.lightingModel = .constant
            coreMaterial.diffuse.contents = UIColor(red: 0.68, green: 0.96, blue: 1.0, alpha: 1.0)
            coreMaterial.emission.contents = UIColor(red: 0.40, green: 0.98, blue: 1.0, alpha: 1.0)
            coreMaterial.transparency = 1.0
            coreMaterial.isDoubleSided = true
            coreGeometry.firstMaterial = coreMaterial

            let glowNode = SCNNode(geometry: glowGeometry)
            let coreNode = SCNNode(geometry: coreGeometry)

            gemRoot.addChildNode(glowNode)
            gemRoot.addChildNode(coreNode)
            eyeRootNode.addChildNode(gemRoot)

            eyeGems[side] = EyeGem(rootNode: gemRoot, coreMaterial: coreMaterial, glowMaterial: glowMaterial)
        }

        private func updateEyeGems(alertActive: Bool, shimmer: Double) {
            for (_, gem) in eyeGems {
                let scale = Float(alertActive ? 1.28 : (1.0 + shimmer * 0.16))
                gem.rootNode.scale = SCNVector3(scale, scale, scale)

                if alertActive {
                    gem.coreMaterial.diffuse.contents = UIColor(red: 1.0, green: 0.30, blue: 0.22, alpha: 1.0)
                    gem.coreMaterial.emission.contents = UIColor(red: 1.0, green: 0.12, blue: 0.08, alpha: 1.0)
                    gem.glowMaterial.diffuse.contents = UIColor(red: 1.0, green: 0.22, blue: 0.16, alpha: 0.26)
                    gem.glowMaterial.emission.contents = UIColor(red: 1.0, green: 0.20, blue: 0.12, alpha: 0.96)
                    gem.glowMaterial.transparency = 0.28
                } else {
                    gem.coreMaterial.diffuse.contents = UIColor(red: 0.72, green: 0.98, blue: 1.0, alpha: 1.0)
                    gem.coreMaterial.emission.contents = UIColor(red: 0.28, green: 0.86, blue: 1.0, alpha: 1.0)
                    gem.glowMaterial.diffuse.contents = UIColor(red: 0.22, green: 0.70, blue: 1.0, alpha: 0.20)
                    gem.glowMaterial.emission.contents = UIColor(red: 0.30, green: 0.88, blue: 1.0, alpha: 0.78)
                    gem.glowMaterial.transparency = 0.22
                }
            }
        }

        // MARK: - Lights

        private func configureLights() {
            ambientLightNode.light = makeLight(
                type: .ambient,
                color: UIColor(red: 1.0, green: 1.0, blue: 0.96, alpha: 1.0),
                intensity: 900
            )

            keyLightNode.light = makeLight(
                type: .directional,
                color: UIColor(red: 1.0, green: 0.98, blue: 0.92, alpha: 1.0),
                intensity: 260
            )

            fillLightNode.light = makeLight(
                type: .omni,
                color: UIColor(red: 1.0, green: 1.0, blue: 0.98, alpha: 1.0),
                intensity: 190
            )

            keyLightNode.eulerAngles = SCNVector3(-0.78, 0.45, 0.0)
            fillLightNode.position = SCNVector3(0.0, 2.2, 6.5)

            scene.rootNode.addChildNode(ambientLightNode)
            scene.rootNode.addChildNode(keyLightNode)
            scene.rootNode.addChildNode(fillLightNode)
        }

        private func configureCamera() {
            let camera = SCNCamera()
            camera.fieldOfView = 55
            camera.zNear = 0.01
            camera.zFar = 100
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0, 8.5)
            cameraNode.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(cameraNode)
        }

        private func makeLight(type: SCNLight.LightType, color: UIColor, intensity: CGFloat) -> SCNLight {
            let light = SCNLight()
            light.type = type
            light.color = color
            light.intensity = intensity
            light.castsShadow = false
            return light
        }

        // MARK: - Fallback

        private func makeFallbackNode() -> SCNNode {
            let sphere = SCNSphere(radius: 1.2)
            sphere.segmentCount = 48

            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = UIColor(red: 0.08, green: 0.58, blue: 0.98, alpha: 1.0)
            material.emission.contents = UIColor(red: 0.18, green: 0.80, blue: 1.0, alpha: 1.0)
            material.roughness.contents = 0.22
            material.metalness.contents = 0

            sphere.firstMaterial = material

            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3Zero
            return node
        }
    }
}

// MARK: - Eye Texture

private func makeArturiaEyeTexture(
    tiltX: Double,
    tiltY: Double,
    shimmer: Double,
    alertActive: Bool,
    mirrored: Bool
) -> UIImage {
    let size = CGSize(width: 512, height: 512)
    let renderer = UIGraphicsImageRenderer(size: size)

    return renderer.image { context in
        let cg = context.cgContext
        let rect = CGRect(origin: .zero, size: size)

        let clampedTiltX = clamp(tiltX, -1, 1)
        let clampedTiltY = clamp(tiltY, -1, 1)
        let side: CGFloat = mirrored ? -1 : 1

        let baseCenter = CGPoint(
            x: size.width * 0.5 + CGFloat(clampedTiltX) * 28 * side,
            y: size.height * 0.46 + CGFloat(clampedTiltY) * 24
        )

        let highlightCenter = CGPoint(
            x: size.width * 0.36 - CGFloat(clampedTiltX) * 18 * side,
            y: size.height * 0.30 + CGFloat(clampedTiltY) * 10
        )

        let coreBlue = alertActive
            ? UIColor(red: 1.00, green: 0.24, blue: 0.18, alpha: 1.0)
            : UIColor(red: 0.18, green: 0.72, blue: 1.0, alpha: 1.0)

        let deepBlue = alertActive
            ? UIColor(red: 0.28, green: 0.03, blue: 0.04, alpha: 1.0)
            : UIColor(red: 0.02, green: 0.14, blue: 0.40, alpha: 1.0)

        let violet = alertActive
            ? UIColor(red: 1.00, green: 0.58, blue: 0.42, alpha: 1.0)
            : UIColor(red: 0.44, green: 0.42, blue: 1.0, alpha: 1.0)

        let aqua = alertActive
            ? UIColor(red: 1.00, green: 0.10, blue: 0.08, alpha: 1.0)
            : UIColor(red: 0.34, green: 0.90, blue: 1.0, alpha: 1.0)

        cg.setFillColor(UIColor(red: 0.01, green: 0.04, blue: 0.09, alpha: 1.0).cgColor)
        cg.fill(rect)

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let gradientColors = [
            UIColor.white.withAlphaComponent(alertActive ? 0.92 : 0.78).cgColor,
            aqua.withAlphaComponent(0.82).cgColor,
            coreBlue.withAlphaComponent(0.88).cgColor,
            deepBlue.cgColor
        ] as CFArray

        let gradientLocations: [CGFloat] = [0.0, 0.16, 0.52, 1.0]

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations) {
            cg.drawRadialGradient(
                gradient,
                startCenter: baseCenter,
                startRadius: 0,
                endCenter: baseCenter,
                endRadius: 262,
                options: [.drawsAfterEndLocation]
            )
        }

        let secondaryGradientColors = [
            violet.withAlphaComponent(0.55).cgColor,
            UIColor.clear.cgColor
        ] as CFArray

        if let secondaryGradient = CGGradient(colorsSpace: colorSpace, colors: secondaryGradientColors, locations: [0, 1]) {
            cg.drawRadialGradient(
                secondaryGradient,
                startCenter: highlightCenter,
                startRadius: 0,
                endCenter: highlightCenter,
                endRadius: 180,
                options: [.drawsAfterEndLocation]
            )
        }

        cg.setStrokeColor(UIColor.white.withAlphaComponent(alertActive ? 0.42 : 0.28).cgColor)
        cg.setLineWidth(8)
        cg.strokeEllipse(in: CGRect(x: 78, y: 78, width: 356, height: 356))

        cg.setStrokeColor(coreBlue.withAlphaComponent(alertActive ? 0.65 : 0.48).cgColor)
        cg.setLineWidth(5)
        cg.strokeEllipse(in: CGRect(x: 104, y: 104, width: 304, height: 304))

        cg.setStrokeColor(aqua.withAlphaComponent(0.22 + CGFloat(shimmer) * 0.16).cgColor)
        cg.setLineWidth(3)
        cg.strokeEllipse(in: CGRect(x: 140, y: 140, width: 232, height: 232))

        cg.setBlendMode(.screen)

        cg.setFillColor(UIColor.white.withAlphaComponent(alertActive ? 0.82 : 0.60).cgColor)
        cg.fillEllipse(in: CGRect(x: 160 + (mirrored ? -8 : 8), y: 128, width: 70, height: 70))

        cg.setFillColor(violet.withAlphaComponent(alertActive ? 0.58 : 0.34).cgColor)
        cg.fillEllipse(in: CGRect(x: 190, y: 170, width: 42, height: 42))

        cg.setFillColor(aqua.withAlphaComponent(alertActive ? 0.70 : 0.42).cgColor)
        cg.fillEllipse(in: CGRect(x: 222, y: 208, width: 92, height: 92))

        cg.setBlendMode(.normal)
    }
}

// MARK: - Utility

private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
    Swift.min(Swift.max(value, minValue), maxValue)
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
