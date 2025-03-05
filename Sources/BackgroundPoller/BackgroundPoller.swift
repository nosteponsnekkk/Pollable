//
//  BackgroundPoller.swift
//
//
//  Created by Oleg on 12.02.2025.
//

import Foundation

public final class BackgroundPoller<D: PollerDelegate>: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDelegate {
    
    // MARK: - Properties
    
    /// The URLRequest to be polled.
    private let request: URLRequest
    
    /// The body data for the polling request (used to create a temporary file).
    private let body: Data?
    
    /// The delegate that will receive the polling results.
    private weak var delegate: D?
    
    /// The number of remaining polling attempts.
    private var attemptsRemaining: Int
    
    /// The delay between retries in nanoseconds.
    private let retryDelay: UInt64
    
    /// The flag that indicates if polling has finished
    private var hasFinished = false
    
    /// The identifier for URLSession
    private let sessionIdentifier: String
    
    /// A background URLSession used for polling.
    private var session: URLSession?
    private var completion: (() -> Void)?
    
    // MARK: - Initialization
    
    /// Initializes a new BackgroundPoller.
    /// - Parameters:
    ///   - request: The URLRequest to be used for polling.
    ///   - body: The body data to be sent with the request.
    ///   - delegate: The delegate to notify once polling is finished.
    ///   - sessionIdentifier: The identifier used for the URLSession.
    ///   - attempts: The maximum number of attempts (default is 10).
    ///   - retryDelay: The delay between polling attempts in nanoseconds (default is 15 seconds).
    
    public init(request: URLRequest,
                body: Data?,
                delegate: D?,
                sessionIdentifier: String,
                attempts: Int = 10,
                retryDelay: UInt64 = 15_000_000_000) {
        self.request = request
        self.body = body
        self.delegate = delegate
        self.attemptsRemaining = attempts
        self.retryDelay = retryDelay
        self.sessionIdentifier = sessionIdentifier
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        
        session = URLSession(configuration: config)
        super.init()
    }
    // MARK: - Public Methods
    public func start() {
        performUploadTask()
    }
    public func restore(withCompletion completion: @escaping () -> Void){
        let config = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        
        session = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: .current
        )
        
        self.completion = completion
    }
    
    // MARK: - Private Methods
    private func performUploadTask() {
        guard !hasFinished, let body = body else {
            print("Polling already completed or no body provided.")
            return
        }
        
        do {
            let fileURL = try body.createTempFile()
            let task = session?.uploadTask(with: request, fromFile: fileURL)
            task?.resume()
        } catch {
            print("Failed to create temporary file for polling: \(error.localizedDescription)")
        }
    }
    
    private func retry() {
        guard !hasFinished else {
            return
        }
        if attemptsRemaining < 0 {
            completePolling(result: nil)
            print("❌ Maximum polling attempts reached. Stopping.")
            return
        }
        
        attemptsRemaining -= 1
        print("🔄 Polling... Remaining attempts: \(attemptsRemaining)")
        
        Task {
            do {
                try await Task.sleep(nanoseconds: retryDelay)
                performUploadTask()
            } catch {
                print("❌ Error while waiting to retry: \(error.localizedDescription)")
            }
        }
    }
    
    private func completePolling(result: D.T?) {
        guard !hasFinished else { return }
        hasFinished = true
        delegate?.pollingDidFinish(result: result)
        session?.invalidateAndCancel()
    }
    
    // MARK: - URLSession Delegates
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !hasFinished else {
            return
        }
        if data.isEmpty {
            print("⚠️ Received empty data or polling. Retrying...")
            retry()
            return
        }
        
        
        do {
            let decoded = try JSONDecoder().decode(D.T.self, from: data)
            
            switch decoded.status {
            case .processing:
                throw PollError.theOperationIsRunning
                
            case .finished:
                print("✅ Polling successful. Stopping retries.")
                completePolling(result: decoded)
                
            case .error:
                attemptsRemaining = 0
                throw PollError.pollingFailedToDecode
            }
            
        } catch {
            if let error = error as? PollError {
                print(error.description)
            }
            retry()
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("URLSession task completed with error: \(error.localizedDescription)")
        }
    }
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        if let completion {
            self.completion = nil
            completion()
        }
        
    }
}

private extension BackgroundPoller {
    enum PollError: Error {
        case theOperationIsRunning
        case pollingFailedToDecode
        
        var description: String {
            switch self {
            case .theOperationIsRunning:
                "⏳ Polling is not finished yet"
            case .pollingFailedToDecode:
                "❌ Polling has failed"
            }
        }
    }
}
