//
//  MetadataExtractionExample.swift
//  SmartParseKit
//
//  Example demonstrating enhanced NLP capabilities for metadata extraction
//

import Foundation
import SmartParseKit

// Example usage of the enhanced NLP system
func demonstrateMetadataExtraction() {
    let calendar = Calendar.current
    let pack = EnglishPack(calendar: calendar)
    let engine = IntentDetector()
    let parser = TemporalComposer(prefs: Preferences(calendar: calendar))

    let testInputs = [
        "Add tag home to pay bills tomorrow 8pm",
        "Book dinner for tomorrow 8pm with reminder 30 minutes before",
        "Create high priority meeting at office next Monday",
        "Schedule urgent task with tag work note: Call client about contract renewal",
        "Add tag personal location gym for workout session"
    ]

    print("🔍 Enhanced NLP Metadata Extraction Demo")
    print("=" * 50)

    for input in testInputs {
        print("\n📝 Input: '\(input)'")

        let (intent, temporalTokens, metadataTokens) = parser.parse(
            input,
            now: Date(),
            pack: pack,
            intentDetector: engine
        )

        print("🎯 Intent: \(intent)")
        print("⏰ Temporal Tokens: \(temporalTokens.count)")
        print("🏷️  Metadata Tokens:")

        for token in metadataTokens {
            switch token.kind {
            case .title(let confidence):
                print("   📋 Title: '\(token.text)' (confidence: \(String(format: "%.1f", confidence)))")
            case .tag(let name, let confidence):
                print("   🏷️  Tag: '\(name)' (confidence: \(String(format: "%.1f", confidence)))")
            case .priority(let level, let confidence):
                print("   ⚡ Priority: \(level.rawValue) (confidence: \(String(format: "%.1f", confidence)))")
            case .reminder(let trigger, let confidence):
                print("   ⏰ Reminder: \(trigger) (confidence: \(String(format: "%.1f", confidence)))")
            case .location(let name, let confidence):
                print("   📍 Location: '\(name)' (confidence: \(String(format: "%.1f", confidence)))")
            case .notes(let content, let confidence):
                print("   📝 Notes: '\(content)' (confidence: \(String(format: "%.1f", confidence)))")
            }
        }

        print("---")
    }

    print("\n✅ Demo completed! The system now recognizes:")
    print("  • Tags and labels")
    print("  • Priority levels")
    print("  • Reminder triggers")
    print("  • Location information")
    print("  • Additional notes")
    print("  • Clean title extraction")
}

// Usage examples for different input patterns
func showPatternExamples() {
    print("\n📚 Supported Pattern Examples:")
    print("=" * 40)

    let patterns = [
        ("Tags", [
            "tag work",
            "add tag home to",
            "with tag personal",
            "tagged as important",
            "tags: work,urgent"
        ]),
        ("Priority", [
            "high priority task",
            "urgent meeting",
            "set priority to medium",
            "mark as important"
        ]),
        ("Reminders", [
            "remind me 30 minutes before",
            "set reminder for 2 hours",
            "alert me at 9am"
        ]),
        ("Locations", [
            "at home",
            "in the office",
            "location: conference room",
            "meeting at downtown cafe"
        ]),
        ("Notes", [
            "note: bring documents",
            "comments: follow up required",
            "description: quarterly review meeting"
        ])
    ]

    for (category, examples) in patterns {
        print("\n\(category):")
        for example in examples {
            print("  • \(example)")
        }
    }
}

// Run the examples
demonstrateMetadataExtraction()
showPatternExamples()