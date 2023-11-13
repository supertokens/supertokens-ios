//
//  GithubLoginURLProtocol.swift
//  with-thirdparty
//
//  Created by Nemi Shah on 13/11/23.
//

import Foundation

public class GithubLoginProtocol: URLProtocol {
    public override class func canInit(with request: URLRequest) -> Bool {
        if let url: String = request.url?.absoluteString, url == "https://github.com/login/oauth/access_token" {
            return true
        }
        
        return false
    }
    
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    public override func startLoading() {
        var mutableRequest = (self.request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        mutableRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        let customSession = URLSession(configuration: URLSessionConfiguration.default)
        
        let apiRequest = mutableRequest.copy() as! URLRequest
        customSession.dataTask(with: apiRequest) {
            data, response, error in
            
            self.resolveToUser(data: data, response: response, error: error)
        }.resume()
    }
    
    public override func stopLoading() {
        // do nothing
    }
    
    func resolveToUser(data: Data?, response: URLResponse?, error: Error?) {
        // This will call the appropriate callbacks and return the data back to the user
        if error != nil {
            self.client?.urlProtocol(self, didFailWithError: error!)
        }
        
        if data != nil {
            self.client?.urlProtocol(self, didLoad: data!)
        }
        
        if response != nil {
            self.client?.urlProtocol(self, didReceive: response!, cacheStoragePolicy: .notAllowed)
        }
        
        // After everything, we need to call this to indicate to URLSession that this protocol has finished its task
        self.client?.urlProtocolDidFinishLoading(self)
    }
}
