import Foundation

// MARK: - Temporal Context

public struct TemporalContext {
    public let finalDate: Date
    public let finalDateDuration: TimeInterval?
    public let dateRange: DateInterval? // For queries that imply a range
    public let confidence: Float // 0.0 to 1.0
    public let resolvedTokens: [TemporalToken]
    public let conflicts: [String] // Descriptions of any conflicts found
    public let isRangeQuery: Bool // True for queries like "next week" that imply a range
    
    public init(finalDate: Date, finalDateDuration: TimeInterval? = nil, dateRange: DateInterval? = nil, confidence: Float, resolvedTokens: [TemporalToken], conflicts: [String] = [], isRangeQuery: Bool = false) {
        self.finalDate = finalDate
        self.finalDateDuration = finalDateDuration
        self.dateRange = dateRange
        self.confidence = confidence
        self.resolvedTokens = resolvedTokens
        self.conflicts = conflicts
        self.isRangeQuery = isRangeQuery
    }
}

// MARK: - Token Interpreter

public class TemporalTokenInterpreter {
    private let calendar: Calendar
    private let timeZone: TimeZone
    private let referenceDate: Date
    
    public init(calendar: Calendar = Calendar.current, timeZone: TimeZone = TimeZone.current, referenceDate: Date = Date()) {
        self.calendar = calendar
        self.timeZone = timeZone
        self.referenceDate = referenceDate
    }
    
    // MARK: - Main Interpretation Method
    
    public func interpret(_ tokens: [TemporalToken]) -> TemporalContext {
        guard !tokens.isEmpty else {
            return TemporalContext(finalDate: referenceDate, confidence: 0.0, resolvedTokens: [])
        }
        
        // Sort tokens by priority (highest first)
        let sortedTokens = tokens.sorted { $0.tokenPriority() > $1.tokenPriority() }
        
        // Group tokens by type for easier processing
        let tokenGroups = groupTokens(sortedTokens)
        
        // Resolve conflicts and build context
        let (resolvedComponents, duration, conflicts) = resolveTokens(tokenGroups)
        
        // Build final date
        let finalDate = buildFinalDate(from: resolvedComponents)
        
        // Check if this is a range query and build date range if needed
        let (dateRange, isRangeQuery) = buildDateRange(from: tokenGroups, baseDate: finalDate)
        
        // Calculate confidence based on conflicts and token quality
        let confidence = calculateConfidence(tokens: sortedTokens, conflicts: conflicts)
        
        return TemporalContext(
            finalDate: finalDate,
            finalDateDuration: duration,
            dateRange: dateRange,
            confidence: confidence,
            resolvedTokens: sortedTokens,
            conflicts: conflicts,
            isRangeQuery: isRangeQuery
        )
    }
    
    // MARK: - Token Grouping
    
    private func groupTokens(_ tokens: [TemporalToken]) -> TokenGroups {
        var groups = TokenGroups()
        
        for token in tokens {
            switch token.kind {
            case .absoluteDate(let components):
                groups.absoluteDates.append((token, components))
            case .absoluteTime(let components):
                groups.absoluteTimes.append((token, components))
            case .timeRange(let start, let end):
                groups.timeRanges.append((token, start, end))
            case .weekday(let dayIndex, let modifier):
                groups.weekdays.append((token, dayIndex, modifier))
            case .relativeDay(let relativeDay):
                groups.relativeDays.append((token, relativeDay))
            case .relativeWeek(let weekSpec):
                groups.relativeWeeks.append((token, weekSpec))
            case .weekend(let weekSpec):
                groups.weekends.append((token, weekSpec))
            case .partOfDay(let partOfDay):
                groups.partsOfDay.append((token, partOfDay))
            case .ordinalDay(let day):
                groups.ordinalDays.append((token, day))
            case .durationOffset(let value, let unit, let mode):
                groups.durationOffsets.append((token, value, unit, mode))
            case .connector:
                groups.connectors.append(token)
            }
        }
        
        return groups
    }
    
    // MARK: - Token Resolution
    
    private func resolveTokens(_ groups: TokenGroups) -> (DateComponents, TimeInterval?, [String]) {
        var resolvedComponents = DateComponents()
        var duration: TimeInterval?
        var conflicts: [String] = []
        
        // Start with reference date as base
        let baseComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: referenceDate)
        resolvedComponents.year = baseComponents.year
        resolvedComponents.month = baseComponents.month
        resolvedComponents.day = baseComponents.day
        resolvedComponents.hour = baseComponents.hour
        resolvedComponents.minute = baseComponents.minute
        resolvedComponents.second = 0
        resolvedComponents.timeZone = timeZone
        
        // Process in order of priority and dependency
        
        // 1. Handle time ranges first (highest priority)
        if let timeRange = groups.timeRanges.first {
            resolvedComponents.hour = timeRange.1.hour
            resolvedComponents.minute = timeRange.1.minute
            duration = try? secondsBetween(timeRange.1, timeRange.2)
        }
        
        // 2. Handle absolute times
        else if !groups.absoluteTimes.isEmpty {
            // Handle conflicts in absolute times
            if groups.absoluteTimes.count > 1 {
                conflicts.append("Multiple time specifications found")
                // Use the last one (highest priority by position)
            }
            
            if let absoluteTime = groups.absoluteTimes.last {
                resolvedComponents.hour = absoluteTime.1.hour
                resolvedComponents.minute = absoluteTime.1.minute
            }
        }
        
        // 3. Handle parts of day
        else if !groups.partsOfDay.isEmpty {
            if let partOfDay = groups.partsOfDay.first {
                let timeComponents = timeComponentsForPartOfDay(partOfDay.1)
                resolvedComponents.hour = timeComponents.hour
                resolvedComponents.minute = timeComponents.minute
            }
        }
        
        // 4. Handle date components
        
        // Check for absolute dates first
        if let absoluteDate = groups.absoluteDates.first {
            resolvedComponents.year = absoluteDate.1.year ?? resolvedComponents.year
            resolvedComponents.month = absoluteDate.1.month ?? resolvedComponents.month
            resolvedComponents.day = absoluteDate.1.day ?? resolvedComponents.day
            
            // If absolute date has time components, use them if no time was set above
            if resolvedComponents.hour == baseComponents.hour && resolvedComponents.minute == baseComponents.minute {
                resolvedComponents.hour = absoluteDate.1.hour ?? resolvedComponents.hour
                resolvedComponents.minute = absoluteDate.1.minute ?? resolvedComponents.minute
            }
        }
        
        // Handle relative days
        else if !groups.relativeDays.isEmpty {
            if let relativeDay = groups.relativeDays.first {
                let dayOffset = offsetForRelativeDay(relativeDay.1)
                if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate) {
                    let targetComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                    resolvedComponents.year = targetComponents.year
                    resolvedComponents.month = targetComponents.month
                    resolvedComponents.day = targetComponents.day
                }
            }
        }
        
        // Handle ordinal days
        else if !groups.ordinalDays.isEmpty {
            if let ordinalDay = groups.ordinalDays.first {
                resolvedComponents.day = ordinalDay.1
            }
        }
        
        // Handle weekends
        else if !groups.weekends.isEmpty {
            if let weekend = groups.weekends.first {
                let weekSpec = weekend.1 ?? .thisWeek
                let saturdayDate = getWeekendDate(for: weekSpec)
                let saturdayComponents = calendar.dateComponents([.year, .month, .day], from: saturdayDate)
                resolvedComponents.year = saturdayComponents.year
                resolvedComponents.month = saturdayComponents.month
                resolvedComponents.day = saturdayComponents.day
            }
        }
        
        // Handle relative weeks and weekdays
        else if !groups.relativeWeeks.isEmpty || !groups.weekdays.isEmpty {
            resolvedComponents = handleRelativeWeeksAndWeekdays(
                groups: groups,
                baseComponents: resolvedComponents,
                conflicts: &conflicts
            )
        }

        
        return (resolvedComponents, duration, conflicts)
    }
    
    // MARK: - Helper Methods
    
    private func handleRelativeWeeksAndWeekdays(groups: TokenGroups, baseComponents: DateComponents, conflicts: inout [String]) -> DateComponents {
        var components = baseComponents
        
        // Determine the target week
        var weekOffset = 0
        if let relativeWeek = groups.relativeWeeks.first {
            switch relativeWeek.1 {
            case .thisWeek:
                weekOffset = 0
            case .nextWeek(let count):
                weekOffset = count
            case .lastWeek(let count):
                weekOffset = -count
            }
        }
        
        // Determine the target weekday
        if let weekday = groups.weekdays.first {
            var targetWeekOffset = weekOffset
            
            // Handle weekday modifiers
            if let modifier = weekday.2 {
                switch modifier {
                case .next:
                    targetWeekOffset = max(1, weekOffset) // At least next week
                case .last:
                    targetWeekOffset = min(-1, weekOffset) // At least last week
                case .this:
                    targetWeekOffset = 0
                }
            }
            
            // Calculate target date
            if let targetDate = getDateForWeekday(weekday.1, weekOffset: targetWeekOffset) {
                let targetComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.year = targetComponents.year
                components.month = targetComponents.month
                components.day = targetComponents.day
            }
        } else if weekOffset != 0 {
            // Only relative week specified, use same weekday as reference
            let referenceWeekday = calendar.component(.weekday, from: referenceDate)
            if let targetDate = getDateForWeekday(referenceWeekday, weekOffset: weekOffset) {
                let targetComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.year = targetComponents.year
                components.month = targetComponents.month
                components.day = targetComponents.day
            }
        }
        
        return components
    }
    
    private func getDateForWeekday(_ weekdayIndex: Int, weekOffset: Int) -> Date? {
        // Convert weekday index to Calendar weekday (1 = Sunday, 2 = Monday, etc.)
//        let calendarWeekday = (weekdayIndex == 7) ? 1 : weekdayIndex + 1
        let calendarWeekday = weekdayIndex
        
        // Get current weekday
        let currentWeekday = calendar.component(.weekday, from: referenceDate)
        
        // Calculate days to add
        var daysToAdd = calendarWeekday - currentWeekday
        if weekOffset > 0 {
//            if daysToAdd <= 0 {
//                daysToAdd += 7
//            }
//            daysToAdd += (weekOffset - 1) * 7
            daysToAdd += weekOffset * 7
        } else if weekOffset < 0 {
//            if daysToAdd >= 0 {
//                daysToAdd -= 7
//            }
//            daysToAdd += (weekOffset + 1) * 7
            daysToAdd += weekOffset * 7
        } else if daysToAdd < 0 {
            daysToAdd += 7 // This week, but the day hasn't passed yet
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: referenceDate)
    }
    
    private func getWeekendDate(for weekSpec: WeekSpecifier) -> Date {
        let weekOffset = weekOffsetForSpecifier(weekSpec)
        // Get Saturday of the target week
        return getDateForWeekday(7, weekOffset: weekOffset) ?? referenceDate // 7 = Saturday
    }
    
    private func weekOffsetForSpecifier(_ weekSpec: WeekSpecifier) -> Int {
        switch weekSpec {
        case .thisWeek:
            return 0
        case .nextWeek(let count):
            return count
        case .lastWeek(let count):
            return -count
        }
    }
    
    private func offsetForRelativeDay(_ relativeDay: RelativeDay) -> Int {
        switch relativeDay {
        case .today, .tonight:
            return 0
        case .tomorrow:
            return 1
        case .yesterday:
            return -1
        }
    }
    
    private func buildDateRange(from groups: TokenGroups, baseDate: Date) -> (DateInterval?, Bool) {
        
        // Check if there is absolute time (indicating no ranges)
        guard groups.absoluteTimes.isEmpty else { return (nil, false)}
        
        // Check for part of day tokens - these always indicate ranges
        if !groups.partsOfDay.isEmpty {
            if let partOfDay = groups.partsOfDay.first {
                let (startTime, endTime) = timeRangeForPartOfDay(partOfDay.1)
                
                let baseCalendar = Calendar.current
                let startDate = baseCalendar.date(bySettingHour: startTime.hour!, minute: startTime.minute!, second: 0, of: baseDate) ?? baseDate
                let endDate = baseCalendar.date(bySettingHour: endTime.hour!, minute: endTime.minute!, second: 59, of: baseDate) ?? baseDate
                
                return (DateInterval(start: startDate, end: endDate), true)
            }
        }
        
        // Check for weekend tokens
        if !groups.weekends.isEmpty {
            if let weekend = groups.weekends.first {
                let weekSpec = weekend.1 ?? .thisWeek
                let saturday = getWeekendDate(for: weekSpec)
                let saturdayStart = calendar.date(bySettingHour: 00, minute: 00, second: 00, of: saturday) ?? saturday
                let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) ?? saturday
                let sundayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: sunday) ?? sunday
                
                return (DateInterval(start: saturdayStart, end: sundayEnd), true)
            }
        }
        
        // Check if we have standalone relative week tokens (indicating range queries)
        if !groups.relativeWeeks.isEmpty && groups.weekdays.isEmpty && groups.relativeDays.isEmpty {
            // This is likely a range query like "next week"
            if let relativeWeek = groups.relativeWeeks.first {
                let weekStart = getWeekStart(for: relativeWeek.1)
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
                let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: weekEnd) ?? weekEnd
                
                return (DateInterval(start: weekStart, end: endOfDay), true)
            }
        }
        
        return (nil, false)
    }
    
    private func getWeekStart(for weekSpec: WeekSpecifier) -> Date {
        let weekOffset = weekOffsetForSpecifier(weekSpec)
        
        // Get the start of the target week (Monday)
        let currentWeekday = calendar.component(.weekday, from: referenceDate)
        let daysFromMonday = (currentWeekday + 5) % 7 // Convert Sunday=1 to Monday=0 system
        let thisWeekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: referenceDate) ?? referenceDate
        let targetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: thisWeekStart) ?? referenceDate
        
        return calendar.startOfDay(for: targetWeekStart)
    }
    
    private func timeComponentsForPartOfDay(_ partOfDay: PartOfDay) -> DateComponents {
        var components = DateComponents()
        
        switch partOfDay {
        case .morning:
            components.hour = 9
            components.minute = 0
        case .afternoon:
            components.hour = 14
            components.minute = 0
        case .evening:
            components.hour = 18
            components.minute = 0
        case .night:
            components.hour = 21
            components.minute = 0
        case .noon:
            components.hour = 12
            components.minute = 0
        case .midnight:
            components.hour = 0
            components.minute = 0
        }
        
        return components
    }
    
    private func timeRangeForPartOfDay(_ partOfDay: PartOfDay) -> (start: DateComponents, end: DateComponents) {
        var start = DateComponents()
        var end = DateComponents()
        
        switch partOfDay {
        case .morning:
            start.hour = 6; start.minute = 0
            end.hour = 11; end.minute = 59
        case .afternoon:
            start.hour = 12; start.minute = 0
            end.hour = 17; end.minute = 59
        case .evening:
            start.hour = 18; start.minute = 0
            end.hour = 21; end.minute = 59
        case .night:
            start.hour = 22; start.minute = 0
            end.hour = 23; end.minute = 59
        case .noon:
            start.hour = 11; start.minute = 30
            end.hour = 12; end.minute = 30
        case .midnight:
            start.hour = 23; start.minute = 30
            end.hour = 0; end.minute = 30 // Next day
        }
        
        return (start, end)
    }
    
    private func buildFinalDate(from components: DateComponents) -> Date {
        var finalComponents = components
        finalComponents.timeZone = timeZone
        
        return calendar.date(from: finalComponents) ?? referenceDate
    }
    
    private func calculateConfidence(tokens: [TemporalToken], conflicts: [String]) -> Float {
        var confidence: Float = 1.0
        
        // Reduce confidence for conflicts
        confidence -= Float(conflicts.count) * 0.2
        
        // Reduce confidence if no high-priority time tokens
        let hasTimeSpecification = tokens.contains { token in
            switch token.kind {
            case .absoluteTime, .timeRange, .partOfDay:
                return true
            default:
                return false
            }
        }
        
        if !hasTimeSpecification {
            confidence -= 0.1
        }
        
        // Reduce confidence if only low-priority tokens
        let highestPriority = tokens.map { $0.tokenPriority() }.max() ?? 0
        if highestPriority < 50 {
            confidence -= 0.2
        }
        
        return max(0.0, min(1.0, confidence))
    }
}

// MARK: - Supporting Structures

private struct TokenGroups {
    var absoluteDates: [(TemporalToken, DateComponents)] = []
    var absoluteTimes: [(TemporalToken, DateComponents)] = []
    var timeRanges: [(TemporalToken, DateComponents, DateComponents)] = []
    var weekdays: [(TemporalToken, Int, WeekModifier?)] = []
    var relativeDays: [(TemporalToken, RelativeDay)] = []
    var relativeWeeks: [(TemporalToken, WeekSpecifier)] = []
    var weekends: [(TemporalToken, WeekSpecifier?)] = []
    var partsOfDay: [(TemporalToken, PartOfDay)] = []
    var ordinalDays: [(TemporalToken, Int)] = []
    var durationOffsets: [(TemporalToken, Int, Calendar.Component, OffsetMode)] = []
    var connectors: [TemporalToken] = []
}

// MARK: - Usage Example

/*
// Example usage:
let interpreter = TemporalTokenInterpreter()
let context = interpreter.interpret(tokens)

print("Final Date: \(context.finalDate)")
print("Confidence: \(context.confidence)")
print("Conflicts: \(context.conflicts)")

if context.isRangeQuery && context.dateRange != nil {
    print("Date Range: \(context.dateRange!.start) to \(context.dateRange!.end)")
    // Query calendar events from range.start to range.end
} else {
    print("Specific Date/Time: \(context.finalDate)")
    // Query calendar events around specific date
}
*/
