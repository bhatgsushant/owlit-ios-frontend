// CameraManager.swift
// Camera management for ScanView

import AVFoundation
import SwiftUI
import Combine

@MainActor
final class CameraManager: ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var cameraAvailable: Bool = false
    private var photoOutput = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?

    private var isSessionConfigured = false
    private var sessionQueue = DispatchQueue(label: "camera.session.queue")

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.configureSession() }
                }
            }
        default:
            self.cameraAvailable = false
        }
    }
    
    private func configureSession() {
        guard !isSessionConfigured else { cameraAvailable = true; return }
        sessionQueue.async {
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }
            // Find camera
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                DispatchQueue.main.async { self.cameraAvailable = false }
                return
            }
            self.captureDevice = device
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) { self.session.addInput(input) }
                if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }
                self.isSessionConfigured = true
                DispatchQueue.main.async {
                    self.session.startRunning()
                    self.cameraAvailable = true
                }
            } catch {
                DispatchQueue.main.async { self.cameraAvailable = false }
            }
        }
    }
    
    func stopSession() {
        guard isSessionConfigured else { return }
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }
    
    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        guard cameraAvailable else {
            completion(.failure(NSError(domain: "CameraUnavailable", code: -1)))
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate(completion: completion))
    }
}

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (Result<Data, Error>) -> Void
    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            completion(.success(data))
        } else {
            completion(.failure(NSError(domain: "PhotoCapture", code: -1)))
        }
    }
}
