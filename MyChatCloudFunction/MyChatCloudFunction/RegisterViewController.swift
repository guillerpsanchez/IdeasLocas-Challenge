//
//  RegisterViewController.swift
//  MyChatCloudFunction
//
//  Created by Guillermo Peñarando Sánchez on 24/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import FirebaseAuth

class RegisterViewController: UIViewController {
    
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
    
    private let userNameField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Usuario..."
        
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
    
    private let registerButton: UIButton = {
        let button = UIButton()
        button.setTitle("Registrarse", for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.circle.fill")
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.black.cgColor
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inicio de Sesión"
        view.backgroundColor = .systemBackground
        
        registerButton.addTarget(self, action: #selector(didtappedregisterButton), for: .touchUpInside)
        
        emailField.delegate = self
        passField.delegate = self
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(userNameField)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passField)
        scrollView.addSubview(registerButton)
        
        imageView.isUserInteractionEnabled = true
        scrollView.isUserInteractionEnabled = true
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapChangeProfilePic))
        
        imageView.addGestureRecognizer(gesture)
    }
    
    //Cuando se pulsa sobre la imagen se ejecuta una funcion que le da a elegir al usuario de donde quiere sacar la foto para su perfil.
    @objc private func didTapChangeProfilePic() {
        presentPhoto()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let size = scrollView.width/3
        imageView.frame = CGRect(x: (scrollView.width-size)/2, y: 30, width: size, height: size)
        imageView.layer.cornerRadius = imageView.width/2.0
        userNameField.frame = CGRect(x: 30, y: imageView.bottom+40, width: scrollView.width-50, height: 50)
        emailField.frame = CGRect(x: 30, y: userNameField.bottom+15, width: scrollView.width-50, height: 50)
        passField.frame = CGRect(x: 30, y: emailField.bottom+15, width: scrollView.width-50, height: 50)
        registerButton.frame = CGRect(x: 30, y: passField.bottom+50, width: scrollView.width-50, height: 50)
    }
    
    //Cuando se pulsa el boton de registrarse se realizan una serie de comprobaciones para ver que todo esta corecto, primero se mira que las casillas tengan texto y que ninguna este vacia, despues se coteja con la base de datos comprobando que no exista ningun usuario con el mismo email, se da de alta al usuario con los datos introducidos y por ultimo se sube la imagen de perfil al servidor.
    @objc private func didtappedregisterButton() {
        emailField.resignFirstResponder()
        passField.resignFirstResponder()
        
        guard let username = userNameField.text, let email = emailField.text, let password = passField.text, !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            registerError()
            return
        }
        
        ManageDatabase.shared.checkNewUser(with: email, completion: { exists in
            guard !exists else {
                self.registerError()
                return
            }
            
            FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password, completion: { authResult, error in
                guard authResult != nil, error == nil else {
                    self.registerError()
                    return
                }
                
                ManageDatabase.shared.newUser(with: ChatAppUser(userName: username, emailAddress: email), completion: {success in
                    if success {
                        guard let image = self.imageView.image, let data = image.pngData() else {
                            return
                        }
                        let charUser = ChatAppUser(userName: username, emailAddress: email)
                        let fileName = charUser.profilePictureFileName
                        ManageStorage.shared.uploadProfilePicture(with: data, fileName: fileName, completion: {result in
                            switch result {
                            case .success(let downloadUrl):
                                UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                self.registerSuccess()
                                print(downloadUrl)
                            case .failure(let error):
                                print(error)
                            }
                        })
                    }
                })
            })
        })
        
    }
    
    //si se genera algun error al registrarse (ya existe el usuario o la contraseña es muy corta se muestra un alert informando al usuario que hay algun tipo de error.
    func registerError() {
        let alert = UIAlertController(title: "Error", message: "Se ha producido un error al procesar los datos introducidos, compruebalos y vuelve a intentarlo.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cerrar", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    //Si el registro no deuvelve ningun error se muestra este alert dando a entender al usuario que el registro se ha realizado con exito
    func registerSuccess() {
        let alert = UIAlertController(title: "Éxito", message: "La cuenta ha sido creada con exito, ya puedes logearte en la aplicación.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cerrar", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
}

//Con esta extensión se permite que se pueda navegar de forma correcta entre las casillas, es decir al pulsar enter que salte de una casilla a otra o que se ejcute la accion de pulsar el boton directamente.
extension RegisterViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == emailField {
            passField.becomeFirstResponder()
        }
        else if textField == passField {
            didtappedregisterButton()
        }
        return true
    }
    
}

extension RegisterViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    //Cuando se llama a esta funcion se genera un alert en al pantalla con 3 botones, el primer boton permite hacer una foto con la camapra y para ello se llama a la funcion openCamera(), el segundo botón permite escoger una imagen de la galeria llamando a openGallery() y el tercer boton simplemente cancela el alert.
    func presentPhoto() {
        let action = UIAlertController(title: "Imagen de perfil", message: "¿De donde te gustaria obtener la foto?", preferredStyle: .alert)
        
        action.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: nil))
        action.addAction(UIAlertAction(title: "Hacer foto", style: .default, handler: {  _ in self.openCamera() }))
        action.addAction(UIAlertAction(title: "Escoger foto", style: .default, handler: {  _ in self.openGallery() }))
        
        present(action, animated: true)
    }
    
    //Se genera un UIImagePicker que va a recibir la imagen desde la camara.
    func openCamera() {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
        vc.allowsEditing = true
        present(vc, animated: true)
    }
    
    //Se genera un UIImagePicker que recibe una imagen desde la galeria.
    func openGallery() {
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
        vc.allowsEditing = true
        present(vc, animated: true)
    }
    
    //Cuando se ha escogido una foto ya sea desde la camara o desde la galería se añade esa imagen al imageView general cambiandolo de la iamgen por defecto a la que se acaba de obtener
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        //Aqui escogemos la editedimage la cual es una imagen cuadrada que el usuario previamente ha encuadrado. De esta forma se normalizan todas las imagenes que entran.
        guard let selectedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        
        self.imageView.image = selectedImage
    }
    
    //si se cancela cualquiera de las dos opciones (cámara o galería)
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
}
