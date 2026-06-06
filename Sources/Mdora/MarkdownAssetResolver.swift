import Foundation
import CoreGraphics
import ImageIO

enum MarkdownAssetResolver {
    static func remoteURL(for source: String) -> URL? {
        guard let url = URL(string: source.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }

        return url
    }

    static func localFileURL(for source: String, relativeTo baseURL: URL?) -> URL? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           !scheme.isEmpty {
            return scheme == "file" ? url.standardizedFileURL : nil
        }

        let path = trimmed.removingPercentEncoding ?? trimmed
        if path.hasPrefix("~") {
            return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).standardizedFileURL
        }

        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        guard let baseURL else { return nil }
        return baseURL.appendingPathComponent(path).standardizedFileURL
    }
}

final class MarkdownLocalImageCache: @unchecked Sendable {
    static let shared = MarkdownLocalImageCache()

    private final class CachedImage: @unchecked Sendable {
        let image: CGImage

        init(_ image: CGImage) {
            self.image = image
        }
    }

    private let cache = NSCache<NSString, CachedImage>()
    private let inFlightLock = NSLock()
    private var inFlightLoads: [NSString: Task<CGImage?, Never>] = [:]
    private let previewMaxPixelDimension = 1_600

    private init() {
        cache.countLimit = 128
        cache.totalCostLimit = 256 * 1024 * 1024
    }

    func cachedPreviewImage(for url: URL) -> CGImage? {
        cachedPreviewImage(for: url, maxPixelDimension: previewMaxPixelDimension)
    }

    func cachedPreviewImage(for url: URL, maxPixelDimension: Int) -> CGImage? {
        let standardizedURL = url.standardizedFileURL
        let clampedPixelDimension = max(64, maxPixelDimension)
        let key = cacheKey(for: standardizedURL, maxPixelDimension: clampedPixelDimension)
        if let cached = cache.object(forKey: key) {
            return cached.image
        }

        return nil
    }

    func loadPreviewImage(for url: URL) -> CGImage? {
        loadPreviewImage(for: url, maxPixelDimension: previewMaxPixelDimension)
    }

    func loadPreviewImage(for url: URL, maxPixelDimension: Int) -> CGImage? {
        let standardizedURL = url.standardizedFileURL
        let clampedPixelDimension = max(64, maxPixelDimension)
        let key = cacheKey(for: standardizedURL, maxPixelDimension: clampedPixelDimension)
        if let cached = cache.object(forKey: key) {
            return cached.image
        }

        guard let image = Self.loadThumbnail(from: standardizedURL, maxPixelDimension: clampedPixelDimension) else { return nil }
        cache.setObject(CachedImage(image), forKey: key, cost: cost(for: image))
        return image
    }

    func loadPreviewImageInBackground(for url: URL) async -> CGImage? {
        await loadPreviewImageInBackground(for: url, maxPixelDimension: previewMaxPixelDimension)
    }

    func loadPreviewImageInBackground(for url: URL, maxPixelDimension: Int) async -> CGImage? {
        let standardizedURL = url.standardizedFileURL
        let clampedPixelDimension = max(64, maxPixelDimension)
        let key = cacheKey(for: standardizedURL, maxPixelDimension: clampedPixelDimension)

        if let cached = cachedPreviewImage(for: standardizedURL, maxPixelDimension: clampedPixelDimension) {
            return cached
        }

        let task = loadTask(for: standardizedURL, key: key, maxPixelDimension: clampedPixelDimension)
        let image = await task.value
        clearFinishedLoad(for: key)
        return image
    }

    func removeAll() {
        cache.removeAllObjects()
        let tasks = cancelInFlightLoads()
        for task in tasks {
            task.cancel()
        }
    }

    private func loadTask(
        for url: URL,
        key: NSString,
        maxPixelDimension: Int
    ) -> Task<CGImage?, Never> {
        inFlightLock.lock()
        if let existing = inFlightLoads[key] {
            inFlightLock.unlock()
            return existing
        }

        let task = Task.detached(priority: .utility) { [self] in
            loadPreviewImage(for: url, maxPixelDimension: maxPixelDimension)
        }
        inFlightLoads[key] = task
        inFlightLock.unlock()
        return task
    }

    private func cacheKey(for url: URL, maxPixelDimension: Int) -> NSString {
        "\(url.absoluteString)|\(maxPixelDimension)" as NSString
    }

    private func clearFinishedLoad(for key: NSString) {
        inFlightLock.lock()
        inFlightLoads[key] = nil
        inFlightLock.unlock()
    }

    private func cancelInFlightLoads() -> [Task<CGImage?, Never>] {
        inFlightLock.lock()
        let tasks = Array(inFlightLoads.values)
        inFlightLoads.removeAll()
        inFlightLock.unlock()
        return tasks
    }

    private static func loadThumbnail(from url: URL, maxPixelDimension: Int) -> CGImage? {
        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
    }

    private func cost(for image: CGImage) -> Int {
        max(1, image.bytesPerRow * image.height)
    }
}
