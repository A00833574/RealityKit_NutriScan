//
//  ContentView.swift
//  RealityKit_NutriScan
//
//  Created by Gabriel Diaz Roa on 15/01/24.
//

import SwiftUI
import UIKit
import RealityKit
import ARKit

struct ContentView : View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> UIViewController {
        let arViewController = ARViewController()
        return arViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

class ARViewController: UIViewController {
    
    var arView: ARView!
    var lastObjectAnchor: AnchorEntity?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView = ARView(frame: .zero)
        view.addSubview(arView)
        arView.frame = view.bounds
        
        startPlaneDetection()
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        arView.addGestureRecognizer(tapGestureRecognizer)
        
        startHandTracking()
    }
    
    func startHandTracking() {
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsUserFaceTracking {
            configuration.userFaceTrackingEnabled = true
        }
        arView.session.run(configuration)
    }
    
    @objc
    func handleTap(recognizer: UITapGestureRecognizer) {
        let tapLocation = recognizer.location(in: arView)
        
        // First, check for hand tracking
        if let bodyAnchors = arView.session.currentFrame?.anchors.compactMap({ $0 as? ARBodyAnchor }),
           let bodyAnchor = bodyAnchors.first {
            let skeleton = bodyAnchor.skeleton
            if let leftHandTransform = skeleton.modelTransform(for: .leftHand) {
                let worldPos = simd_make_float3(leftHandTransform.columns.3)
                placeOrUpdateObject(at: worldPos)
                return
            }
        }
        
        // If no hand is detected, fall back to plane detection
        let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
        if let firstResult = results.first {
            let worldPos = simd_make_float3(firstResult.worldTransform.columns.3)
            placeOrUpdateObject(at: worldPos)
        }
    }

    func placeOrUpdateObject(at worldPos: SIMD3<Float>) {
        if let lastObjectAnchor = lastObjectAnchor {
            // If an object already exists, update its position
            lastObjectAnchor.setPosition(worldPos, relativeTo: nil)
        } else {
            // If no object exists, create a new one
            let sphere = createSphere()
            lastObjectAnchor = placeObject(object: sphere, at: worldPos)
        }
    }
    
    func startPlaneDetection() {
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
    }
    
    func createSphere() -> ModelEntity {
        let sphere = MeshResource.generateSphere(radius: 0.05)
        let sphereMaterial = SimpleMaterial(color: .blue, isMetallic: false)
        let sphereEntity = ModelEntity(mesh: sphere, materials: [sphereMaterial])
        return sphereEntity
    }
    
    func placeObject(object: ModelEntity, at location:SIMD3<Float>) -> AnchorEntity {
        let objectAnchor = AnchorEntity(world: location)
        objectAnchor.addChild(object)
        arView.scene.addAnchor(objectAnchor)
        return objectAnchor
    }
}
