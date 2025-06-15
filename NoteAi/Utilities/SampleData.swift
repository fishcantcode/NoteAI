import Foundation

 

struct SampleData {
    static let documents: [Document] = [
         
        Document(id: UUID(), name: "Project Alpha", type: .folder, creationDate: Date().addingTimeInterval(-86400 * 5), url: URL(string: "file:///dummy/Project%20Alpha")!),
        Document(id: UUID(), name: "Meeting Notes", type: .folder, creationDate: Date().addingTimeInterval(-86400 * 2), url: URL(string: "file:///dummy/Meeting%20Notes")!),
        Document(id: UUID(), name: "Recipes Collection", type: .folder, creationDate: Date().addingTimeInterval(-86400 * 10), url: URL(string: "file:///dummy/Recipes%20Collection")!),
        Document(id: UUID(), name: "Archived Projects", type: .folder, creationDate: Date().addingTimeInterval(-86400 * 30), url: URL(string: "file:///dummy/Archived%20Projects")!),

         
         
         
        Document(id: UUID(), name: "Q3 Roadmap Planning", type: .note, creationDate: Date().addingTimeInterval(-86400 * 4), 
                 url: URL(string: "file:///dummy/Project%20Alpha/Q3%20Roadmap.note")!, 
                 content: "Outline for Q3:\n- Launch new 'Collaboration' feature.\n- Address top 5 user-reported bugs.\n- Begin research for Q4 AI integration."),
        Document(id: UUID(), name: "Client Onboarding Checklist", type: .note, creationDate: Date().addingTimeInterval(-86400 * 1), 
                 url: URL(string: "file:///dummy/Meeting%20Notes/Client%20Onboarding.note")!, 
                 content: "1. Send welcome email.\n2. Schedule kickoff call.\n3. Grant access to platform.\n4. Share documentation links."),
        Document(id: UUID(), name: "Pasta Carbonara Recipe", type: .note, creationDate: Date().addingTimeInterval(-3600 * 5), 
                 url: URL(string: "file:///dummy/Recipes%20Collection/Pasta%20Carbonara.note")!, 
                 content: "Ingredients: Spaghetti, Eggs, Pancetta, Pecorino Romano, Black Pepper. Instructions: ..."),
        Document(id: UUID(), name: "Brainstorming - New App Idea", type: .note, creationDate: Date().addingTimeInterval(-86400 * 15), 
                 url: URL(string: "file:///dummy/Personal%20Ideas/New%20App%20Idea.note")!, 
                 content: "A social platform for sharing dream interpretations. Potential features: dream journal, symbol dictionary, community forum."),

         
        Document(id: UUID(), name: "Market_Research_Report.pdf", type: .file, creationDate: Date().addingTimeInterval(-86400 * 6), 
                 url: URL(string: "file:///dummy/Project%20Alpha/Market_Research_Report.pdf")!, 
                 fileExtension: "pdf"),
        Document(id: UUID(), name: "User_Interview_Audio.mp3", type: .file, creationDate: Date().addingTimeInterval(-86400 * 3), 
                 url: URL(string: "file:///dummy/Meeting%20Notes/User_Interview_Audio.mp3")!, 
                 fileExtension: "mp3"),
        Document(id: UUID(), name: "Company_Logo_Final.png", type: .file, creationDate: Date().addingTimeInterval(-86400 * 9), 
                 url: URL(string: "file:///dummy/Branding/Company_Logo_Final.png")!, 
                 fileExtension: "png"),
        Document(id: UUID(), name: "Financial_Projections.xlsx", type: .file, creationDate: Date().addingTimeInterval(-86400 * 20), 
                 url: URL(string: "file:///dummy/Project%20Alpha/Financial_Projections.xlsx")!, 
                 fileExtension: "xlsx")
    ]

     
    static var exampleFolder: Document {
        documents.first { $0.type == .folder } ?? 
        Document(id: UUID(), name: "Default Folder", type: .folder, creationDate: Date(), url: URL(string: "file:///dummy/defaultfolder")!)
    }

    static var exampleNote: Document {
        documents.first { $0.type == .note && $0.content != nil } ?? 
        Document(id: UUID(), name: "Default Note", type: .note, creationDate: Date(), url: URL(string: "file:///dummy/defaultnote")!, content: "Default note content.")
    }

    static var exampleFile: Document {
        documents.first { $0.type == .file && $0.fileExtension != nil } ?? 
        Document(id: UUID(), name: "Default File.txt", type: .file, creationDate: Date(), url: URL(string: "file:///dummy/defaultfile.txt")!, fileExtension: "txt")
    }
}
