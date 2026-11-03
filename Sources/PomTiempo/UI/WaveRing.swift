import AppKit
import QuartzCore
import SwiftUI

/// The dial's ring, drawn straight into Core Animation layers from the
/// screen's refresh (30 times a second while it moves) without going through
/// SwiftUI, so the flowing wave costs very little.
///
/// - The remaining time is a line whose radius ripples as a sine wave that
///   slides along it; the wave eases out toward both ends so the round caps
///   sit on the circle.
/// - The used-up part is a thin, quiet track.
/// - Starting and stopping eases the wave in and out; once it's flat and the
///   timer is stopped, drawing stops completely.
/// - Colour comes from a fixed conic gradient seen through the line, so a
///   multi-colour palette stays put while the wave moves through it. The
///   gradient's shadow is the glow.
struct WaveRing: NSViewRepresentable {
    var fractionLeft: (Date) -> Double
    var isRunning: Bool
    /// Two colours fade along the arc to full strength at its leading end;
    /// more than two span the whole circle.
    var colors: [Color]
    var glowColor: Color
    var trackColor: Color
    var lineWidth: CGFloat
    var waveHeight: CGFloat
    var waves: Double = 14
    /// Radians per second the wave slides along the line.
    var flowSpeed: Double = 2.4
    var settleTime: TimeInterval = 0.7

    func makeNSView(context: Context) -> RingView { RingView() }

    func updateNSView(_ view: RingView, context: Context) { view.update(self) }

    final class RingView: NSView {
        private let track = CAShapeLayer()
        private let glow = CALayer()            // its shadow is the halo
        private let clip = CALayer()            // cut to the line's shape
        private let gradient = CAGradientLayer()
        private let wave = CAShapeLayer()

        private var config: WaveRing?
        private var link: CADisplayLink?
        /// The last start or stop: when, and the wave height it eased from and to.
        private var change = (date: Date.distantPast, from: CGFloat(0), to: CGFloat(0))

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            let root = CALayer()
            layer = root
            root.addSublayer(track)
            root.addSublayer(glow)
            glow.addSublayer(clip)
            clip.addSublayer(gradient)
            clip.mask = wave
            gradient.type = .conic
            glow.shadowOffset = .zero
            glow.shadowRadius = 9
            glow.shadowOpacity = 0.9
            for shape in [wave, track] {
                shape.fillColor = nil
                shape.lineCap = .round
                shape.lineJoin = .round
            }
            wave.strokeColor = NSColor.white.cgColor
            track.lineWidth = 4
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for l in [track, glow, clip, wave] as [CALayer] { l.frame = bounds }
            // The gradient is mirrored (below), so place it by size and centre.
            gradient.bounds = CGRect(origin: .zero, size: bounds.size)
            gradient.position = CGPoint(x: bounds.midX, y: bounds.midY)
            // This layer's origin is at the bottom and a conic gradient turns
            // counterclockwise: point it at 12 o'clock and mirror it so it
            // runs clockwise, the same way as the line.
            gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)
            gradient.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
            CATransaction.commit()
            render(at: Date())
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { stopLink() } else { startLinkIfNeeded() }
        }

        func update(_ new: WaveRing) {
            let previous = config
            config = new
            let now = Date()
            if let previous, previous.isRunning != new.isRunning {
                change = (now, amplitude(at: now, running: previous.isRunning), new.isRunning ? new.waveHeight : 0)
            } else if previous == nil {
                change = (.distantPast, 0, new.isRunning ? new.waveHeight : 0)
            }
            applyColors(new)
            render(at: now)
            startLinkIfNeeded()
        }

        // MARK: Frames

        private var isSettled: Bool {
            guard let c = config else { return true }
            return !c.isRunning && Date().timeIntervalSince(change.date) > c.settleTime
        }

        private func startLinkIfNeeded() {
            guard link == nil, window != nil, !isSettled else { return }
            let l = displayLink(target: self, selector: #selector(frame(_:)))
            l.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
            l.add(to: .main, forMode: .common)
            link = l
        }

        private func stopLink() {
            link?.invalidate()
            link = nil
        }

        @objc private func frame(_ link: CADisplayLink) {
            // Nothing to draw for a window nobody can see.
            if let window, !window.occlusionState.contains(.visible) { return }
            render(at: Date())
            if isSettled { stopLink() }
        }

        private func amplitude(at date: Date, running: Bool? = nil) -> CGFloat {
            guard let c = config else { return 0 }
            let t = date.timeIntervalSince(change.date) / c.settleTime
            guard t < 1 else { return (running ?? c.isRunning) ? c.waveHeight : 0 }
            let k = CGFloat(max(0, t))
            return change.from + (change.to - change.from) * k * k * (3 - 2 * k)
        }

        private func render(at date: Date) {
            guard let c = config, bounds.width > 0 else { return }
            let left = min(1, max(0, c.fractionLeft(date)))
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let radius = min(bounds.width, bounds.height) / 2 - c.lineWidth / 2 - c.waveHeight
            let phase = (date.timeIntervalSinceReferenceDate * c.flowSpeed).truncatingRemainder(dividingBy: 2 * .pi)
            // Gap between the line's end and the track, allowing for both round caps.
            let gap = Double((c.lineWidth + 8) / (2 * .pi * radius))

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            wave.lineWidth = c.lineWidth
            wave.path = flipped(WavyArc.path(sweep: left, amplitude: amplitude(at: date), phase: phase,
                                             radius: radius, center: center, waves: c.waves))
            if left < 1 - gap * 2 {
                track.isHidden = false
                track.path = flipped(WavyArc.path(sweep: 1 - gap - (left + gap), amplitude: 0, phase: 0,
                                                  radius: radius, center: center,
                                                  startFraction: left + gap))
            } else {
                track.isHidden = true
            }
            if let colors = gradient.colors, colors.count == 3 {
                gradient.locations = [0, NSNumber(value: max(left, 0.01)), 1]
            }
            CATransaction.commit()
        }

        /// WavyArc works top-down like SwiftUI; this layer's origin is at the
        /// bottom, so mirror vertically to keep 12 o'clock on top and clockwise.
        private func flipped(_ path: Path) -> CGPath {
            var flip = CGAffineTransform(translationX: 0, y: bounds.height).scaledBy(x: 1, y: -1)
            return path.cgPath.copy(using: &flip) ?? path.cgPath
        }

        private func applyColors(_ c: WaveRing) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let cg = c.colors.map { NSColor($0).cgColor }
            if cg.count > 2 {
                gradient.colors = cg
                gradient.locations = nil
            } else if cg.count == 2 {
                gradient.colors = [cg[0], cg[1], cg[1]]
            }
            track.strokeColor = NSColor(c.trackColor).cgColor
            glow.shadowColor = NSColor(c.glowColor).cgColor
            CATransaction.commit()
        }
    }
}
