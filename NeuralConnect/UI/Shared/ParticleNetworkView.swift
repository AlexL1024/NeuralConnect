import SwiftUI

private struct Particle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var depth: Double // 0.3...1.0, controls size and speed
}

struct ParticleNetworkView: View {
    var particleCount: Int = 150
    var connectionDistance: CGFloat = 100
    var baseColor: Color = .cyan

    @State private var particles: [Particle] = []
    @State private var lastUpdate: Date = .now
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                if canvasSize != size {
                    DispatchQueue.main.async {
                        canvasSize = size
                        if particles.isEmpty {
                            initParticles(in: size)
                        }
                    }
                }

                let dt = min(timeline.date.timeIntervalSince(lastUpdate), 0.05)
                DispatchQueue.main.async { lastUpdate = timeline.date }

                var pts = particles
                guard !pts.isEmpty else { return }

                // Update positions
                for i in pts.indices {
                    pts[i].x += pts[i].vx * dt
                    pts[i].y += pts[i].vy * dt

                    // Bounce off edges
                    let margin = 20.0
                    if pts[i].x < -margin { pts[i].x = -margin; pts[i].vx = abs(pts[i].vx) }
                    if pts[i].x > size.width + margin { pts[i].x = size.width + margin; pts[i].vx = -abs(pts[i].vx) }
                    if pts[i].y < -margin { pts[i].y = -margin; pts[i].vy = abs(pts[i].vy) }
                    if pts[i].y > size.height + margin { pts[i].y = size.height + margin; pts[i].vy = -abs(pts[i].vy) }
                }
                DispatchQueue.main.async { particles = pts }

                // Compute minimum distances for color shifting
                var minDist = [Double](repeating: Double.infinity, count: pts.count)

                // Draw connections
                let threshold = Double(connectionDistance)
                for i in 0..<pts.count {
                    for j in (i + 1)..<pts.count {
                        let dx = pts[i].x - pts[j].x
                        let dy = pts[i].y - pts[j].y
                        let d = sqrt(dx * dx + dy * dy)

                        if d < threshold {
                            let ratio = 1.0 - d / threshold
                            let lineWidth = max(0.5, 2.0 * ratio)
                            let opacity = ratio * 0.8

                            // Interpolate deep blue -> bright white based on proximity
                            let r = pow(ratio, 0.6)
                            let g = pow(ratio, 0.6)
                            let b = 1.0

                            var path = Path()
                            path.move(to: CGPoint(x: pts[i].x, y: pts[i].y))
                            path.addLine(to: CGPoint(x: pts[j].x, y: pts[j].y))
                            context.stroke(
                                path,
                                with: .color(Color(red: r, green: g, blue: b).opacity(opacity)),
                                lineWidth: lineWidth
                            )

                            if d < minDist[i] { minDist[i] = d }
                            if d < minDist[j] { minDist[j] = d }
                        }
                    }
                }

                // Draw particles with depth-of-field blur
                for i in pts.indices {
                    let radius = 0.5 + pts[i].depth * 0.83
                    let rect = CGRect(
                        x: pts[i].x - radius,
                        y: pts[i].y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )

                    // Shift toward bright white when close to neighbors
                    let whiteness: Double
                    if minDist[i] < threshold {
                        whiteness = pow(max(0, 1.0 - minDist[i] / threshold), 0.5)
                    } else {
                        whiteness = 0
                    }

                    // Base color by depth: far (low depth) = deep blue, near (high depth) = pale/white
                    let depthWhite = (pts[i].depth - 0.3) / 0.7 // 0...1 normalized
                    let combined = min(1.0, depthWhite * 0.6 + whiteness * 0.6)
                    let r = 0.1 + 0.9 * combined
                    let g = 0.2 + 0.8 * combined
                    let b = 0.7 + 0.3 * combined

                    let dotColor = Color(red: r, green: g, blue: b)

                    // Depth-of-field: far particles (low depth) get more blur
                    let blurRadius = (1.0 - pts[i].depth) * 4.0 // 0~2.8pt blur
                    context.drawLayer { layerCtx in
                        if blurRadius > 0.3 {
                            layerCtx.addFilter(.blur(radius: blurRadius))
                        }
                        layerCtx.fill(
                            Path(ellipseIn: rect),
                            with: .color(dotColor.opacity(0.3 + 0.7 * pts[i].depth))
                        )
                    }
                }
            }
        }
        .background(Color.black)
    }

    private func initParticles(in size: CGSize) {
        var result: [Particle] = []
        for _ in 0..<particleCount {
            let depth = Double.random(in: 0.3...1.0)
            let speed = Double.random(in: 5...50) * depth // 1.5~50 pt/s, wide range
            let angle = Double.random(in: 0...(2 * .pi))
            result.append(Particle(
                x: Double.random(in: 0...max(1, size.width)),
                y: Double.random(in: 0...max(1, size.height)),
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                depth: depth
            ))
        }
        particles = result
    }
}
