//
//  FullScreenAdEvent.swift
//  AdStack
//
//  Created by Marcio Garcia on 8/5/25.
//

public enum FullScreenAdEvent {
    case didDismiss
    case didFailToPresent(Error)
    case didRecordImpression
    case didClick
}
