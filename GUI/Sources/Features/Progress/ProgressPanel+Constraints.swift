// ProgressPanel+Constraints.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Auto Layout constraints for ProgressPanel.

import AppKit

// MARK: - Constraints

extension ProgressPanel {
    // MARK: - Pin Container
    func pinContainer(_ containerView: NSView, backgroundView: NSView, contentView: NSView) {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }

    // MARK: - Pin Log Background
    func pinLogBackground(_ logEffectView: NSView, to scrollView: NSScrollView) {
        NSLayoutConstraint.activate([
            logEffectView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            logEffectView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            logEffectView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            logEffectView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
        ])
    }

    // MARK: - Main Constraints
    func activateMainConstraints(containerView: NSView) {
        guard let iconView, let titleLabel, let statusLabel, let progressIndicator, let scrollView, let actionButton else { return }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Layout.outerPadding),
            iconView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Layout.topInset),
            iconView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Layout.iconSize),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Layout.titleSpacing),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Layout.outerPadding),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Layout.outerPadding),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Layout.outerPadding),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.statusTopSpacing),
            progressIndicator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Layout.outerPadding),
            progressIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Layout.outerPadding),
            progressIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: Layout.progressTopSpacing),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Layout.outerPadding),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Layout.outerPadding),
            scrollView.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: Layout.logTopSpacing),
            scrollView.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -Layout.logTopSpacing),
            actionButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Layout.outerPadding),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Layout.buttonBottomInset),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.buttonMinWidth),
            actionButton.heightAnchor.constraint(equalToConstant: Layout.buttonHeight),
        ])
        let progressHeightConstraint = progressIndicator.heightAnchor.constraint(equalToConstant: 0)
        progressHeightConstraint.isActive = true
        self.progressHeightConstraint = progressHeightConstraint
    }
}
