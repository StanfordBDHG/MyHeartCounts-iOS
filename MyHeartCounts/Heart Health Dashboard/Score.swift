//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order type_contents_order

import Foundation
import SpeziLocalization
import SwiftUI


protocol ScoreDefinitionPatternRange<Bound>: RangeExpression, Sendable {
    override associatedtype Bound: Comparable
    
    var textualDescription: String { get }
    
    // the type system doesn't let us express "same type but with a different generic parameter"
    func map<NewBound: Comparable>(_ transform: (Bound) -> NewBound) -> any ScoreDefinitionPatternRange<NewBound>
}


/// Intended to be declared as a static property somewhere.
final class ScoreDefinition: Hashable, Sendable, AnyObjectBasedDefaultImpls {
    struct TextualExplainer: Sendable {
        final class Band: Sendable {
            enum Background: Sendable { // swiftlint:disable:this nesting
                case color(Color)
                case gradient(Gradient)
            }
            let leadingText: LocalizedStringResource?
            let trailingText: LocalizedStringResource?
            let background: Background
            init(
                leadingText: LocalizedStringResource,
                trailingText: LocalizedStringResource? = nil, // swiftlint:disable:this function_default_parameter_at_end
                background: Background
            ) {
                self.leadingText = leadingText
                self.trailingText = trailingText
                self.background = background
            }
            // periphery:ignore - API
            @_disfavoredOverload
            init(
                leadingText: LocalizedStringResource? = nil, // swiftlint:disable:this function_default_parameter_at_end
                trailingText: LocalizedStringResource,
                background: Background
            ) {
                self.leadingText = leadingText
                self.trailingText = trailingText
                self.background = background
            }
        }
        
        let headerText: LocalizedStringResource?
        let bands: [Band]
    }
    
    enum Variant: Sendable {
        case distinctMapping(default: Double, scoringBands: [ScoringBand], explainer: TextualExplainer)
        case range(Range<Double>, explainer: TextualExplainer)
        case custom(@Sendable (Any) -> Double, explainer: TextualExplainer)
    }
    
    final class ScoringBand: Hashable, Sendable, AnyObjectBasedDefaultImpls { // not ideal but we need this to be a class so that it can be Hashable
        let score: Double
        let explainerBand: TextualExplainer.Band
        private let matchImp: @Sendable (Any) -> Bool
        
        init<Input>(score: Double, explainerBand: TextualExplainer.Band, _ matches: @escaping @Sendable (Input) -> Bool) {
            self.score = score
            self.explainerBand = explainerBand
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
            explainer: LocalizedStringResource? = nil
        ) -> ScoreDefinition.ScoringBand {
            .init(
                score: score,
                explainerBand: .init(
                    leadingText: "\(explainer?.localizedString() ?? range.textualDescription)",
                    trailingText: "\(Int(score * 100).formatted(.number))",
                    background: .color(Gradient.redToGreen.color(at: score))
                )
            ) { input in
                range.contains(input)
            }
        }
        
        /// Creates a rule that matches numeric values against an integer range.
        static func inRange(
            _ range: some ScoreDefinitionPatternRange<Int>,
            score: Double,
            explainer: LocalizedStringResource? = nil
        ) -> ScoreDefinition.ScoringBand {
            let doubleRange = range.map(Double.init)
            return .inRange(doubleRange, score: score, explainer: explainer)
        }
        
        static func equal(
            to value: some Equatable & Sendable,
            score: Double,
            explainerBand: TextualExplainer.Band
        ) -> ScoreDefinition.ScoringBand {
            .init(score: score, explainerBand: explainerBand) { input in
                input == value
            }
        }
    }
    
    let variant: Variant
    
    
    // periphery:ignore:parameters `default` - false positive
    init(
        `default`: Double,
        scoringBands: [ScoringBand],
        explainerHeaderText: LocalizedStringResource? = nil
    ) {
        self.variant = .distinctMapping(
            default: `default`,
            scoringBands: scoringBands,
            explainer: .init(headerText: explainerHeaderText, bands: scoringBands.map(\.explainerBand))
        )
    }
    
    // periphery:ignore:parameters `default` - false positive
    /// Creates a ``ScoreDefinition`` that uses a custom closure to calculate score values.
    ///
    /// - parameter default: the score value that should be used for inputs that aren't compatible with the closure's input type.
    /// - parameter textualRepresentation: a textual description that will be used to explain the scoring rules in the app's UI.
    /// - parameter calcScore: closure that determines the score of an input.
    init<Input>(
        `default`: Double,
        explainer: TextualExplainer,
        _ calcScore: @Sendable @escaping (Input) -> Double
    ) {
        let mapping = erasingClosureInputType(floatToIntHandlingRule: .allowRounding, calcScore)
        self.variant = .custom({ mapping($0) ?? `default` }, explainer: explainer)
    }
    
    
    func apply(to value: some Any) -> Double {
        switch variant {
        case let .distinctMapping(`default`, elements, _):
            elements.first { $0.matches(value) }?.score ?? `default`
        case .range(let range, _):
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
    /// a user-visible title that explains the kind of this score result, e.g. "Most Recent Sample" or "Daily Average"
    let title: LocalizedStringResource
    let definition: ScoreDefinition
    let sampleType: MHCSampleType
    @MakeHashable var inputValue: (any Hashable & Sendable)?
    /// The ``sample`` value, normalized onto a `0...1` range, with `0` denoting "bad" and `1` denoting "good".
    let score: Double?
    /// The time range represented by this score result
    let timeRange: Range<Date>?
    
    init(
        _ title: LocalizedStringResource,
        sampleType: MHCSampleType,
        definition: ScoreDefinition,
        timeRange: Range<Date>? = nil
    ) {
        self.title = title
        self.definition = definition
        self.sampleType = sampleType
        self._inputValue = .init(wrappedValue: nil)
        self.score = nil
        self.timeRange = timeRange
    }
    
    // periphery:ignore - API
    init(
        _ title: LocalizedStringResource,
        sampleType: MHCSampleType,
        definition: ScoreDefinition,
        value: (any Hashable & Sendable)? = nil, // swiftlint:disable:this function_default_parameter_at_end
        score: Double,
        timeRange: Range<Date>
    ) {
        self.title = title
        self.sampleType = sampleType
        self.definition = definition
        self._inputValue = .init(wrappedValue: nil)
        self.score = score
        self.timeRange = timeRange
    }
    
    init(
        _ title: LocalizedStringResource,
        sampleType: MHCSampleType,
        value: some Hashable & Sendable,
        timeRange: Range<Date>,
        definition: ScoreDefinition
    ) {
        self.title = title
        self.definition = definition
        self.sampleType = sampleType
        self._inputValue = .init(wrappedValue: value)
        self.score = definition.apply(to: value)
        self.timeRange = timeRange
    }
    
    init<Sample: CVHScore.ComponentSampleProtocol>(
        _ title: LocalizedStringResource,
        sampleType: MHCSampleType,
        sample: Sample?,
        value: (Sample) -> (some Hashable & Sendable)?,
        definition: ScoreDefinition
    ) {
        if let sample, let value = value(sample) {
            self.init(title, sampleType: sampleType, value: value, timeRange: sample.timeRange, definition: definition)
        } else {
            self.init(title, sampleType: sampleType, definition: definition, timeRange: sample?.timeRange)
        }
    }
    
    init<Sample>(
        _ title: LocalizedStringResource,
        sampleType: MHCSampleType,
        timeRange: Range<Date>,
        input: Sample?,
        value: (Sample) -> (some Hashable & Sendable)?,
        definition: ScoreDefinition
    ) {
        if let input, let value = value(input) {
            self.init(title, sampleType: sampleType, value: value, timeRange: timeRange, definition: definition)
        } else {
            self.init(title, sampleType: sampleType, definition: definition, timeRange: timeRange)
        }
    }
    
    
//    func hash(into hasher: inout Hasher) {
//    }
}


extension LocalizedStringResource: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.key)
        hasher.combine(self.table)
        hasher.combine(self.bundle)
        hasher.combine(self.locale)
    }
}


extension LocalizedStringResource.BundleDescription: @retroactive Hashable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.main, .main):
            true
        case let (.forClass(lhs), .forClass(rhs)):
            ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
        case let (.atURL(lhs), .atURL(rhs)):
            lhs.absoluteURL.resolvingSymlinksInPath() == rhs.absoluteURL.resolvingSymlinksInPath()
        case (.main, .forClass), (.main, .atURL), (.forClass, .main), (.forClass, .atURL), (.atURL, .main), (.atURL, .forClass):
            false
        @unknown default:
            String(reflecting: lhs) == String(reflecting: rhs)
        }
    }
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .main:
            hasher.combine(0)
            hasher.combine(Bundle.main)
        case .forClass(let cls):
            hasher.combine(1)
            hasher.combine(ObjectIdentifier(cls))
        case .atURL(let url):
            hasher.combine(2)
            hasher.combine(url.absoluteURL.resolvingSymlinksInPath())
        @unknown default:
            hasher.combine(3)
            hasher.combine(String(reflecting: self))
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
