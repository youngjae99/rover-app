import Foundation
import CoreGraphics

/// Translates between Anthropic computer-use tool coordinates (the model's
/// view of the screenshot it received) and on-screen logical points.
///
/// Per Anthropic docs:
/// - Opus 4.7 / Sonnet 4.7 with `computer_20251124`: coordinates are 1:1
///   with the image we send (no rescaling), so we send the image at the
///   primary screen's logical size.
/// - Older `computer_20250124` etc. need scaling so the long edge ≤ 1568px
///   and total pixels ≤ ~1.15M. This v0.2 ships only the new tool, so the
///   scaler is essentially identity for now — but the hook is here.
struct CoordinateScaler {
    /// The (width, height) Roger asks ScreenCaptureKit to render at and
    /// then sends to the API. Uses the primary screen's logical points.
    let captureSize: CGSize

    /// Map a model-supplied (x, y) back to logical screen points where
    /// CGEvent posts can land.
    func toScreenPoint(x: Int, y: Int) -> CGPoint {
        // 1:1 for computer_20251124. If we add legacy support, scale here.
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}
