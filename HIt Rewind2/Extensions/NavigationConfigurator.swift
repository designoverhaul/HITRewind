//
//  NavigationConfigurator.swift
//  HIt Rewind2
//
//  Created by Assistant on 8/25/25.
//

import SwiftUI
import UIKit

struct NavigationConfigurator: UIViewControllerRepresentable {
    var configure: (UINavigationController) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let nc = uiViewController.navigationController {
            configure(nc)
        }
    }
}



