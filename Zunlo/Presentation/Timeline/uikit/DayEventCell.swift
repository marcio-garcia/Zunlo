//
//  DayEventCell.swift
//  Zunlo
//
//  Created by Marcio Garcia on 7/28/25.
//

import UIKit
import SwiftUI
import GlowUI

class DayEventCell: UICollectionViewCell {
    private let containerView = UIView()
    private let titleStackView = UIStackView()
    private let weekLabel = UILabel()
    private let dayLabel = UILabel()
    private let weatherIconImageView = UIImageView()
    private let weatherLabel = UILabel()

    var onTap: ((EventOccurrence?) -> Void)?
    
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
        weatherIconImageView.alpha = 0
        weatherLabel.alpha = 0
    }
    
    private func setupViews() {

        titleStackView.axis = .horizontal
        titleStackView.spacing = 4
        titleStackView.alignment = .center
        
        weekLabel.font = AppFontStyle.body.uiFont()
        dayLabel.font = AppFontStyle.body.weight(.semibold).uiFont()

        weatherIconImageView.contentMode = .scaleAspectFit
        weatherIconImageView.tintColor = .label // or a softer tone
        weatherIconImageView.translatesAutoresizingMaskIntoConstraints = false
        weatherIconImageView.alpha = 0

        weatherLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        weatherLabel.textColor = .secondaryLabel
        weatherLabel.translatesAutoresizingMaskIntoConstraints = false
        weatherLabel.alpha = 0
        
        titleStackView.addArrangedSubview(weekLabel)
        titleStackView.addArrangedSubview(dayLabel)
        titleStackView.addArrangedSubview(UIView())
        titleStackView.addArrangedSubview(weatherIconImageView)
        titleStackView.addArrangedSubview(weatherLabel)

        contentView.addSubview(containerView)
        containerView.addSubview(titleStackView)
        
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            
            titleStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            titleStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            weatherIconImageView.widthAnchor.constraint(equalToConstant: 16),
            weatherIconImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    private func setupTheme() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        weekLabel.textColor = UIColor(Color.theme.text)
        dayLabel.textColor = UIColor(Color.theme.text)
    }
    
    func configure(with date: Date, viewModel: CalendarScheduleViewModel) {
        self.configure(with: date, weather: nil)

        // Trigger weather fetch for today
        guard date.isSameDay(as: Date()) else { return }

        viewModel.fetchWeather(for: date) { [weak self] weather in
            guard let self = self, let weather else { return }

            DispatchQueue.main.async {
                self.updateWeatherUI(with: weather)
            }
        }
    }

    func configure(with date: Date, weather: WeatherInfo?) {
        let isToday = date.isSameDay(as: Date())
        weekLabel.text = date.formattedDate(
            dateFormat: .week,
            locale: Locale(identifier: Locale.current.identifier),
            timeZone: Calendar.appDefault.timeZone
        )
        dayLabel.text = date.formattedDate(
            dateFormat: .day,
            locale: Locale(identifier: Locale.current.identifier),
            timeZone: Calendar.appDefault.timeZone
        )
        weekLabel.textColor = isToday ? UIColor(Color.theme.accent) : UIColor(Color.theme.text)
        dayLabel.textColor = isToday ? UIColor(Color.theme.accent) : UIColor(Color.theme.text)
    }
    
    private func updateWeatherUI(with weather: WeatherInfo) {
        weatherIconImageView.image = UIImage(systemName: weather.condition.symbolName())
        weatherLabel.text = "\(Int(weather.temperature))°"

        UIView.animate(withDuration: 0.2) {
            self.weatherIconImageView.alpha = 1
            self.weatherLabel.alpha = 1
        }
    }
}
