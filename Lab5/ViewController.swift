//
//  ViewController.swift
//  Lab5
//
//  Created by Tong Li on 11/22/24.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var drawingView: DrawingView!
    @IBOutlet weak var numberTextField: UITextField!
    @IBOutlet weak var dsidTextField: UITextField!
    @IBOutlet weak var modelSelector: UISegmentedControl!
    
    // TODO: switch to your own IP address
    private let serverIP = "192.168.1.69:8000"
    
    @IBAction func modelSelectionChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
                print("Model changed to: Turi")
            } else if sender.selectedSegmentIndex == 1 {
                print("Model changed to: Sklearn")
            }
    }
    @IBAction func clearCanvas(_ sender: UIButton) {
        drawingView.clear()
    }

    @IBAction func submitDrawing(_ sender: UIButton) {
        guard let image = drawingView.getImage() else {
            print("Image is missing")
            return
        }

        if let labelText = numberTextField.text, !labelText.isEmpty,
           let label = Int(labelText),
           let dsidText = dsidTextField.text, !dsidText.isEmpty,
           let dsid = Int(dsidText) {
            // 用户输入了 labelText 和 dsid，上传图片用于训练
            uploadImage(image: image, label: String(label), dsid: dsid)
        } else if let dsidText = dsidTextField.text, let dsid = Int(dsidText) {
            // 用户未输入 labelText，仅使用 dsid 进行预测
            predictImage(image: image, dsid: dsid)
        } else {
            print("Label or DSID is missing")
        }
    }
    
    @IBAction func trainModelButtonTapped(_ sender: UIButton) {
        guard let dsidText = dsidTextField.text, let dsid = Int(dsidText) else {
            print("Invalid DSID")
            return
        }

        let selectedModelType = modelSelector.selectedSegmentIndex == 0 ? "turi" : "sklearn"
        let url = URL(string: "http://\(serverIP)/train_model_\(selectedModelType)/\(dsid)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Training failed: \(error.localizedDescription)")
                return
            }

            if let data = data {
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    if let summary = jsonResponse?["summary"] as? String {
                        print("Training Response: \(summary)")
                    }
                } catch {
                    print("Error parsing response: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        numberTextField.delegate = self
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    

    @objc func hideKeyboard() {
        view.endEditing(true)
    }


    func uploadImage(image: UIImage, label: String, dsid: Int) {
        let url = URL(string: "http://\(serverIP)/labeled_data/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

       
        let imageData = image.jpegData(compressionQuality: 0.8)!.base64EncodedString()

        // JSON
        let json: [String: Any] = [
            "image_base64": imageData,
            "label": label,
            "dsid": dsid
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Upload failed: \(error.localizedDescription)")
                return
            }

            if let data = data {
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    if let message = jsonResponse?["message"] as? String {
                        print("Upload Response: \(message)")
                    }
                } catch {
                    print("Error parsing response: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }

    
    
    
    func trainModel() {
        guard let dsidText = dsidTextField.text, let dsid = Int(dsidText) else {
            print("Invalid DSID")
            return
        }

        let selectedModelType = modelSelector.selectedSegmentIndex == 0 ? "turi" : "sklearn"
        
        let url = URL(string: "http://\(serverIP)/train_model_\(selectedModelType)/\(dsid)")!
        print("Training URL: \(url)")  // 打印 URL 以确认请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Train request failed: \(error.localizedDescription)")
                return
            }

            if let data = data {
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    if let summary = jsonResponse?["summary"] as? String {
                        print("Training Response: \(summary)")
                    }
                } catch {
                    print("Error parsing response: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }


    func predictImage(image: UIImage, dsid: Int) {
        let modelType = modelSelector.selectedSegmentIndex == 0 ? "turi" : "sklearn"
        
        let url = URL(string: "http://\(serverIP)/predict_\(modelType)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    
        let imageData = image.jpegData(compressionQuality: 0.8)!
        let base64Image = imageData.base64EncodedString()

        // JSON request
        let json: [String: Any] = [
            "image": base64Image,
            "dsid": dsid
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Prediction failed: \(error)")
                return
            }

            if let data = data {
                        do {
                            if let responseString = String(data: data, encoding: .utf8) {
                                print("Server response: \(responseString)")  // Log the full response for debugging
                            }

                            let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                            if let prediction = jsonResponse?["prediction"] as? Int {
                                print("Prediction: \(prediction)")
                            } else if let errorMessage = jsonResponse?["error"] as? String {
                                print("Server error: \(errorMessage)")
                            } else {
                                print("Unexpected response format.")
                            }
                        } catch {
                            print("Error decoding response: \(error.localizedDescription)")
                        }
                    }
        }
        task.resume()
    }

    
}
extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder() // 隐藏键盘
        return true
    }
}



