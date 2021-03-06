//
//  AnimationController.swift
//  ImagePickerTrayController
//
//  Created by Laurin Brandner on 15.04.17.
//  Copyright © 2017 Laurin Brandner. All rights reserved.
//

import Foundation

class AnimationController: NSObject {
    
    enum Transition {
        case presentation(UIPanGestureRecognizer)
        case dismissal
    }
    
    fileprivate let transition: Transition
    
    init(transition: Transition) {
        self.transition = transition
        super.init()
    }
    
}

extension AnimationController: UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.25
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        switch transition {
        case .presentation(let gestureRecognizer):
            present(with: gestureRecognizer, using: transitionContext)
        case .dismissal:
            dismiss(using: transitionContext)
        }
    }
    
    private func present(with gestureRecognizer: UIPanGestureRecognizer, using transitionContext: UIViewControllerContextTransitioning) {
        guard let to = transitionContext.viewController(forKey: .to) as? ImagePickerTrayController else {
            transitionContext.completeTransition(false)
            return
        }
        let container = transitionContext.containerView
        container.backgroundColor = .clear
        
//        container.window?.addGestureRecognizer(gestureRecognizer)
        
        let trayHeight = to.trayHeight
        container.translatesAutoresizingMaskIntoConstraints = false
        
        if let superview = container.superview {
            if #available(iOS 11, *) {
                // In iOS 11 attach the view to the SafeArea
                let constraint = container.topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.bottomAnchor, constant: -trayHeight)
            	constraint.isActive = true
                to.heightConstraint = constraint
            } else {
                let constraint = container.topAnchor.constraint(equalTo: superview.bottomAnchor, constant: -trayHeight)
                constraint.isActive = true
                to.heightConstraint = constraint
            }
            container.leftAnchor.constraint(equalTo: superview.leftAnchor).isActive = true
            container.rightAnchor.constraint(equalTo: superview.rightAnchor).isActive = true
            container.bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true
            
            superview.backgroundColor = .clear
        }

        container.addSubview(to.view)
        to.view.translatesAutoresizingMaskIntoConstraints = false
        to.view.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        to.view.leftAnchor.constraint(equalTo: container.leftAnchor).isActive = true
        to.view.rightAnchor.constraint(equalTo: container.rightAnchor).isActive = true
        to.view.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        to.view.transform = CGAffineTransform(translationX: 0, y: to.trayHeight)
        
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(withDuration: duration, delay: 0, options: .allowUserInteraction, animations: {
            to.view.transform = .identity
        }, completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
    
    private func dismiss(using transitionContext: UIViewControllerContextTransitioning) {
        guard let from = transitionContext.viewController(forKey: .from) as? ImagePickerTrayController else {
                transitionContext.completeTransition(false)
                return
        }
        
        let duration = transitionDuration(using: transitionContext)
        var delta = from.trayHeight
        if #available(iOS 11, *) {
            // in iOS 11, move the view to the view bounds, which means below the safeArea.
            if let safeAreaFrame = from.view.superview?.safeAreaLayoutGuide.layoutFrame {
                let bottomDistance = from.view.frame.size.height - safeAreaFrame.size.height - safeAreaFrame.origin.y
            	delta += bottomDistance
            }
        }
        UIView.animate(withDuration: duration, animations: {
            from.view.frame.origin.y += delta
        }, completion: { _ in
            if !transitionContext.transitionWasCancelled {
                from.view.removeFromSuperview()
            }
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
    
}
