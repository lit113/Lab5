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

        let url = URL(string: "http://192.168.1.69:8000/train_model_turi/\(dsid)")!
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
        let url = URL(string: "http://192.168.1.69:8000/labeled_data/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 将图像数据编码为 Base64
        let imageData = image.jpegData(compressionQuality: 0.8)!.base64EncodedString()

        // 构建 JSON 请求体
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

        let url = URL(string: "http://192.168.1.69:8000/train_model_turi/\(dsid)")!
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


    
    //            if let data = data, let responseString = String(data: data, encoding: .utf8) {
    //                print("Response from train: \(responseString)")
    //            }

//    func predictImage(image: UIImage, dsid: Int) {
//        let url = URL(string: "http://192.168.1.69:8000/predict_turi/")!
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        // 将图像转换为 Base64
//        let imageData = image.jpegData(compressionQuality: 0.8)!
//        let base64Image = imageData.base64EncodedString()
//
//        // 构造 JSON 请求体
//        let json: [String: Any] = [
//            "image": base64Image,
//            "dsid": dsid
//        ]
//        let jsonData = try? JSONSerialization.data(withJSONObject: json)
//        request.httpBody = jsonData
//
//        let task = URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                print("Prediction failed: \(error.localizedDescription)")
//                return
//            }
//
//            if let data = data {
//                do {
//                    let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
//                    if let prediction = jsonResponse?["prediction"] as? String {
//                        print("Prediction: \(prediction)")
//                    }
//                } catch {
//                    print("Error decoding response: \(error.localizedDescription)")
//                }
//            }
//        }
//        task.resume()
//    }
    func predictImage(image: UIImage, dsid: Int) {
        let url = URL(string: "http://192.168.1.69:8000/predict_turi/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 将图转换为 Base64
        let imageData = image.jpegData(compressionQuality: 0.8)!
        let base64Image = imageData.base64EncodedString()

        // 构造 JSON 请求体
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
                    let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    if let prediction = jsonResponse?["prediction"] as? String {
                        print("Prediction: \(prediction)") // 打印预测结果
                    } else {
                        print("Prediction field missing in response.")
                    }
                } catch {
                    print("Error decoding response: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }


    
    func createMultipartData(image: UIImage, label: String?, boundary: String) -> Data {
        var data = Data()
        let imageData = image.jpegData(compressionQuality: 0.8)!

        if let label = label, !label.isEmpty {  // 如果 label 存在并且非空
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"label\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(label)\r\n".data(using: .utf8)!)
        }

        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"drawing.jpg\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        data.append(imageData)
        data.append("\r\n".data(using: .utf8)!)

        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }

    
}
extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder() // 隐藏键盘
        return true
    }
}



