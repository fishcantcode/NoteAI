import Foundation

enum DocumentType {
    case folder
    case file
    case note
}

struct Document: Identifiable {
    let id: UUID
    let name: String
    let type: DocumentType
    let creationDate: Date
    let url: URL 
    var content: String? = nil  
    var fileExtension: String? = nil  
    var difyConversationId: String? = nil  
}
