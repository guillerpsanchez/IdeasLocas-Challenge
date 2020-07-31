//
//  ViewController.swift
//  TrainMaster
//
//  Created by Guillermo Peñarando Sánchez on 21/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

// Esta aplicación esta basada en el ejemplo que trae XCode de seguimiento de imagenes en AR
class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Se declara que el sceneView va a ser el va a tener que estar sincronizado para mostrar las imagenes en AR que se superponen.
        sceneView.delegate = self
        
        // Se carga la escena de AR desde la carpeta de arte la cual ha sido configurada para mostrar los mapas que sean necesarios.
        let scene = SCNScene(named: "art.scnassets/arItems.scn")!
        
        // Se añade la escena al view para que se muestre en pantalla.
        sceneView.scene = scene
        // se llama a la funcion add pinchgesture el cual añade a la pantalla un elemento que detecta cuando se realiza el gesto de "pinch".
        addPinchGesture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Se carga como configuracion el reconocimiento de imagenes "conocidas" es decir de imagenes que tenemos precargadas en la aplicación.
        let configuration = ARImageTrackingConfiguration()

        //Se da como imagenes de modelo todas las que se encuentren en la subcarpeta AR REsources de el directorio de Assest de la aplicación.
        guard let arImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else { return }
        configuration.trackingImages = arImages
        
        // Se inicia la sesión AR con la configuración que acabamos de cargar.
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Cuando se sale de la aplicación se pausa la sesión para evitar el consumo de recursos inecesarios.
        sceneView.session.pause()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        //Se busca la imagen en el feed de video obteniendo su posicion y orientacion en el mundo.
        guard anchor is ARImageAnchor else { return }
        
        //Con estas 3 lineas lo que se hace es buscar el primer elemento en la arScene que se llame container se le separa del nodo padre y se añade a la escena, cambiando su visibilidad a "visible" siempre que se encuentre la imagen que se buscaba en el feed de video.
        guard let container = sceneView.scene.rootNode.childNode(withName: "container", recursively: false) else { return }
        container.removeFromParentNode()
        node.addChildNode(container)
        container.isHidden = false
    }
    //Funcion que añade al sceneView el control de gestos, en este caso reconoce "pinch" e decir cuando con dos dedos se realizan pinzas sobre la pantalla.
    private func addPinchGesture() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(scaleObject(_:)))
        self.sceneView.addGestureRecognizer(pinchGesture)
    }
    //Esta funcion se ejecuta cuando se detect un gesto de pinch sobre la pantalla, de esta forma se obtiene la posicion hacia la que se desea escalar (cerrando los dedos para alejar y separandolos para acercar). aplicando una funcion de vector3 (es decir una escala en "X", "Y" y "Z" como es un plano el z se ignora) cambiando la escala del mapa.
    @objc func scaleObject(_ gesture: UIPinchGestureRecognizer) {

        let location = gesture.location(in: sceneView)
        let hitTest = sceneView.hitTest(location)
        guard let nodeToScale = hitTest.first?.node else {
            return
        }
        if gesture.state == .changed {

            let pinchScaleX: CGFloat = gesture.scale * CGFloat((nodeToScale.scale.x))
            let pinchScaleY: CGFloat = gesture.scale * CGFloat((nodeToScale.scale.y))
            let pinchScaleZ: CGFloat = gesture.scale * CGFloat((nodeToScale.scale.z))
            nodeToScale.scale = SCNVector3Make(Float(pinchScaleX), Float(pinchScaleY), Float(pinchScaleZ))
            gesture.scale = 1

        }
        if gesture.state == .ended { }

    }
    
    @IBAction func onMetro(_ sender: Any) {
        //Cuando se pulsa el boton con el icono de la renfe, se cambia a una escena igual la cual en vez de cargar el mapa de metro y tener un boton de renfe, tiene el mapa de renfe y el boton de metro.
        performSegue(withIdentifier: "renfeView", sender: self)
    }
}
