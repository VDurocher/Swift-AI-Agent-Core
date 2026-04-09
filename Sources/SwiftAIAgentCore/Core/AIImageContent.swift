import Foundation

/// Represents image content that can be attached to a user message.
/// Supported by vision-capable models (GPT-4o, Claude 3+, Gemini 1.5+).
public enum AIImageContent: Sendable, Hashable, Codable {
    /// Remote image URL — fetched by the model at inference time
    case url(URL)
    /// Inline image bytes with explicit MIME type (base64-encoded in API requests)
    case data(Data, mimeType: String)

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
    /// Create image content from a UIImage, JPEG-encoded at the given quality
    static func uiImage(_ image: UIImage, compressionQuality: CGFloat = 0.85) -> AIImageContent? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return nil }
        return .data(data, mimeType: "image/jpeg")
    }
}
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

public extension AIImageContent {
    /// Create image content from an NSImage, PNG-encoded
    static func nsImage(_ image: NSImage) -> AIImageContent? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return .data(png, mimeType: "image/png")
    }
}
#endif
