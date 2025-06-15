import SwiftUI

struct ConnectionStatusIndicator: View {
    @ObservedObject var apiManager = APIManager.shared

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)  
            Text(statusHint)
                .font(.caption)
        }
        .onAppear {
             
             
             
             
        }
    }

    private var statusColor: Color {
        switch apiManager.overallConnectionStatus {
        case .connected:
            return .green
        case .partial:
            return .yellow
        case .disconnected:
            return .red
        case .unknown:
            return .gray
        }
    }

    private var statusHint: String {
        switch apiManager.overallConnectionStatus {
        case .connected:
            return "Connected"
        case .partial:
            return "Partial"
        case .disconnected:
            return "Offline"
        case .unknown:
            return "Checking..."
        }
    }
}

struct ConnectionStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionStatusIndicator()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
