# Controls

Zoom and fit-to-view control buttons for the SwiftFlow canvas.

## Basic Usage

```swift
SwiftFlow(nodes: nodes, edges: edges, ...) { node in
    MyNodeView(node: node)
} overlay: {
    Controls()
}
```

## Customization

```swift
// Zoom only (no fit button)
Controls(showZoom: true, showFitView: false)

// Fit only (no zoom buttons)
Controls(showZoom: false, showFitView: true)

// Different position
Controls(position: .bottomRight)

// With interactive toggle
Controls(showInteractive: true)
```

## Adding Custom Buttons

Extend Controls with your own buttons:

```swift
Controls(position: .bottomLeft) {
    Divider()
    ControlButton(action: {
        // Custom action
    }) {
        Image(systemName: "arrow.clockwise")
            .font(.system(size: 14, weight: .medium))
    }
}
```

Use `ControlButton` for consistent styling with the built-in zoom buttons.

## Parameters

| Property          | Type            | Default       | Description                                    |
| ----------------- | --------------- | ------------- | ---------------------------------------------- |
| `showZoom`        | `Bool`          | `true`        | Show zoom in/out buttons and zoom percentage   |
| `showFitView`     | `Bool`          | `true`        | Show fit-to-view button                        |
| `showInteractive` | `Bool`          | `false`       | Show interactive mode toggle                   |
| `tool`             | `Binding<CanvasTool>?` | `nil` | When set, shows pan (hand) and pointer (mouse) tools and writes the choice |
| `position`        | `PanelPosition` | `.bottomLeft` | Panel position on canvas                       |
| `children`        | `() -> Children`| `EmptyView()` | ViewBuilder for additional custom buttons      |

## PanelPosition Values

| `.topLeft`     | `.topCenter`     | `.topRight`     |
| `.centerLeft`  | `.center`        | `.centerRight`  |
| `.bottomLeft`  | `.bottomCenter`  | `.bottomRight`  |

## How It Works

Controls reads viewport state from the `SwiftFlowState` environment object and applies changes through it. The zoom buttons call `zoomIn()`, `zoomOut()`, and `zoomTo(1.0)` on the state, while the fit button fits the view using the canvas `fitViewOptions`. Each zoom step is a factor of 1.2. Button accessibility labels come from `accessibilityConfig` (`zoomInAriaLabel`, `zoomOutAriaLabel`, `fitViewAriaLabel`, `interactiveAriaLabel`, `controlsAriaLabel`).

The zoom percentage display shows the current zoom level as an integer percentage (e.g., "100%" at default zoom).

## Styling

Controls are rendered with a `.ultraThinMaterial` background, 8pt corner radius, and a subtle gray border. The panel is `fixedSize()` so it doesn't expand to fill the canvas.


## Move and hand tools

Pass `tool: $tool` to show a floating cluster next to the zoom controls (same chrome and `position`, not a second source of truth). Do not also add a custom tool bar that writes a different value.

- **Move (`CanvasTool.pointer`, shortcut `V`)**: drag empty space to box-select; Shift+drag pans; nodes can be dragged. Tooltip / accessibility label defaults to “Move (V)”; the host can override it (ZhuQue uses `移动（V）`).
- **Hand tool (`CanvasTool.pan`, shortcut `H`)**: drag empty space to pan; nodes are not dragged. Tooltip / accessibility label defaults to “Hand tool (H)”; the host can override it (ZhuQue uses `抓手工具（H）`).

Pass the same `tool` value to `SwiftFlow`, and `onToolChange` so `V` / `H` update that state. Unmodified `V` and `H` are handled by the canvas key monitor only when the canvas is live and active in this window and the user is not editing text; they do not claim `Cmd+V` or keys in other windows. `nil` `tool` keeps the historical mix of `panOnDrag` / `selectionOnDrag` with nodes still draggable, and does not steal `V` / `H`. Trackpad pan and pinch are independent of the tool.
