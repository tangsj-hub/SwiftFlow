import CoreGraphics
import Foundation

/// Routes macOS trackpad scroll and magnify after the event has already been
/// limited to the canvas window. SwiftUI `MagnificationGesture` is not used on
/// macOS because it does not reliably receive native pinch events.
struct TrackpadCanvasRouter {
  private(set) var isMagnifying = false
  private var pinchTotal: CGFloat = 0
  /// After a pinch ends, leftover scroll/momentum from the same fingers is ignored
  /// until a new scroll gesture begins.
  private var suppressScrollUntilBegan = false

  enum Outcome: Equatable {
    /// Leave the event for the rest of the app.
    case pass
    /// Swallow the event without changing the viewport.
    case consume
    case scroll(delta: CGSize, ended: Bool)
    /// `factorFromStart` is `1 +` the cumulative `NSEvent.magnification`.
    case magnify(factorFromStart: CGFloat, ended: Bool)
  }

  static func isInScope(isSameWindow: Bool, isInBounds: Bool) -> Bool {
    isSameWindow && isInBounds
  }

  mutating func handleMagnify(
    increment: CGFloat,
    ended: Bool,
    isSameWindow: Bool,
    isInBounds: Bool,
    enabled: Bool
  ) -> Outcome {
    guard isSameWindow else { return .pass }
    guard enabled else { return .pass }
    if ended {
      // Finish an in-flight pinch even if the pointer has left the view.
      guard isMagnifying || isInBounds else { return .pass }
      isMagnifying = false
      pinchTotal = 0
      suppressScrollUntilBegan = true
      return .magnify(factorFromStart: 1, ended: true)
    }
    guard isInBounds else { return .pass }
    if !isMagnifying {
      isMagnifying = true
      pinchTotal = 0
    }
    pinchTotal += increment
    return .magnify(factorFromStart: 1 + pinchTotal, ended: false)
  }

  mutating func handleScroll(
    delta: CGSize,
    ended: Bool,
    phaseBegan: Bool,
    isMomentum: Bool,
    isSameWindow: Bool,
    isInBounds: Bool,
    enabled: Bool
  ) -> Outcome {
    guard isSameWindow, isInBounds else { return .pass }
    if isMagnifying || (suppressScrollUntilBegan && !phaseBegan) {
      return .consume
    }
    if phaseBegan { suppressScrollUntilBegan = false }
    guard enabled else { return .pass }
    if ended { return .scroll(delta: .zero, ended: true) }
    let threshold: CGFloat = isMomentum ? 0.5 : 0.1
    guard abs(delta.width) > threshold || abs(delta.height) > threshold else {
      return .pass
    }
    return .scroll(delta: delta, ended: false)
  }
}
