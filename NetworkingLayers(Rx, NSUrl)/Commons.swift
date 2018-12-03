//
//  NetwrokingConstants.swift
//  APIClient
//
//  Created by David on 21/03/2018.
//  Copyright © 2018 David. All rights reserved.
//

import Foundation

enum NetworkError: Error {
    case invalidURL(_: String)
    case error(_: ResponseProtocol)
    case noResponse()
    case invalidResponse()
    case emptyData()
    case missingEndpoint
}
enum RequestMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

public struct RequestBody {
    
    /// Data to carry out into the body of the request
    let data: Any
    /// Type of encoding to use
    let encoding: Encoding
    
    public enum Encoding {
//        case rawData
//        case rawString(_: String.Encoding?)
        case json
//        case urlEncoded(_: String.Encoding?)
//        case custom(_: CustomEncoder)
        
    }
    private init(_ data: Any, as encoding: Encoding = .json) {
        self.data = data
        self.encoding = encoding
    }
    
    /// Create a new body which will be encoded as JSON
    ///
    /// - Parameter data: any serializable to JSON object
    /// - Returns: RequestBody
    public static func json(_ data: Any) -> RequestBody {
        return RequestBody(data, as: .json)
    }
    
    public func encodedData() -> Data {
        switch self.encoding {
        case .json:
            do {
                let encodedData = try JSONEncoder().encode(self.data as! Data)
                return encodedData
            } catch let encodingError {
                fatalError("Encoding Error, with data: \(String(describing: String(data: self.data as! Data, encoding: .utf8))) & Error:\(encodingError.localizedDescription)")
            }
        }
    }
    
}
