//
//  myclassiferView.swift
//  Lab5
//
//  Created by shirley on 11/24/24.
//

import UIKit
import CoreML
import Vision

import UIKit
import CoreML
import Vision

class ClassifierViewController: UIViewController {
    @IBOutlet weak var drawingView: DrawingView! //canvas
    
    
    @IBOutlet weak var resultLabel: UILabel!
    

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func classifyDrawing(_ sender: UIButton) {
        // 从 DrawingView 获取 UIImage
       guard let image = drawingView.getImage() else {
           print("Image is missing")
           resultLabel.text = "Error: Could not capture the drawing"
           return
       }
       classifyImage(image: image) // 调用分类方法
    }
    @IBAction func clearDrawing(_ sender: UIButton) {
            drawingView.clear()
            resultLabel.text = "" // 清除结果显示
        }
    
    
    
    let model: VNCoreMLModel = {
            do {
                let config = MLModelConfiguration()
                let model = try MyImageClassifier_1(configuration: config).model
                return try VNCoreMLModel(for: model)
            } catch {
                fatalError("Failed to load CoreML model: \(error)")
            }
        }()
   
    func classifyImage(image: UIImage) {
        // 将 UIImage 转换为 CIImage
        guard let ciImage = CIImage(image: image) else {
            print("Could not convert UIImage to CIImage")
            resultLabel.text = "Error: Unable to process the drawing"
            return
        }

    
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Classification error: \(error.localizedDescription)")
                    self?.resultLabel.text = "Error: \(error.localizedDescription)"
                    return
                }

                // 获取分类结果
                guard let results = request.results as? [VNClassificationObservation],
                      let firstResult = results.first else {
                    print("No classification results found")
                    self?.resultLabel.text = "No classification results"
                    return
                }

                // 更新 UI 显示结果
                print("Classification Result: \(firstResult.identifier)")
                self?.resultLabel.text = """
                Result: \(firstResult.identifier)
                """
            }
        }

        // 在后台线程执行分类
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    print("Failed to perform classification: \(error.localizedDescription)")
                    self.resultLabel.text = "Failed to process image"
                }
            }
        }
    }

   
    
}
