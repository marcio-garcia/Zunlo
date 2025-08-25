//
//  MarkdownConverter.swift
//  ZunloHelpers
//
//  Created by Marcio Garcia on 8/25/25.
//

import SwiftUI

public struct MarkdownConverterConfig {
    public var heading1Font: Font
    public var heading2Font: Font
    public var heading3Font: Font
    public var bodyFont: Font
    public var boldFont: Font
    public var codeFont: Font
    public var codeBackgroundColor: Color
    public var linkColor: Color
    
    public init(
        heading1Font: Font = .largeTitle.bold(),
        heading2Font: Font = .title.bold(),
        heading3Font: Font = .title2.bold(),
        bodyFont: Font = .body,
        boldFont: Font = .bold(.body)(),
        codeFont: Font = .system(.body, design: .monospaced),
        codeBackgroundColor: Color = Color.gray.opacity(0.15),
        linkColor: Color = .blue
    ) {
        self.heading1Font = heading1Font
        self.heading2Font = heading2Font
        self.heading3Font = heading3Font
        self.bodyFont = bodyFont
        self.boldFont = boldFont
        self.codeFont = codeFont
        self.codeBackgroundColor = codeBackgroundColor
        self.linkColor = linkColor
    }
}

public struct MarkdownConverter {
    
    public static func convertToAttributedString(_ markdown: String, config: MarkdownConverterConfig = MarkdownConverterConfig()) -> AttributedString {
        var attributedString = AttributedString()
        
        let lines = markdown.components(separatedBy: .newlines)
        var i = 0
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage = ""
        
        while i < lines.count {
            let line = lines[i]
            
            // Handle code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End of code block
                    let codeBlock = createCodeBlock(codeBlockContent, language: codeBlockLanguage, config: config)
                    attributedString.append(codeBlock)
                    attributedString.append(AttributedString("\n"))
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                    inCodeBlock = false
                } else {
                    // Start of code block
                    codeBlockLanguage = String(line.dropFirst(3).trimmingCharacters(in: .whitespaces))
                    inCodeBlock = true
                }
                i += 1
                continue
            }
            
            if inCodeBlock {
                codeBlockContent += line + "\n"
                i += 1
                continue
            }
            
            // Handle headings
            if line.hasPrefix("# ") {
                let heading = createHeading(String(line.dropFirst(2)), level: 1, config: config)
                attributedString.append(heading)
                attributedString.append(AttributedString("\n"))
            } else if line.hasPrefix("## ") {
                let heading = createHeading(String(line.dropFirst(3)), level: 2, config: config)
                attributedString.append(heading)
                attributedString.append(AttributedString("\n"))
            } else if line.hasPrefix("### ") {
                let heading = createHeading(String(line.dropFirst(4)), level: 3, config: config)
                attributedString.append(heading)
                attributedString.append(AttributedString("\n"))
            }
            // Handle list items
            else if line.hasPrefix("- ") {
                let listItem = createListItem(String(line.dropFirst(2)), config: config)
                attributedString.append(listItem)
                
                // Check if next line is a continuation (indented)
                if i + 1 < lines.count && lines[i + 1].hasPrefix("  ") && !lines[i + 1].trimmingCharacters(in: .whitespaces).isEmpty {
                    attributedString.append(AttributedString("\n"))
                    i += 1
                    let continuation = processInlineFormatting(lines[i].trimmingCharacters(in: .whitespaces), config: config)
                    var continuationString = AttributedString("  ")
                    continuationString.append(continuation)
                    attributedString.append(continuationString)
                }
                attributedString.append(AttributedString("\n"))
            }
            // Handle empty lines (paragraph breaks)
            else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                // Only add paragraph break if we're not already at the end of a block
                if !attributedString.characters.isEmpty {
                    attributedString.append(AttributedString("\n"))
                }
            }
            // Handle regular paragraphs
            else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let paragraph = processInlineFormatting(line, config: config)
                attributedString.append(paragraph)
                
                // Check if next line is not empty and not a special formatting line
                if i + 1 < lines.count {
                    let nextLine = lines[i + 1]
                    if !nextLine.trimmingCharacters(in: .whitespaces).isEmpty &&
                       !nextLine.hasPrefix("#") &&
                       !nextLine.hasPrefix("- ") &&
                       !nextLine.hasPrefix("```") {
                        // Soft break
                        attributedString.append(AttributedString("\n"))
                    } else if nextLine.trimmingCharacters(in: .whitespaces).isEmpty {
                        // Hard break (paragraph)
                        attributedString.append(AttributedString("\n"))
                    }
                }
            }
            
            i += 1
        }
        
        return attributedString
    }
    
    static func createHeading(_ text: String, level: Int, config: MarkdownConverterConfig) -> AttributedString {
        var attributedString = AttributedString(text)
        
        switch level {
        case 1:
            attributedString.font = config.heading1Font
        case 2:
            attributedString.font = config.heading2Font
        case 3:
            attributedString.font = config.heading3Font
        default:
            attributedString.font = config.heading3Font
        }
        
        return attributedString
    }
    
    static func createListItem(_ text: String, config: MarkdownConverterConfig) -> AttributedString {
        var attributedString = AttributedString("• ")
        let processedText = processInlineFormatting(text, config: config)
        attributedString.append(processedText)
        return attributedString
    }
    
    static func createCodeBlock(_ code: String, language: String, config: MarkdownConverterConfig) -> AttributedString {
        var attributedString = AttributedString(code.trimmingCharacters(in: .newlines))
        attributedString.font = config.codeFont
        attributedString.backgroundColor = config.codeBackgroundColor
        attributedString.foregroundColor = Color.primary
        return attributedString
    }
    
    static func processInlineFormatting(_ text: String, config: MarkdownConverterConfig) -> AttributedString {
        let result = processAllInlineFormatting(text, config: config)
        return result
    }
    
    static func processAllInlineFormatting(_ text: String, config: MarkdownConverterConfig) -> AttributedString {
        var result = AttributedString()
        let remainingText = text
        var processedUpTo = remainingText.startIndex
        
        while processedUpTo < remainingText.endIndex {
            var foundMatch = false
            var earliestRange: Range<String.Index>? = nil
            var matchType = ""
            
            // Find the earliest match among all patterns
            
            // Check for inline code `code`
            if let codeRange = remainingText.range(of: "`([^`]+)`", options: .regularExpression, range: processedUpTo..<remainingText.endIndex) {
                if earliestRange == nil || codeRange.lowerBound < earliestRange!.lowerBound {
                    earliestRange = codeRange
                    matchType = "code"
                }
            }
            
            // Check for links [text](url)
            if let linkRange = remainingText.range(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", options: .regularExpression, range: processedUpTo..<remainingText.endIndex) {
                if earliestRange == nil || linkRange.lowerBound < earliestRange!.lowerBound {
                    earliestRange = linkRange
                    matchType = "link"
                }
            }
            
            // Check for **bold**
            if let boldRange = remainingText.range(of: "\\*\\*([^*]+)\\*\\*", options: .regularExpression, range: processedUpTo..<remainingText.endIndex) {
                if earliestRange == nil || boldRange.lowerBound < earliestRange!.lowerBound {
                    earliestRange = boldRange
                    matchType = "bold"
                }
            }
            
            // Check for _underlined_
            if let underlineRange = remainingText.range(of: "_([^_]+)_", options: .regularExpression, range: processedUpTo..<remainingText.endIndex) {
                if earliestRange == nil || underlineRange.lowerBound < earliestRange!.lowerBound {
                    earliestRange = underlineRange
                    matchType = "underline"
                }
            }
            
            // Check for ~~strikethrough~~
            if let strikeRange = remainingText.range(of: "~~([^~]+)~~", options: .regularExpression, range: processedUpTo..<remainingText.endIndex) {
                if earliestRange == nil || strikeRange.lowerBound < earliestRange!.lowerBound {
                    earliestRange = strikeRange
                    matchType = "strike"
                }
            }
            
            if let matchRange = earliestRange {
                // Add text before the match
                if processedUpTo < matchRange.lowerBound {
                    let beforeText = String(remainingText[processedUpTo..<matchRange.lowerBound])
                    var plainText = AttributedString(beforeText)
                    plainText.font = config.bodyFont
                    result.append(plainText)
                }
                
                // Process the match based on type
                let fullMatch = String(remainingText[matchRange])
                
                switch matchType {
                case "code":
                    let codeContent = String(fullMatch.dropFirst().dropLast()) // Remove backticks
                    var codeAttributed = AttributedString(codeContent)
                    codeAttributed.font = config.codeFont
                    codeAttributed.backgroundColor = config.codeBackgroundColor
                    result.append(codeAttributed)
                    
                case "link":
                    if let textMatch = fullMatch.range(of: "\\[([^\\]]+)\\]", options: .regularExpression),
                       let urlMatch = fullMatch.range(of: "\\(([^)]+)\\)", options: .regularExpression) {
                        
                        let linkText = String(fullMatch[textMatch]).dropFirst().dropLast()
                        let linkURL = String(fullMatch[urlMatch]).dropFirst().dropLast()
                        
                        var linkAttributed = AttributedString(String(linkText))
                        if let url = URL(string: String(linkURL)) {
                            linkAttributed.link = url
                        }
                        linkAttributed.foregroundColor = config.linkColor
                        linkAttributed.underlineStyle = .single
                        
                        result.append(linkAttributed)
                    }
                    
                case "bold":
                    let boldText = String(fullMatch.dropFirst(2).dropLast(2))
                    var boldAttributed = AttributedString(boldText)
                    boldAttributed.font = config.boldFont
                    result.append(boldAttributed)
                    
                case "underline":
                    let underlinedText = String(fullMatch.dropFirst().dropLast())
                    var underlinedAttributed = AttributedString(underlinedText)
                    underlinedAttributed.underlineStyle = .single
                    result.append(underlinedAttributed)
                    
                case "strike":
                    let strikeText = String(fullMatch.dropFirst(2).dropLast(2))
                    var strikeAttributed = AttributedString(strikeText)
                    strikeAttributed.strikethroughStyle = .single
                    result.append(strikeAttributed)
                    
                default:
                    break
                }
                
                processedUpTo = matchRange.upperBound
                foundMatch = true
            }
            
            // If no matches found, we've processed all formatting
            if !foundMatch {
                break
            }
        }
        
        // Add any remaining unprocessed text
        if processedUpTo < remainingText.endIndex {
            let remainingString = String(remainingText[processedUpTo...])
            var plainText = AttributedString(remainingString)
            plainText.font = config.bodyFont
            result.append(plainText)
        }
        
        return result
    }
}
