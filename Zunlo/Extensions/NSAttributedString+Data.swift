//
//  NSAttributedString+Data.swift
//  Zunlo
//
//  Created by Marcio Garcia on 9/3/25.
//

import Foundation

extension NSAttributedString {
    func toData() -> Data? {
        try? data(from: NSRange(location: 0, length: length),
                  documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    static func fromData(_ data: Data) -> NSAttributedString? {
        try? NSAttributedString(data: data,
                                options: [.documentType: NSAttributedString.DocumentType.rtf],
                                documentAttributes: nil)
    }
}
