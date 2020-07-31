//
//  ManageDatabase.swift
//  MyChatCloudFunction
//
//  Created by Guillermo Peñarando Sánchez on 25/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import Foundation
import FirebaseDatabase
import MessageKit
import RNCryptor

final class ManageDatabase {
    
    static let shared = ManageDatabase()
    
    private let database = Database.database().reference()
    
    //debido a las limitaciones de la base de datos en teimpo real de firebase, el uso de @ y. no esta permitido por lo cual he decidido cambiarlo por _ para evitarlo.
    static func fixedEmail(email: String) -> String {
        var fixedEmail = email.replacingOccurrences(of: ".", with: "_")
        fixedEmail = fixedEmail.replacingOccurrences(of: "@", with: "_")
        return fixedEmail
    }
    
}

extension ManageDatabase {
    
    //Esta funcion sirve para obtener el username de la base de datos del usuario actual, para poder enviar y recibir mas adelante de forma correcta los mensajes.
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
            database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
                guard let value = snapshot.value else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(value))
            }
        }

    //Con esta funcion se genera un nuevo chat, basicamente lo que se hace es crear la entrada en la base de datos del chat con todos sus datos.
    public func createNewChat(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String, let currentUserName = UserDefaults.standard.value(forKey: "username") as? String else {
                return
        }
        //se crean estas dos variables para poder trabajar de forma mas como despues
        let fixedEmail = ManageDatabase.fixedEmail(email: currentEmail)
        let reference = database.child("\(fixedEmail)")
        
        reference.observeSingleEvent(of: .value, with: { snapshot in
            guard var userNode = snapshot.value as? [String: Any]  else {
                completion(false)
                return
            }
            //Se guarda la fecha del primer mensaje de la conversacion y se le da un formato utilizable.
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            
            //se obtiene el texto del mensaje y se guarda en una variable, debido a como funciona MessageKit hay que utilizar un switch ya que los mensajes pueden ser de muchos tipos.
            switch firstMessage.kind {
                
            case .text(let messageText):
                message = messageText
            default:
                message = ""
            }
            
            //se genera un id de chat.
            let ID = "chat_\(firstMessage.messageId)"
            
            //se generan dos array uno para la informacion del que escribe el mensaje y otro del que recibe el mismo.
            let newChat: [String: Any] = ["ID": ID, "other_user_email": otherUserEmail,"name": name,"latest_message": ["date": dateString,"message": message,"is_read": false]]
            
            let receiver_newChat: [String: Any] = ["ID": ID, "other_user_email": otherUserEmail,"name": currentUserName,"latest_message": ["date": dateString,"message": message,"is_read": false]]
            
            
            self.database.child("\(otherUserEmail)/chats").observeSingleEvent(of: .value, with: { snapshot in
                    if var chats = snapshot.value as? [[String: Any]] {
                        // si ya existia se añade despues del ultimo mensaje
                        chats.append(receiver_newChat)
                        self.database.child("\(otherUserEmail)/chats").setValue(chats)
                    }
                    else {
                        // si no existe, se crea una nueva entrada en la base de datos con los datos generados antes.
                        self.database.child("\(otherUserEmail)/chats").setValue([receiver_newChat])
                    }
                })


                if var chats = userNode["chats"] as? [[String: Any]] {
                    chats.append(newChat)
                    userNode["chats"] = chats
                    reference.setValue(userNode, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        self.finishCreatingChat(name: name, chatID: ID, firstMessage: firstMessage, completion: completion)
                    })
                }
                else {
                    userNode["chats"] = [ newChat ]

                    reference.setValue(userNode, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }

                        self.finishCreatingChat(name: name, chatID: ID, firstMessage: firstMessage, completion: completion)
                    })
                }
            })
    }
    
    //Se llama a la base de datos y se obtiene una lista con todos los chat del email que le pasamos.
    public func getAllChats(for email: String, completion: @escaping (Result<[Chat], Error>) -> Void) {
        database.child("\(email)/chats").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            let chats: [Chat] = value.compactMap({ dictionary in
                
                guard let chatID = dictionary["ID"] as? String,
                    let name = dictionary["name"] as? String,
                    let otherUserEmail = dictionary["other_user_email"] as? String,
                    let latestMessage = dictionary["latest_message"] as? [String: Any],
                    let date = latestMessage["date"] as? String,
                    let message = latestMessage["message"] as? String,
                    let isRead = latestMessage["is_read"] as? Bool else {
                        return nil
                }

                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Chat(id: chatID, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            })

            completion(.success(chats))
        })
    }
    
    //esta funcion sirve para desencriptar los mensajes que han sido encriptados, de esta forma nunca se va a tener el mensaje encriptado en el servidor.
    func decryptMessage(encryptedMessage: String, encryptionKey: String) throws -> String {

        let encryptedData = Data.init(base64Encoded: encryptedMessage)!
        let decryptedData = try RNCryptor.decrypt(data: encryptedData, withPassword: encryptionKey)
        let decryptedString = String(data: decryptedData, encoding: .utf8)!

        return decryptedString
    }
    
    //Igual que getAllChats() pero en este caso se recibe el id del chat y se obtienen los mensajes del chat.
    public func getAllMessagesForChat(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let messages: [Message] = value.compactMap({ dictionary in
                var safeText: String?
                do {
                    safeText = try self.decryptMessage(encryptedMessage: (dictionary["content"] as? String)!, encryptionKey: id)
                } catch {
                    print("error")
                }
                
                
                guard let name = dictionary["name"] as? String,
                    let _ = dictionary["is_read"] as? Bool,
                    let messageID = dictionary["id"] as? String,
                    let content = safeText,
                    let senderEmail = dictionary["sender_email"] as? String,
                    let _ = dictionary["type"] as? String,
                    let dateString = dictionary["date"] as? String,
                    let date = ChatViewController.dateFormatter.date(from: dateString)else {
                        return nil
                }
                var kind: MessageKind?
                kind = .text(content)
                
                let sender = Sender(photoURL: "", senderId: senderEmail,
                                    displayName: name)

                return Message(sender: sender, messageId: messageID, sentDate: date, kind: kind!)
            })

            completion(.success(messages))
        })
    }
    //Esta funcion es algo larga, pero es muy sencilla, lo que hace es basicamente añadir el mensaje recibido a la lista de mensajes, actualizar cual es el ultimo mensaje de quien envia el mensaje y de quien lo recibe.
    public func sendMessage(to chat: String, otherUserEmail: String, username: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }

        let currentFixedEmail = ManageDatabase.fixedEmail(email: myEmail)

        database.child("\(chat)/messages").observeSingleEvent(of: .value, with: { snapshot in
            //se guarda la lista de mensajes que ya existen
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }

            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)

            var message = ""
            switch newMessage.kind {
                
            case .text(let messageText):
                message = messageText
            default:
                message = ""
            }

            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }

            let currentUserEmail = ManageDatabase.fixedEmail(email: myEmail)
            
            let newMessageEntry: [String: Any] = ["id": newMessage.messageId, "type": newMessage.kind.messageKindString, "content": message, "date": dateString, "sender_email": currentUserEmail, "is_read": false, "name": username]
            //se añade el nuevo mensaje a los que ya existian.
            currentMessages.append(newMessageEntry)

            self.database.child("\(chat)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }

                self.database.child("\(currentFixedEmail)/chats").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryChats = [[String: Any]]()
                    let updatedValue: [String: Any] = [ "date": dateString, "is_read": false, "message": message]

                    if var currentUserChats = snapshot.value as? [[String: Any]] {
                        var targetChat: [String: Any]?
                        var position = 0

                        for chatDictionary in currentUserChats {
                            if let currentId = chatDictionary["id"] as? String, currentId == chat {
                                targetChat = chatDictionary
                                break
                            }
                            position += 1
                        }

                        if var targetChat = targetChat {
                            targetChat["latest_message"] = updatedValue
                            currentUserChats[position] = targetChat
                            databaseEntryChats = currentUserChats
                        }
                        else {
                            let newChatData: [String: Any] = ["id": chat, "other_user_email": ManageDatabase.fixedEmail(email: otherUserEmail), "name": username, "latest_message": updatedValue]
                            currentUserChats.append(newChatData)
                            databaseEntryChats = currentUserChats
                        }
                    }
                    else {
                        let newChatData: [String: Any] = ["id": chat, "other_user_email": ManageDatabase.fixedEmail(email: otherUserEmail), "name": username, "latest_message": updatedValue]
                        databaseEntryChats = [newChatData]
                    }

                    self.database.child("\(currentFixedEmail)/chats").setValue(databaseEntryChats, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        self.database.child("\(otherUserEmail)/chats").observeSingleEvent(of: .value, with: { snapshot in
                            let updatedValue: [String: Any] = [
                                "date": dateString,
                                "is_read": false,
                                "message": message
                            ]
                            var databaseEntryChats = [[String: Any]]()

                            guard let currentName = UserDefaults.standard.value(forKey: "username") as? String else {
                                return
                            }

                            if var otherUserChats = snapshot.value as? [[String: Any]] {
                                var targetChat: [String: Any]?
                                var position = 0

                                for chatDictionary in otherUserChats {
                                    if let currentId = chatDictionary["id"] as? String, currentId == chat {
                                        targetChat = chatDictionary
                                        break
                                    }
                                    position += 1
                                }

                                if var targetChat = targetChat {
                                    targetChat["latest_message"] = updatedValue
                                    otherUserChats[position] = targetChat
                                    databaseEntryChats = otherUserChats
                                }
                                else {
                                    let newChatData: [String: Any] = ["id": chat, "other_user_email": ManageDatabase.fixedEmail(email: currentFixedEmail), "name": currentName, "latest_message": updatedValue]
                                    otherUserChats.append(newChatData)
                                    databaseEntryChats = otherUserChats
                                }
                            }
                            else {
                                let newChatData: [String: Any] = ["id": chat, "other_user_email": ManageDatabase.fixedEmail(email: currentFixedEmail), "name": currentName, "latest_message": updatedValue]
                                databaseEntryChats = [newChatData]
                            }

                            self.database.child("\(otherUserEmail)/chats").setValue(databaseEntryChats, withCompletionBlock: { error, _ in
                                guard error == nil else {
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                        })
                    })
                })
            }
        })
    }
    
    private func finishCreatingChat(name: String, chatID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)

            var message = ""
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            default:
                message = ""
            }

            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }

            let currentUserEmail = ManageDatabase.fixedEmail(email: myEmail)

            let collectionMessage: [String: Any] = ["id": firstMessage.messageId, "type": "text", "content": message, "date": dateString, "sender_email": currentUserEmail, "is_read": false, "name": name]

            let value: [String: Any] = ["messages":[collectionMessage]]

            database.child("\(chatID)").setValue(value, withCompletionBlock: { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                completion(true)
            })
        }
    
    //Se comprueba en la base de datos si existe ya un chat con la persona con la que se quiere hablar si la encuentra se devuelve el ID de la conversación para poder cargarla, si no, se devuelve un error.
    public func chatExists(with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
            let safeRecipientEmail = ManageDatabase.fixedEmail(email: targetRecipientEmail)
            guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                return
            }
            let fixedSenderEmail = ManageDatabase.fixedEmail(email: senderEmail)

            database.child("\(safeRecipientEmail)/chats").observeSingleEvent(of: .value, with: { snapshot in
                guard let collection = snapshot.value as? [[String: Any]] else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }

                if let conversation = collection.first(where: {
                    guard let targetSenderEmail = $0["other_user_email"] as? String else {
                        return false
                    }
                    return fixedSenderEmail == targetSenderEmail
                }) {
                    guard let id = conversation["id"] as? String else {
                        completion(.failure(DatabaseError.failedToFetch))
                        return
                    }
                    completion(.success(id))
                    return
                }

                completion(.failure(DatabaseError.failedToFetch))
                return
            })
        }
    //Se comprueba si el usuario (con el email) ya existe en la base de datos.
    public func checkNewUser(with email: String, completion: @escaping ((Bool) -> Void)) {
        
        var fixedEmail = email.replacingOccurrences(of: ".", with: "_")
        fixedEmail = fixedEmail.replacingOccurrences(of: "@", with: "_")
        
        database.child(fixedEmail).observeSingleEvent(of: .value, with: {snapshot in
            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }
            
            completion(true)
        })
    }
    //Esta funcion sirve para registrar en la base de datos un usuario nuevo.
    public func newUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.fixedEmail).setValue(["user_name": user.userName], withCompletionBlock: {error, _ in
            guard error == nil else{
                completion(false)
                return
            }
            
            self.database.child("usuarios").observeSingleEvent(of: .value, with: { snapshot in
                if var receivedCollection = snapshot.value as? [[String: String]] {
                    //Se añade el usuario creado al array de usuarios.
                    let addedCollection = ["username": user.userName, "email": user.fixedEmail]
                    
                    receivedCollection.append(addedCollection)
                    
                    self.database.child("usuarios").setValue(receivedCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                    })
                }
                else {
                    //Se crea el array de usuarios si este no existe (solo se deberia ejecutar una vez)
                    let Collection: [[String: String]] = [["username": user.userName, "email": user.fixedEmail]]
                    
                    self.database.child("usuarios").setValue(Collection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)})}})
            completion(true)})
    }
    
    //Con esta funcion se cachea en el terminal la lista de usuarios permitiendo reducir la cantidad de consultas a la base de datos.
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("usuarios").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }

            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
}


extension MessageKind {
    var messageKindString: String {
        return "text"
    }
}

struct ChatAppUser {
    let userName: String
    let emailAddress: String
    
    var fixedEmail: String {
        var fixedEmail = emailAddress.replacingOccurrences(of: ".", with: "_")
        fixedEmail = fixedEmail.replacingOccurrences(of: "@", with: "_")
        return fixedEmail
    }
    
    var profilePictureFileName: String {
        return "\(fixedEmail)_profile_picture.png"
    }
}

struct Chat {
    let id: String
    let name: String
    let otherUserEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage {
    let date: String
    let text: String
    let isRead: Bool
}
