//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import UIKit


@MainActor
enum AXDump {
    nonisolated static func enableAXRuntime() {
        guard let lib = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW) else {
            return
        }
        typealias SetEnabled = @convention(c) (Bool) -> Void
        for sym in ["_AXSSetAutomationEnabled", "_AXSApplicationAccessibilitySetEnabled"] {
            if let ptr = dlsym(lib, sym) {
                unsafeBitCast(ptr, to: SetEnabled.self)(true)
            }
        }
    }
    
    // MARK: Identifier lookup (SwiftUI AX nodes respond to the selector but don't conform to UIAccessibilityIdentification)
    
    
    private static func axIdentifier(of obj: NSObject) -> String? {
        if let id = (obj as? any UIAccessibilityIdentification)?.accessibilityIdentifier {
            return id
        }
        let sel = Selector(("accessibilityIdentifier"))
        guard obj.responds(to: sel),
              let id = obj.perform(sel)?.takeUnretainedValue() as? String else {
            return nil
        }
        return id
    }
    
    // MARK: XCUIElementType-style classification
    
    private static func elementType(of obj: NSObject) -> String { // swiftlint:disable:this cyclomatic_complexity function_body_length
        let traits = obj.accessibilityTraits
        if traits.contains(.button) {
            return traits.contains(.selected) || obj is UISwitch ? "Switch" : "Button"
        }
        if traits.contains(.link) {
            return "Link"
        }
        if traits.contains(.image) {
            return "Image"
        }
        if traits.contains(.searchField) {
            return "SearchField"
        }
        if traits.contains(.header) {
            return "StaticText"
        }
        if traits.contains(.adjustable) {
            return switch obj {
            case is UISlider:
                "Slider"
            case is UIStepper:
                "Stepper"
            default:
                "Slider"
            }
        }
        if traits.contains(.tabBar) {
            return "TabBar"
        }
        if traits.contains(.keyboardKey) {
            return "Key"
        }
        switch obj {
        case is UIWindow:
            return "Window"
        case is UILabel:
            return "StaticText"
        case let obj as UITextField:
            return obj.isSecureTextEntry ? "SecureTextField" : "TextField"
        case is UITextView:
            return "TextView"
        case is UIButton:
            return "Button"
        case is UIImageView:
            return "Image"
        case is UITableView:
            return "Table"
        case is UICollectionView:
            return "CollectionView"
        case is UIScrollView:
            return "ScrollView"
        case is UITableViewCell, is UICollectionViewCell:
            return "Cell"
        case is UINavigationBar:
            return "NavigationBar"
        case is UITabBar:
            return "TabBar"
        case is UIToolbar:
            return "Toolbar"
        case is UISwitch:
            return "Switch"
        case is UISlider:
            return "Slider"
        case is UISegmentedControl:
            return "SegmentedControl"
        case is UIPickerView:
            return "Picker"
        case is UIDatePicker:
            return "DatePicker"
        case is UIActivityIndicatorView:
            return "ActivityIndicator"
        case is UIProgressView:
            return "ProgressIndicator"
        case is UIPageControl:
            return "PageIndicator"
        default:
            break
        }
        if traits.contains(.staticText) {
            return "StaticText"
        }
        return "Other"
    }
    
    
    // MARK: Formatting (mirrors XCUIElement debugDescription lines)
    
    private static func line(for obj: NSObject, depth: Int) -> String {
        var parts = [elementType(of: obj)]
        let frame = obj.accessibilityFrame
        parts.append(String(format: "{{%.1f, %.1f}, {%.1f, %.1f}}", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height))
        if let id = axIdentifier(of: obj), !id.isEmpty {
            parts.append("identifier: '\(id)'")
        }
        if let label = obj.accessibilityLabel, !label.isEmpty {
            parts.append("label: '\(label)'")
        }
        if let value = obj.accessibilityValue, !value.isEmpty {
            parts.append("value: \(value)")
        }
        if let hint = obj.accessibilityHint, !hint.isEmpty {
            parts.append("hint: '\(hint)'")
        }
        let traits = obj.accessibilityTraits
        if traits.contains(.selected) {
            parts.append("Selected")
        }
        if traits.contains(.notEnabled) {
            parts.append("Disabled")
        }
        return String(repeating: "  ", count: depth) + parts.joined(separator: ", ")
    }
    
    
    // XCUI omits pure layout containers; skip views with no AX relevance, flattening children up.
    private static func isTransparentContainer(_ obj: NSObject) -> Bool {
        guard let view = obj as? UIView, !(view is UIWindow) else {
            return false
        }
        if view.isAccessibilityElement {
            return false
        }
        if let id = axIdentifier(of: view), !id.isEmpty {
            return false
        }
        if let label = view.accessibilityLabel, !label.isEmpty {
            return false
        }
        if elementType(of: view) != "Other" {
            return false
        }
        return true
    }
    
    
    private static func children(of obj: NSObject) -> [NSObject] {
        if let elements = obj.accessibilityElements as? [NSObject], !elements.isEmpty {
            return elements
        }
        let count = obj.accessibilityElementCount()
        if count > 0, count != NSNotFound {
            return (0..<count).compactMap {
                obj.accessibilityElement(at: $0) as? NSObject
            }
        }
        if let view = obj as? UIView {
            return view.subviews.filter {
                !$0.isHidden && $0.alpha > 0.01
            }
        }
        return []
    }
    
    
    private static func dump(_ obj: NSObject, depth: Int, into out: inout String) {
        let isTransparentContainer = isTransparentContainer(obj)
        if !isTransparentContainer {
            out += line(for: obj, depth: depth) + "\n"
        }
        for child in children(of: obj) {
            dump(child, depth: isTransparentContainer ? depth : depth + 1, into: &out)
        }
    }
    
    
    static func dumpAll() -> String {
        enableAXRuntime()
        let appLabel = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ""
        var out = "Application, pid: \(ProcessInfo.processInfo.processIdentifier), label: '\(appLabel)'\n"
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows where !window.isHidden {
                dump(window, depth: 1, into: &out)
            }
        }
        return out
    }
}
