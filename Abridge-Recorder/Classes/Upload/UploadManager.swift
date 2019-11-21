//
//  UploadManager.swift
//  AVAudioEngine
//
//  Created by arvindhsukumar on 21/11/19.
//  Copyright © 2019 arvindh. All rights reserved.
//

import UIKit
import Moya

public class UploadManager: NSObject {
  private var provider: MoyaProvider<API>
  
  init(provider: MoyaProvider<API> = MoyaProvider<API>()) {
    self.provider = provider
    super.init()
  }
  
  func upload(params: UploadParams, progress: @escaping ProgressBlock, completion: @escaping (Error?) -> Void) {
    self.getUploadURL(params: params) {
      [weak self] (result) in
      guard let this = self else {
        return
      }
      
      switch result {
      case .failure(let error):
        completion(error)
      case .success(let uploadResponse):
        this.uploadFile(
          params,
          uploadResponse,
          progress: progress,
          completion: completion
        )
      }
    }
  }
  
  fileprivate func getUploadURL(params: UploadParams, completion: @escaping (Result<UploadResponse, Error>) -> Void) {
    provider.request(API.getUploadURL(params: params)) {
      (result) in
      
      switch result {
      case .failure(let error):
        completion(Result.failure(error))
      case .success(let response):
        do {
          let uploadResponse = try response.map(UploadResponse.self)
          completion(Result.success(uploadResponse))
        }
        catch {
          completion(Result.failure(error))
        }
      }
    }
  }
  
  fileprivate func uploadFile(_ params: UploadParams, _ uploadResponse: UploadResponse, progress: @escaping ProgressBlock, completion: @escaping (Error?) -> Void) {
    provider.request(
      API.upload(params: params, uploadResponse: uploadResponse),
      callbackQueue: DispatchQueue.main,
      progress: progress,
      completion: {
      [weak self](result) in
        completion(result.error)
      }
    )
  }
}
