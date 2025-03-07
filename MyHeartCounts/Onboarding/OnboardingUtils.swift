//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


import SpeziFoundation
import SpeziOnboarding
import SwiftUI


private struct WithKeyPathBasedEnvironmentVariableWrapper<Value, Body: View>: View {
    @Environment private var value: Value
    private let makeBody: @MainActor (Value) -> Body
    
    var body: Body {
        makeBody(value)
    }
    
    init(_ keyPath: KeyPath<EnvironmentValues, Value>, makeBody: @MainActor @escaping (Value) -> Body) {
        self._value = .init(keyPath)
        self.makeBody = makeBody
    }
}


private struct WithTypeBasedEnvironmentVariableWrapper<Value: AnyObject & Observable, Body: View>: View {
    @Environment private var value: Value
    private let makeBody: @MainActor (Value) -> Body
    
    var body: Body {
        makeBody(value)
    }
    
    init(_ type: Value.Type, makeBody: @MainActor @escaping (Value) -> Body) {
        self._value = .init(type)
        self.makeBody = makeBody
    }
}


private struct WithOptionalTypeBasedEnvironmentVariableWrapper<Value: AnyObject & Observable, Body: View>: View {
    @Environment private var value: Value?
    private let makeBody: @MainActor (Value?) -> Body
    
    var body: Body {
        makeBody(value)
    }
    
    init(_ type: Value.Type, makeBody: @MainActor @escaping (Value?) -> Body) {
        self._value = .init(type)
        self.makeBody = makeBody
    }
}


@MainActor
func withEnvironmentValue<Value>(
    _ keyPath: KeyPath<EnvironmentValues, Value>,
    @ViewBuilder _ makeBody: @MainActor @escaping (Value) -> some View
) -> some View {
    WithKeyPathBasedEnvironmentVariableWrapper(keyPath, makeBody: makeBody)
}


@MainActor
func withEnvironmentValue<Value: AnyObject & Observable>(
    _ type: Value.Type,
    @ViewBuilder _ makeBody: @MainActor @escaping (Value) -> some View
) -> some View {
    WithTypeBasedEnvironmentVariableWrapper(type, makeBody: makeBody)
}


@MainActor
func withEnvironmentValue<Value: AnyObject & Observable, Body: View>(
    _: Value?.Type,
    @ViewBuilder _ makeBody: @MainActor @escaping (Value?) -> Body
) -> some View {
    WithOptionalTypeBasedEnvironmentVariableWrapper<Value, Body>(Value.self, makeBody: makeBody)
}


@MainActor
func withOnboardingStackPath<Body: View>(@ViewBuilder _ makeContent: @MainActor @escaping (OnboardingNavigationPath) -> Body) -> some View {
    withEnvironmentValue(OnboardingNavigationPath.self, makeContent)
}
