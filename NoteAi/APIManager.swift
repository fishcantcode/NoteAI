import Foundation
import Combine
import SwiftUI

enum APIConnectionStatus {
    case connected
    case partial
    case disconnected
    case unknown
}

enum APIError: Error, LocalizedError, Equatable { 
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case noData
    case decodingError(Error)
    case invalidRequest
    case networkError(Error)
    case encodingError(Error)
    case custom(String)
    case unknownError(Error?)
    case fileAccessError(String)
    case parameterEncodingError(message: String)
    case apiKeyMissing

        var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The provided URL was invalid."
        case .requestFailed(let err):
            return "The network request failed: \(err.localizedDescription)"
        case .invalidResponse:
            return "The server's response was invalid."
        case .decodingError(let err):
            return "Failed to decode the server's response: \(err.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "No additional information")"
        case .noData:
            return "No data was received from the server."
        case .invalidRequest:
            return "The request setup was invalid."
        case .networkError(let error):
            return "A network error occurred: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode the request body: \(error.localizedDescription)"
        case .custom(let message):
            return message
        case .unknownError(let err):
            return "An unknown error occurred: \(err?.localizedDescription ?? "N/A")"
        case .fileAccessError(let msg):
            return "File access error: \(msg)"
        case .parameterEncodingError(let message):
            return "Parameter encoding error: \(message)"
        case .apiKeyMissing:
            return "API key is missing."
        }
    }

        static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case (.requestFailed(let lError), .requestFailed(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        case (.invalidResponse, .invalidResponse):
            return true
        case (.serverError(let lCode, let lMsg), .serverError(let rCode, let rMsg)):
            return lCode == rCode && lMsg == rMsg
        case (.noData, .noData):
            return true
        case (.decodingError(let lError), .decodingError(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        case (.invalidRequest, .invalidRequest):
            return true
        case (.networkError(let lError), .networkError(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        case (.encodingError(let lError), .encodingError(let rError)):
            return lError.localizedDescription == rError.localizedDescription
        case (.custom(let lMsg), .custom(let rMsg)):
            return lMsg == rMsg
        case (.unknownError(let lErr), .unknownError(let rErr)):
            return lErr?.localizedDescription == rErr?.localizedDescription
        case (.fileAccessError(let lMsg), .fileAccessError(let rMsg)):
            return lMsg == rMsg
        case (.parameterEncodingError(let lMsg), .parameterEncodingError(let rMsg)):
            return lMsg == rMsg
        case (.apiKeyMissing, .apiKeyMissing):
            return true
        default:
             
            return false
        }
    }
}

struct PreProcessingRule: Codable {
    let id: String
    let enabled: Bool
}

struct SegmentationRule: Codable {
    let separator: String
    let max_tokens: Int  
}

struct ProcessRules: Codable {
    let pre_processing_rules: [PreProcessingRule]  
    let segmentation: SegmentationRule
}

struct ProcessRuleConfig: Codable {
    let mode: String
    let rules: ProcessRules
}

struct DataPayload: Codable {
    let indexing_technique: String  
    let process_rule: ProcessRuleConfig  
}

class APIManager: ObservableObject {
    static let shared = APIManager()

        @Published var chatServiceStatus: Bool = false
    @Published var knowledgeServiceStatus: Bool = false
    @Published var overallConnectionStatus: APIConnectionStatus = .unknown

    private var cancellables = Set<AnyCancellable>()

        init() {
        checkOverallConnectionStatus()
    }

    private func createRequest(endpoint: String, method: String, apiKey: String, body: Data? = nil) -> URLRequest? {
        let baseURL = ConfigManager.shared.difyBaseURL 
        guard let url = URL(string: baseURL + endpoint) else {
            print("Invalid base URL or endpoint")
            return nil
        }
        let urlRequest = URLRequest(url: url)
        var request = urlRequest
        request.httpMethod = method
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.httpBody = body
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        print("Creating request for URL: \(url.absoluteString), Method: \(method)")
        return request
    }

     
    func fetchDatasets(completion: @escaping (Result<[KnowledgeDataset], APIError>) -> Void) { 
        let endpoint = "/datasets"
        guard let request = createRequest(endpoint: endpoint, method: "GET", apiKey: ConfigManager.shared.difyKnowledgeID) else { 
            completion(.failure(.invalidRequest))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Response Status: \(httpResponse.statusCode)")
                print("HTTP Response Headers: \(httpResponse.allHeaderFields)")
            } else {
                print("Response is not HTTPURLResponse or is nil")
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            if let dataString = String(data: data, encoding: .utf8) {
                print("Raw data string: \(dataString)")
            } else {
                print("Could not convert data to UTF-8 string. Data count: \(data.count)")
            }

            do {
                let decoder = JSONDecoder()
                let datasetListResponse = try decoder.decode(KnowledgeDatasetResponse.self, from: data) 
                completion(.success(datasetListResponse.data)) 
                completion(.success(datasetListResponse.data))  
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }

    func createDataset(name: String, description: String? = nil, indexingTechnique: String = "high_quality", permission: String = "only_me", completion: @escaping (Result<KnowledgeDataset, APIError>) -> Void) {  
        let endpoint = "/datasets"
        
         
        let requestBody = CreateKnowledgeDatasetRequest(
            name: name,
            description: description, 
            indexingTechnique: indexingTechnique,
            permission: permission
        )

        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
            completion(.failure(.encodingError(EncodingError.invalidValue(requestBody, EncodingError.Context(codingPath: [], debugDescription: "Failed to encode CreateKnowledgeDatasetRequest")))))
            return
        }

         
        guard let request = createRequest(endpoint: endpoint, method: "POST", apiKey: ConfigManager.shared.difyKnowledgeID, body: jsonData) else {  
            completion(.failure(.invalidRequest))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
             
             
            if (200...299).contains(httpResponse.statusCode) {
                guard let data = data else {
                    completion(.failure(.noData))  
                    return
                }
                do {
                    let decoder = JSONDecoder()
                     
                    let createdDataset = try decoder.decode(KnowledgeDataset.self, from: data)  
                    completion(.success(createdDataset))  
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            } else {
                 
                if let data = data, let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Failed to create dataset: \(errorResponse.message) (Code: \(errorResponse.code ?? "N/A"))")))
                } else {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Failed to create dataset with status code: \(httpResponse.statusCode)")))
                }
            }
        }.resume()
    }

    func fetchDocuments(datasetId: String, completion: @escaping (Result<[APIDocument], APIError>) -> Void) {
        let endpoint = "/datasets/\(datasetId)/documents"
         
        guard let request = createRequest(endpoint: endpoint, method: "GET", apiKey: ConfigManager.shared.difyKnowledgeID) else {  
            completion(.failure(.invalidRequest))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                 
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let documentListResponse = try JSONDecoder().decode(DocumentListResponse.self, from: data)
                completion(.success(documentListResponse.data))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }

     

    struct UploadedDocumentDetail: Codable {
        let id: String
        let name: String
        let indexing_status: String?
        let created_at: Double  
    }

    struct DocumentUploadResponse: Codable {
        let document: UploadedDocumentDetail
        let batch: String?
    }

        func createDocumentFromFile(datasetId: String, fileURL: URL, indexingTechnique: String = "high_quality", completion: @escaping (Result<DocumentUploadResponse, APIError>) -> Void) {
        let endpoint = "/datasets/\(datasetId)/document/create-by-file"
        guard let url = URL(string: ConfigManager.shared.difyBaseURL + endpoint) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(ConfigManager.shared.difyKnowledgeID)", forHTTPHeaderField: "Authorization")  

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        var humanReadableLog = "--- Constructing Multipart Form Data (CRLF = \\r\\n, LF = \\n) ---\n"
        
        func addToLog(_ stringRepresentation: String) {
            humanReadableLog += stringRepresentation.replacingOccurrences(of: "\r\n", with: "\\r\\n[CRLF]")
                                               .replacingOccurrences(of: "\n", with: "\\n[LF]")
            humanReadableLog += "\n"
        }
        
        func logBinaryDataDescription(_ description: String) {
            humanReadableLog += description + "\n"
        }

         
        let processRule = ProcessRuleConfig(
            mode: "custom",
            rules: ProcessRules(
                pre_processing_rules: [
                    PreProcessingRule(id: "remove_extra_spaces", enabled: true),
                    PreProcessingRule(id: "remove_urls_emails", enabled: true)
                ],
                segmentation: SegmentationRule(separator: "###", max_tokens: 500)
            )
        )
        
        let dataPayload = DataPayload(indexing_technique: indexingTechnique, process_rule: processRule)
        
        do {
            let jsonData = try JSONEncoder().encode(dataPayload)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                completion(.failure(.parameterEncodingError(message: "Failed to convert data payload to JSON string")))
                return
            }

             
            var partString = "--\(boundary)\r\n"
            body.append(partString.data(using: .utf8)!)
            addToLog(partString)

            partString = "Content-Disposition: form-data; name=\"data\"\r\n\r\n"  
            body.append(partString.data(using: .utf8)!)
            addToLog(partString)

             
            body.append(jsonString.data(using: .utf8)!)
            addToLog(jsonString)  

            partString = "\r\n"  
            body.append(partString.data(using: .utf8)!)
            addToLog(partString)

        } catch {
            completion(.failure(.parameterEncodingError(message: "Failed to encode data payload: \(error.localizedDescription)")))
            return
        }

         
        do {
            let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            let fileData = try Data(contentsOf: fileURL)
            let filename = fileURL.lastPathComponent
            let mimetype = fileURL.mimeType()

            var partString = "--\(boundary)\r\n"  
            body.append(partString.data(using: .utf8)!)
            addToLog(partString)

            partString = "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
            body.append(partString.data(using: .utf8)!)
            addToLog(partString)

            partString = "Content-Type: \(mimetype)\r\n\r\n"
            body.append(partString.data(using: .utf8)!)
            addToLog(partString)

            body.append(fileData)
            logBinaryDataDescription("[File Data: \(fileData.count) bytes, Original Filename: \(filename), MIME Type: \(mimetype)]")
            
            partString = "\r\n"  
            body.append(partString.data(using: .utf8)!)
            addToLog(partString)

        } catch {
            completion(.failure(.fileAccessError("Could not read data from file: \(error.localizedDescription)")))
            return
        }

         
        let endBoundaryString = "--\(boundary)--\r\n"
        body.append(endBoundaryString.data(using: .utf8)!)
        addToLog(endBoundaryString)

        print(humanReadableLog)
        print("--- Multipart Form Data Construction Complete ---")

        request.httpBody = body
        
        print("Uploading file: \(fileURL.lastPathComponent) to dataset: \(datasetId) at endpoint: \(endpoint)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }

             
             

            if (200...299).contains(httpResponse.statusCode) {
                do {
                    let decodedResponse = try JSONDecoder().decode(DocumentUploadResponse.self, from: data)
                    completion(.success(decodedResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            } else {
                 
                if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Code: \(apiError.code ?? "N/A"), Message: \(apiError.message ?? "Unknown server error")")))
                } else {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Could not parse error response.")))
                }
            }
        }.resume()
    }

    
    func deleteDataset(datasetId: String, completion: @escaping (Result<Void, APIError>) -> Void) {
         
        let apiKey = ConfigManager.shared.difyKnowledgeID  
        let baseURL = ConfigManager.shared.difyBaseURL

        guard !apiKey.isEmpty else {
            completion(.failure(.apiKeyMissing))
            return
        }
        
        let urlString = "\(baseURL)/datasets/\(datasetId)"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
             
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                 
                if let data = data, let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Failed to delete dataset: \(errorResponse.message) (Code: \(errorResponse.code ?? "N/A"))")))
                } else {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Failed to delete dataset with status code: \(httpResponse.statusCode)")))
                }
            }
        }
        task.resume()
    }

    func deleteDocument(datasetId: String, documentId: String, completion: @escaping (Result<Void, APIError>) -> Void) {
         
        let apiKey = ConfigManager.shared.difyKnowledgeID  
        let baseURL = ConfigManager.shared.difyBaseURL

        guard !apiKey.isEmpty else {
            completion(.failure(.apiKeyMissing))
            return
        }

        let urlString = "\(baseURL)/datasets/\(datasetId)/documents/\(documentId)"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
             
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                 
                if let data = data, let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Failed to delete document: \(errorResponse.message) (Code: \(errorResponse.code ?? "N/A"))")))
                } else {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: "Failed to delete document with status code: \(httpResponse.statusCode)")))
                }
            }
        }
        task.resume()
    }

     
    func checkChatConnection(completion: @escaping (Bool) -> Void) {
                                let chatAPIKeyToCheck = ConfigManager.shared.difyChatAPIKey
        let baseURLToCheck = ConfigManager.shared.difyBaseURL       

        print("Checking Chat API: \(baseURLToCheck)/conversations with key \(chatAPIKeyToCheck.prefix(8))...")
         
         
        guard let url = URL(string: "\(baseURLToCheck)/parameters") else {  
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(chatAPIKeyToCheck)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("Chat API connection successful.")
                    self.chatServiceStatus = true
                    completion(true)
                } else {
                    print("Chat API connection failed. Status: \((response as? HTTPURLResponse)?.statusCode ?? -1), Error: \(error?.localizedDescription ?? "N/A")")
                    self.chatServiceStatus = false
                    completion(false)
                }
            }
        }.resume()
    }

    func checkKnowledgeConnection(completion: @escaping (Bool) -> Void) {
        print("Checking Knowledge API by fetching datasets...")
         
        fetchDatasets { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let datasets):
                    print("Knowledge API connection successful, found \(datasets.count) datasets.")
                    self.knowledgeServiceStatus = true
                    completion(true)
                case .failure(let error):
                    print("Knowledge API connection failed: \(error.localizedDescription)")
                    self.knowledgeServiceStatus = false
                    completion(false)
                }
            }
        }
    }
    
    func checkOverallConnectionStatus() {
        checkChatConnection { [weak self] chatConnected in 
            self?.checkKnowledgeConnection { [weak self] knowledgeConnected in
                guard let self = self else { return }
                
                if chatConnected && knowledgeConnected {
                    self.overallConnectionStatus = .connected
                } else if chatConnected || knowledgeConnected {
                    self.overallConnectionStatus = .partial
                } else {
                    self.overallConnectionStatus = .disconnected
                }
                print("Overall connection status: \(self.overallConnectionStatus)")
            }
        }
    }
    
     
     
     
     
}

 
struct APIErrorResponse: Codable {
    let code: String?
    let message: String?
}

import UniformTypeIdentifiers

extension URL {
    func mimeType() -> String {
        if #available(iOS 14.0, macOS 11.0, *) {
            if let type = UTType(filenameExtension: self.pathExtension) {
                return type.preferredMIMEType ?? "application/octet-stream"
            }
        }
         
         
         
        switch self.pathExtension.lowercased() {
            case "txt": return "text/plain"
            case "pdf": return "application/pdf"
            case "png": return "image/png"
            case "jpg", "jpeg": return "image/jpeg"
            case "doc": return "application/msword"
            case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
             
            default: return "application/octet-stream"
        }
    }
}
