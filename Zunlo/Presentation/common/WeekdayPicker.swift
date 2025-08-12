//
//  WeekdayPicker.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/5/25.
//

import SwiftUI

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    @State var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        HStack {
            ForEach(0..<7, id: \.self) { i in
                Button {
                    if selection.contains(i) {
                        selection.remove(i)
                    } else {
                        selection.insert(i)
                    }
                } label: {
                    Text(days[i])
                        .padding(6)
                        .background(selection.contains(i) ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.2))
                        .cornerRadius(6)
                        .foregroundColor(selection.contains(i) ? .white : .primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onAppear {
            days = getLocalizedWeekdayNames()
        }
    }
    
    private func getLocalizedWeekdayNames() -> [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE" // Use "EEE" for abbreviated weekday name
        dateFormatter.locale = Locale.current // Use the current device locale
        
        var weekdayNames = [String]()
        
        // Iterate through each day of the week (1 to 7, corresponding to Sunday to Saturday)
        for dayIndex in 1...7 {
            let dateComponents = DateComponents(calendar: .current, weekday: dayIndex) // Weekday 1 = Sunday
            if let date = Calendar.appDefault.date(from: dateComponents) {
                let weekdayName = dateFormatter.string(from: date)
                weekdayNames.append(weekdayName)
            }
        }
        
        return weekdayNames
    }
}
