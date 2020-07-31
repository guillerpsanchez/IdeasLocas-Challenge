//
//  ManageStorage.swift
//  MyChatCloudFunction
//
//  Created by Guillermo Peñarando Sánchez on 25/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import Foundation
import FirebaseStorage

final class ManageStorage {
    static let shared = ManageStorage()
    
    private let storage = Storage.storage().reference()
    
    //Sube al servidor la imagen que recibe y la guarda en la carpeta images.
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: { metadata, error in
            guard error == nil else {
                completion(.failure(StorageError.uploadFailed))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL(completion: {url, error in
                guard let url = url else {
                    completion(.failure(StorageError.urlFailed))
                    return
                }
                let urlString = url.absoluteString
                completion(.success(urlString))
            })
        })
    }
    
    public enum StorageError: Error {
        case uploadFailed
        case urlFailed
    }
    //Se obtiene la url de descarga de la imagen a la que hace referencia con el "path"
    public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let reference = storage.child(path)

        reference.downloadURL(completion: { url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageError.urlFailed))
                return
            }

            completion(.success(url))
        })
    }
}
