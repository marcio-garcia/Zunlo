//
//  FreeWindowSettings.swift
//  Zunlo
//
//  Created by Marcio Garcia on 8/16/25.
//

import SwiftUI

struct FreeWindowSettings: View {
    @EnvironmentObject var policyProvider: SuggestionPolicyProvider
    let minutes = [15, 25, 30, 45, 60, 90]
    
    var body: some View {
        HStack {
            Text("Minimum focus duration")
                .themedBody()
            Spacer()
            Picker("",
                   selection: Binding(
                    get: { Int(policyProvider.minFocusDuration / 60) },
                    set: { minutes in
                        policyProvider.setMinFocusDuration(seconds: TimeInterval(minutes) * 60.0)
                    })
            ) {
                ForEach(minutes, id: \.self) { min in
                    Text("\(min)").themedBody()
                }
            }
        }
    }
}
