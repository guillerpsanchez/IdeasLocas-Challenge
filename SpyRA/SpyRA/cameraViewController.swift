//
//  cameraViewController.swift
//  SpyRA
//
//  Created by Guillermo Peñarando Sánchez on 19/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class cameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var drawings: [CAShapeLayer] = []
    private let photoOutput = AVCapturePhotoOutput()
    
    var imageReciber = UIImage()
    
    @IBOutlet weak var showCamera: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.addCameraInput()
        self.showCameraFeed()
        self.getCameraFrames()
        self.captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.showCamera.frame
    }
    //Se obtiene el input desde la camara del dispositivo y se añade el buffer de video que devuelven a la sesión de captura.
    private func addCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .back).devices.first else { return }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(cameraInput)
        captureSession.addOutput(photoOutput)
    }
    //Con el buffer de video obtenido desde la camara se ejecuta la funcion de detectar caras, la cual se ejecutara en cada frame de video, de esta forma se detectaran las caras y su movimiento.
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        self.detectFace(in: frame)
    }
    //La función detectFace() permite la busqueda a traves de la librería del sistema de caras en la imagen que se obtiene del buffer de video, de esta forma si detecta una camara llamara a la funcion handleFaceDetectionResults() para que dibuje encima de las caras el emoticono, en caso de no encontrar ninguna cara se llamara a la funcion clearDrawings() la cual eliminara los emoticonos de la imagen.
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation] {
                    self.handleFaceDetectionResults(results)
                } else {
                    self.clearDrawings()
                }
            }
        })
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    //Esta funcion recibe las posiciones de las caras detectadas y añade un subview por cada cara mostrando un emoticono encima de cada cara detectada.
    private func handleFaceDetectionResults(_ observedFaces: [VNFaceObservation]) {
        
        self.clearDrawings()
        
        let facesBoundingBoxes: [CAShapeLayer] = observedFaces.flatMap({ (observedFace: VNFaceObservation) -> [CAShapeLayer] in
            let faceBoundingBoxOnScreen = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)
            
            let image = UIImage(named: "happy_emoji.png")
            let imageView = UIImageView(image: image!)
            imageView.frame = faceBoundingBoxOnScreen
            showCamera.addSubview(imageView)
            let newDrawings = [CAShapeLayer]()
            
            return newDrawings
        })
        
        self.drawings = facesBoundingBoxes
    }
    //Cuando se llama a esta funcion se eliminan todos los subviews que contienen un emoticono, de esta forma no se quedan en la imagen si la cara se mueve y tampoco lo hacen si deja de existir una cara detectada.
    private func clearDrawings() {
        showCamera.subviews.forEach({ $0.removeFromSuperview() })
    }
    //Con esta funcion se añaden todos los frames recibidos del buffer de video a el imageView que se muestra en pantalla dando al usuario un input de imagen.
    private func showCameraFeed() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.showCamera.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.showCamera.frame
    }
    
    //esta funcion va ligada a showCameraFeed() y simplemente da la configuracion que debe tener el vido para mostrarse de forma correcta en la pantalla.
    private func getCameraFrames() {
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        guard let connection = self.videoDataOutput.connection(with: AVMediaType.video),
            connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
    //Cuando se pulsa el boton de tomar una foto (el central gris) se ejcuta esta acción, que guarda una captura de lo que se muestra en ese momento en la pantalla, diciendole en que formato se quiere guardar la imagen.
    @IBAction func onPhotoTaken(_ sender: Any) {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        self.photoOutput.capturePhoto(with: settings, delegate: self)
    }
    //Esta funcion se ejecuta justo despues de pulsar el boton de captura de imagen y sirve para dos cosas, la primera guardar en el dispositivo una captura de la iamgen sin ningun tipo de emoticono por encima y segundo, para guardar esa misma imagen en una variable para que mas tarde se pueda trabajar con ella.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        
        let image = UIImage(data: imageData)
        
        showCamera.image = image
        imageReciber = image!
        UIImageWriteToSavedPhotosAlbum(showCamera.image!, nil, nil, nil)
        saveEmoji()
    }
    
    //La funcion saveEmoji() sirve para con la imagen guardada en la funcion photoOutput(), sobreponer el emoticono por encima y guardarlo en el dispositivo.
    func saveEmoji() {
        showCamera.backgroundColor = UIColor.clear
        UIGraphicsBeginImageContextWithOptions(showCamera.frame.size, true, 0.0)
        if let context = UIGraphicsGetCurrentContext() {
            showCamera.layer.render(in: context)
        }
        let outputImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        var topImage = outputImage
        
        UIImageWriteToSavedPhotosAlbum(topImage!, nil, nil, nil)
        topImage = nil
    }
    //Esta acción permite el cambio entre el modo de cámara normal y el modo de camara AR.
    @IBAction func onClickARButton(_ sender: Any) {
        performSegue(withIdentifier: "ARView", sender: self)
    }
}
