//! A native Swift drawing library whose sketch lifecycle and core API mirror p5.js.

#if canImport(UIKit)
import UIKit

/// The native view type used to display a sketch on iOS.
public typealias P5CanvasView = UIView
#elseif canImport(AppKit)
import AppKit

/// The native view type used to display a sketch on macOS.
public typealias P5CanvasView = NSView
#endif
