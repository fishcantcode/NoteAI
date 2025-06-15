import Foundation

struct MessageFile: Codable, Identifiable, Equatable {
    var id: String { uploadFileId ?? url ?? UUID().uuidString }
    var type: String
    var transferMethod: String
    var url: String?
    var uploadFileId: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case transferMethod = "transfer_method"
        case url
        case uploadFileId = "upload_file_id"
    }
}
