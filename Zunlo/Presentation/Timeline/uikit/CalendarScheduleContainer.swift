//
//  CalendarScheduleContainer.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import SwiftUI

struct CalendarScheduleContainer: UIViewControllerRepresentable {
    @ObservedObject var viewModel: CalendarScheduleViewModel
    @EnvironmentObject var nav: AppNav
    
    var onTapClose: (() -> Void)?
    
    init(viewModel: CalendarScheduleViewModel, onTapClose: (() -> Void)?) {
        self.viewModel = viewModel
        self.onTapClose = onTapClose
    }
    
    func makeUIViewController(context: Context) -> CalendarScheduleViewController {
        let vc = CalendarScheduleViewController(
            viewModel: viewModel,
            nav: nav,
            onTapClose: onTapClose
        )
        return vc
    }

    func updateUIViewController(_ uiViewController: CalendarScheduleViewController, context: Context) { }
}
