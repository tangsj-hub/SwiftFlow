import SwiftUI

/// A single button for use inside `Controls` or as a standalone control.
///
/// ```swift
/// ControlButton(action: { print("tapped") }) {
///     Image(systemName: "plus")
/// }
/// ```
public struct ControlButton<Content: View>: View {
  public var action: () -> Void
  public var tooltip: String
  @ViewBuilder public var content: () -> Content

  public init(
    action: @escaping () -> Void,
    tooltip: String = "",
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.action = action
    self.tooltip = tooltip
    self.content = content
  }

  public var body: some View {
    Button(action: action) {
      content()
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .flowHoverTip(tooltip)
  }
}
