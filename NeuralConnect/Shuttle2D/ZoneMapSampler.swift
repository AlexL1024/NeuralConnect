//
//  ZoneMapSampler.swift
//  NeuralConnect
//
//  Loads a color-coded ZoneMap.png and samples pixel color to determine
//  which zone a given scene position falls in. O(1) per query.
//

import UIKit
import os.log

final class ZoneMapSampler {

    private let pixelData: CFData
    private let width: Int
    private let height: Int
    private let bytesPerRow: Int
    private let bytesPerPixel: Int

    // Color → zone ID lookup (tolerance-based matching)
    private static let colorTable: [(r: UInt8, g: UInt8, b: UInt8, zoneId: String)] = [
        (0x22, 0xC5, 0x5E, "gym"),       // #22C55E green
        (0x14, 0xB8, 0xA6, "hospital"),   // #14B8A6 teal
        (0x06, 0xB6, 0xD4, "lab"),        // #06B6D4 cyan
        (0x63, 0x66, 0xF1, "energy"),     // #6366F1 indigo
        (0x8B, 0x5C, 0xF6, "bar"),        // #8B5CF6 purple
        (0xEF, 0x44, 0x44, "casino"),     // #EF4444 red
    ]

    init?() {
        guard let image = UIImage(named: "TheMapColour"),
              let cgImage = image.cgImage else {
            NHLogger.scene.error("[ZoneMapSampler] ZoneMap image not found in assets")
            return nil
        }

        // Re-render into a known RGBA pixel format
        let w = cgImage.width
        let h = cgImage.height
        let bpp = 4
        let bpr = w * bpp

        guard let context = CGContext(
            data: nil,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: bpr,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            NHLogger.scene.error("[ZoneMapSampler] Failed to create bitmap context")
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        guard let rawPtr = context.data else {
            NHLogger.scene.error("[ZoneMapSampler] Failed to get pixel data")
            return nil
        }

        let totalBytes = bpr * h
        self.pixelData = CFDataCreate(nil, rawPtr.assumingMemoryBound(to: UInt8.self), totalBytes)!
        self.width = w
        self.height = h
        self.bytesPerRow = bpr
        self.bytesPerPixel = bpp

        NHLogger.scene.info("[ZoneMapSampler] Loaded zone map \(w)x\(h)")
    }

    /// Returns the zone ID for a given scene position, or nil if outside any zone.
    ///
    /// - Parameters:
    ///   - scenePos: Player position in SpriteKit scene coordinates
    ///   - backdropFrame: The frame of the backdrop sprite node (position + size)
    func zoneId(atScenePosition scenePos: CGPoint, backdropFrame: CGRect) -> String? {
        // Scene coords → normalized UV (0..1)
        let u = (scenePos.x - backdropFrame.minX) / backdropFrame.width
        let v = 1.0 - (scenePos.y - backdropFrame.minY) / backdropFrame.height // Y flip

        let px = Int((u * CGFloat(width)).clamped(to: 0...CGFloat(width - 1)))
        let py = Int((v * CGFloat(height)).clamped(to: 0...CGFloat(height - 1)))

        let ptr = CFDataGetBytePtr(pixelData)!
        let offset = py * bytesPerRow + px * bytesPerPixel
        let r = ptr[offset]
        let g = ptr[offset + 1]
        let b = ptr[offset + 2]
        let a = ptr[offset + 3]

        // Transparent or near-black → no zone
        if a < 128 { return nil }
        if r < 20 && g < 20 && b < 20 { return nil }

        return matchColor(r: r, g: g, b: b)
    }

    private func matchColor(r: UInt8, g: UInt8, b: UInt8) -> String? {
        var bestZone: String?
        var bestDist = Int.max

        for entry in Self.colorTable {
            let dr = Int(r) - Int(entry.r)
            let dg = Int(g) - Int(entry.g)
            let db = Int(b) - Int(entry.b)
            let dist = dr * dr + dg * dg + db * db

            if dist < bestDist {
                bestDist = dist
                bestZone = entry.zoneId
            }
        }

        // Tolerance: if color is too far from any known zone, treat as no zone
        // sqrt(6400) ≈ 80 per channel → generous for anti-aliased edges
        if bestDist > 6400 { return nil }

        return bestZone
    }
}

// MARK: - CGFloat clamping helper

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
