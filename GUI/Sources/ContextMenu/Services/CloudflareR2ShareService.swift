// CloudflareR2ShareService.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Uploads media to a public R2 bucket and copies its direct URL.

import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

// MARK: - CloudflareR2ShareService
@MainActor
enum CloudflareR2ShareService {
    // MARK: - Media Eligibility
    static func isMedia(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .movie) || type.conforms(to: .audio)
    }
    // MARK: - Copy Share Link
    static func copyShareLink(for source: URL) async -> Bool {
        let panel = ProgressPanel.shared
        panel.show(icon: "cloud.fill", title: "Share+Link: \(source.lastPathComponent)", status: "Uploading to Cloudflare R2…", operationKey: "cloudflare-r2-share", cancelHandler: { CloudLinkService.cancelActiveShare() })
        panel.updateProgress(nil)
        panel.appendKeyValueLog("Source", value: source.path)
        do {
            guard isMedia(source) else { throw R2ShareError.unsupportedFile }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory), !isDirectory.boolValue else { throw R2ShareError.missingFile }
            let config = try R2Configuration.load()
            let key = "miminavi/\(UUID().uuidString)/\(source.lastPathComponent)"
            let request = try R2Signer.uploadRequest(config: config, key: key, contentType: UTType(filenameExtension: source.pathExtension)?.preferredMIMEType ?? "application/octet-stream")
            panel.appendLog("Uploading media to R2…")
            let (_, response) = try await URLSession.shared.upload(for: request, fromFile: source)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw R2ShareError.uploadFailed((response as? HTTPURLResponse)?.statusCode ?? 0) }
            let directURL = config.publicURL.appending(path: key).absoluteString
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(directURL, forType: .string)
            panel.appendKeyValueLog("Direct URL", value: directURL)
            panel.finish(success: true, message: "Share+Link ready: direct URL copied")
            FileOperationOutcomePresenter.success(.shareLink, resultURL: URL(string: directURL), displayName: "for \(source.lastPathComponent)")
            log.info("[CloudLink] R2 upload completed key='\(key)'")
            return true
        } catch is CancellationError {
            panel.finish(success: false, message: "Share+Link cancelled")
            FileOperationOutcomePresenter.cancelled(.shareLink)
            return false
        } catch {
            panel.appendLog("❌ \(error.localizedDescription)")
            panel.finish(success: false, message: "Cloudflare R2 Share+Link failed")
            FileOperationOutcomePresenter.failure(.shareLink, error: error)
            log.error("[CloudLink] R2 upload failed: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - R2Configuration
private struct R2Configuration {
    let accountID: String
    let bucket: String
    let publicURL: URL
    let accessKeyID: String
    let secretAccessKey: String
    // MARK: - Load
    static func load() throws -> Self {
        let saved = try CloudLinkCredentialsStore.load()
        guard let accountID = saved.r2AccountID?.trimmingCharacters(in: .whitespacesAndNewlines), accountID.range(of: "^[0-9a-fA-F]{32}$", options: .regularExpression) != nil,
              let bucket = saved.r2Bucket?.trimmingCharacters(in: .whitespacesAndNewlines), bucket.range(of: "^[a-z0-9][a-z0-9.-]*$", options: .regularExpression) != nil,
              let rawURL = saved.r2PublicURL?.trimmingCharacters(in: .whitespacesAndNewlines), let publicURL = URL(string: rawURL), publicURL.scheme == "https", publicURL.host != nil, publicURL.user == nil, publicURL.password == nil, publicURL.query == nil, publicURL.fragment == nil,
              let accessKeyID = saved.r2AccessKeyID, !accessKeyID.isEmpty,
              let secretAccessKey = saved.r2SecretAccessKey, !secretAccessKey.isEmpty else { throw R2ShareError.invalidConfiguration }
        return Self(accountID: accountID, bucket: bucket, publicURL: publicURL, accessKeyID: accessKeyID, secretAccessKey: secretAccessKey)
    }
}

// MARK: - R2Signer
private enum R2Signer {
    // MARK: - Upload Request
    static func uploadRequest(config: R2Configuration, key: String, contentType: String) throws -> URLRequest {
        let host = "\(config.accountID).r2.cloudflarestorage.com"
        guard let url = URL(string: "https://\(host)/\(config.bucket)")?.appending(path: key) else { throw R2ShareError.invalidConfiguration }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let timestamp = formatter.string(from: Date())
        let day = String(timestamp.prefix(8))
        let scope = "\(day)/auto/s3/aws4_request"
        let headers = "host:\(host)\nx-amz-content-sha256:UNSIGNED-PAYLOAD\nx-amz-date:\(timestamp)\n"
        let signedHeaders = "host;x-amz-content-sha256;x-amz-date"
        guard let encodedPath = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath else { throw R2ShareError.invalidConfiguration }
        let canonical = "PUT\n\(encodedPath)\n\n\(headers)\n\(signedHeaders)\nUNSIGNED-PAYLOAD"
        let stringToSign = "AWS4-HMAC-SHA256\n\(timestamp)\n\(scope)\n\(digest(canonical))"
        let dateKey = hmac(Data(("AWS4" + config.secretAccessKey).utf8), day)
        let regionKey = hmac(dateKey, "auto")
        let serviceKey = hmac(regionKey, "s3")
        let signingKey = hmac(serviceKey, "aws4_request")
        let signature = hmac(signingKey, stringToSign).map { String(format: "%02x", $0) }.joined()
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("UNSIGNED-PAYLOAD", forHTTPHeaderField: "x-amz-content-sha256")
        request.setValue(timestamp, forHTTPHeaderField: "x-amz-date")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("AWS4-HMAC-SHA256 Credential=\(config.accessKeyID)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)", forHTTPHeaderField: "Authorization")
        return request
    }
    // MARK: - Cryptography
    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private static func hmac(_ key: Data, _ value: String) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: SymmetricKey(data: key)))
    }
}

// MARK: - R2ShareError
private enum R2ShareError: LocalizedError {
    case invalidConfiguration
    case unsupportedFile
    case missingFile
    case uploadFailed(Int)
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "Configure the R2 account, bucket, public URL and S3 keys in Cloud Share+Link settings."
        case .unsupportedFile: "Cloudflare R2 Share+Link accepts image, video and audio files."
        case .missingFile: "The source media file is missing or is a directory."
        case .uploadFailed(let code): "R2 rejected the upload (HTTP \(code)). Check the bucket and Object Read & Write key."
        }
    }
}
