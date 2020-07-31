//
//  ChatViewController.swift
//  MyChatCloudFunction
//
//  Created by Guillermo Peñarando Sánchez on 25/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import RNCryptor

final class ChatViewController: MessagesViewController {
    
    private var senderPhotoURL: URL?
    private var otherUserPhotoURL: URL?
    
    public let otherUserEmail: String
    public var isNewChat = false

    private var messages = [Message]()
    
    private var chatId: String?
    
    private var safeText: String?
    
    public static let dateFormatter: DateFormatter = {
        let formattre = DateFormatter()
        formattre.dateStyle = .medium
        formattre.timeStyle = .long
        formattre.locale = .current
        return formattre
    }()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = ManageDatabase.fixedEmail(email: email)

        return Sender(photoURL: "", senderId: safeEmail, displayName: "Yo")
    }
    
    init(with email: String, id: String?) {
        self.chatId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
    }
    //Esta funcion se queda "escuchando" continuamente al servidor para recibir nuevos mensajes en caso de que exista alguno.
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        ManageDatabase.shared.getAllMessagesForChat(with: id, completion: { result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else { return }
                
                self.messages = messages

                self.messagesCollectionView.reloadDataAndKeepOffset()

                if shouldScrollToBottom {
                    self.messagesCollectionView.scrollToBottom()
                }
                
            case .failure(_):
                break
            }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let chatId = chatId {
            listenForMessages(id: chatId, shouldScrollToBottom: true)
        }
    }
    
}

//funcion para encriptar string.
func encryptMessage(message: String, encryptionKey: String) throws -> String {
    let messageData = message.data(using: .utf8)!
    let cipherData = RNCryptor.encrypt(data: messageData, withPassword: encryptionKey)
    return cipherData.base64EncodedString()
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty, let selfSender = self.selfSender, let messageID = generateMessageID() else {
            return
        }
        
        //Se desencripta el mensaje cuando se va a enviar al servidor, de esta forma solamente esta desencriptado cuando el mensaje esta en el terminal, es decir es un cifrado de punto a punto.
        do {
            safeText = try encryptMessage(message: text, encryptionKey: chatId ?? "chat_\(messageID)")
        } catch {
            print("error")
        }
        
        
        let message = Message(sender: selfSender, messageId: messageID, sentDate: Date(), kind: .text(safeText!))
        if isNewChat {
            //Si el chat es nuevo se crea uno nuevo en la base de datos con como primer mensaje el que se acaba de enviar. Una vez se ha ejecutado la accion correctamente se llama al "listener" que va a estar esperando continuamente la llegada de nuevos mensajes, consiguiendo asi mensajeria instantanea en tiempo real.
            ManageDatabase.shared.createNewChat(with: otherUserEmail, name: self.title ?? "Usuario", firstMessage: message, completion: { success in
                if success {
                        self.isNewChat = false
                        let newChatId = "chat_\(message.messageId)"
                        self.chatId = newChatId
                    print("\(newChatId)")
                        self.listenForMessages(id: newChatId, shouldScrollToBottom: true)
                        self.messageInputBar.inputTextView.text = nil
                    } else { return }})
        } else {
            //Si el chat ya existe simplemente se envia el mensaje.
                    guard let chatId = self.chatId, let name = self.title else {
                        return
                    }
                    ManageDatabase.shared.sendMessage(to: chatId, otherUserEmail: self.otherUserEmail, username: name, newMessage: message, completion: {  success in
                        if success {
                            self.messageInputBar.inputTextView.text = nil
                        }
                        else { return}})
                }
    }
    
    //Se genera un message ID unico para cada mensaje, para poder identificarlos de froma sencilla y poder ordenarlos cronologicamente.
    private func generateMessageID() -> String? {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }

        let fixedCurrentEmail = ManageDatabase.fixedEmail(email: currentUserEmail)

        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(fixedCurrentEmail)_\(dateString)"

        return newIdentifier
    }
}
struct Message: MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind

}

struct Sender: SenderType {
    public var photoURL: String
    public var senderId: String
    public var displayName: String
    
}


extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {

            let sender = message.sender

            if sender.senderId == selfSender?.senderId {
                // Se carga nuestra imagen de perfil para mostrarla en la burbuja de mensaje.
                if let currentUserImageURL = self.senderPhotoURL {
                    avatarView.sd_setImage(with: currentUserImageURL, completed: nil)
                }
                else {
                    guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                        return
                    }

                    let fixedEmail = ManageDatabase.fixedEmail(email: email)
                    let path = "images/\(fixedEmail)_profile_picture.png"

                    ManageStorage.shared.downloadURL(for: path, completion: { [weak self] result in
                        switch result {
                        case .success(let url):
                            self?.senderPhotoURL = url
                            DispatchQueue.main.async {
                                avatarView.sd_setImage(with: url, completed: nil)
                            }
                        case .failure(let error):
                            print("\(error)")
                        }
                    })
                }
            }
            else {
                // Se carga la imagen del otro usuario con el que estamos hablando en la burbuja demensaje.
                if let otherUserPhotoURL = self.otherUserPhotoURL {
                    avatarView.sd_setImage(with: otherUserPhotoURL, completed: nil)
                }
                else {
                    let email = self.otherUserEmail

                    let fixedEmail = ManageDatabase.fixedEmail(email: email)
                    let path = "images/\(fixedEmail)_profile_picture.png"

                    ManageStorage.shared.downloadURL(for: path, completion: { result in
                        switch result {
                        case .success(let url):
                            self.otherUserPhotoURL = url
                            DispatchQueue.main.async {
                                avatarView.sd_setImage(with: url, completed: nil)
                            }
                        case .failure(_):
                            break
                        }
                    })
                }
            }

        }
    }
