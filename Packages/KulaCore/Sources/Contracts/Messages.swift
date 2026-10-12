import Foundation

/// One recent Messages item (SMS or iMessage) the user allowed AI to read.
public struct MessageSnapshot: Sendable, Hashable, Codable {
    /// Messages row ID; increases with every new message.
    public var id: String
    /// Chat the message belongs to, so a reply is read together with what it answers.
    public var conversation: String
    /// Contact name when known, otherwise a masked handle.
    public var sender: String
    public var isFromMe: Bool
    /// Group chat name; nil for one-to-one conversations.
    public var group: String?
    public var date: Date
    public var text: String
    public init(id: String, conversation: String = "", sender: String, isFromMe: Bool, group: String? = nil, date: Date, text: String) {
        self.id = id
        self.conversation = conversation
        self.sender = sender
        self.isFromMe = isFromMe
        self.group = group
        self.date = date
        self.text = text
    }

    public var sequence: Int64 { Int64(id) ?? 0 }
}
