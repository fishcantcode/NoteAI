import SwiftUI

struct CardView: View {
    let document: Document

     
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(document.name)
                .font(.headline)
                .lineLimit(2)

            Spacer()

            switch document.type {
            case .file:
                let fileExtensionValue = document.fileExtension ?? document.url.pathExtension
                if !fileExtensionValue.isEmpty {
                    Text("Type: \(fileExtensionValue.uppercased())")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Text("File")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            case .note:
                if let content = document.content, !content.isEmpty {
                    Text(content)
                        .font(.subheadline)
                        .lineLimit(3)
                        .foregroundColor(.secondary)
                } else {
                    Text("Note")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            case .folder: 
                Image(systemName: "folder.fill") 
                    .foregroundColor(.blue)
                Text("Folder")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(dateFormatter.string(from: document.creationDate))
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(minHeight: 120, maxHeight: 150) 
        .background(Color(.systemGray6)) 
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        let exampleFile = Document(id: UUID(), name: "My Important Report.pdf", type: .file, creationDate: Date(), url: URL(string: "file:///dummy/My Important Report.pdf")!, fileExtension: "pdf")
        let exampleNote = Document(id: UUID(), name: "Quick Idea", type: .note, creationDate: Date(), url: URL(string: "file:///dummy/note1")!, content: "This is a brilliant idea for a new feature that will revolutionize the app.")
        let exampleFolder = Document(id: UUID(), name: "Project Alpha", type: .folder, creationDate: Date(), url: URL(string: "file:///dummy/Project Alpha")!)


        return VStack(spacing: 20) {
            CardView(document: exampleFile)
            CardView(document: exampleNote)
            CardView(document: exampleFolder)
        }
        .padding()
    }
}
