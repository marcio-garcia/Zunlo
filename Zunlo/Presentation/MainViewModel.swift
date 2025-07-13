//
//  MainViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

final class MainViewModel: ObservableObject {
    let eventRepository: EventRepository
    let userTaskRepository: UserTaskRepository
    let chatViewModel: ChatScreenViewModel

    init(eventRepository: EventRepository,
         userTaskRepository: UserTaskRepository,
         chatViewModel: ChatScreenViewModel) {
        self.eventRepository = eventRepository
        self.userTaskRepository = userTaskRepository
        self.chatViewModel = chatViewModel
    }
}
