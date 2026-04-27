import Foundation

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var stub: (statusCode: Int, body: Data)?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static func makeSession(statusCode: Int, body: Data) -> URLSession {
        stub = (statusCode, body)
        lastRequest = nil
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    nonisolated override class func canInit(with request: URLRequest) -> Bool { true }
    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    nonisolated override func startLoading() {
        MockURLProtocol.lastRequest = request
        if let stub = MockURLProtocol.stub, let url = request.url {
            let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
        }
    }

    nonisolated override func stopLoading() {}
}
