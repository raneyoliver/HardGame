//
//  GameScene2.swift
//  HTTPSwiftExample
//
//  Created by Oliver Raney on 11/20/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

import UIKit
import SpriteKit

enum Move {
    case left
    case right

    var numericValue: Double {
        switch self {
        case .left:
            return 1.0
        case .right:
            return 2.0
        }
    }
}

struct GameData {
    var playerMoves: [Move]
    var enemyMoves: [Move]
    var outcome: CGFloat
}


class GameScene2: SKScene, URLSessionDelegate {
    lazy var session: URLSession = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 20.0
        sessionConfig.timeoutIntervalForResource = 20.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        return URLSession(configuration: sessionConfig,
            delegate: self,
            delegateQueue:self.operationQueue)
    }()
    
    let operationQueue = OperationQueue()
    
    var playerCanMove:Bool = true
    
    var playerNode = SKSpriteNode(imageNamed: "warrior")
    var missileNode: SKSpriteNode!
    var enemyMissileNode: SKSpriteNode!
    var enemyNode = SKSpriteNode(imageNamed: "enemy")
    
    var nextEnemyMove:String = ""
    
    // change model according to button title
    var model = "KNN" {
        didSet {
            changeModel(to: model)
        }
    }
    
    let gridSize = 4
    let sidePadding = 10.0
    var cellSize:CGFloat = 0.0
    var gridHeight:CGFloat = 0.0
    var playerPosition = CGPoint(x: 0, y: 0) // Initial player position
    var enemyPosition = CGPoint(x: 3, y: 3) // Initial enemy position
    var missilePosition: CGPoint?
    var enemyMissilePosition: CGPoint?
    var tapCount = 0

    enum PhysicsCategory {
        static let none: UInt32 = 0
        static let missile: UInt32 = 0x1            // 1
        static let enemy: UInt32 = 0x1 << 1         // 2
        static let player: UInt32 = 0x1 << 2        // 4
    }
    
    var currentGame = GameData(playerMoves: [], enemyMoves: [], outcome: -1.0)

    // move player across grid
    func playerDidMove(_ move: Move) {
        currentGame.playerMoves.append(move)
        switch move {
            case .left:
            if playerPosition.x > 0 {
                playerPosition.x -= 1
            }
            case .right:
            if playerPosition.x < CGFloat(gridSize) - 1 {
                playerPosition.x += 1
            }
        }
        
        //can't move while enemy moving
        playerCanMove = false

        // enemy moves 1 second after you
        scheduleEnemyMove()
    }

    func scheduleEnemyMove() {
        let wait = SKAction.wait(forDuration: 1.0)
        let performEnemyMove = SKAction.run {
            self.enemyMove()
        }
        run(SKAction.sequence([wait, performEnemyMove]))
    }

    func enemyMove() {

        // predicts the next move based on all of the moves leading up to this move.
         // may choose left or right, cannot go above 1000 moves
        getPrediction(convertGameDataToFeatureVector(currentGame, maxMoves: 1000))

        if self.nextEnemyMove == "Left" {
            enemyDidMove(.left)
        }
        else if self.nextEnemyMove == "Right" {
            enemyDidMove(.right)
        }
        else {
            // place holder -- moves randomly if an error occurs in prediction
            enemyDidMove(Bool.random() ? .left : .right)
            //enemyDidMove(.right)
        }
        
        
    }


    // same as player did move()
    func enemyDidMove(_ move: Move) {
        currentGame.enemyMoves.append(move)
        // allow player to move afterward
        playerCanMove = true
        switch move {
        case .left:
            if enemyPosition.x > 0 {
                enemyPosition.x -= 1
            }
        case .right:
            if enemyPosition.x < CGFloat(gridSize) - 1 {
                enemyPosition.x += 1
            }
            
        }
    }

    // ends the game (needs work)
    func endGame(playerWon: Bool) {
        // 1.0 == enemy wins
        currentGame.outcome = playerWon ? 0.0 : 1.0
        
        // adds a sample feature vector to the model
        addDataPoint(currentGame)
        
        // updates the model
        makeModel()
        
        // reset game data
        currentGame = GameData(playerMoves: [], enemyMoves: [], outcome: -1.0)
    }

    func addDataPoint(_ gameData: GameData) {
        // sample feature vector ---> server
        print("added all moves as a sample to model")
        let array = convertGameDataToFeatureVector(currentGame, maxMoves: 1000)
        sendFeatures(array, withLabel: "\(gameData.outcome)")
    }

    // add datapoint
    func sendFeatures(_ array:[Double], withLabel label:String){
        let baseURL = "\(SERVER_URL)/AddDataPoint"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":array,
                                       "label":"\(label)"]
        
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                if(error != nil){
                    if let res = response{
                        print("Response:\n",res)
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                    print(jsonDictionary["feature"]!)
                    print(jsonDictionary["label"]!)
                }

        })
        
        postTask.resume() // start the task
    }
    
    // CHANGE from KNN to XGB
    func changeModel(to model:String) {
        let baseURL = "\(SERVER_URL)/ChangeModel"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["model":model]
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{
            (data, response, error) in
            if(error != nil){
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{ // no error we are aware of
                let jsonDictionary = self.convertDataToDictionary(with: data)
                
                let r = jsonDictionary["to"]!
                print(r)
                //self.model = "\(r)"
            }
                                                                    
        })
        
        postTask.resume() // start the task
    }
    
    // ENEMY predicts to move left or right based on array: all the current moves in this match
    func getPrediction(_ array:[Double]){
        let baseURL = "\(SERVER_URL)/PredictOne"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":array]
        
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{
            (data, response, error) in
            if(error != nil){
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{ // no error we are aware of
                let jsonDictionary = self.convertDataToDictionary(with: data)
                
                let r = jsonDictionary["prediction"]!
                print(r)
                self.nextEnemyMove = "\(r)"
            }
                                                                    
        })
        
        postTask.resume() // start the task
    }
    
    // updates the model (probably should change the name)
    func makeModel() {
        
        // create a GET request for server to update the ML model with current data
        let baseURL = "\(SERVER_URL)/UpdateModel"
        let query = "?dsid=69"
        
        let getUrl = URL(string: baseURL+query)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
              completionHandler:{(data, response, error) in
                // handle error!
                if (error != nil) {
                    if let res = response{
                        print("Response:\n",res)
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                    if let resubAcc = jsonDictionary["resubAccuracy"]{
                        print("Resubstitution Accuracy is", resubAcc)
                    }
                }
                                                                    
        })
        
        dataTask.resume() // start the task
        
    }
    
    //MARK: JSON Conversion Functions
    func convertDictionaryToData(with jsonUpload:NSDictionary) -> Data?{
        do { // try to make JSON and deal with errors using do/catch block
            let requestBody = try JSONSerialization.data(withJSONObject: jsonUpload, options:JSONSerialization.WritingOptions.prettyPrinted)
            return requestBody
        } catch {
            print("json error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertDataToDictionary(with data:Data?)->NSDictionary{
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: NSDictionary =
                try JSONSerialization.jsonObject(with: data!,
                                              options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            
            return jsonDictionary
            
        } catch {
            
            if let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue)){
                            print("printing JSON received as string: "+strData)
            }else{
                print("json error: \(error.localizedDescription)")
            }
            return NSDictionary() // just return empty
        }
    }
    override func didMove(to view: SKView) {
        // spritekit stuff
        cellSize = view.frame.width / CGFloat(gridSize)
        gridHeight = cellSize * CGFloat(gridSize) // Since the height matches the width
        
        print("GameScene2")
        playerNode.position = CGPoint(x: size.width * 0.2, y: size.height * 0.2)
        playerNode.size = CGSize(width: cellSize - 2, height: cellSize - 2)
        playerNode.alpha = 1.0
        playerNode.isHidden = false
        playerNode.color = SKColor.red

        addChild(playerNode)
        
        playerNode.physicsBody = SKPhysicsBody(rectangleOf: playerNode.size)
        playerNode.physicsBody?.categoryBitMask = PhysicsCategory.player
        playerNode.physicsBody?.contactTestBitMask = PhysicsCategory.missile
        playerNode.physicsBody?.collisionBitMask = PhysicsCategory.none
        playerNode.physicsBody?.affectedByGravity = false
        
        // Set up the enemy
        enemyNode.position = CGPoint(x: size.width * 0.8, y: size.height * 0.8)
        enemyNode.zPosition = 1
        enemyNode.size = CGSize(width: cellSize - 2, height: cellSize - 2)
        addChild(enemyNode)
        
        enemyNode.physicsBody = SKPhysicsBody(rectangleOf: enemyNode.size)
        enemyNode.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        enemyNode.physicsBody?.contactTestBitMask = PhysicsCategory.missile
        enemyNode.physicsBody?.collisionBitMask = PhysicsCategory.none
        enemyNode.physicsBody?.affectedByGravity = false

        physicsWorld.contactDelegate = self

        // Set initial positions
        updateNodePositions()
        
        createGrid()
    }
    
    func createGrid() {
        let gridNode = SKNode()
        addChild(gridNode)

        for i in 0...gridSize {
            let xPos = CGFloat(i) * cellSize
            let yPos = CGFloat(i) * cellSize

            // Vertical line
            let verticalLine = SKShapeNode(path: CGPath(rect: CGRect(x: xPos, y: 0, width: 1, height: gridHeight), transform: nil))
            verticalLine.strokeColor = SKColor.black
            gridNode.addChild(verticalLine)

            // Horizontal line
            let horizontalLine = SKShapeNode(path: CGPath(rect: CGRect(x: 0, y: yPos, width: size.width, height: 1), transform: nil))
            horizontalLine.strokeColor = SKColor.black
            gridNode.addChild(horizontalLine)
        }

        // Center the grid vertically
        let yOffset = (size.height - gridHeight) / 2
        gridNode.position = CGPoint(x: 0, y: yOffset)
    }


    override func update(_ currentTime: TimeInterval) {
        updateNodePositions()

        checkForCollisions()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if !playerCanMove { return }
        let location = touch.location(in: self)

        if location.x < frame.midX {
            // Move left
            playerDidMove(.left)
        } else if location.x >= frame.midX {
            // Move right
            playerDidMove(.right)
        }

        // Handle missile logic
        handleMissileLogic()
    }
    
    func handleMissileLogic() {
        tapCount += 1

        if tapCount % 5 == 0 {
            spawnMissile()
        }
        
        if tapCount % 7 == 0 {
            spawnEnemyMissile()
        }

        // Move missile
        moveMissile()
    }
    
    func spawnMissile() {
        // Create missile if not already present
        if missilePosition == nil {
            missilePosition = CGPoint(x: playerPosition.x, y: playerPosition.y)
        }
    }
    
    func spawnEnemyMissile() {
        // Create missile if not already present
        if enemyMissilePosition == nil {
            enemyMissilePosition = CGPoint(x: enemyPosition.x, y: enemyPosition.y)
        }
    }
    
    func moveMissile() {
        // Move missile upwards
        if let missilePos = missilePosition {
            missilePosition = CGPoint(x: missilePos.x, y: missilePos.y + 1)

            // Check if missile is off the grid
            if missilePos.y >= CGFloat(gridSize) {
                missilePosition = nil
            }
        }
        
        if let enemyMissilePos = enemyMissilePosition {
            enemyMissilePosition = CGPoint(x: enemyMissilePos.x, y: enemyMissilePos.y - 1)

            // Check if missile is off the grid
            if enemyMissilePos.y < 0 {
                enemyMissilePosition = nil
            }
        }
    }
    
    func updateNodePositions() {
        // Update player position
        playerNode.position = positionForGridPoint(playerPosition)

        // Update missile position if it exists
        if let missilePos = missilePosition {
            if missileNode == nil {
                missileNode = createMissileNode() // Method to create missile node
                addChild(missileNode!)
            }
            missileNode!.position = positionForGridPoint(missilePos)
        } else {
            missileNode?.removeFromParent()
            missileNode = nil
        }
        
        if let enemyMisslePos = enemyMissilePosition {
            if enemyMissileNode == nil {
                enemyMissileNode = createEnemyMissile() // Method to create missile node
                addChild(enemyMissileNode!)
            }
            enemyMissileNode!.position = positionForGridPoint(enemyMisslePos)
        } else {
            enemyMissileNode?.removeFromParent()
            enemyMissileNode = nil
        }

     
        enemyNode.position = positionForGridPoint(enemyPosition)

    }

    func positionForGridPoint(_ point: CGPoint) -> CGPoint {
        // Determine the size of each grid cell
        let cellWidth = size.width / CGFloat(gridSize)
        let cellHeight = cellWidth // Since the height should match the width

        // Calculate the x and y position
        let xPosition = (point.x * cellWidth) + (cellWidth / 2) // Center of the cell
        let yPosition = (point.y * cellHeight) + (cellHeight / 2) // Center of the cell

        // Return the calculated position
        let yOffset = (size.height - gridHeight) / 2
        return CGPoint(x: xPosition, y: yPosition + yOffset)
    }


    func checkForCollisions() {
   
    }

    // Other methods...
    func createMissileNode() -> SKSpriteNode {
        let missile = SKSpriteNode(imageNamed: "fireball")
        missile.position = playerNode.position // Starting position is the player's position
        missile.zPosition = 1 // Ensure it's visible above other nodes
        missile.size = CGSize(width: cellSize - 2, height: cellSize - 2) // Set the size as needed
        missile.zRotation = CGFloat.pi // Rotate 180 degrees

        missile.physicsBody = SKPhysicsBody(rectangleOf: missile.size) // or use `circleOfRadius` if more appropriate
        missile.physicsBody?.categoryBitMask = PhysicsCategory.missile
        missile.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        missile.physicsBody?.collisionBitMask = PhysicsCategory.none
        missile.physicsBody?.affectedByGravity = false
        
        return missile
    }
    
    func createEnemyMissile() -> SKSpriteNode {
        let enemyMissile = SKSpriteNode(imageNamed: "enemyMissile")
        enemyMissile.position = enemyPosition
        enemyMissile.name = "enemyMissile"
        enemyMissile.zPosition = 1  // Adjust as needed
        enemyMissile.size = CGSize(width: cellSize - 2, height: cellSize - 2) // Set the size as needed

        // Set up physics body for collision detection, if needed
        enemyMissile.physicsBody = SKPhysicsBody(rectangleOf: enemyMissile.size)
        enemyMissile.physicsBody?.categoryBitMask = PhysicsCategory.missile
        enemyMissile.physicsBody?.contactTestBitMask = PhysicsCategory.player
        enemyMissile.physicsBody?.collisionBitMask = 0
        enemyMissile.physicsBody?.affectedByGravity = false

        return enemyMissile
    }

    
    func convertGameDataToFeatureVector(_ gameData: GameData, maxMoves: Int) -> [Double] {
        var featureVector = [Double]()

        // Interleave player and enemy moves
        for index in 0..<maxMoves {
            if index < gameData.playerMoves.count {
                featureVector.append(gameData.playerMoves[index].numericValue)
            } else {
                featureVector.append(0) // Pad with 0 if no move
            }

            if index < gameData.enemyMoves.count {
                featureVector.append(gameData.enemyMoves[index].numericValue + 2) // +2 to differentiate enemy moves
            } else {
                featureVector.append(0) // Pad with 0 if no move
            }
        }

        return featureVector
    }

    
    

}

extension GameScene2: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        print(collision)
        
        if collision == PhysicsCategory.missile | PhysicsCategory.enemy {
            print("done")
            endGame(playerWon: true)
            return
        }
        
        if (collision == PhysicsCategory.missile | PhysicsCategory.player) {
            endGame(playerWon: false)
            return
        }
    }
}
