import Foundation

extension String {
     
     
    func drop(prefix: String) -> String? {
        guard self.hasPrefix(prefix) else { return nil }
        return String(self.dropFirst(prefix.count))
    }
}
