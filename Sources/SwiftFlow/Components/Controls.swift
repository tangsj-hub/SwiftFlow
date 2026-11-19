import SwiftUI

/// Zoom, fit-view, and interactivity buttons for the SwiftFlow canvas.
///
/// Reads viewport state from the environment and applies changes through
/// the shared `SwiftFlowState`. The fit-view button uses the canvas's
/// `fitViewOptions`. Place inside the `overlay` ViewBuilder.
///
/// When `tool` is set, a separate floating cluster (same chrome as zoom)
/// is placed next to the zoom controls in the same `position`, and writes
/// the chosen `CanvasTool`. This is not a second source of truth: pass the
/// same value to `SwiftFlow` and handle `onToolChange` / the binding here.
///
/// ```swift
/// SwiftFlow(nodes: nodes, edges: edges, ...) { node in
///     MyNodeView(node: node)
/// } overlay: {
///     Controls()
/// }
/// ```
public struct Controls<Children: View>: View {
  @EnvironmentObject private var flowState: SwiftFlowState
  @Environment(\.swiftFlowAccessibilityConfig) private var accessibilityConfig

  public var showZoom: Bool
  public var showFitView: Bool
  public var showInteractive: Bool
  public var position: PanelPosition
  /// When set, Controls shows a neighboring hand / move tool cluster and writes the choice here.
  public var tool: Binding<CanvasTool>?
  /// Tooltip and accessibility name for the hand tool. `nil` uses the localized default.
  public var panToolLabel: String?
  /// Tooltip and accessibility name for the move tool. `nil` uses the localized default.
  public var pointerToolLabel: String?
  @ViewBuilder public var children: () -> Children

  public init(
    showZoom: Bool = true,
    showFitView: Bool = true,
    showInteractive: Bool = false,
    position: PanelPosition = .bottomLeft,
    tool: Binding<CanvasTool>? = nil,
    panToolLabel: String? = nil,
    pointerToolLabel: String? = nil,
    @ViewBuilder children: @escaping () -> Children = { EmptyView() }
  ) {
    self.showZoom = showZoom
    self.showFitView = showFitView
    self.showInteractive = showInteractive
    self.position = position
    self.tool = tool
    self.panToolLabel = panToolLabel
    self.pointerToolLabel = pointerToolLabel
    self.children = children
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let tool {
        toolCluster(tool)
      }
      if showZoom || showFitView || showInteractive {
        zoomCluster
      }
      if !(showZoom || showFitView || showInteractive || tool != nil) {
        children()
      }
    }
    .fixedSize()
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
  }

  private var resolvedPanToolLabel: String {
    panToolLabel
      ?? String(localized: "Hand tool (H)", bundle: .module, comment: "Label of the hand / pan tool, including the H shortcut")
  }

  private var resolvedPointerToolLabel: String {
    pointerToolLabel
      ?? String(localized: "Move (V)", bundle: .module, comment: "Label of the move / selection tool, including the V shortcut")
  }

  private var toolClusterLabel: String {
    String(
      localized: "Interaction tools", bundle: .module,
      comment: "Accessibility name of the hand / move tool cluster")
  }

  @ViewBuilder
  private func toolCluster(_ tool: Binding<CanvasTool>) -> some View {
    VStack(spacing: 0) {
      toolButton(
        selected: tool.wrappedValue == .pointer,
        systemName: "cursorarrow",
        label: resolvedPointerToolLabel,
        action: { tool.wrappedValue = .pointer }
      )
      Divider()
      toolButton(
        selected: tool.wrappedValue == .pan,
        systemName: "hand.draw",
        label: resolvedPanToolLabel,
        action: { tool.wrappedValue = .pan }
      )
    }
    .modifier(ControlsChrome())
    .accessibilityElement(children: .contain)
    .accessibilityLabel(toolClusterLabel)
  }

  private func toolButton(
    selected: Bool,
    systemName: String,
    label: String,
    action: @escaping () -> Void
  ) -> some View {
    ControlButton(action: action, tooltip: label) {
      Image(systemName: systemName)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(selected ? Color.primary : Color.secondary)
        .background(
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(selected ? Color.primary.opacity(0.12) : Color.clear)
        )
    }
    .accessibilityLabel(label)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  @ViewBuilder
  private var zoomCluster: some View {
    VStack(spacing: 0) {
      if showZoom {
        ControlButton(action: { flowState.zoomIn() }, tooltip: accessibilityConfig.zoomInAriaLabel) {
          Image(systemName: "plus")
            .font(.system(size: 14, weight: .medium))
        }
        .accessibilityLabel(accessibilityConfig.zoomInAriaLabel)
        Divider()
        Button {
          flowState.zoomTo(1.0)
        } label: {
          Text(Double(flowState.viewport.zoom), format: .percent.precision(.fractionLength(0)))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .frame(width: 32, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          String(
            localized: "Reset zoom to 100 percent", bundle: .module,
            comment: "Label of the zoom level button"))
        .flowHoverTip(
          String(
            localized: "Reset zoom to 100 percent", bundle: .module,
            comment: "Label of the zoom level button"))
        Divider()
        ControlButton(action: { flowState.zoomOut() }, tooltip: accessibilityConfig.zoomOutAriaLabel) {
          Image(systemName: "minus")
            .font(.system(size: 14, weight: .medium))
        }
        .accessibilityLabel(accessibilityConfig.zoomOutAriaLabel)
      }
      if showFitView {
        if showZoom { Divider() }
        ControlButton(action: { flowState.fitView(options: flowState.fitViewOptions) }, tooltip: accessibilityConfig.fitViewAriaLabel) {
          Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 12, weight: .medium))
        }
        .accessibilityLabel(accessibilityConfig.fitViewAriaLabel)
      }
      if showInteractive {
        if showZoom || showFitView { Divider() }
        ControlButton(action: { flowState.isInteractive.toggle() }, tooltip: accessibilityConfig.interactiveAriaLabel) {
          Image(systemName: flowState.isInteractive ? "lock.open" : "lock")
            .font(.system(size: 12, weight: .medium))
        }
        .accessibilityLabel(accessibilityConfig.interactiveAriaLabel)
        .accessibilityAddTraits(flowState.isInteractive ? [] : .isSelected)
      }
      children()
    }
    .modifier(ControlsChrome())
    .accessibilityElement(children: .contain)
    .accessibilityLabel(accessibilityConfig.controlsAriaLabel)
  }
}

/// Shared floating chrome for the zoom controls and the neighboring tool cluster.
struct ControlsChrome: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(.ultraThinMaterial)
      .cornerRadius(8)
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
      .fixedSize()
  }
}
