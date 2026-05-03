// ConnectErrorPopupController.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Floating HUD showing full SFTP/FTP connection error diagnostics.
//   Triggered by the ⚠ button in ConnectToServerView section title bar.
//   Inherits all panel/show/hide logic from InfoPopupController.

import AppKit
import Foundation

// MARK: - ConnectErrorPopupController
// NOTE: renamed to InfoPopupController as base; this class kept for call-site compat.
// TODO: migrate all call sites to use InfoPopupController.shared directly.

@MainActor
final class ConnectErrorPopupController: InfoPopupController {

    static let shared = ConnectErrorPopupController()

    private override init() { super.init() }

    // MARK: - show(server:anchorFrame:)
    func show(server: RemoteServer, anchorFrame: CGRect) {
        show(content: buildContent(server: server), anchorFrame: anchorFrame, width: 360)
    }

    // MARK: - buildContent
    private func buildContent(server: RemoteServer) -> NSAttributedString {
        let out  = NSMutableAttributedString()
        let para = defaultPara()

        out.appendHUD("Connection Failed\n", font: Self.titleFont, color: Self.titleColor, para: para)

        out.appendField(label: "Host",     value: "\(server.host):\(server.port)", para: para)
        out.appendField(label: "Protocol", value: server.remoteProtocol.rawValue,  para: para)
        out.appendField(label: "User",     value: server.user.isEmpty ? "—" : server.user, para: para)
        out.appendField(label: "Status",   value: server.lastResult.rawValue,      para: para)

        if let detail = server.lastErrorDetail, !detail.isEmpty {
            out.appendHUD("\nError detail:\n", font: Self.labelFont, color: Self.labelColor, para: para)
            out.appendHUD(detail + "\n",       font: Self.valueFont, color: Self.valueColor, para: para)
        }

        let tip: String
        switch server.lastResult {
        case .authFailed: tip = "Check username / password / SSH key."
        case .timeout:    tip = "Host unreachable or firewall blocking port \(server.port)."
        case .refused:    tip = "Service not running on \(server.host):\(server.port)."
        default:
            if server.remoteProtocol == .smb {
                tip = "SMB path must start with a shared folder name. For SSH access to /Users, use SFTP."
            } else {
                tip = "Check host, port, credentials, VPN, firewall."
            }
        }
        out.appendHUD("\nTip: \(tip)\n", font: Self.labelFont, color: Self.labelColor, para: para)

        return out
    }

    // MARK: - defaultPara
    private func defaultPara() -> NSMutableParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineBreakMode    = .byWordWrapping
        p.paragraphSpacing = 3
        return p
    }
}
