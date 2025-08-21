//
//  AgendaComputing.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/19/25.
//

import Foundation

protocol AgendaComputing {
    func computeAgenda(range: Range<Date>, timezone: TimeZone) async throws -> GetAgendaResult
}
