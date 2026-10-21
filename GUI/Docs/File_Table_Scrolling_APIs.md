# File table scrolling APIs

The list panel is a SwiftUI `ScrollView` with a pinned column header and an AppKit `NSScrollView` backing it. Keyboard navigation uses the native clip view so it can reveal a row at the nearest edge and keep Page Up/Down at a stable screen position.

| API | Current use |
| --- | --- |
| `ScrollViewReader.scrollTo(_:anchor:)` | Fallback when the native scroll view has not yet been captured. |
| `NSScrollView.contentView` / `NSClipView.scroll(to:)` | Precise row and page placement, including Home/End. |
| `NSAnimationContext.animate(_:changes:completion:)` | Short, velocity-preserving AppKit animation for keyboard scrolling. |
| `Animation.snappy(duration:extraBounce:)` | Small spring finish for the viewport and nearby selection changes. |
| `NSWorkspace.accessibilityDisplayShouldReduceMotion` | Immediate movement when Reduce Motion is enabled. |

Apple also provides `ScrollPosition`, `onScrollGeometryChange`, and `onScrollPhaseChange` for SwiftUI scroll views. `ScrollPosition` supports minimal ID-based scrolling, offsets, and edges. The file panel keeps the native path because Page Up/Down needs a precise pixel offset under the pinned header and its existing scrollbar setup. Geometry and phase callbacks are unnecessary until a feature needs continuous scroll observation.

References: [ScrollPosition](https://developer.apple.com/documentation/swiftui/scrollposition), [onScrollGeometryChange](https://developer.apple.com/documentation/swiftui/view/onscrollgeometrychange(for:of:action:)), [NSAnimationContext.animate](https://developer.apple.com/documentation/appkit/nsanimationcontext/animate(_:changes:completion:)), [Animation.snappy](https://developer.apple.com/documentation/swiftui/animation/snappy(duration:extrabounce:)).
