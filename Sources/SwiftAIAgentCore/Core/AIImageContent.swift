import Foundation

/// Represents image content that can be attached to a user message.
/// Supported by vision-capable models (GPT-4o, Claude 3+, Gemini 1.5+).
public enum AIImageContent: Sendable, Hashable, Codable {
    /// Remote image URL — must use HTTPS or HTTP scheme; fetched by the model at inference time
    case url(URL)
    /// Inline image bytes with explicit MIME type (base64-encoded in API requests).
    /// Maximum size: 20 MB. Allowed types: image/jpeg, image/png, image/gif, image/webp.
    case data(Data, mimeType: String)

    // MARK: - Validation

    /// Allowed MIME types for inline image data
    private static let allowedMimeTypes: Set<String> = [
        "image/jpeg", "image/png", "image/gif", "image/webp"
    ]

    /// Maximum inline image size accepted by the major providers (20 MB)
    private static let maxDataSize = 20 * 1024 * 1024

    /// Validates and returns the image content, or throws if the input is invalid.
    /// Call this before passing user-controlled data to an agent.
    public func validated() throws -> AIImageContent {
        switch self {
        case .url(let url):
            guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
                throw AIError.invalidContext("Image URL must use an HTTP(S) scheme")
            }
            return self

        case .data(let bytes, let mime):
            guard Self.allowedMimeTypes.contains(mime) else {
                throw AIError.invalidContext(
                    "Unsupported MIME type '\(mime)'. Allowed: \(Self.allowedMimeTypes.sorted().joined(separator: ", "))"
                )
            }
            guard bytes.count <= Self.maxDataSize else {
                throw AIError.invalidContext(
                    "Image data exceeds the 20 MB limit (\(bytes.count / 1_024 / 1_024) MB provided)"
                )
            }
            return self
        }
    }

    // MARK: - Accessors

    /// Base64-encoded image bytes, or nil for URL images
    public var base64String: String? {
        guard case .data(let bytes, _) = self else { return nil }
        return bytes.base64EncodedString()
    }

    /// MIME type of the image, or nil for URL images
    public var mimeType: String? {
        guard case .data(_, let mime) = self else { return nil }
        return mime
    }

    /// The remote URL, or nil for data images
    public var remoteURL: URL? {
        guard case .url(let url) = self else { return nil }
        return url
    }
}

#if canImport(UIKit)
import UIKit

public extension AIImageContent {
    /// Create image content from a UIImage, JPEG-encoded at the given quality.
    /// Returns nil if JPEG encoding fails.
    static func uiImage(_ image: UIImage, compressionQuality: CGFloat = 0.85) -> AIImageContent? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return nil }
        return .data(data, mimeType: "image/jpeg")
    }
}
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

public extension AIImageContent {
    /// Create image content from an NSImage, PNG-encoded.
    /// Returns nil if PNG encoding fails.
    static func nsImage(_ image: NSImage) -> AIImageContent? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return .data(png, mimeType: "image/png")
    }
}
#endif
