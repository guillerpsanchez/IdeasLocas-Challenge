//
//  ViewController.swift
//  MyChatCloudFunction
//
//  Created by Guillermo Peñarando Sánchez on 24/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import FirebaseAuth

class ConversationsViewController: UIViewController {
    
    private var chats = [Chat]()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ChatTableViewCell.self,
                       forCellReuseIdentifier: ChatTableViewCell.identifier)
        return table
    }()
    
    private let noChats: UILabel = {
        let label = UILabel()
        label.text = "No hay ningún chat creado."
        label.textAlignment = .center
        label.textColor = .darkGray
        label.font = .systemFont(ofSize: 21, weight: .bold)
        label.isHidden = true
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTappedComposeNewChat))
        
        
        view.addSubview(tableView)
        view.addSubview(noChats)
        
        self.setupTableView()
        self.getConversations()
        
        
    }
    
    //Cuando se pulsa sobre el "+" se genera un nuevo view que permite buscar usuarios con los que comenzar una conversación.
    @objc private func didTappedComposeNewChat() {
        let vc = NewConversationViewController()
        vc.completion = { result in
            let currentChats = self.chats
            
            if let targetChat = currentChats.first(where: {
                $0.otherUserEmail == ManageDatabase.fixedEmail(email: result.email)
            }) {
                let vc = ChatViewController(with: targetChat.otherUserEmail, id: targetChat.id)
                vc.isNewChat = false
                vc.title = targetChat.name
                vc.navigationItem.largeTitleDisplayMode = .never
                self.navigationController?.pushViewController(vc, animated: true)
            }
            else {
                self.createNewChat(result: result)
            }
        }
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
    //Cuando se ha buscado un nuevo usuario con el conversar se llama aesta funcion la cual se encarga de comprobar si la conversación ay existe, si existe simplemente la abre y si no tambien la abre pero estara vacia ya que no hay mensajes.
    private func createNewChat(result: SearchResult) {
        let username = result.name
        let email = ManageDatabase.fixedEmail(email: result.email)
        
        ManageDatabase.shared.chatExists(with: email, completion: {  result in
            
            switch result {
            case .success(let conversationId):
                let vc = ChatViewController(with: email, id: conversationId)
                vc.isNewChat = false
                vc.title = username
                vc.navigationItem.largeTitleDisplayMode = .never
                self.navigationController?.pushViewController(vc, animated: true)
            case .failure(_):
                let vc = ChatViewController(with: email, id: nil)
                vc.isNewChat = true
                vc.title = username
                vc.navigationItem.largeTitleDisplayMode = .never
                self.navigationController?.pushViewController(vc, animated: true)
            }
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noChats.frame = CGRect(x: 10, y: (view.height-100)/2, width: view.width-20, height: 100)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
    }
    
    private func validateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
        }
    }
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    //Se obtienen todas las conversaciones que se tienen abiertas con otro usuario, de esta forma si se encuentra alguna conversacion, se ocultara el mensaje de que no hay chats y se mostrara la lista de las conversacion que hay, en caso de error se dejara el mensaje de que no hay chats.
    private func getConversations() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        let safeEmail = ManageDatabase.fixedEmail(email: email)
        
        ManageDatabase.shared.getAllChats(for: safeEmail, completion: { result in
            switch result {
            case .success(let chats):
                guard !chats.isEmpty else {
                    self.tableView.isHidden = true
                    self.noChats.isHidden = false
                    return
                }
                self.noChats.isHidden = true
                self.tableView.isHidden = false
                self.chats = chats
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            case .failure(_):
                self.tableView.isHidden = true
                self.noChats.isHidden = false
            }
        })
    }
    
    
}

extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = chats[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatTableViewCell.identifier,
                                                 for: indexPath) as! ChatTableViewCell
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = chats[indexPath.row]
        openChat(model)
    }
    
    func openChat(_ model: Chat) {
        let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
}
