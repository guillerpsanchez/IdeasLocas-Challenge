//
//  ProfileViewController.swift
//  MyChatCloudFunction
//
//  Created by Guillermo Peñarando Sánchez on 24/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import FirebaseAuth
import SDWebImage

//Este view es muy simple, muestra un boton y una imagen, la imagen es la imagen de perfil del usuario y el boton le permite cerrar sesión.
class ConfigViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    
    let data = ["Cerrar sesión"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "celda")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = tableHeader()
    }
    
    func tableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let fixedEmail = ManageDatabase.fixedEmail(email: email)
        let fileName = "\(fixedEmail)_profile_picture.png"
        let path = "images/\(fileName)"
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 250))
        
        let imageView = UIImageView(frame: CGRect(x: (view.width-150) / 2, y: 50, width: 150, height: 150))
        
        
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderWidth = 2
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width/2
        
        view.addSubview(imageView)
        
        ManageStorage.shared.downloadURL(for: path, completion: {result in
            switch result {
            case .success(let url):
                imageView.sd_setImage(with: url, completed: nil)
                print(url)
            case .failure:
                return
            }
        })
        
        return view
    }
    
}

extension ConfigViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "celda", for: indexPath)
        cell.textLabel?.text = data[indexPath.row]
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.textColor = .systemRed
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let alertMessage = UIAlertController(title: "¿Estas seguro?", message: "", preferredStyle: .alert)
        
        alertMessage.addAction(UIAlertAction(title: "Cerrar Sesión", style: .destructive, handler: { _ in
            //Si el usuario decide cerrar sesion simplemente se le dice a firebase que queremos realizar esta accion lo cual sera automatico, una vez completado se llama al view controller de login para que pueda volver a logearse o crear una nueva cuenta si quiere.
        do {
            try FirebaseAuth.Auth.auth().signOut()
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true)
        } catch {
            
        }
        }))
        
        alertMessage.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: nil))
            
        present(alertMessage, animated: true)
        
    }
}
