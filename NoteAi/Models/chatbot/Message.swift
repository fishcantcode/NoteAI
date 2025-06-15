import Foundation

struct Message: Identifiable, Codable, Equatable {
    var id: String
    var conversationId: String
    var query: String
    var answer: String
    var createdAt: Int
    var parentMessageId: String?
    var status: String
    var agentThoughts: [String]?
    var error: String?
    var feedback: Feedback?
    var inputs: [String: String]?
    var messageFiles: [MessageFile]?
    private var _retrieverResources: RetrieverResourceWrapper?
    
     
    var retrieverResources: [RetrieverResource] {
        return _retrieverResources?.resources ?? []
    }
    
     
    var createdDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(createdAt))
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
    
    var cleanAnswer: String {
        return answer.replacingOccurrences(
            of: "<think>[\\s\\S]*?</think>",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var thinkingContent: String? {
        if let range = answer.range(of: "<think>(.+?)</think>", options: .regularExpression) {
            let thinking = String(answer[range])
            return thinking.replacingOccurrences(of: "<think>", with: "")
                .replacingOccurrences(of: "</think>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    var isFromUser: Bool {
        return !query.isEmpty && answer.isEmpty
    }
    
     
    init(id: String, conversationId: String, query: String, answer: String, createdAt: Int, parentMessageId: String?, status: String, agentThoughts: [String]?, error: String?, feedback: Feedback?, inputs: [String: String]?, messageFiles: [MessageFile]?, _retrieverResources: RetrieverResourceWrapper?) {
        self.id = id
        self.conversationId = conversationId
        self.query = query
        self.answer = answer
        self.createdAt = createdAt
        self.parentMessageId = parentMessageId
        self.status = status
        self.agentThoughts = agentThoughts
        self.error = error
        self.feedback = feedback
        self.inputs = inputs
        self.messageFiles = messageFiles
        self._retrieverResources = _retrieverResources
    }
    
     
    func withUpdatedAnswer(_ newAnswer: String) -> Message {
        return Message(
            id: self.id,
            conversationId: self.conversationId,
            query: self.query,
            answer: newAnswer,
            createdAt: self.createdAt,
            parentMessageId: self.parentMessageId,
            status: self.status,
            agentThoughts: self.agentThoughts,
            error: self.error,
            feedback: self.feedback,
            inputs: self.inputs,
            messageFiles: self.messageFiles,
            _retrieverResources: self._retrieverResources
        )
    }
    
     
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case query
        case answer
        case createdAt = "created_at"
        case parentMessageId = "parent_message_id"
        case status
        case agentThoughts = "agent_thoughts"
        case error
        case feedback
        case inputs
        case messageFiles = "message_files"
        case _retrieverResources = "retriever_resources"
    }
    
     
    static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id &&
               lhs.conversationId == rhs.conversationId &&
               lhs.query == rhs.query &&
               lhs.answer == rhs.answer &&
               lhs.createdAt == rhs.createdAt &&
               lhs.parentMessageId == rhs.parentMessageId &&
               lhs.status == rhs.status &&
               lhs.agentThoughts == rhs.agentThoughts &&
               lhs.error == rhs.error &&
               lhs.feedback == rhs.feedback &&
               lhs.inputs == rhs.inputs &&
               lhs.messageFiles == rhs.messageFiles &&
               lhs.retrieverResources.count == rhs.retrieverResources.count &&
               lhs.retrieverResources.elementsEqual(rhs.retrieverResources)
    }
}
