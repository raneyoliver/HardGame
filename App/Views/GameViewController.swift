//
//  GameViewController.swift
//  HTTPSwiftExample
//
//  Created by Oliver Raney on 11/20/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

import UIKit
import SpriteKit
import RealmSwift

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
        //scene.model = sender.currentTitle!
    }
    
    override func viewDidLoad() {
            super.viewDidLoad()

            print("GameViewController loaded")
        
        
        
        
        
            if let view = self.view as? SKView {
                // Create and configure the scene
                scene = GameScene2(size: view.bounds.size)
                scene.scaleMode = .resizeFill
                
                // Present the scene
                view.presentScene(scene)
                
                view.ignoresSiblingOrder = true
            }

        
            let button = UIButton(frame: CGRect(x: 20, y: 50, width: 150, height: 50))
            button.setTitle("Leaderboards", for: .normal)
            button.backgroundColor = .blue
            button.addTarget(self, action: #selector(navigateButtonPressed), for: .touchUpInside)
            self.view.addSubview(button)
        }
    
    @objc func navigateButtonPressed() {
            self.performSegue(withIdentifier: "showTableSegue", sender: self)
        }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "yourSegueIdentifier" {
            if let tableViewController = segue.destination as? LeaderboardTableViewController {
                // Configure tableViewController as needed
            }
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

