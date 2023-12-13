//
//  GameViewController.swift
//  HTTPSwiftExample
//
//  Created by Oliver Raney on 11/20/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

import UIKit
import SpriteKit

let SERVER_URL = "http://192.168.1.48:8000" // change this for your server name!!!

class GameViewController: UIViewController {
    lazy var scene = GameScene2()
    @IBOutlet weak var modelButton: UIButton!
    
    @IBAction func modelChanged(_ sender: UIButton) {
        if modelButton.currentTitle == "KNN" {
            modelButton.setTitle("XGB", for: .normal)
        }
        else {
            modelButton.setTitle("KNN", for: .normal)
        }
        scene.model = sender.currentTitle!
    }
    
    override func viewDidLoad() {
            super.viewDidLoad()

            if let view = self.view as? SKView {
                // Create and configure the scene
                scene = GameScene2(size: view.bounds.size)
                scene.scaleMode = .resizeFill
                
                // Present the scene
                view.presentScene(scene)
                
                view.ignoresSiblingOrder = true
            }
        }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
