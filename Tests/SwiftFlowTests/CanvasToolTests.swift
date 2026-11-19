import Testing

@testable import SwiftFlow

@Suite("CanvasTool")
struct CanvasToolTests {

  @Test func nilToolKeepsHistoricalPaneAndNodeBehavior() {
    #expect(
      CanvasTool.paneDragAction(
        tool: nil, panOnDrag: true, selectionOnDrag: false, shiftDown: false,
        isInteractive: true, elementsSelectable: true) == .pan)
    #expect(
      CanvasTool.paneDragAction(
        tool: nil, panOnDrag: true, selectionOnDrag: false, shiftDown: true,
        isInteractive: true, elementsSelectable: true) == .selectionBox)
    #expect(
      CanvasTool.paneDragAction(
        tool: nil, panOnDrag: true, selectionOnDrag: true, shiftDown: false,
        isInteractive: true, elementsSelectable: true) == .selectionBox)
    #expect(
      CanvasTool.paneDragAction(
        tool: nil, panOnDrag: true, selectionOnDrag: true, shiftDown: true,
        isInteractive: true, elementsSelectable: true) == .pan)
    #expect(
      CanvasTool.allowsNodeDrag(tool: nil, nodesDraggable: true, isInteractive: true))
    #expect(
      CanvasTool.paneCursor(
        tool: nil, panOnDrag: true, selectionOnDrag: false, isInteractive: true) == .grab)
  }

  @Test func panToolPansThePaneAndDoesNotDragNodes() {
    #expect(
      CanvasTool.paneDragAction(
        tool: .pan, panOnDrag: true, selectionOnDrag: true, shiftDown: false,
        isInteractive: true, elementsSelectable: true) == .pan)
    #expect(
      CanvasTool.paneDragAction(
        tool: .pan, panOnDrag: true, selectionOnDrag: true, shiftDown: true,
        isInteractive: true, elementsSelectable: true) == .pan)
    #expect(
      !CanvasTool.allowsNodeDrag(tool: .pan, nodesDraggable: true, isInteractive: true))
    #expect(
      CanvasTool.paneCursor(
        tool: .pan, panOnDrag: true, selectionOnDrag: false, isInteractive: true) == .grab)
  }

  @Test func pointerToolSelectsOnDragAndPansWithShift() {
    #expect(
      CanvasTool.paneDragAction(
        tool: .pointer, panOnDrag: true, selectionOnDrag: false, shiftDown: false,
        isInteractive: true, elementsSelectable: true) == .selectionBox)
    #expect(
      CanvasTool.paneDragAction(
        tool: .pointer, panOnDrag: true, selectionOnDrag: false, shiftDown: true,
        isInteractive: true, elementsSelectable: true) == .pan)
    #expect(
      CanvasTool.allowsNodeDrag(tool: .pointer, nodesDraggable: true, isInteractive: true))
    #expect(
      CanvasTool.paneCursor(
        tool: .pointer, panOnDrag: true, selectionOnDrag: false, isInteractive: true)
        == .default)
  }

  @Test func switchingToolsChangesDragBehaviorNotJustTheLabel() {
    var tool = CanvasTool.pointer
    #expect(
      CanvasTool.paneDragAction(
        tool: tool, panOnDrag: true, selectionOnDrag: false, shiftDown: false,
        isInteractive: true, elementsSelectable: true) == .selectionBox)
    #expect(CanvasTool.allowsNodeDrag(tool: tool, nodesDraggable: true, isInteractive: true))
    tool = .pan
    #expect(
      CanvasTool.paneDragAction(
        tool: tool, panOnDrag: true, selectionOnDrag: false, shiftDown: false,
        isInteractive: true, elementsSelectable: true) == .pan)
    #expect(!CanvasTool.allowsNodeDrag(tool: tool, nodesDraggable: true, isInteractive: true))
  }

  @Test func disabledCanvasProducesNoPaneOrNodeDrag() {
    for tool: CanvasTool? in [nil, .pan, .pointer] {
      #expect(
        CanvasTool.paneDragAction(
          tool: tool, panOnDrag: true, selectionOnDrag: true, shiftDown: false,
          isInteractive: false, elementsSelectable: true) == .none)
      #expect(
        !CanvasTool.allowsNodeDrag(tool: tool, nodesDraggable: true, isInteractive: false))
    }
  }


  @Test func unmodifiedVAndHSwitchTools() {
    #expect(
      CanvasTool.shortcutTool(
        key: "v", hasCommand: false, hasOption: false, hasControl: false, hasShift: false,
        canvasLive: true) == .pointer)
    #expect(
      CanvasTool.shortcutTool(
        key: "H", hasCommand: false, hasOption: false, hasControl: false, hasShift: false,
        canvasLive: true) == .pan)
  }

  @Test func toolShortcutsIgnoredWhenCanvasIsNotLiveOrModifiersAreHeld() {
    #expect(
      CanvasTool.shortcutTool(
        key: "v", hasCommand: false, hasOption: false, hasControl: false, hasShift: false,
        canvasLive: false) == nil)
    #expect(
      CanvasTool.shortcutTool(
        key: "v", hasCommand: true, hasOption: false, hasControl: false, hasShift: false,
        canvasLive: true) == nil)
    #expect(
      CanvasTool.shortcutTool(
        key: "h", hasCommand: false, hasOption: false, hasControl: false, hasShift: true,
        canvasLive: true) == nil)
    #expect(
      CanvasTool.shortcutTool(
        key: "h", hasCommand: false, hasOption: true, hasControl: false, hasShift: false,
        canvasLive: true) == nil)
  }


  @Test func panToolPansFromNodesAndKeepsTheGrabCursor() {
    #expect(
      CanvasTool.nodeDragKind(
        tool: .pan, panOnDrag: true, nodesDraggable: true, isInteractive: true) == .panCanvas)
    #expect(
      CanvasTool.nodeCursor(
        tool: .pan, panOnDrag: true, nodesDraggable: true, isInteractive: true) == .grab)
    #expect(
      !CanvasTool.allowsNodeDrag(tool: .pan, nodesDraggable: true, isInteractive: true))
  }

  @Test func pointerToolStillDragsNodes() {
    #expect(
      CanvasTool.nodeDragKind(
        tool: .pointer, panOnDrag: true, nodesDraggable: true, isInteractive: true) == .dragNode)
    #expect(
      CanvasTool.nodeCursor(
        tool: .pointer, panOnDrag: true, nodesDraggable: true, isInteractive: true) == .grab)
  }

  @Test func nilToolKeepsHistoricalNodeDrag() {
    #expect(
      CanvasTool.nodeDragKind(
        tool: nil, panOnDrag: true, nodesDraggable: true, isInteractive: true) == .dragNode)
  }

  @Test func disabledOrPausedCanvasDoesNotPanOrDragFromNodes() {
    #expect(
      CanvasTool.nodeDragKind(
        tool: .pan, panOnDrag: false, nodesDraggable: false, isInteractive: true) == .none)
    #expect(
      CanvasTool.nodeDragKind(
        tool: .pan, panOnDrag: true, nodesDraggable: true, isInteractive: false) == .none)
  }
}
