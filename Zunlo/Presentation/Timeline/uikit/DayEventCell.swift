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

    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        // Return desired height for day headers
        return CGSize(width: targetSize.width, height: 40)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        DispatchQueue.main.async {
            let shapeLayer = CAShapeLayer.roundCorners(
                for: [.topLeft, .topRight],
                bounds: self.containerView.bounds,
                radius: 8
            )
            
            self.containerView.layer.mask = shapeLayer
        }
    }
    
    private func setupViews() {

//        containerView.layer.cornerRadius = 8
        containerView.layer.borderWidth = 1

        titleStackView.axis = .horizontal
        titleStackView.spacing = 4
        titleStackView.alignment = .center
        
        dayLabel.font = AppFontStyle.strongBody.uiFont()

        weatherIconImageView.contentMode = .scaleAspectFit
        weatherIconImageView.tintColor = .label // or a softer tone
        weatherIconImageView.translatesAutoresizingMaskIntoConstraints = false
        weatherIconImageView.alpha = 0

        weatherLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        weatherLabel.textColor = .secondaryLabel
        weatherLabel.translatesAutoresizingMaskIntoConstraints = false
        weatherLabel.alpha = 0
        
//        contentStackView.axis = .vertical
//        contentStackView.spacing = 8
//        contentStackView.alignment = .fill
//        contentStackView.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
//        contentStackView.isLayoutMarginsRelativeArrangement = true

        titleStackView.addArrangedSubview(dayLabel)
        titleStackView.addArrangedSubview(weatherIconImageView)
        titleStackView.addArrangedSubview(weatherLabel)

        contentView.addSubview(containerView)
        containerView.addSubview(titleStackView)
        
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0),
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
        containerView.backgroundColor = UIColor(Color.theme.eventCellBackground)
        containerView.layer.borderColor = UIColor(Color.theme.lightBorder).cgColor
        dayLabel.textColor = UIColor(Color.theme.text)
    }
    
    func configure(with date: Date, viewModel: CalendarScheduleViewModel) {
        // Basic event UI
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
        dayLabel.text = date.formattedDate(
            dateFormat: .weekAndDay,
            locale: Locale(identifier: Locale.current.identifier)
        )
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
