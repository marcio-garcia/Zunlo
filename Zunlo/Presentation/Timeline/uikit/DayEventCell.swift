//
//  DayEventCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import UIKit
import SwiftUI

class DayEventCell: UICollectionViewCell {
    private let containerView = UIView()
    private let titleStackView = UIStackView()
    private let dayLabel = UILabel()
    private let weatherIconImageView = UIImageView()
    private let weatherLabel = UILabel()
    private let eventsStack = UIStackView()
    private let contentStackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        weatherIconImageView.image = nil
        weatherLabel.text = nil
        weatherIconImageView.isHidden = true
        weatherLabel.isHidden = true
    }

    private func setupViews() {
        containerView.layer.cornerRadius = 8
        containerView.layer.borderWidth = 1

        titleStackView.axis = .horizontal
        titleStackView.spacing = 4
        titleStackView.alignment = .leading
        
        dayLabel.font = AppFontStyle.strongBody.uiFont()

        weatherIconImageView.contentMode = .scaleAspectFit
        weatherIconImageView.tintColor = .label // or a softer tone
        weatherIconImageView.translatesAutoresizingMaskIntoConstraints = false
        weatherIconImageView.alpha = 0

        weatherLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        weatherLabel.textColor = .secondaryLabel
        weatherLabel.translatesAutoresizingMaskIntoConstraints = false
        weatherLabel.alpha = 0
        
        eventsStack.axis = .vertical
        eventsStack.spacing = 4
        eventsStack.alignment = .fill

        contentStackView.axis = .vertical
        contentStackView.spacing = 8
        contentStackView.alignment = .fill
        contentStackView.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        contentStackView.isLayoutMarginsRelativeArrangement = true

        titleStackView.addArrangedSubview(dayLabel)
        titleStackView.addArrangedSubview(weatherIconImageView)
        titleStackView.addArrangedSubview(weatherLabel)
        
        contentStackView.addArrangedSubview(titleStackView)
        contentStackView.addArrangedSubview(eventsStack)

        contentView.addSubview(containerView)
        containerView.addSubview(contentStackView)
        
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            weatherIconImageView.widthAnchor.constraint(equalToConstant: 16),
            weatherIconImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    private func setupTheme() {
        contentView.backgroundColor = .clear
        containerView.backgroundColor = UIColor(Color.theme.eventCellBackground)
        containerView.layer.borderColor = UIColor(Color.theme.lightBorder).cgColor
        dayLabel.textColor = UIColor(Color.theme.text)
    }
    
    func configure(with date: Date, events: [EventOccurrence], viewModel: CalendarScheduleViewModel) {
        // Basic event UI
        self.configure(with: date, events: events, weather: nil)

        // Trigger weather fetch for today
        guard date.isSameDay(as: Date()) else { return }

        viewModel.fetchWeather(for: date) { [weak self] weather in
            guard let self = self, let weather else { return }

            DispatchQueue.main.async {
                self.updateWeatherUI(with: weather)
            }
        }
    }

    func configure(with date: Date, events: [EventOccurrence], weather: WeatherInfo?) {
        let isToday = date.isSameDay(as: Date())
        dayLabel.text = date.formattedDate(dateFormat: .weekAndDay)
        dayLabel.textColor = isToday ? UIColor(Color.theme.accent) : UIColor(Color.theme.text)
        
        eventsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if events.isEmpty {
            let label = UILabel()
            label.text = "No events"
            label.font = AppFontStyle.footnote.uiFont()
            label.textColor = UIColor(Color.theme.secondaryText)
            eventsStack.addArrangedSubview(label)
        } else {
            for occ in events {
                let row = EventRowView()
                row.configure(with: occ)
                row.addTarget(self, action: #selector(eventTapped(_:)), for: .touchUpInside)
                row.tag = occ.id.hashValue // or use a map
                eventsStack.addArrangedSubview(row)
            }
        }
    }
    
    private func updateWeatherUI(with weather: WeatherInfo) {
        weatherIconImageView.image = UIImage(systemName: weather.conditionCode.symbolName())
        weatherLabel.text = "\(Int(weather.temperature.value))°"

        UIView.animate(withDuration: 0.2) {
            self.weatherIconImageView.alpha = 1
            self.weatherLabel.alpha = 1
        }
    }
    
    @objc private func eventTapped(_ sender: UIControl) {
        // You can use delegation or closure callbacks to notify parent
        print("Tapped event with tag:", sender.tag)
    }

}
