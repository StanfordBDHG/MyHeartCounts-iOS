//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

enum ClosureInputErasureFloatToIntHandlingRule { // swiftlint:disable:this type_name
    /// For `BinaryFloatingPoint` input values passed to a type-erased closure expecting a `BinaryInteger` value,
    /// we only allow the conversion if the input value can be losslessly represented in the destination `BinaryInteger` type.
    case requireLosslessConversion
    /// For `BinaryFloatingPoint` input values passed to a type-erased closure expecting a `BinaryInteger` value,
    /// we simply convert to the closest representation in the destination `BinaryInteger` type, possibly rounding towards zero if required.
    case allowRounding
}

/// Erases a closure's input type, in a way that allows calling it with values of other, related types that can be converted into the original input type.
///
/// You can use this function to turn a `(Double) -> T` into an `(Any) -> T` that can be called with inputs of type `Double`, `Float`, `Int`, `UInt`, etc.
/// If the closure returned by this function is called with an input value of a type that cannot be trivially converted into the closure's actual input type, it returns `nil`.
///
/// - parameter floatToIntRounding: the allowed behaviour when attempting to convert `BinaryFloatingPoint` inputs into `BinaryInteger` values.
///     Specify `nil` to disallow rounding and require that the value always have an exact representation in the target type.
func erasingClosureInputType<Input, Result>( // swiftlint:disable:this cyclomatic_complexity
    floatToIntHandlingRule: ClosureInputErasureFloatToIntHandlingRule,
    _ closure: @escaping @Sendable (Input) -> Result
) -> @Sendable (Any) -> Result? {
    { value in // swiftlint:disable:this closure_body_length
        if let value = value as? Input {
            closure(value)
        } else if let intValue = value as? any BinaryInteger,
                  let inputTy = Input.self as? any BinaryInteger.Type { // int -> int
            if let inputValue = inputTy.init(exactly: intValue) {
                closure(inputValue as! Input) // swiftlint:disable:this force_cast
            } else {
                nil
            }
        } else if let floatValue = value as? any BinaryFloatingPoint,
                  let inputTy = Input.self as? any BinaryFloatingPoint.Type { // float -> float
            if let inputValue = inputTy.init(exactly: floatValue) {
                closure(inputValue as! Input) // swiftlint:disable:this force_cast
            } else {
                nil
            }
        } else if let intValue = value as? any BinaryInteger,
                  let inputTy = Input.self as? any BinaryFloatingPoint.Type { // int -> float
            // if the input is an integer, but the predicate expects a FloatingPoint value, we perform a conversion
            if let floatValue = inputTy.init(exactly: intValue) {
                closure(floatValue as! Input) // swiftlint:disable:this force_cast
            } else {
                nil
            }
        } else if let floatValue = value as? any BinaryFloatingPoint,
                  let inputTy = Input.self as? any BinaryInteger.Type { // float -> int
            switch floatToIntHandlingRule {
            case .requireLosslessConversion:
                // if the input is a FloatingPoint value, but the predicate expects an Integer,
                // we check if the value can be losslessly converted, and if yes pass it to the predicate.
                if let intValue: any BinaryInteger = inputTy.init(exactly: floatValue),
                   let floatValue2 = type(of: floatValue).init(exactly: intValue),
                   floatValue.isEqual(to: floatValue2) {
                    closure(intValue as! Input) // swiftlint:disable:this force_cast
                } else {
                    nil
                }
            case .allowRounding:
                closure(inputTy.init(floatValue) as! Input) // swiftlint:disable:this force_cast
            }
        } else {
            nil
        }
    }
}
