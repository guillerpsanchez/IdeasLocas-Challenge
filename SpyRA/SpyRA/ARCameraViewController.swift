//
//  ARCameraViewController.swift
//  SpyRA
//
//  Created by Guillermo Peñarando Sánchez on 29/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import ARKit

class ARcameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var drawings: [CAShapeLayer] = []
    private let photoOutput = AVCapturePhotoOutput()
    
    var imageReciber:UIImage?
    
    @IBOutlet weak var showCamera: ARSCNView!
    
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
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection) {
        
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        self.detectFace(in: frame)
    }
    
    private func addCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .back).devices.first else { return }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(cameraInput)
        captureSession.addOutput(photoOutput)
    }
    
    private func showCameraFeed() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.showCamera.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.showCamera.frame
    }
    
    private func getCameraFrames() {
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        guard let connection = self.videoDataOutput.connection(with: AVMediaType.video),
            connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
    
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
    
    private func clearDrawings() {
        showCamera.subviews.forEach({ $0.removeFromSuperview() })
    }
    
    
    @IBAction func onPhotoTaken(_ sender: Any) {
        
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        self.photoOutput.capturePhoto(with: settings, delegate: self)
        
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        
        let image = UIImage(data: imageData)
        
        showCamera.largeContentImage = image
        imageReciber = showCamera.largeContentImage
        UIImageWriteToSavedPhotosAlbum(showCamera.largeContentImage!, nil, nil, nil)
        saveEmoji()
    }
    
    //Al contrario que con la misma funcion en el modo normal, en el modo AR hay que realizar una serie de ajustes para que la funcion para guardar el emoticono sobre la imagen quede bien en todos los dispositivos, para ello con la imagen original, se obtiene su tamaño en pixeles, una vez realizado eso, se redimensiona la imagen con los emoticonos para que sea del mismo tamaño que la imagen obtenida de la camara (si no se hace esto, los emoticonos quedan pequeños y descuadrados), una vez redimensionada, simplemente se superpone la imagen con los emoticonos y la captura de la camara, guardando la imagen final en el dispositivo.
    func saveEmoji() {
        showCamera.backgroundColor = UIColor.clear
        UIGraphicsBeginImageContextWithOptions(showCamera.frame.size, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            showCamera.layer.render(in: context)
        }
        let outputImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        
        let topImage = outputImage
        
        let heightInPoints = imageReciber!.size.height
        let heightInPixels = heightInPoints * imageReciber!.scale
        
        let widthInPoints = imageReciber!.size.width
        let widthInPixels = widthInPoints * imageReciber!.scale
        
        let semiFinalImage = resizeImage(image: topImage!, targetSize: CGSize(width: widthInPixels,height: heightInPixels))
        
        let superFinalImage = imageReciber?.imageByCombiningImage(firstImage: imageReciber!, withImage: semiFinalImage)
        
        UIImageWriteToSavedPhotosAlbum(superFinalImage!, nil, nil, nil)
    }
    
    //Esta función permite reescalar una imagen a la resolucion dada, para ello se obtiene el ratio de reescalado, con ese ratio, se calcula la orientacion de la imagen por ultimo se redibuja la imagen con los parametros que se han calculado.
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    //Esta acción permite el cambio desde la camra AR a la camara normal.
    @IBAction func onClickNormalCamera(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension UIImage {
    //Esta funcion permite la fusion de dos imagenes una encima de la otra, basicamente obtiene sus tamaños y en base a eso las dibuja una encima de la otra devolviendo la imagen resultante.
    func imageByCombiningImage(firstImage: UIImage, withImage secondImage: UIImage) -> UIImage {
        
        let newImageWidth  = max(firstImage.size.width,  secondImage.size.width )
        let newImageHeight = max(firstImage.size.height, secondImage.size.height)
        let newImageSize = CGSize(width : newImageWidth, height: newImageHeight)
        
        
        UIGraphicsBeginImageContextWithOptions(newImageSize, false, UIScreen.main.scale)
        
        let firstImageDrawX  = round((newImageSize.width  - firstImage.size.width  ) / 2)
        let firstImageDrawY  = round((newImageSize.height - firstImage.size.height ) / 2)
        
        let secondImageDrawX = round((newImageSize.width  - secondImage.size.width ) / 2)
        let secondImageDrawY = round((newImageSize.height - secondImage.size.height) / 2)
        
        firstImage.draw(at: CGPoint(x: firstImageDrawX,  y: firstImageDrawY))
        secondImage.draw(at: CGPoint(x: secondImageDrawX, y: secondImageDrawY))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        
        return image!
    }
}

