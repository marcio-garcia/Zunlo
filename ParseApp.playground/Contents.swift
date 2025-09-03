import Foundation


func extractDates(text: String) {
    let ns = text as NSString
    
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    guard let matches = detector?.matches(in: text, range: NSRange(location: 0, length: ns.length)) else { return }
    
    for match in matches {
        print("resultType: \(match.resultType)")
        if match.resultType == .date {
            print("dur: \(match.duration)")
            print("date: \(match.date)")
        }
    }
}

extractDates(text: "semana")
