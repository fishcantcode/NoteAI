import SwiftUI

struct FolderInputSheet: View {
    @Binding var folderName: String
    @Binding var showing: Bool
    var onDone: () -> Void

    var body: some View {
        ZStack {
             
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .edgesIgnoringSafeArea(.all)
                .overlay(Color.black.opacity(0.1))

            VStack {
                 
                HStack {
                    Button("Cancel") {
                        showing = false
                        folderName = ""
                    }
                    Spacer()
                    Text("New Folder")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Done") {
                        if !folderName.isEmpty {
                            onDone()
                            showing = false
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.3))  

                Spacer()

                 
                Image("file")  
                    .resizable()
                    .frame(width: 340, height: 340)
                    .shadow(radius: 8)

                 
                TextField("Untitled", text: $folderName)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(width: 300)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.95)))
                    .shadow(radius: 5)
                    .font(.title2)
                    .padding(.top, 10)

                Spacer()
            }
        }
    }
}
