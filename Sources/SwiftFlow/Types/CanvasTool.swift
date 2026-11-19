import Foundation

/// Pointer (mouse) vs pan (hand) tools for the empty canvas.
///
/// `nil` on `SwiftFlow` keeps the historical mix: `panOnDrag` / `selectionOnDrag` as
/// passed, and nodes stay draggable. A concrete tool is exclusive:
/// - ``pan``: drag empty space to pan; nodes are not dragged.
/// - ``pointer``: drag empty space to box-select; Shift+drag pans; nodes can be dragged.
public enum CanvasTool: String, Equatable, Sendable, CaseIterable {
  case pan
  case pointer

  public enum PaneDragAction: Equatable, Sendable {
    case pan
    case selectionBox
    case none
  }

  /// Decision for a drag that starts on the empty pane, not on a node.
  public static func paneDragAction(
    tool: CanvasTool?,
    panOnDrag: Bool,
    selectionOnDrag: Bool,
    shiftDown: Bool,
    isInteractive: Bool,
    elementsSelectable: Bool
  ) -> PaneDragAction {
    guard isInteractive else { return .none }
    switch tool {
    case .pan:
      return panOnDrag ? .pan : .none
    case .pointer:
      if shiftDown {
        return panOnDrag ? .pan : .none
      }
      return elementsSelectable ? .selectionBox : .none
    case nil:
      let wantsBox = selectionOnDrag ? !shiftDown : shiftDown
      if wantsBox && elementsSelectable { return .selectionBox }
      return panOnDrag ? .pan : .none
    }
  }

  public static func allowsNodeDrag(
    tool: CanvasTool?,
    nodesDraggable: Bool,
    isInteractive: Bool,
    nodeDraggable: Bool = true
  ) -> Bool {
    guard isInteractive, nodesDraggable, nodeDraggable else { return false }
    return tool != .pan
  }

  public static func paneCursor(
    tool: CanvasTool?,
    panOnDrag: Bool,
    selectionOnDrag: Bool,
    isInteractive: Bool
  ) -> FlowCursor {
    guard isInteractive else { return .default }
    switch tool {
    case .pan:
      return .grab
    case .pointer:
      return .default
    case nil:
      return panOnDrag && !selectionOnDrag ? .grab : .default
    }
  }

  /// What a pointer interaction on a node should do.
  public enum NodeDragKind: Equatable, Sendable {
    /// Pan the viewport; the node itself does not move.
    case panCanvas
    /// Drag the node.
    case dragNode
    case none
  }

  /// `.pan` pans the canvas from the node when `panOnDrag` is on. `.pointer` and
  /// `nil` keep the historical node-drag behavior. Disabled canvases return `.none`.
  public static func nodeDragKind(
    tool: CanvasTool?,
    panOnDrag: Bool,
    nodesDraggable: Bool,
    isInteractive: Bool,
    nodeDraggable: Bool = true
  ) -> NodeDragKind {
    guard isInteractive else { return .none }
    if tool == .pan {
      return panOnDrag ? .panCanvas : .none
    }
    return nodesDraggable && nodeDraggable ? .dragNode : .none
  }

  public static func nodeCursor(
    tool: CanvasTool?,
    panOnDrag: Bool,
    nodesDraggable: Bool,
    isInteractive: Bool,
    nodeDraggable: Bool = true
  ) -> FlowCursor {
    switch nodeDragKind(
      tool: tool,
      panOnDrag: panOnDrag,
      nodesDraggable: nodesDraggable,
      isInteractive: isInteractive,
      nodeDraggable: nodeDraggable
    ) {
    case .panCanvas, .dragNode:
      return .grab
    case .none:
      return .default
    }
  }

  /// Unmodified `V` selects the move / pointer tool; unmodified `H` selects the hand tool.
  /// Returns `nil` when modifiers are present (so Cmd+V and similar stay available),
  /// the canvas is not live, or the key is not a tool shortcut.
  public static func shortcutTool(
    key: String?,
    hasCommand: Bool,
    hasOption: Bool,
    hasControl: Bool,
    hasShift: Bool,
    canvasLive: Bool
  ) -> CanvasTool? {
    guard canvasLive, !hasCommand, !hasOption, !hasControl, !hasShift,
      let raw = key?.lowercased(), raw.count == 1
    else { return nil }
    switch raw {
    case "v": return .pointer
    case "h": return .pan
    default: return nil
    }
  }
}
