import Foundation

/// Pure value type representing the canvas transform state (translate + scale).
/// All mutation methods return a new instance — no side effects.
struct CanvasTransform: Equatable {
    var translateX: Double
    var translateY: Double
    var scale: Double

    static let minScale: Double = 0.1
    static let maxScale: Double = 10.0

    static let identity = CanvasTransform(translateX: 0, translateY: 0, scale: 1)

    // MARK: - Zoom

    /// Zoom toward/away from a screen-space point by a multiplicative delta.
    /// `delta > 0` zooms out, `delta < 0` zooms in.
    /// The point (centerX, centerY) stays fixed on screen after the zoom.
    func zoomedAt(centerX: Double, centerY: Double, delta: Double) -> CanvasTransform {
        let newScale = Self.clampedScale(scale * (1 - delta))
        return zoomedTo(centerX: centerX, centerY: centerY, newScale: newScale)
    }

    /// Zoom to an absolute scale, keeping the given screen-space point fixed.
    func zoomedTo(centerX: Double, centerY: Double, newScale: Double) -> CanvasTransform {
        let clamped = Self.clampedScale(newScale)
        let ratio = clamped / scale
        return CanvasTransform(
            translateX: centerX - (centerX - translateX) * ratio,
            translateY: centerY - (centerY - translateY) * ratio,
            scale: clamped
        )
    }

    // MARK: - Pan

    /// Pan by a screen-space delta.
    func panned(dx: Double, dy: Double) -> CanvasTransform {
        CanvasTransform(
            translateX: translateX + dx,
            translateY: translateY + dy,
            scale: scale
        )
    }

    // MARK: - Fit to View

    /// Compute the transform that fits a diagram of `diagramSize` inside `viewportSize`
    /// with the given padding, capped at `maxFitScale`.
    static func fitting(
        diagramWidth: Double,
        diagramHeight: Double,
        viewportWidth: Double,
        viewportHeight: Double,
        padding: Double = 80,
        maxFitScale: Double = 2
    ) -> CanvasTransform {
        guard diagramWidth > 0, diagramHeight > 0 else { return .identity }

        let scaleX = (viewportWidth - padding * 2) / diagramWidth
        let scaleY = (viewportHeight - padding * 2) / diagramHeight
        let fitScale = min(min(scaleX, scaleY), maxFitScale)
        let clamped = clampedScale(fitScale)

        let tx = (viewportWidth - diagramWidth * clamped) / 2
        let ty = (viewportHeight - diagramHeight * clamped) / 2

        return CanvasTransform(translateX: tx, translateY: ty, scale: clamped)
    }

    // MARK: - Content-space mapping

    /// Convert a screen-space point to content-space.
    func screenToContent(x: Double, y: Double) -> (x: Double, y: Double) {
        ((x - translateX) / scale, (y - translateY) / scale)
    }

    /// Convert a content-space point to screen-space.
    func contentToScreen(x: Double, y: Double) -> (x: Double, y: Double) {
        (x * scale + translateX, y * scale + translateY)
    }

    /// The visible rect in content-space for a given viewport size.
    func visibleRect(viewportWidth: Double, viewportHeight: Double) -> (x: Double, y: Double, width: Double, height: Double) {
        let origin = screenToContent(x: 0, y: 0)
        return (origin.x, origin.y, viewportWidth / scale, viewportHeight / scale)
    }

    // MARK: - CSS

    /// The CSS transform string for `transform-origin: 0 0`.
    var cssTransform: String {
        "translate(\(translateX)px, \(translateY)px) scale(\(scale))"
    }

    /// Scale percentage for display (e.g. "150%").
    var scalePercent: Int {
        Int((scale * 100).rounded())
    }

    // MARK: - Helpers

    static func clampedScale(_ s: Double) -> Double {
        min(maxScale, max(minScale, s))
    }
}
