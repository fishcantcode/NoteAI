import Foundation

 
struct RetrieverResourceWrapper: Codable {
    let resources: [RetrieverResource]
    
    init(resources: [RetrieverResource] = []) {
        self.resources = resources
    }
    
     
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        do {
             
            self.resources = try container.decode([RetrieverResource].self)
        } catch {
             
            let singleResource = try container.decode(RetrieverResource.self)
            self.resources = [singleResource]
        }
    }
}
