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


/// Intended to be declared as a static property somewhere.
final class ScoreDefinition: Hashable, Sendable, AnyObjectBasedDefaultImpls {
    enum Variant: Sendable {
        case distinctMapping(default: Double, elements: [Element])
        case range(Range<Double>)
        case custom(@Sendable (Any) -> Double, textualRepresentation: String)
    }
    
    final class Element: Hashable, Sendable, AnyObjectBasedDefaultImpls { // not ideal but we need this to be a class so that it can be Hashable
        let score: Double
        let textualRepresentation: String
        private let matchImp: @Sendable (Any) -> Bool
        
        init<Input>(score: Double, textualRepresentation: String, _ matches: @escaping @Sendable (Input) -> Bool) {
            self.score = score
            self.textualRepresentation = textualRepresentation
            let matches = erasingClosureInputType(floatToIntHandlingRule: .allowRounding, matches)
            self.matchImp = { matches($0) ?? false }
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
    
    let variant: Variant
    
    init(`default`: Double, mapping: [Element]) {
        self.variant = .distinctMapping(default: `default`, elements: mapping)
    }
    
    /// Creates a ``ScoreDefinition`` that uses a custom closure to calculate score values.
    ///
    /// - parameter default: the score value that should be used for inputs that aren't compatible with the closure's input type.
    /// - parameter textualRepresentation: a textual description that will be used to explain the scoring rules in the app's UI.
    /// - parameter calcScore: closure that determines the score of an input.
    init<Input>(`default`: Double, textualRepresentation: String, _ calcScore: @Sendable @escaping (Input) -> Double) {
        let mapping = erasingClosureInputType(floatToIntHandlingRule: .allowRounding, calcScore)
        self.variant = .custom({ mapping($0) ?? `default` }, textualRepresentation: textualRepresentation)
    }
    
    init(range: Range<Double>) {
        self.variant = .range(range)
    }
    
    func apply(to value: some Any) -> Double {
        switch variant {
        case let .distinctMapping(`default`, elements):
            elements.first { $0.matches(value) }?.score ?? `default`
        case .range(let range):
            // we pipe our matching code through `erasingClosureInputType` so that it can also handle `Int` inputs.
            erasingClosureInputType(floatToIntHandlingRule: .allowRounding) { (value: Double) in
                if value < range.lowerBound {
                    0
                } else if value >= range.upperBound {
                    1
                } else {
                    value.distance(to: range.lowerBound) / range.upperBound.distance(to: range.lowerBound)
                }
            }(value) ?? 0
        case .custom(let calcScore, _):
            calcScore(value)
        }
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
