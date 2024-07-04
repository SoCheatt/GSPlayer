//
//  AppDelegate.swift
//  GSPlayer
//
//  Created by Gesen on 04/20/2019.
//  Copyright (c) 2019 Gesen. All rights reserved.
//

import UIKit
import GSPlayer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let nav = UINavigationController(rootViewController: MenuViewController())
        nav.navigationBar.barStyle = .blackTranslucent
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        
        DispatchQueue.global(qos: .background).async {
            VideoCacheManager.configCacheDirectory(path: self.getCacheFilePath())
            VideoCacheManager.configExpirationDate(.days(2))
            VideoCacheManager.clearExpiredCache()
        }
        
        return true
    }
    
    private func getCacheFilePath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let docURL = URL(string: documentsDirectory)!
        let dataPath = docURL.appendingPathComponent("GSPlayerCache")
        if !FileManager.default.fileExists(atPath: dataPath.path) {
            do {
                try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription)
            }
        }
        
        return dataPath.path
    }

}

