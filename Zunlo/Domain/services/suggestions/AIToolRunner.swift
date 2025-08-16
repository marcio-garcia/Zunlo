//
//  AIToolRunner.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/15/25.
//

import Foundation

enum AIToolRunnerError: Error {
    case failed(String)
}

protocol AIToolRunner {
    func startDailyPlan(context: AIContext) async throws
    func createFocusBlock(start: Date, minutes: Int, suggestedTask: UserTask?) async throws
    func scheduleTask(_ task: UserTask, at start: Date, minutes: Int) async throws
    func bookSlot(at start: Date, minutes: Int, title: String?) async throws
    func resolveConflictsToday() async throws
    func addPrepTasksForNextEvent(prepTemplate: PrepPackTemplate) async throws
    func shiftErrandsEarlierToday() async throws
    func startEveningWrap() async throws
}
