//
//  Mapping+RecurrenceRule.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/4/25.
//

import Foundation

extension RecurrenceRule {
    init(remote: RecurrenceRuleRemote) {
        guard let id = remote.id else {
            fatalError("Error mapping remote to local: invalid id.")
        }
        self.id = id
        self.eventId = remote.event_id
        self.freq = remote.freq
        self.interval = remote.interval
        self.byWeekday = remote.byweekday
        self.byMonthday = remote.bymonthday
        self.byMonth = remote.bymonth
        self.until = remote.until
        self.count = remote.count
        self.createdAt = remote.created_at
        self.updatedAt = remote.updated_at
    }

    init(local: RecurrenceRuleLocal) {
        self.id = local.id
        self.eventId = local.eventId
        self.freq = local.freq
        self.interval = local.interval
        self.byWeekday = local.byWeekdayArray
        self.byMonthday = local.byMonthdayArray
        self.byMonth = local.byMonthArray
        self.until = local.until
        self.count = local.count
        self.createdAt = local.createdAt
        self.updatedAt = local.updatedAt
    }
}

extension RecurrenceRuleRemote {
    init(domain: RecurrenceRule) {
        self.id = domain.id
        self.event_id = domain.eventId
        self.freq = domain.freq
        self.interval = domain.interval
        self.byweekday = domain.byWeekday
        self.bymonthday = domain.byMonthday
        self.bymonth = domain.byMonth
        self.until = domain.until
        self.count = domain.count
        self.created_at = domain.createdAt
        self.updated_at = domain.updatedAt
    }
}

extension RecurrenceRuleLocal {
    convenience init(domain: RecurrenceRule) {
        guard let id = domain.id else {
            fatalError("Error mapping domain to local: invalid id.")
        }
        self.init(
            id: id,
            eventId: domain.eventId,
            freq: domain.freq,
            interval: domain.interval,
            byWeekday: domain.byWeekday,
            byMonthday: domain.byMonthday,
            byMonth: domain.byMonth,
            until: domain.until,
            count: domain.count,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt
        )
    }
    
    convenience init(remote: RecurrenceRuleRemote) {
        guard let id = remote.id else {
            fatalError("Error mapping remote to local: invalid id.")
        }
        self.init(id: id,
                  eventId: remote.event_id,
                  freq: remote.freq,
                  interval: remote.interval,
                  byWeekday: remote.byweekday,
                  byMonthday: remote.bymonthday,
                  byMonth: remote.bymonth,
                  until: remote.until,
                  count: remote.count,
                  createdAt: remote.created_at,
                  updatedAt: remote.updated_at
        )
    }
    
    func getUpdateFields(_ local: RecurrenceRuleRemote) {
        self.freq = local.freq
        self.interval = local.interval
        self.byWeekdayArray = local.byweekday ?? []
        self.byMonthdayArray = local.bymonthday ?? []
        self.byMonthArray = local.bymonth ?? []
        self.until = local.until
        self.count = local.count
        self.createdAt = local.created_at
        self.updatedAt = local.updated_at
    }
}

