// GoogleDriveAPIClient.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Minimal Google Drive API client for upload and sharing links.

import Foundation
import UniformTypeIdentifiers

// MARK: - GoogleDriveAPIClient

struct GoogleDriveAPIClient {
    private let accessToken: String
    private let apiRoot = "https://www.googleapis.com/drive/v3"
    private let uploadRoot = "https://www.googleapis.com/upload/drive/v3"

    // MARK: - Init

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    // MARK: - Public Folder

    func ensurePublicFolder() async throws -> GoogleDriveFile {
        if let folder = try await findPublicFolder() {
            return folder
        }
        return try await createFolder(name: GoogleDriveOAuthConfig.publicFolderName, parentID: "root")
    }

    // MARK: - Upload Entry

    func uploadEntry(at url: URL, parentID: String) async throws -> GoogleDriveFile {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else { throw CocoaError(.fileNoSuchFile) }
        if isDirectory.boolValue {
            return try await uploadDirectory(at: url, parentID: parentID)
        }
        return try await uploadFile(at: url, parentID: parentID)
    }

    // MARK: - Apply Permission

    func applyPermission(fileID: String, permission: CloudLinkPermission) async throws {
        let role = permission == .readOnly ? "reader" : "writer"
        let body: [String: Any] = [
            "type": "anyone",
            "role": role,
            "allowFileDiscovery": false,
        ]
        let url = try endpoint("/files/\(fileID)/permissions", query: ["fields": "id"])
        let data = try await jsonRequest(url: url, method: "POST", body: body)
        _ = try JSONDecoder().decode(GoogleDrivePermissionResponse.self, from: data)
    }

    // MARK: - File Metadata

    func fileMetadata(fileID: String) async throws -> GoogleDriveFile {
        let fields = "id,name,mimeType,webViewLink,webContentLink"
        let url = try endpoint("/files/\(fileID)", query: ["fields": fields])
        let data = try await jsonRequest(url: url, method: "GET", body: nil)
        return try JSONDecoder().decode(GoogleDriveFile.self, from: data)
    }

    // MARK: - Find Public Folder

    private func findPublicFolder() async throws -> GoogleDriveFile? {
        let q = "name='\(escapeQuery(GoogleDriveOAuthConfig.publicFolderName))' and mimeType='application/vnd.google-apps.folder' and 'root' in parents and trashed=false"
        let fields = "files(id,name,mimeType,webViewLink)"
        let url = try endpoint("/files", query: ["q": q, "spaces": "drive", "fields": fields, "pageSize": "1"])
        let data = try await jsonRequest(url: url, method: "GET", body: nil)
        return try JSONDecoder().decode(GoogleDriveFileListResponse.self, from: data).files.first
    }

    // MARK: - Upload Directory

    private func uploadDirectory(at url: URL, parentID: String) async throws -> GoogleDriveFile {
        let folder = try await createFolder(name: url.lastPathComponent, parentID: parentID)
        let children = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        )
        for child in children.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            _ = try await uploadEntry(at: child, parentID: folder.id)
        }
        return folder
    }

    // MARK: - Create Folder

    private func createFolder(name: String, parentID: String) async throws -> GoogleDriveFile {
        let fields = "id,name,mimeType,webViewLink"
        let url = try endpoint("/files", query: ["fields": fields])
        let body: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder",
            "parents": [parentID],
        ]
        let data = try await jsonRequest(url: url, method: "POST", body: body)
        return try JSONDecoder().decode(GoogleDriveFile.self, from: data)
    }

    // MARK: - Upload File

    private func uploadFile(at url: URL, parentID: String) async throws -> GoogleDriveFile {
        let fields = "id,name,mimeType,webViewLink,webContentLink"
        let sessionURL = try await createUploadSession(fileURL: url, parentID: parentID, fields: fields)
        var request = URLRequest(url: sessionURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType(for: url), forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: url)
        try validate(data: data, response: response)
        return try JSONDecoder().decode(GoogleDriveFile.self, from: data)
    }

    // MARK: - Create Upload Session

    private func createUploadSession(fileURL: URL, parentID: String, fields: String) async throws -> URL {
        let url = try uploadEndpoint("/files", query: ["uploadType": "resumable", "fields": fields])
        var request = authorizedRequest(url: url, method: "POST")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(contentType(for: fileURL), forHTTPHeaderField: "X-Upload-Content-Type")
        request.setValue("\(try fileSize(fileURL))", forHTTPHeaderField: "X-Upload-Content-Length")
        let body: [String: Any] = ["name": fileURL.lastPathComponent, "parents": [parentID]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        guard let location = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Location"),
              let sessionURL = URL(string: location) else {
            throw GoogleDriveError.missingUploadSession
        }
        return sessionURL
    }

    // MARK: - JSON Request

    private func jsonRequest(url: URL, method: String, body: [String: Any]?) async throws -> Data {
        var request = authorizedRequest(url: url, method: method)
        if let body {
            request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        return data
    }

    // MARK: - Authorized Request

    private func authorizedRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    // MARK: - Endpoints

    private func endpoint(_ path: String, query: [String: String]) throws -> URL {
        try makeURL(root: apiRoot, path: path, query: query)
    }

    private func uploadEndpoint(_ path: String, query: [String: String]) throws -> URL {
        try makeURL(root: uploadRoot, path: path, query: query)
    }

    private func makeURL(root: String, path: String, query: [String: String]) throws -> URL {
        guard var components = URLComponents(string: "\(root)\(path)") else { throw GoogleDriveError.invalidURL("\(root)\(path)") }
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw GoogleDriveError.invalidURL("\(root)\(path)") }
        return url
    }

    // MARK: - Helpers

    private func escapeQuery(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
    }

    private func fileSize(_ url: URL) throws -> UInt64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(values.fileSize ?? 0)
    }

    private func contentType(for url: URL) -> String {
        guard let type = UTType(filenameExtension: url.pathExtension),
              let mimeType = type.preferredMIMEType else {
            return "application/octet-stream"
        }
        return mimeType
    }

    private func validate(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GoogleDriveError.requestFailed(http.statusCode, body)
        }
    }
}
