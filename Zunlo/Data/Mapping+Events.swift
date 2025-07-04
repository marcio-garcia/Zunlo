//
//  Mapping+Events.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

import Foundation

extension Event {
    func toLocal() -> EventLocal {
        return EventLocal(id: self.id ?? UUID(),
                          userId: userId ?? UUID(),
                          title: title,
                          createdAt: createdAt ?? Date(),
                          dueDate: dueDate,
                          recurrence: recurrence,
                          exceptions: exceptions,
                          isComplete: isComplete)
    }
    
    func toRemote() -> EventRemote {
        return EventRemote(id: self.id,
                           userId: userId,
                           title: title,
                           createdAt: createdAt,
                           dueDate: dueDate,
                           recurrence: recurrence,
                           exceptions: exceptions,
                           isComplete: isComplete)
    }
}

extension EventLocal {
    func toDomain() -> Event {
        return Event(id: self.id,
                     userId: userId,
                     title: title,
                     createdAt: createdAt,
                     dueDate: dueDate,
                     recurrence: recurrence ?? .none,
                     exceptions: exceptions,
                     isComplete: isComplete)
    }
    
    func toRemote() -> EventRemote {
        return EventRemote(id: self.id,
                           userId: userId,
                           title: title,
                           createdAt: createdAt,
                           dueDate: dueDate,
                           recurrence: recurrence ?? .none,
                           isComplete: isComplete)
    }
    
    func getUpdateFields(_ event: EventLocal) {
        self.title = event.title
        self.dueDate = event.dueDate
        self.recurrence = event.recurrence
        self.exceptions = event.exceptions
        self.isComplete = event.isComplete
    }
}

extension EventRemote {
    func toDomain() -> Event {
        return Event(id: self.id,
                     userId: userId,
                     title: title,
                     createdAt: createdAt,
                     dueDate: dueDate,
                     recurrence: recurrence,
                     exceptions: exceptions,
                     isComplete: isComplete)
    }
    
    func toLocal() -> EventLocal {
        return EventLocal(id: self.id ?? UUID(),
                          userId: userId ?? UUID(),
                          title: title,
                          createdAt: createdAt ?? Date(),
                          dueDate: dueDate,
                          recurrence: recurrence,
                          exceptions: exceptions,
                          isComplete: isComplete)
    }
}
