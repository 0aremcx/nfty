//
//  Throttle.swift
//  NFTY
//
//  Created by Varun Kohli on 2/12/22.
//

import Foundation

class UrlTaskThrottle {
  
  let queue : DispatchQueue
  let deadline:DispatchTimeInterval
  let urlSession : URLSession
  
  init(queue:DispatchQueue,deadline:DispatchTimeInterval,timeoutIntervalForRequest:Double,timeoutIntervalForResource:Double) {
    self.queue = queue
    self.deadline = deadline
    
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
    configuration.timeoutIntervalForResource = timeoutIntervalForResource
    configuration.httpShouldUsePipelining = true
    configuration.httpMaximumConnectionsPerHost = 2
    
    self.urlSession = URLSession(configuration:configuration)
  }
  
  struct Task {
    let request:URLRequest
    let completionHandler : (Data?, URLResponse?, Error?) -> Void
  }
  private var tasks : [Task] = []
  private var isPending = false
  
  func enqueue(
    with request: URLRequest,
    completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
      self.queue.async {
        self.tasks.append(Task(request:request,completionHandler:completionHandler))
        self.next()
      }
    }
  
  private func next() {
    queue.async {
      if (self.isPending || self.tasks.isEmpty) { return }
      self.isPending = true
      let task = self.tasks.removeFirst()
      self.queue.asyncAfter(deadline:.now() + self.deadline) {
        print("UrlTaskThrottle Calling url=\(task.request.url!)")
        
        self.urlSession.dataTask(with: task.request, completionHandler: { data, response, error in
          self.queue.async {
            task.completionHandler(data,response,error)
            self.isPending = false
            self.next()

          }
        }).resume()
      }
    }
  }
  
}
