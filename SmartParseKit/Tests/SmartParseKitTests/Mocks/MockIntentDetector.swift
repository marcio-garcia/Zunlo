//
//  MockIntentDetector.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/14/25.
//

import Foundation
import NaturalLanguage
@testable import SmartParseKit

class MockIntentDetector: IntentDetector {
    
    var languge: NLLanguage
    var intent: SmartParseKit.Intent
    
    init(languge: NLLanguage, intent: SmartParseKit.Intent) {
        self.languge = languge
        self.intent = intent
    }
    
    func detectLanguage(_ text: String) -> NLLanguage {
        return languge
    }

    func classify(_ text: String) -> SmartParseKit.Intent {
        return intent
    }
}
