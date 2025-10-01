//
//  CalendarTopBarView.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/30/25.
//

import UIKit
import SwiftUI
import GlowUI

final class CalendarTopBarView: UIView {
    // MARK: - Public callbacks
    var onTapClose: (() -> Void)?
    var onTapToday: (() -> Void)?
    var onTapAdd: (() -> Void)?

    // MARK: - UI
    private let contentContainer = UIView()
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let rightStack = UIStackView()
    private let todayButton = UIButton(type: .system)
    private let addButton = UIButton(type: .system)
    private let bottomSeparator = UIView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))

    private var titleCenterXConstraint: NSLayoutConstraint!
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupConstraints()
        setupTheme()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupConstraints()
        setupTheme()
    }

    // MARK: - Public API
    func configure(title: String, accentColor: UIColor? = nil) {
        titleLabel.text = title
        if let accent = accentColor {
            if var c = todayButton.configuration { c.baseForegroundColor = accent; todayButton.configuration = c }
            if var c = addButton.configuration { c.baseForegroundColor = accent; addButton.configuration = c }
            if var c = closeButton.configuration { c.baseForegroundColor = accent; closeButton.configuration = c }
        }
    }

    func setButtonsEnabled(_ isEnabled: Bool) {
        [todayButton, addButton].forEach { $0.isEnabled = isEnabled }
    }

    // MARK: - Private setup
    private func setupView() {
//        blurView.effect = UIBlurEffect(style: traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        
        var closeConfig = UIButton.Configuration.plain()
        closeConfig.image = UIImage(systemName: "chevron.left")
        closeConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        closeButton.configuration = closeConfig
        closeButton.addTarget(self, action: #selector(handleCloseTapped), for: .touchUpInside)
        closeButton.accessibilityLabel = String(localized: "Close event list")
        
        rightStack.axis = .horizontal
        rightStack.alignment = .center
        rightStack.spacing = 4
        
        var todayConfig = UIButton.Configuration.plain()
        todayConfig.image = UIImage(systemName: "calendar.badge.clock")
        todayConfig.imagePadding = 6
        todayConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        todayButton.configuration = todayConfig
        todayButton.addTarget(self, action: #selector(handleTodayTapped), for: .touchUpInside)

        var addConfig = UIButton.Configuration.plain()
        addConfig.image = UIImage(systemName: "plus")
        addConfig.imagePadding = 6
        addConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        addButton.configuration = addConfig
        addButton.addTarget(self, action: #selector(handleAddTapped), for: .touchUpInside)

        titleLabel.font = AppFontStyle.heading.uiFont()
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        addSubview(blurView)
        addSubview(contentContainer)
        contentContainer.addSubview(closeButton)
        contentContainer.addSubview(rightStack)
        rightStack.addArrangedSubview(todayButton)
        rightStack.addArrangedSubview(addButton)
        addSubview(titleLabel)
        addSubview(bottomSeparator)
    }

    private func setupConstraints() {
        blurView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
        
        let topMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor),

            closeButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: topMargins.left),
            closeButton.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: topMargins.top),
            closeButton.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -topMargins.bottom),

            rightStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -topMargins.right),
            rightStack.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            rightStack.topAnchor.constraint(greaterThanOrEqualTo: contentContainer.topAnchor, constant: topMargins.top),
            rightStack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor, constant: -topMargins.bottom),

            bottomSeparator.topAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            bottomSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            // View bottom = separator bottom (intrinsic height)
            bottomAnchor.constraint(equalTo: bottomSeparator.bottomAnchor)
        ])
        
        // Title overlay constraints
        titleCenterXConstraint = titleLabel.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor)
        titleCenterXConstraint.priority = .defaultHigh // allows it to relax if space is tight
        NSLayoutConstraint.activate([
            titleCenterXConstraint,
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            // Keep title between left & right controls (required)
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -12)
        ])

        // Let the title truncate if needed
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal) // 751
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func setupTheme() {
        backgroundColor = .clear
        titleLabel.textColor = UIColor(Color.theme.text)
        bottomSeparator.backgroundColor = UIColor.separator.withAlphaComponent(0.1)
    }

    // MARK: - Actions
    
    @objc private func handleCloseTapped() {
        onTapClose?()
    }
    
    @objc private func handleTodayTapped() {
        onTapToday?()
    }

    @objc private func handleAddTapped() {
        onTapAdd?()
    }
}
