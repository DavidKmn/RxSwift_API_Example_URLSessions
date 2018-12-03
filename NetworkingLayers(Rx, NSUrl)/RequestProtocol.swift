//
//  RequestProtocol.swift
//  APIClient
//
//  Created by David on 21/03/2018.
//  Copyright © 2018 David. All rights reserved.
//

import Foundation
import RxSwift

typealias HeadersDict = [String: String]

public final class ServiceConfiguration {
    
    /// This is the base host url (ie. "http://www.myserver.com/api/v2"
    private(set) var url: URL
    
    /// These are the global headers which must be included in each session of the service
    private(set) var headers: HeadersDict = [:]
    
    /// Cache policy you want apply to each request done with this service
    /// By default is `.useProtocolCachePolicy`.
    public var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    
    /// Global timeout for any request. If you want, you can override it in Request
    /// Default value is 15 seconds.
    public var timeout: TimeInterval = 15.0
    
    private(set) var queue: DispatchQueue = DispatchQueue.global(qos: .background)
    
    public init?(name: String? = nil, base urlString: String) {
        guard let url = URL(string: urlString) else { return nil }
        self.url = url
    }
}


protocol ServiceProtocol {
    
    var configuration: ServiceConfiguration { get }
    
    var headers: HeadersDict { get }
    
    init(config: ServiceConfiguration)
    
    func execute(_ request: RequestProtocol) -> Single<ResponseProtocol>
}

protocol RequestProtocol {
    /// This is the endpoint of the request (ie. `/v2/auth/login`)
    var endpoint: String { get set }
    /// The HTTP method used to perform the request.
    var method: RequestMethod? { get set }
    
    var parameters: Parameters? { get set }
    
    /// This is the time interval of the request.
    /// If not set related `Service` timeout is used.
    var timeout: TimeInterval? { get set }
    
    /// Optional headers to append to the request.
    var headers: HeadersDict? { get set }
    
    /// THe body of the request. Will be encoded based upon the
    var body: RequestBody? { get set }
    
    /// This is the default cache policy used for this request.
    /// If not set related `Service` policy is used.
    var cachePolicy: URLRequest.CachePolicy? { get set }
    
    func url(in service: ServiceProtocol) -> URL
    
    func urlRequest(in service: ServiceProtocol) -> URLRequest

}

extension RequestProtocol {
    
    func headers(in service: ServiceProtocol) -> HeadersDict {
        var params: HeadersDict = service.headers // initial set is composed by service's current headers
        // append (and replace if needed) with request's headers
        self.headers?.forEach({ k,v in params[k] = v })
        return params
    }
    
    func url(in service: ServiceProtocol) -> URL {
        let baseURL = service.configuration.url.absoluteString.appending(self.endpoint)
        guard let url = URL(string: baseURL) else {
            fatalError("Invalid url: \(baseURL)")
        }
        return url
    }
    
    public func urlRequest(in service: ServiceProtocol) -> URLRequest {
        // Compose default full url
        let requestURL = self.url(in: service)
        // Setup cache policy, timeout and headers of the request
        let cachePolicy = self.cachePolicy ?? service.configuration.cachePolicy
        let timeout = self.timeout ?? service.configuration.timeout
        let headers = self.headers(in: service)
        
        // Create the URLRequest object
        var urlRequest = URLRequest(url: requestURL, cachePolicy: cachePolicy, timeoutInterval: timeout)
        urlRequest.httpMethod = (self.method ?? .get).rawValue // if not specified default HTTP method is GET
        urlRequest.allHTTPHeaderFields = headers
        if let bodyData = self.body?.encodedData() { // set body if specified
            urlRequest.httpBody = bodyData
        }
        return urlRequest
    }

}

class Request: RequestProtocol {
    
    var body: RequestBody?
    
    var timeout: TimeInterval?
    
    var headers: HeadersDict?
    
    var cachePolicy: URLRequest.CachePolicy?

    var endpoint: String
    
    var method: RequestMethod?
    
    var parameters: Parameters?
    
    init(method: RequestMethod = .get, endpoint: String = "", parameters: Parameters? = nil, body: RequestBody? = nil) {
        self.method = method
        self.endpoint = endpoint
        self.parameters = parameters
    }
    
}

protocol ResponseProtocol {
    
    var type: Response.Result { get }
}

class Response: ResponseProtocol {

    enum Result {
        case success(_: Int)
        case error(_: Int)
        case noResponse
        
        private static let successCodes: Range<Int> = 200..<299
        
        public static func from(response: HTTPURLResponse?) -> Result {
            guard let r = response else {
                return .noResponse
            }
            return (Result.successCodes.contains(r.statusCode) ? .success(r.statusCode) : .error(r.statusCode))
        }
        
        public var code: Int? {
            switch self {
            case .success(let code):
                return code
            case .error(let code):
                return code
            case .noResponse:
                return nil
            }
        }
    }
    
    var type: Response.Result
    /// Status code of the response
    public var httpStatusCode: Int? {
        return self.type.code
    }
    
    public let httpResponse: HTTPURLResponse?
    
    /// Raw data of the response
    public var data: Data?

    init(data: Data, response: HTTPURLResponse) {
        self.type = Result.from(response: response)
        self.httpResponse = response
        self.data = data
    }
    
    public func toString(_ encoding: String.Encoding? = nil) -> String? {
        guard let d = self.data else { return nil }
        return String(data: d, encoding: encoding ?? .utf8)
    }
}

protocol OperationProtocol {
    
    associatedtype T
    
    var request: RequestProtocol? {get set}
    
    func execute(in service: ServiceProtocol) -> Observable<T>
}

class JSONOperation<Output>: OperationProtocol {
    
    typealias T = Output
    
    var request: RequestProtocol?
    
    func execute(in service: ServiceProtocol) -> Observable<Output> {
        return Observable<Output>.create({ (observer) -> Disposable in
            
            guard let request = self.request else {
                observer.onError(NetworkError.missingEndpoint)
                return Disposables.create()
            }
        
            service.execute(request).subscribe({ response in
                
            })
            
            
            return Disposables.create()
        })
    }
    
}

class Service: ServiceProtocol {
    var configuration: ServiceConfiguration
    
    var headers: HeadersDict
    
    required init(config: ServiceConfiguration) {
        self.configuration = config
        self.headers = config.headers
    }
    
    func execute(_ request: RequestProtocol) -> Single<ResponseProtocol> {
        return Single<ResponseProtocol>.create(subscribe: { (observer) -> Disposable in
            
            let request = request.urlRequest(in: self)
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                
                guard let response = response else {
                    observer(.error(NetworkError.noResponse()))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    observer(.error(NetworkError.invalidResponse()))
                    return
                }
                
                guard let data = data else {
                    observer(.error(NetworkError.emptyData()))
                    return
                }
                
                let parsedResponse = Response(data: data, response: httpResponse)
                
                switch parsedResponse.type {
                case .success(_):
                    observer(.success(parsedResponse))
                case .error(_):
                    observer(.error(NetworkError.error(parsedResponse)))
                case .noResponse:
                    observer(.error(NetworkError.noResponse()))
                }
                
            })
            
            task.resume()
            
            return Disposables.create {
                task.cancel()
            }
        })
        
    }
}










