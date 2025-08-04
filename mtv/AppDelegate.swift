//
//  AppDelegate.swift
//  mtv
//
//  Created by Ali Humza on 08/03/2024.
//

import UIKit
import RevenueCat



@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Purchases.configure(withAPIKey: "appl_goRXxhJHqIfrgGhdFgBXrSiPTMZ")
        
        // Enable sandbox mode for simulator testing
        #if targetEnvironment(simulator)
        Purchases.shared.purchasesAreCompletedBy = .revenueCat
        print("RevenueCat configured for simulator testing")
        #else
        print("RevenueCat configured for production")
        #endif
        
        print("In app subscription configured")
        // print("RevenueCat configuration temporarily bypassed for debugging.")

        // --- Start of added code for DebugPlayerViewController ---
        // window = UIWindow(frame: UIScreen.main.bounds)

        // let debugVC = DebugPlayerViewController()
        // If you want a navigation bar for the debug view (optional, usually not needed for this simple test):
        // let navigationController = UINavigationController(rootViewController: debugVC)
        // window?.rootViewController = navigationController
        
        // Directly set DebugPlayerViewController as root:
        // window?.rootViewController = debugVC

        // window?.makeKeyAndVisible()
        // --- End of added code for DebugPlayerViewController ---

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }


}

