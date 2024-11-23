//
//  DrawingView.swift
//  NumberRecognition
//
//  Created by Tong Li on 11/22/24.
//

import UIKit

class DrawingView: UIView {
    private var path = UIBezierPath()
    private var previousTouch: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        previousTouch = touch.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let previousTouch = previousTouch else { return }
        let currentTouch = touch.location(in: self)

        path.move(to: previousTouch)
        path.addLine(to: currentTouch)

        self.previousTouch = currentTouch
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        UIColor.black.setStroke()
        path.stroke()
    }

    func clear() {
        path = UIBezierPath()
        setNeedsDisplay()
    }

    func getImage() -> UIImage? {
        UIGraphicsBeginImageContext(self.bounds.size)
        drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
