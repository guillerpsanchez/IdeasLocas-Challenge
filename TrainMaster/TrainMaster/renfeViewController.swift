//
//  renfeViewController.swift
//  TrainMaster
//
//  Created by Guillermo Peñarando Sánchez on 21/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class renfeViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        
        let scene = SCNScene(named: "art.scnassets/arItems.scn")!
        
        sceneView.scene = scene
        addPinchGesture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARImageTrackingConfiguration()

        guard let arImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else { return }
        configuration.trackingImages = arImages
        
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        guard anchor is ARImageAnchor else { return }
        
        guard let container = sceneView.scene.rootNode.childNode(withName: "container2", recursively: false) else { return }
        
        container.removeFromParentNode()
        
        node.addChildNode(container)
        
        container.isHidden = false
    }
    
    private func addPinchGesture() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(scaleObject(_:)))
        self.sceneView.addGestureRecognizer(pinchGesture)
    }
    
    @objc func scaleObject(_ gesture: UIPinchGestureRecognizer) {

        let location = gesture.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(location)
        guard let nodeToScale = hitTestResults.first?.node else {
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
        dismiss(animated: true, completion: nil)
    }
}
