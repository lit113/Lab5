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
    @IBOutlet weak var predictionLabel: UILabel!

    
    // TODO: switch to your own IP address
    private let serverIP = "192.168.50.164:8000"
    
    // Handle changes in the model selector
    @IBAction func modelSelectionChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
                print("Model changed to: Turi")
            } else if sender.selectedSegmentIndex == 1 {
                print("Model changed to: Sklearn")
            }
    }
    
    // Clear the drawing canvas
    @IBAction func clearCanvas(_ sender: UIButton) {
        drawingView.clear()
        clearResult()
    }

    // Handle submission of the drawing
    @IBAction func submitDrawing(_ sender: UIButton) {
        guard let image = drawingView.getImage() else {
            print("Image is missing")
            return
        }

        if let labelText = numberTextField.text, !labelText.isEmpty,
           let label = Int(labelText),
           let dsidText = dsidTextField.text, !dsidText.isEmpty,
           let dsid = Int(dsidText) {
            // If both label and DSID are provided, upload the image for training
            uploadImage(image: image, label: String(label), dsid: dsid)
        } else if let dsidText = dsidTextField.text, let dsid = Int(dsidText) {
            // If only DSID is provided, use it for prediction
            predictImage(image: image, dsid: dsid)
        } else {
            print("Label or DSID is missing") // Handle missing inputs
        }
    }
    
    // Handle training the selected model
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
        view.addGestureRecognizer(tapGesture) // Hide keyboard when tapping outside text fields
    }
    
    

    @objc func hideKeyboard() {
        view.endEditing(true) // Dismiss the keyboard
    }

    // Upload an image with its label and DSID to the server
    func uploadImage(image: UIImage, label: String, dsid: Int) {
        let url = URL(string: "http://\(serverIP)/labeled_data/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

       
        let imageData = image.jpegData(compressionQuality: 0.8)!.base64EncodedString()

        // Construct the JSON request body
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

    
    // Train the selected model with the given DSID
    func trainModel() {
        guard let dsidText = dsidTextField.text, let dsid = Int(dsidText) else {
            print("Invalid DSID")
            return
        }

        let selectedModelType = modelSelector.selectedSegmentIndex == 0 ? "turi" : "sklearn"
        
        let url = URL(string: "http://\(serverIP)/train_model_\(selectedModelType)/\(dsid)")!
        print("Training URL: \(url)")  // Debug: Verify the training URL
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

    // Predict the label for the uploaded image using the selected model
    func predictImage(image: UIImage, dsid: Int) {
        let modelType = modelSelector.selectedSegmentIndex == 0 ? "turi" : "sklearn"
        
        let url = URL(string: "http://\(serverIP)/predict_\(modelType)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    
        let imageData = image.jpegData(compressionQuality: 0.8)!
        let base64Image = imageData.base64EncodedString()

        // Construct the JSON request body
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
                                // Update the label with the prediction result
                                DispatchQueue.main.async {
                                    self.predictionLabel.text = "Prediction: \(prediction)"
                                }
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
    func clearResult() {
        DispatchQueue.main.async {
            self.predictionLabel.text = "" // Clear the result label
        }
    }

    
}
extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder() // Hide Keyboard
        return true
    }
}



