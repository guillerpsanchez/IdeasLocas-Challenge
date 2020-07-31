//
//  NewConversationViewController.swift
//  MyChatCloudFunction
//
//  Created by Guillermo Peñarando Sánchez on 24/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit

class NewConversationViewController: UIViewController {
    
    // MARK: - Declaración de variables
    private var users = [[String: String]]()
    private var gotUsersFromFirebase = false
    private var results = [SearchResult]()
    public var completion: ((SearchResult) -> (Void))?
    
    // MARK: - Creación programatica de elementos de interfaz.
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Buscar usuario..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(NewChatCell.self, forCellReuseIdentifier: NewChatCell.identifier)
        return table
    }()
    
    private let noResults: UILabel = {
        let label = UILabel()
        label.text = "Sin resultados"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20, weight: .bold)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(noResults)
        view.addSubview(tableView)
        view.backgroundColor = .systemBackground
        
        tableView.delegate = self
        tableView.dataSource = self
        
        searchBar.delegate = self
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancelar", style: .done, target: self, action: #selector(dismissFunc))
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = view.bounds
        noResults.frame = CGRect(x: view.width/4, y: (view.height-200)/2, width: view.width/2, height: 150)
    }
    
    //Esta funcion permite que cuando se pulse sobre cancelar se haga un "dismiss" de la ventana de busqueda.
    @objc private func dismissFunc() {
            dismiss(animated: true, completion: nil)
        }
}

extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: NewChatCell.identifier, for: indexPath) as! NewChatCell
        cell.configure(with: model)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // start conversation
        let targetUserData = results[indexPath.row]

        dismiss(animated: true, completion: { [weak self] in
            self?.completion?(targetUserData)
        })
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
}

extension NewConversationViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return
        }
        //Cuando se ejecuta la accion de buscar "pulsar enter" primero se ciera el chat para que no moleste, despues se eliminan antiguos resultados si existian, para que no se solapen y por ultimo se realiza la busqueda.
        searchBar.resignFirstResponder()
        results.removeAll()
        self.searchUser(query: text)
    }
    
        func searchUser(query: String) {
            //Si existe el array de usuarios de forma local, simplemente se llama a la funcion filterUser que se encarga de filtrar los usuarios con el String que le llega
            if gotUsersFromFirebase {
                self.filterUser(with: query)
            } else {
                //En caso de que no exista el array de usuarios de froma local se va a cargar desde firebase y despues de se va a filtrar para mostrar el usuario que se ha buscado.
                ManageDatabase.shared.getAllUsers(completion: {result in
                    switch result {
                    case .success(let usersCollection):
                        self.gotUsersFromFirebase = true
                        self.users = usersCollection
                        self.filterUser(with: query)
                    case .failure:
                        return
                    }
                })
                
            }
        }
    
    //Se filtran los usuarios segun el termino introducido en la casilla de busqueda, para que sea una busqueda mas facil se busca el texto como prefijo de esta forma se muestran todos los usuario que comienzen por el texto introducido ej: "mateo" se introduce y se muestra "mateo_2000" "mateobatman19" etc...
    func filterUser(with term: String) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String, gotUsersFromFirebase else {
            return
        }

        let fixedEmail = ManageDatabase.fixedEmail(email: currentUserEmail)

        let results: [SearchResult] = users.filter({
            guard let email = $0["email"], email != fixedEmail else {
                return false
            }

            guard let username = $0["username"]?.lowercased() else {
                return false
            }

            return username.hasPrefix(term.lowercased())
        }).compactMap({

            guard let email = $0["email"],
                let username = $0["username"] else {
                return nil
            }

            return SearchResult(name: username, email: email)
        })

        self.results = results
        
        updateInterface()
    }
    func updateInterface() {
        if results.isEmpty {
            self.noResults.isHidden = false
            self.tableView.isHidden = true
        } else {
            self.noResults.isHidden = true
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
}

struct SearchResult {
    let name: String
    let email: String
}
