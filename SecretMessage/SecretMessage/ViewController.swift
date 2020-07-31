//
//  ViewController.swift
//  SecretMessage
//
//  Created by Guillermo Peñarando Sánchez on 28/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import ARCL
import CoreLocation
import SceneKit
import MapKit
import Foundation
import RNCryptor

class ViewController: UIViewController {

    var sceneLocationView = SceneLocationView()
    let locationManager = CLLocationManager()
    var newMessage = ""
    var getMessage = ""
    var currentLatitude = 0.0
    var currentLongitude = 0.0
    var currentAltitude = 0.0
    let pasteboard = UIPasteboard.general
    var image = "_".image(withAttributes: [.font: UIFont.systemFont(ofSize: 30.0)])
    
    @IBOutlet weak var newLocation: UIButton!
    @IBOutlet weak var getLocation: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.stopMonitoringSignificantLocationChanges()
        }
        
        sceneLocationView.run()
        view.addSubview(sceneLocationView)
        sceneLocationView.addSubview(newLocation)
        sceneLocationView.addSubview(getLocation)
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sceneLocationView.frame = view.bounds
    }
    
    //Esta funcion permite la carga de mensajes, recibiendo la localizacion gps y el mensaje, pasando el texto a una imagen y presentandola frente al usuario.
    public func ARINIT(latitude: CLLocationDegrees, longitude: CLLocationDegrees, altitude: CLLocationDegrees, message: String)  {
        image = "\(message)".image(withAttributes: [.font: UIFont.systemFont(ofSize: 30.0)])
        let annotationNode = LocationAnnotationNode(location: CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), altitude: altitude), image: image!)
        annotationNode.annotationNode.name = "\(latitude)_\(longitude)_\(message)_\(altitude)"
        sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
    }
    
    // Esta función detecta cuando tocas un mensaje en la pantalla y te devuelve un alert que te copia al portapapeles el codigo cifrado que tienes que enviar a los demas para que puedan mostrarlo en su mapa
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchLocation = touch.location(in: sceneLocationView)
            
            let hitResults = sceneLocationView.hitTest(touchLocation, options: [.boundingBoxOnly : true])
            for result in hitResults {
                
                var encryptedText: String?
                let key = result.node.name
                do {
                    encryptedText = try self.encryptMessage(message: key!, encryptionKey: "id")
                } catch {
                    print("error")
                }
                
                let alert = UIAlertController(title: "Enviar", message: "Este es su mensaje cifrado, compartelo con quien quieras que reciba el mensaje: \(encryptedText ?? "Error al recuperar su mensaje cifrado, vuelve a intentarlo mas tarde.")", preferredStyle: .alert)

                let shareAction = UIAlertAction(title: "Copiar", style: .default, handler: { _ -> Void in
                    self.pasteboard.string = encryptedText
                    alert.dismiss(animated: true, completion: nil)
                 })

                alert.addAction(shareAction)
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    // Cuando se pulsa sobre el + de abajo a la izquierda se genera un alert que permite al usuario poner un mensaje que se añadirá a la aplicación y se mostrara en la localizacion en la que se encuentre el usuario.
    @IBAction func onClickNewLocation(_ sender: Any) {
        let alert = UIAlertController(title: "Nueva localización.", message: "¿Que mensaje quiere dejar?", preferredStyle: .alert)
                alert.addTextField { (textField) in
                    textField.text = ""
                }
                alert.addAction(UIAlertAction(title: "Añadir", style: .default, handler: { (_) in
                    let textField = alert.textFields![0]
                    self.newMessage = textField.text!
                    
                    self.image = "\(self.newMessage)".image(withAttributes: [.font: UIFont.systemFont(ofSize: 30.0)])
                    
                    let annotationNode = LocationAnnotationNode(location: nil, image: self.image!)
                    self.sceneLocationView.addLocationNodeForCurrentPosition(locationNode:annotationNode)
                    let fullText    = "\(self.currentLatitude)_\(self.currentLongitude)_\(self.newMessage)_\(self.currentAltitude)"
                    annotationNode.annotationNode.name = "\(fullText)"
                }))
                self.present(alert, animated: true, completion: nil)
    }
    
    //Cuando se pulsa sobre el boton de añadir nueva localizacion (el boton de la derecha) se genera un alert en el cual puedes pegar el codigo encriptado que has recibido para añadir el mensaje en tu mundo.
    @IBAction func onClickGetLocation(_ sender: Any) {
        let alert = UIAlertController(title: "Recibir mensaje.", message: "Pega aquí el codigo que has recibido para añadir el mensaje a tu alrededor.", preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.text = ""
        }
        alert.addAction(UIAlertAction(title: "Añadir", style: .default, handler: { (_) in
            let textField = alert.textFields![0]
            self.getMessage = textField.text!
            var decryptedText: String?
            
            do {
                decryptedText = try self.decryptMessage(encryptedMessage: self.getMessage, encryptionKey: "id")
            } catch {
                print("error")
            }
            
            let fullNameArr = decryptedText!.components(separatedBy: "_")
            let gotLatitude = Double("\(fullNameArr[0])")
            let gotLongitude = Double("\(fullNameArr[1])")
            let gotAltitude = Double("\(fullNameArr[3])")
            self.ARINIT(latitude: gotLatitude!, longitude: gotLongitude!, altitude: gotAltitude!, message: fullNameArr[2])
        }))
        self.present(alert, animated: true, completion: nil)
        }
    
    // Cuando se solicita una nueva localizacion se ejecuta esta funcion que guarda en variables la posicion gps actual del usuario.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            self.currentLatitude = location.coordinate.latitude
            self.currentLongitude = location.coordinate.longitude
            self.currentAltitude = location.altitude
            }
    }
    
    //Si existe un aviso de memoria, se elimina y se vuelve a crear, de esta forma la aplicacion funcionara bien aun cuando exista poca memoria disponible en el dispositivo.
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    //Esta funcion encripta un String con una clave.
    func encryptMessage(message: String, encryptionKey: String) throws -> String {
        let messageData = message.data(using: .utf8)!
        let cipherData = RNCryptor.encrypt(data: messageData, withPassword: encryptionKey)
        return cipherData.base64EncodedString()
    }
    //Esta desencripta el mensaje con la misma clave.
    func decryptMessage(encryptedMessage: String, encryptionKey: String) throws -> String {

        let encryptedData = Data.init(base64Encoded: encryptedMessage)!
        let decryptedData = try RNCryptor.decrypt(data: encryptedData, withPassword: encryptionKey)
        let decryptedString = String(data: decryptedData, encoding: .utf8)!

        return decryptedString
    }

}

extension ViewController: SceneLocationViewDelegate {
    func sceneLocationViewDidUpdateLocationAndScaleOfLocationNode(sceneLocationView: SceneLocationView, locationNode: LocationNode) {}
}

extension ViewController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) { return }
}

//Esta extension permite dibujar texto y guardarlo en una imagen para mostrarlo posteriormente en RA.
extension String {
    func image(withAttributes attributes: [NSAttributedString.Key: Any]? = nil, size: CGSize? = nil) -> UIImage? {
        let size = size ?? (self as NSString).size(withAttributes: attributes)
        return UIGraphicsImageRenderer(size: size).image { _ in
            (self as NSString).draw(in: CGRect(origin: .zero, size: size),
                                    withAttributes: attributes)
        }
    }

}
