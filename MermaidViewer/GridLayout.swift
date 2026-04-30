import Foundation

/// Pure functions for computing the dot-grid background parameters.
enum GridLayout {
    /// Compute the adaptive grid spacing that stays visually comfortable
    /// across zoom levels. Returns the effective grid spacing in screen pixels.
    static func adaptiveGridSize(baseGrid: Double = 20, scale: Double) -> Double {
        var gridSize = baseGrid * scale
        var adjusted = baseGrid
        while gridSize < 10 { gridSize *= 5; adjusted *= 5 }
        while gridSize > 100 { gridSize /= 5; adjusted /= 5 }
        return gridSize
    }

    /// Dot radius in screen pixels.
    static func dotSize(scale: Double) -> Double {
        max(0.8, scale * 0.8)
    }

    /// Dot opacity (0…0.35), increasing with grid spacing.
    static func dotAlpha(gridSize: Double) -> Double {
        min(0.35, 0.1 + (gridSize - 10) / 200)
    }

    /// Grid offset for seamless scrolling. Returns the pixel offset
    /// so dots align with the canvas translate.
    static func gridOffset(translate: Double, gridSize: Double) -> Double {
        // Swift `truncatingRemainder` preserves sign, matching JS `%`
        translate.truncatingRemainder(dividingBy: gridSize)
    }
}
