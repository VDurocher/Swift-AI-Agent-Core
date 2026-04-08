import Foundation
import SwiftData

/// Persistent record of an individual message in a conversation
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
@Model
public final class MessageRecord {
    public var id: UUID
    /// Message role: "user", "assistant" or "system"
    public var role: String
    public var content: String
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
