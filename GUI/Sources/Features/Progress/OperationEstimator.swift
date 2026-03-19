// OperationEstimator.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Pre-operation estimator — computes file counts, sizes, and estimated time
//   BEFORE starting lengthy operations. Uses fast shallow enumeration.

import Foundation

// MARK: - Operation Estimator

@MainActor
final class OperationEstimator {
    
    // Speed assumptions (conservative, bytes/sec)
    private enum Speed {
        static let localSSD: Int64 = 400_000_000      // 400 MB/s
        static let localHDD: Int64 = 80_000_000       // 80 MB/s
        static let networkFast: Int64 = 12_000_000    // 100 Mbps = ~12 MB/s
        static let networkSlow: Int64 = 1_000_000     // 8 Mbps = ~1 MB/s
        static let deletePerFile: TimeInterval = 0.001 // 1ms per file delete
    }
    
    static let shared = OperationEstimator()
    private init() {}
    
    // MARK: - Public API
    
    /// Estimate operation cost without full recursive scan.
    /// Uses shallow enumeration + extrapolation for directories.
    func estimate(
        urls: [URL],
        operation: FileOperationType,
        destination: URL? = nil,
        isRemote: Bool = false,
        isSlowNetwork: Bool = false
    ) async -> OperationEstimate {
        
        var totalFiles = 0
        var totalDirs = 0
        var totalBytes: Int64 = 0
        
        for url in urls {
            let (files, dirs, bytes) = await estimateURL(url)
            totalFiles += files
            totalDirs += dirs
            totalBytes += bytes
        }
        
        let seconds = estimateTime(
            operation: operation,
            files: totalFiles,
            bytes: totalBytes,
            destination: destination,
            isRemote: isRemote,
            isSlowNetwork: isSlowNetwork
        )
        
        return OperationEstimate(
            totalFiles: totalFiles,
            totalDirectories: totalDirs,
            totalBytes: totalBytes,
            estimatedSeconds: seconds
        )
    }
    
    // MARK: - Private: URL estimation
    
    /// Fast estimate for a single URL (file or directory)
    private func estimateURL(_ url: URL) async -> (files: Int, dirs: Int, bytes: Int64) {
        let fm = FileManager.default
        
        // Get resource values
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .fileSizeKey,
            .totalFileSizeKey,
            .directoryEntryCountKey
        ]
        
        guard let values = try? url.resourceValues(forKeys: keys) else {
            return (1, 0, 0)
        }
        
        let isDir = values.isDirectory ?? false
        
        if !isDir {
            // Simple file
            let size = Int64(values.totalFileSize ?? values.fileSize ?? 0)
            return (1, 0, size)
        }
        
        // Directory — use shallow enumeration + extrapolation
        let childCount = values.directoryEntryCount ?? 0
        
        if childCount == 0 {
            return (0, 1, 0)
        }
        
        // Sample first level to estimate avg file size and dir ratio
        var sampleFiles = 0
        var sampleDirs = 0
        var sampleBytes: Int64 = 0
        let sampleLimit = min(childCount, 100)  // Sample max 100 items
        
        let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
        
        var count = 0
        while let itemURL = enumerator?.nextObject() as? URL, count < sampleLimit {
            count += 1
            let itemValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if itemValues?.isDirectory == true {
                sampleDirs += 1
            } else {
                sampleFiles += 1
                sampleBytes += Int64(itemValues?.fileSize ?? 0)
            }
        }
        
        // Extrapolate from sample
        let ratio = Double(childCount) / Double(max(sampleFiles + sampleDirs, 1))
        let avgFileSize: Int64 = sampleFiles > 0 ? sampleBytes / Int64(sampleFiles) : 50_000
        
        // Estimate subdirectory depth factor (assume avg 2 levels deep)
        let depthFactor: Double = 3.0
        
        let estFiles = Int(Double(sampleFiles) * ratio * depthFactor)
        let estDirs = Int(Double(sampleDirs) * ratio * depthFactor) + 1
        let estBytes = Int64(Double(estFiles)) * avgFileSize
        
        return (estFiles, estDirs, estBytes)
    }
    
    // MARK: - Private: Time estimation
    
    private func estimateTime(
        operation: FileOperationType,
        files: Int,
        bytes: Int64,
        destination: URL?,
        isRemote: Bool,
        isSlowNetwork: Bool
    ) -> TimeInterval {
        
        switch operation {
        case .delete:
            // Delete is mostly metadata ops, very fast
            return Double(files) * Speed.deletePerFile
            
        case .copy, .move, .archive, .extract:
            let speed: Int64
            if isRemote {
                speed = isSlowNetwork ? Speed.networkSlow : Speed.networkFast
            } else if let dest = destination, isOnSSD(dest) {
                speed = Speed.localSSD
            } else {
                speed = Speed.localHDD
            }
            // Add overhead per file (metadata, open/close)
            let ioTime = TimeInterval(bytes) / TimeInterval(speed)
            let overhead = Double(files) * 0.002  // 2ms per file overhead
            return ioTime + overhead
            
        case .upload, .download:
            let speed = isSlowNetwork ? Speed.networkSlow : Speed.networkFast
            return TimeInterval(bytes) / TimeInterval(speed)
        }
    }
    
    /// Simple heuristic: assume /Volumes paths are HDD, others SSD
    private func isOnSSD(_ url: URL) -> Bool {
        let path = url.path
        // External drives often under /Volumes
        if path.hasPrefix("/Volumes/") { return false }
        // Network shares
        if path.hasPrefix("/net/") || path.hasPrefix("/mnt/") { return false }
        return true
    }
}
