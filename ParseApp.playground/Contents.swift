import Foundation

let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)


let text = "domingo às 15:00."
let fullRange = NSRange(text.startIndex..., in: text)

detector.enumerateMatches(in: text, options: [], range: fullRange) { m, _, _ in
    guard let match = m, let date = match.date else { return }
    print(date)
    print(match.range)
}
