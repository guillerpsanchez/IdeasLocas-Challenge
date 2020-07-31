//
//  LoginViewController.swift
//  MyChatCloudFunction
//
//  Created by Guillermo Peñarando Sánchez on 24/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController {
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Correo Electrónico..."
        
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 7, height: 0))
        field.leftViewMode = .always
        return field
    }()
    
    private let passField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Contraseña..."
        field.isSecureTextEntry = true
        
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 7, height: 0))
        field.leftViewMode = .always
        return field
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Iniciar Sesión", for: .normal)
        button.backgroundColor = .link
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "bubble.left.fill")
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inicio de Sesión"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Registro", style: .done, target: self, action: #selector(didTapRegistro))
        
        loginButton.addTarget(self, action: #selector(didtappedLoginButton), for: .touchUpInside)
        emailField.delegate = self
        passField.delegate = self
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passField)
        scrollView.addSubview(loginButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (scrollView.width-size)/2, y: 30, width: size, height: size)
        emailField.frame = CGRect(x: 30, y: imageView.bottom+40, width: scrollView.width-50, height: 50)
        passField.frame = CGRect(x: 30, y: emailField.bottom+7, width: scrollView.width-50, height: 50)
        loginButton.frame = CGRect(x: 30, y: passField.bottom+50, width: scrollView.width-50, height: 50)
    }
    
    //Cuando se pulsa sobre el boton de login se van a seguir una serie de acciones para comprobar que todo esta en orden y que se cargan los datos necesarios para el funcionamiento de la app.
    @objc private func didtappedLoginButton() {
        //Antes de hacer nada, cuando se ejecuta la accion de dar al botón de login se esconde el teclado con ".resignfirstresponder"
        emailField.resignFirstResponder()
        passField.resignFirstResponder()
        //Se sealiza una sencilla comprobación el la cual se comprueba que ninguno de los dos campos esta vacio, si estan vacios se llama a la función loginError()
        guard let email = emailField.text, let password = passField.text, !email.isEmpty, !password.isEmpty else {
            loginError()
            return
        }
        //Se llama a Firebase para realizar el login a traves de email y password de esta forma se realiza el login en sus servidores y se queda la sesion iniciada para futuras sesiones.
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: {authResult, error in
            guard authResult != nil, error == nil else {
                print("Error")
                return
            }
            
            let fixedEmail = ManageDatabase.fixedEmail(email: email)
            ManageDatabase.shared.getDataFor(path: fixedEmail, completion: { result in
                switch result {
                case .success(let data):
                    guard let userData = data as? [String: Any],
                        let userName = userData["user_name"] as? String else {
                            return
                    }
                    //Para poder trabajar bien con los chat se guarda como variable de usuario el nombre de usuario que tiene, de esta forma se podra recuperar los datos de los chat que tenga de forma rapida y limpia.
                    UserDefaults.standard.set("\(userName)", forKey: "username")
                    
                case .failure(let error):
                    print("Failed to read data with error \(error)")
                }
            })
            
            UserDefaults.standard.set(email, forKey: "email")
            
            self.dismiss(animated: true, completion: nil)
        })
    }
    //Esta funcion genera un alert muy simple que permite informar al usuario que algun campo esta vacio y por lo tanto no se le permite hacer un login con los datos que hay.
    func loginError() {
        let alert = UIAlertController(title: "Error", message: "Parece que no has introducido todos los datos para iniciar sesión", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cerrar", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    @objc private func didTapRegistro() {
        let vc = RegisterViewController()
        vc.title = "Registro"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    
}

extension LoginViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == emailField {
            passField.becomeFirstResponder()
        }
        else if textField == passField {
            didtappedLoginButton()
        }
        return true
    }
    
}
