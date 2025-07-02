//
//  DaySidebarView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/1/25.
//

import SwiftUI

struct DaySidebarView: View {
    let date: Date
    
    var body: some View {
        VStack {
            Text(weekdayString(from: date))
                .font(.caption)
            Text(dayString(from: date))
                .font(.title2)
        }
        .frame(width: 44) // Sidebar width
    }
    
    // Helpers
    private func weekdayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE" // e.g. "Mon"
        return formatter.string(from: date)
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d" // e.g. "3"
        return formatter.string(from: date)
    }
}

