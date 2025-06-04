//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order type_contents_order

import Foundation
import SwiftUI


protocol ScoreDefinitionPatternRange<Bound>: RangeExpression, Sendable {
    override associatedtype Bound: Comparable
    
    var textualDescription: String { get }
    
    // the type system doesn't let us express "same type but with a different generic parameter"
    func map<NewBound: Comparable>(_ transform: (Bound) -> NewBound) -> any ScoreDefinitionPatternRange<NewBound>
}


struct ScoreDefinition: Hashable, Sendable {
    final class Element: Hashable, Sendable { // not idea but we need this to be a class so that it can be Hashable
        let score: Double
        let textualRepresentation: String
        private let matchImp: @Sendable (Any) -> Bool
        
        init<Input>(score: Double, textualRepresentation: String, _ matches: @escaping @Sendable (Input) -> Bool) {
            self.score = score
            self.textualRepresentation = textualRepresentation
            self.matchImp = { value in
                if let value = value as? Input {
                    return matches(value)
                } else if let intValue = value as? any BinaryInteger, let inputTy = Input.self as? any BinaryFloatingPoint.Type {
                    // if the input is an integer, but the predicate expects a FloatingPoint value, we perform a conversion
                    if let floatValue = inputTy.init(exactly: intValue) {
                        return matches(floatValue as! Input) // swiftlint:disable:this force_cast
                    } else {
                        return false
                    }
                } else if let floatValue = value as? any BinaryFloatingPoint, let inputTy = Input.self as? any BinaryInteger.Type {
                    // if the input is a FloatingPoint value, but the predicate expects an Integer,
                    // we check if the value can be losslessly converted, and if yes pass it to the predicate.
                    if let intValue: any BinaryInteger = inputTy.init(exactly: floatValue),
                       let floatValue2 = type(of: floatValue).init(exactly: intValue),
                       floatValue.isEqual(to: floatValue2) {
                        return matches(intValue as! Input) // swiftlint:disable:this force_cast
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            }
        }
        
        func matches(_ value: some Any) -> Bool {
            matchImp(value)
        }
        
        /// Creates a rule that matches numeric values against a floating point range.
        static func inRange(
            _ range: some ScoreDefinitionPatternRange<Double>,
            score: Double,
            textualRepresentation: String? = nil
        ) -> ScoreDefinition.Element {
            .init(score: score, textualRepresentation: textualRepresentation ?? range.textualDescription) { input in
                range.contains(input)
            }
        }
        
        /// Creates a rule that matches numeric values against an integer range.
        static func inRange(
            _ range: some ScoreDefinitionPatternRange<Int>,
            score: Double,
            textualRepresentation: String? = nil
        ) -> ScoreDefinition.Element {
            let doubleRange = range.map(Double.init)
            return .inRange(doubleRange, score: score, textualRepresentation: textualRepresentation ?? range.textualDescription)
        }
        
        static func equal(to value: some Equatable & Sendable, score: Double, textualRepresentation: String) -> ScoreDefinition.Element {
            .init(score: score, textualRepresentation: textualRepresentation) { input in
                input == value
            }
        }
    }
    
    let `default`: Double
    let mapping: [Element]
    
    init(`default`: Double, mapping: [Element]) {
        self.default = `default`
        self.mapping = mapping
    }
    
    func apply(to value: some Any) -> Double {
        mapping.first { $0.matches(value) }?.score ?? `default`
    }
}


extension ScoreDefinition.Element {
    static func == (lhs: ScoreDefinition.Element, rhs: ScoreDefinition.Element) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}


struct ScoreResult: Hashable, Sendable {
    let definition: ScoreDefinition
    let sampleType: MHCSampleType
    @MakeHashable var inputValue: (any Hashable & Sendable)?
    /// The ``sample`` value, normalized onto a `0...1` range, with `0` denoting "bad" and `1` denoting "good".
    let score: Double?
    /// The time range represented by this score result
    let timeRange: Range<Date>?
    
    init(sampleType: MHCSampleType, definition: ScoreDefinition) {
        self.definition = definition
        self.sampleType = sampleType
        self._inputValue = .init(wrappedValue: nil)
        self.score = nil
        self.timeRange = nil
    }
    
    init(
        sampleType: MHCSampleType,
        definition: ScoreDefinition,
        value: (any Hashable & Sendable)? = nil, // swiftlint:disable:this function_default_parameter_at_end
        score: Double,
        timeRange: Range<Date>
    ) {
        self.sampleType = sampleType
        self.definition = definition
        self._inputValue = .init(wrappedValue: nil)
        self.score = score
        self.timeRange = timeRange
    }
    
    init(sampleType: MHCSampleType, value: some Hashable & Sendable, timeRange: Range<Date>, definition: ScoreDefinition) {
        self.definition = definition
        self.sampleType = sampleType
        self._inputValue = .init(wrappedValue: value)
        self.score = definition.apply(to: value)
        self.timeRange = timeRange
    }
    
    init<Sample: CVHScore.ComponentSampleProtocol>(
        sampleType: MHCSampleType,
        sample: Sample?,
        value: (Sample) -> (some Hashable & Sendable)?,
        definition: ScoreDefinition
    ) {
        if let sample, let value = value(sample) {
            self.init(sampleType: sampleType, value: value, timeRange: sample.timeRange, definition: definition)
        } else {
            self.init(sampleType: sampleType, definition: definition)
        }
    }
}


extension Range: ScoreDefinitionPatternRange {
    var textualDescription: String {
        if let upperBound = upperBound as? any BinaryInteger { // Int-based range
            "\(lowerBound) – \(upperBound.advanced(by: -1))"
        } else {
            "\(self)"
        }
    }
    
    func map<NewBound: Comparable>(_ transform: (Bound) -> NewBound) -> any ScoreDefinitionPatternRange<NewBound> {
        transform(lowerBound)..<transform(upperBound)
    }
}


extension ClosedRange: ScoreDefinitionPatternRange {
    var textualDescription: String {
        "\(lowerBound) – \(upperBound)"
    }
    
    func map<NewBound: Comparable>(_ transform: (Bound) -> NewBound) -> any ScoreDefinitionPatternRange<NewBound> {
        transform(lowerBound)...transform(upperBound)
    }
}


extension PartialRangeFrom: ScoreDefinitionPatternRange {
    var textualDescription: String {
        "≥ \(lowerBound)"
    }
    
    func map<NewBound: Comparable>(_ transform: (Bound) -> NewBound) -> any ScoreDefinitionPatternRange<NewBound> {
        transform(lowerBound)...
    }
}


extension PartialRangeUpTo: ScoreDefinitionPatternRange {
    var textualDescription: String {
        "< \(upperBound)"
    }
    func map<NewBound: Comparable>(_ transform: (Bound) -> NewBound) -> any ScoreDefinitionPatternRange<NewBound> {
        ..<transform(upperBound)
    }
}


extension PartialRangeThrough: ScoreDefinitionPatternRange {
    var textualDescription: String {
        "≤ \(upperBound)"
    }
    func map<NewBound: Comparable>(_ transform: (Bound) -> NewBound) -> any ScoreDefinitionPatternRange<NewBound> {
        ...transform(upperBound)
    }
}
