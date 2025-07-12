//
//  MainViewModel.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/12/25.
//

import SwiftUI

final class MainViewModel: ObservableObject {
    let eventRepository: EventRepository
    let chatViewModel: ChatScreenViewModel

    init(eventRepository: EventRepository, chatViewModel: ChatScreenViewModel) {
        self.eventRepository = eventRepository
        self.chatViewModel = chatViewModel
    }
}
