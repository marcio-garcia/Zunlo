//
//  Modifiers.swift
//  SmartParseKit
//
//  Created by Marcio Garcia on 9/12/25.
//

public enum WeekSpecifier: Equatable {
    case thisWeek
    case nextWeek(count: Int)
    case lastWeek(count: Int)
}

public enum WeekModifier {
    case next
    case last
    case this
}

public enum RelativeDay {
    case today
    case tomorrow
    case yesterday
    case tonight
}

public enum PartOfDay {
    case morning
    case afternoon
    case evening
    case night
    case noon
    case midnight
}

public enum OffsetMode {
    case fromNow
    case shift
    case ago
}
