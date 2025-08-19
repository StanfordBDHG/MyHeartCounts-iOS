//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import SpeziQuestionnaire


extension Foundation.Bundle {
    func localizedQuestionnaire(
        withName name: String,
        for locale: Locale,
        fallbackLocales: [Locale] = [.init(identifier: "en_US")]
    ) -> Questionnaire? {
        let locales = [locale].appending(contentsOf: fallbackLocales)
        for locale in locales {
            let identifier = String(locale.identifier(.icu).prefix(while: { $0 != "@" }))
            let filename = "\(name)_\(identifier)"
            guard let url = self.url(forResource: filename, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let questionnaire = try? JSONDecoder().decode(Questionnaire.self, from: data) else {
                logger.error("Failed to locate/load questionnaire '\(filename).json' in bundle")
                continue
            }
            return questionnaire
        }
        return nil
    }
}
