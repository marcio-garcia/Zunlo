//
//  Mapping+Events.swift
//  Zunlo
//
//  Created by Marcio Garcia on 6/25/25.
//

extension Event {
    func toLocal() -> EventLocal {
        return EventLocal(id: self.id, userId: userId, title: title, createdAt: createdAt, dueDate: dueDate, isComplete: isComplete)
    }
    
    func toRemote() -> EventRemote {
        return EventRemote(id: self.id, userId: userId, title: title, createdAt: createdAt, dueDate: dueDate, isComplete: isComplete)
    }
}

extension EventLocal {
    func toDomain() -> Event {
        return Event(id: self.id, userId: userId, title: title, createdAt: createdAt, dueDate: dueDate, isComplete: isComplete)
    }
    
    func toRemote() -> EventRemote {
        return EventRemote(id: self.id, userId: userId, title: title, createdAt: createdAt, dueDate: dueDate, isComplete: isComplete)
    }
}

extension EventRemote {
    func toDomain() -> Event {
        return Event(id: self.id, userId: userId, title: title, createdAt: createdAt, dueDate: dueDate, isComplete: isComplete)
    }
    
    func toLocal() -> EventLocal {
        return EventLocal(id: self.id, userId: userId, title: title, createdAt: createdAt, dueDate: dueDate, isComplete: isComplete)
    }
}
