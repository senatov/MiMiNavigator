//
//  File.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 12.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AVFoundation
import AVKit
import AppKit
import SwiftyBeaver
import UniformTypeIdentifiers

@MainActor
extension MediaInfoPanel {
    // MARK: - makeIconAttachment
    func makeIconAttachment(systemName: String) -> NSAttributedString {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        let att = NSTextAttachment()
        att.image = image
        att.bounds = NSRect(x: 0, y: -2, width: 16, height: 16)
        return NSAttributedString(attachment: att)
    }

    // MARK: - buildAttributedContent
    func buildAttributedContent(baseText: String, coordinates: (Double, Double)?) -> NSAttributedString {
        let bodyFont = NSFont.systemFont(ofSize: 12, weight: .light)
        let headerFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        let color = NSColor.labelColor
        let result = NSMutableAttributedString()
        let headerA: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: color]
        let bodyA: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: color]
        for line in baseText.components(separatedBy: "\n") {
            if line.hasPrefix("---") {
                let s = line.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespaces)
                result.append(NSAttributedString(string: "\n\(s)\n", attributes: headerA))
            } else {
                result.append(NSAttributedString(string: line + "\n", attributes: bodyA))
            }
        }
        guard let (lat, lon) = coordinates else { return result }
        result.append(NSAttributedString(string: "\nMaps\n", attributes: headerA))
        appendMapLink(into: result, icon: "globe", title: "Google", urlString: "https://www.google.com/maps?q=\(lat),\(lon)")
        appendMapLink(into: result, icon: "applelogo", title: "Apple", urlString: "https://maps.apple.com/?ll=\(lat),\(lon)")
        appendMapLink(
            into: result, icon: "map", title: "OSM",
            urlString: "https://www.openstreetmap.org/?mlat=\(lat)&mlon=\(lon)#map=15/\(lat)/\(lon)")
        appendMapLink(
            into: result, icon: "location.circle", title: "HERE", urlString: "https://wego.here.com/?map=\(lat),\(lon),15,normal")
        return result
    }

    func appendMapLink(into result: NSMutableAttributedString, icon: String, title: String, urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 4
        ps.paragraphSpacing = 4
        let line = NSMutableAttributedString()
        line.append(makeIconAttachment(systemName: icon))
        line.append(NSAttributedString(string: "   "))
        line.append(
            NSAttributedString(
                string: title + "\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .light),
                    .foregroundColor: NSColor.linkColor, .link: url, .paragraphStyle: ps,
                ]))
        result.append(line)
    }

    func extractCoordinates(from text: String) -> (Double, Double)? {
        if let r = text.range(of: "ll=") {
            let t = text[r.upperBound...]
            let p = String(t.split(whereSeparator: { $0 == "\n" || $0 == "&" }).first ?? "")
            let c = p.split(separator: ",")
            if c.count == 2, let la = Double(c[0].trimmingCharacters(in: .whitespaces)),
                let lo = Double(c[1].trimmingCharacters(in: .whitespaces))
            {
                return (la, lo)
            }
        }
        if let r = text.range(of: "GPS:") {
            let ln = String(text[r.lowerBound...].split(separator: "\n").first ?? "")
            let n = ln.split(whereSeparator: { !$0.isNumber && $0 != "." && $0 != "-" })
            if n.count >= 2, let la = Double(n[0].trimmingCharacters(in: .whitespaces)),
                let lo = Double(n[1].trimmingCharacters(in: .whitespaces))
            {
                return (la, lo)
            }
        }
        return nil
    }
}
