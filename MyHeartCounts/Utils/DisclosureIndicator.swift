//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import class UIKit.UIColor
import class UIKit.UIFont


struct DisclosureIndicator: View {
    var body: some View {
        Image(systemSymbol: .chevronForward)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(Color.disclosureIndicator)
            .font(Font(UIFont.preferredFont(forTextStyle: .emphasizedBody) as CTFont))
            .imageScale(.small)
            .accessibilityLabel("Disclosure Indicator")
    }
}

extension UIFont.TextStyle {
    static let emphasizedBody = Self(rawValue: "UICTFontTextStyleEmphasizedBody")
}


extension UIColor {
    // not perfect (ideally we'd use one of the system colors, where we know that it's the same as what UIKit uses),
    // but close enough
    static let disclosureIndicator = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 84 / 255, green: 84 / 255, blue: 86 / 255, alpha: 1) // swiftlint:disable:this object_literal
        case .light, .unspecified:
            fallthrough
        @unknown default:
            return UIColor(red: 187 / 255, green: 187 / 255, blue: 187 / 255, alpha: 1) // swiftlint:disable:this object_literal
        }
    }
}


extension Color {
    static let disclosureIndicator = Color(uiColor: .disclosureIndicator)
}
