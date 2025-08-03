//
//  CalendarScheduleContainer.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import SwiftUI

struct CalendarScheduleContainer: UIViewControllerRepresentable {
    @ObservedObject var viewModel: CalendarScheduleViewModel

    func makeUIViewController(context: Context) -> CalendarScheduleViewController {
        CalendarScheduleViewController(viewModel: viewModel)
    }

    func updateUIViewController(_ uiViewController: CalendarScheduleViewController, context: Context) { }
}
