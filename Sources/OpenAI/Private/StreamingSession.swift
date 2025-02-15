//
//  StreamingSession.swift
//  
//
//  Created by Sergii Kryvoblotskyi on 18/04/2023.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol StreamingProtocol {
    func perform()
    func cancel()
}

final class StreamingSession<ResultType: Codable>: NSObject, Identifiable, URLSessionDelegate, URLSessionDataDelegate, StreamingProtocol {
    
    enum StreamingError: Error {
        case unknownContent
        case emptyContent
    }
    
    var onReceiveContent: ((StreamingSession, ResultType) -> Void)?
    var onProcessingError: ((StreamingSession, Error) -> Void)?
    var onComplete: ((StreamingSession, Error?) -> Void)?
    
    private let streamingCompletionMarker = "[DONE]"
    private let urlRequest: URLRequest
    private lazy var urlSession: URLSession = {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        return session
    }()

    public private(set) var sessionTask: URLSessionDataTask?
    
    init(urlRequest: URLRequest) {
        self.urlRequest = urlRequest
    }
    
    func perform() {
        sessionTask = self.urlSession
            .dataTask(with: self.urlRequest)
        sessionTask?.resume()
    }

    func cancel() {
        sessionTask?.cancel()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?(self, error)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let stringContent = String(data: data, encoding: .utf8) else {
            onProcessingError?(self, StreamingError.unknownContent)
            return
        }
        let jsonObjects = stringContent
            .components(separatedBy: "data:")
            .filter { $0.isEmpty == false }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard jsonObjects.isEmpty == false, jsonObjects.first != streamingCompletionMarker else {
            return
        }
        jsonObjects.forEach { jsonContent  in
            guard jsonContent != streamingCompletionMarker else {
                return
            }
            guard let jsonData = jsonContent.data(using: .utf8) else {
                onProcessingError?(self, StreamingError.unknownContent)
                return
            }
            do {
                let decoder = JSONDecoder()
                let object = try decoder.decode(ResultType.self, from: jsonData)
                onReceiveContent?(self, object)
            } catch {
                onProcessingError?(self, error)
            }
        }
    }
}
