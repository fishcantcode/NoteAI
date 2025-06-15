import Foundation

class ConfigManager {
    static let shared = ConfigManager()
    private let userDefaults = UserDefaults.standard

     
    private enum PlistKeys {
        static let baseURL = "BASE_URL"
        static let chatAPIKey = "CHAT_MSG_API_KEY"
        static let knowledgeAPIKey = "KNOWLEDGE_API_KEY"
         
        static let openAIAPIKey = "OPENAI_API_KEY"
        static let deepgramAPIKey = "DEEPGRAM_API_KEY"
    }

     
    private enum UserDefaultsKeys {
        static let baseURL = "USER_OVERRIDE_BASE_URL"
        static let chatAPIKey = "USER_OVERRIDE_CHAT_MSG_API_KEY"
        static let knowledgeAPIKey = "USER_OVERRIDE_KNOWLEDGE_API_KEY"
        static let openAIAPIKey = "USER_OVERRIDE_OPENAI_API_KEY"
        static let deepgramAPIKey = "USER_OVERRIDE_DEEPGRAM_API_KEY"
    }

     

    var difyBaseURL: String {
        get {
            userDefaults.string(forKey: UserDefaultsKeys.baseURL) ?? 
            plistValue(forKey: PlistKeys.baseURL) ?? 
            "http://192.168.0.218/v1"  
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaultsKeys.baseURL)
            print("[ConfigManager] Dify Base URL (UserDefaults) updated to: \(newValue)")
        }
    }

    var difyChatAPIKey: String {  
        get {
            userDefaults.string(forKey: UserDefaultsKeys.chatAPIKey) ?? 
            plistValue(forKey: PlistKeys.chatAPIKey) ?? 
            "app-fwXnQZPSDK6QqyoXEaMZRcfX"  
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaultsKeys.chatAPIKey)
        }
    }

    var difyKnowledgeID: String {  
        get {
            userDefaults.string(forKey: UserDefaultsKeys.knowledgeAPIKey) ?? 
            plistValue(forKey: PlistKeys.knowledgeAPIKey) ?? 
            "dataset-ooZF2QFSdrp671kt8RmQEdN8"  
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaultsKeys.knowledgeAPIKey)
        }
    }

     
    var isDifyChatConfigured: Bool {
        return !difyBaseURL.isEmpty && !difyChatAPIKey.isEmpty
    }

     
    var openAIAPIKey: String {
        get {
            userDefaults.string(forKey: UserDefaultsKeys.openAIAPIKey) ?? 
            plistValue(forKey: PlistKeys.openAIAPIKey) ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaultsKeys.openAIAPIKey)
        }
    }

     
    var deepgramAPIKey: String {
        get {
            userDefaults.string(forKey: UserDefaultsKeys.deepgramAPIKey) ?? 
            plistValue(forKey: PlistKeys.deepgramAPIKey) ?? ""
        }
        set {
            userDefaults.set(newValue, forKey: UserDefaultsKeys.deepgramAPIKey)
        }
    }

     
    private func plistValue(forKey key: String) -> String? {  
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            return nil
        }
        return value
    }

     
    
    func updateDifyBaseURLWithIP(_ ipAddress: String) {
        let newBaseURL = "http://\(ipAddress.trimmingCharacters(in: .whitespacesAndNewlines))/v1"
        self.difyBaseURL = newBaseURL  
    }
    
    func updateDifyBaseURLWithFullURL(_ fullURL: String) {
        self.difyBaseURL = fullURL.trimmingCharacters(in: .whitespacesAndNewlines)  
    }

     
    func clearDifySettings() {
        userDefaults.removeObject(forKey: UserDefaultsKeys.chatAPIKey)
        userDefaults.removeObject(forKey: UserDefaultsKeys.knowledgeAPIKey)  
        userDefaults.removeObject(forKey: UserDefaultsKeys.baseURL)        
        print("[ConfigManager] Cleared all Dify settings from UserDefaults.")
    }

    private init() {
        print("[ConfigManager] Initialized. Current Dify settings:")
        print("  Base URL: \(difyBaseURL)")
        print("  Chat API Key: \(difyChatAPIKey.isEmpty ? "Not Set" : "[REDACTED]")")
        print("  Knowledge ID: \(difyKnowledgeID.isEmpty ? "Not Set" : difyKnowledgeID)")
    }
}
