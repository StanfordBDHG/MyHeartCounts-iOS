//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


/// A result builder that constructs an instance of a `RangeReplaceableCollection`.
@resultBuilder
protocol RangeReplaceableCollectionBuilderBase {
    associatedtype Element = IntermediateStep.Element
    associatedtype IntermediateStep: RangeReplaceableCollection<Element> = Array<Element>
//    associatedtype Result
//    /// The `Element` of the `RangeReplaceableCollection` that will be built up.
//    typealias Element = C.Element
}


extension RangeReplaceableCollectionBuilderBase {
    
    /// :nodoc:
    @inlinable
    static func buildExpression(_ expression: Element) -> IntermediateStep {
        IntermediateStep(CollectionOfOne(expression))
    }
    
    /// :nodoc:
    @inlinable
    static func buildExpression(_ expression: IntermediateStep) -> IntermediateStep {
        expression
    }
    
    /// :nodoc:
    @inlinable
    static func buildExpression(_ expression: some Sequence<Element>) -> IntermediateStep {
        IntermediateStep(expression)
    }
    
    /// :nodoc:
    @inlinable
    static func buildOptional(_ component: IntermediateStep?) -> IntermediateStep {
        component ?? IntermediateStep()
    }
    
    /// :nodoc:
    @inlinable
    static func buildEither(first component: IntermediateStep) -> IntermediateStep {
        component
    }
    
    /// :nodoc:
    @inlinable
    static func buildEither(second component: IntermediateStep) -> IntermediateStep {
        component
    }
    
    /// :nodoc:
    @inlinable
    static func buildPartialBlock(first: IntermediateStep) -> IntermediateStep {
        first
    }
    
    /// :nodoc:
    @inlinable
    static func buildPartialBlock(accumulated: IntermediateStep, next: IntermediateStep) -> IntermediateStep {
        accumulated + next
    }
    
    /// :nodoc:
    @inlinable
    static func buildBlock() -> IntermediateStep {
        IntermediateStep()
    }
    
    /// :nodoc:
    @inlinable
    static func buildArray(_ components: [IntermediateStep]) -> IntermediateStep {
        components.reduce(into: IntermediateStep()) { $0.append(contentsOf: $1) }
    }
    
    /// :nodoc:
    @inlinable
    static func buildLimitedAvailability(_ component: IntermediateStep) -> IntermediateStep {
        component
    }
}
