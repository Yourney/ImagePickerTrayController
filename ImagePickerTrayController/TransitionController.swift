//
//  TransitionController.swift
//  ImagePickerTrayController
//
//  Created by Laurin Brandner on 17.04.17.
//  Copyright © 2017 Laurin Brandner. All rights reserved.
//

import Foundation

class TransitionController: NSObject {
    
    fileprivate weak var trayController: ImagePickerTrayController?
    
    var allowsInteractiveTransition = true
    
    fileprivate let gestureRecognizer = UIPanGestureRecognizer()
    fileprivate var interactiveTransition: UIPercentDrivenInteractiveTransition?
    fileprivate var panDirection: CGFloat = 0
    
    init(trayController: ImagePickerTrayController) {
        self.trayController = trayController
        super.init()
        
        gestureRecognizer.addTarget(self, action: #selector(didRecognizePan(gestureRecognizer:)))
        gestureRecognizer.delegate = self
    }
    
    fileprivate func cancel() {
        interactiveTransition?.cancel()
        interactiveTransition = nil
        gestureRecognizer.cancel()
    }
    
    fileprivate func finish() {
        interactiveTransition?.finish()
        interactiveTransition = nil
        gestureRecognizer.cancel()
    }
    
}

// MARK: - UIViewControllerTransitioningDelegate

extension TransitionController: UIViewControllerTransitioningDelegate {
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return AnimationController(transition: .presentation(gestureRecognizer))
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return AnimationController(transition: .dismissal)
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactiveTransition
    }
    
}

// MARK: - UIGestureRecognizerDelegate

extension TransitionController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return allowsInteractiveTransition
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc fileprivate func didRecognizePan(gestureRecognizer: UIPanGestureRecognizer) {
        guard let trayController = trayController,
            let view = gestureRecognizer.view else {
                cancel()
                return
        }
        
        if gestureRecognizer.state == .began {
            gestureRecognizer.setTranslation(.zero, in: gestureRecognizer.view)
        }
        else if gestureRecognizer.state == .changed {
            let end = gestureRecognizer.location(in: gestureRecognizer.view).y
            let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
            let start = end - translation.y
            let threshold = view.frame.maxY - trayController.trayHeight
            if let transition = self.interactiveTransition {
                let progress = end - threshold
                transition.update(progress/trayController.trayHeight)
            }
            if start < threshold && end >= threshold && self.interactiveTransition == nil {
                self.interactiveTransition = UIPercentDrivenInteractiveTransition()
                trayController.dismiss(animated: true, completion: nil)
            }
        }
        else if gestureRecognizer.state == .cancelled {
            self.interactiveTransition?.completionSpeed = 0.95
            cancel()
        }
        else if gestureRecognizer.state == .ended {
            let velocity = gestureRecognizer.velocity(in: gestureRecognizer.view).y
            
            // This needs to be set, otherwise the cancel animation glitches from time to time
            // If you figure out how to fix this, let me know
            interactiveTransition?.completionSpeed = 0.95
            
            if velocity <= 0 {
                cancel()
            }
            else {
                finish()
            }
        }
    }
    
}

fileprivate extension UIPanGestureRecognizer {
    
    fileprivate func cancel() {
        isEnabled = false
        isEnabled = true
    }
    
}
