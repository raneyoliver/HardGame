//
//  GameScene2.swift
//  HTTPSwiftExample
//
//  Created by Oliver Raney on 11/20/23.
//  Copyright © 2023 Eric Larson. All rights reserved.
//

import UIKit
import SpriteKit
import RealmSwift
import CoreML

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
    var playerX: Double
    var playerY: Double
    var enemyX: Double
    var enemyY: Double
    var missileX: Double
    var missileY: Double
    var enemyMissileX: Double
    var enemyMissileY: Double
    var enemyPotentialMove: String
}

struct MoveData: Codable {
    var playerX: Double
    var playerY: Double
    var enemyX: Double
    var enemyY: Double
    var missileX: Double
    var missileY: Double
    var enemyMissileX: Double
    var enemyMissileY: Double
    var enemyMove: Double
    var outcome: Double
}

let flask_app_url:String = "https://hardgameflaskapp.uc.r.appspot.com"

class GameScene2: SKScene, URLSessionDelegate {
    
    let gameAIManager:GameAIManager = GameAIManager()
    
    let operationQueue = OperationQueue()
    
    var playerCanMove:Bool = true
    
    var playerNode = SKSpriteNode(imageNamed: "warrior")
    var missileNode: SKSpriteNode!
    var enemyMissileNode: SKSpriteNode!
    var enemyNode = SKSpriteNode(imageNamed: "enemy")
    
    var nextEnemyMove:Double = -1.0
    
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
    
    var currentGameData = GameData(playerX: 0.0, playerY: 0.0, enemyX: 0.0, enemyY: 0.0, missileX: 0.0, missileY: 0.0, enemyMissileX: 0.0, enemyMissileY: 0.0, enemyPotentialMove: "")
    
    var allMoves:[MoveData] = []
    
    func playMoveSound() {
        let playSound = SKAction.playSoundFileNamed("move.wav", waitForCompletion: false)
        self.run(playSound)
    }
    
    func playKillSound() {
        let playSound = SKAction.playSoundFileNamed("kill.mp3", waitForCompletion: false)
        self.run(playSound)
    }
    
    func triggerHapticFeedback() {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred()
    }

    
    // move player across grid
    func playerDidMove(_ move: Move) {
        
        // if player moving, enemy wasn't hit on previous move
        let previousEnemyMove = MoveData(playerX: playerNode.position.x, playerY: playerNode.position.y, enemyX: enemyNode.position.x, enemyY: enemyNode.position.y, missileX: Double(missileNode?.position.x ?? -1.0), missileY: Double(missileNode?.position.y ?? -1.0), enemyMissileX: Double(enemyMissileNode?.position.x ?? -1.0), enemyMissileY: Double(enemyMissileNode?.position.y ?? -1.0), enemyMove: nextEnemyMove, outcome: 0.0)
        
        allMoves.append(previousEnemyMove)
        
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
        
        playMoveSound()
        triggerHapticFeedback()
        
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
        // Assume gameAIManager has already loaded the model
        
        let bestMove = gameAIManager.predictBestMove(gameData: currentGameData)
        
        if bestMove == "left" {
            enemyDidMove(.left)
        }
        else if bestMove == "right" {
            enemyDidMove(.right)
        }
        else {
            // place holder -- moves randomly if an error occurs in prediction
            enemyDidMove(Bool.random() ? .left : .right)
            //enemyDidMove(.right)
        }
        
        triggerHapticFeedback()
        
    }
    
    
    // same as player did move()
    func enemyDidMove(_ move: Move) {
        
        
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
    func endGame(playerWon: Bool) async {
        
        if (playerWon) {
            await addDataPoint()
        }
        
        allMoves.append(MoveData(playerX: playerNode.position.x, playerY: playerNode.position.y, enemyX: enemyNode.position.x, enemyY: enemyNode.position.y, missileX: Double(missileNode?.position.x ?? -1.0), missileY: Double(missileNode?.position.y ?? -1.0), enemyMissileX: Double(enemyMissileNode?.position.x ?? -1.0), enemyMissileY: Double(enemyMissileNode?.position.y ?? -1.0), enemyMove: nextEnemyMove, outcome: playerWon ? 1.0 : 0.0))
                        
        
        // RETRAIN!! THIS IS THe WHOLE GIMMICK
        uploadGameData(allMoves)
        
        // reset game data
        currentGameData = GameData(playerX: 0.0, playerY: 0.0, enemyX: 0.0, enemyY: 0.0, missileX: 0.0, missileY: 0.0, enemyMissileX: 0.0, enemyMissileY: 0.0, enemyPotentialMove: "")
        
        func downloadAndLoadModel() {
            downloadLatestCoreMLModel { localURL in
                guard let url = localURL else {
                    print("Failed to download the model")
                    return
                }
                print("url:", url)
                self.gameAIManager.loadModel(from: url)
            }
        }
        downloadAndLoadModel()
    }
    
    func openSyncedRealm() async throws -> Realm  {
        let realm = try! await openFlexibleSyncRealm()
        
        // Opening a realm and accessing it must be done from the same thread.
        // Marking this function as `@MainActor` avoids threading-related issues.
        @MainActor
        func openFlexibleSyncRealm() async throws  -> Realm {
            let user = app.currentUser
            var config = user!.flexibleSyncConfiguration()
            // Pass object types to the Flexible Sync configuration
            // as a temporary workaround for not being able to add complete schema
            // for a Flexible Sync app
            config.objectTypes = [leaderboard.self, leaderboard_additionalStats.self]
            let realm = try await Realm(configuration: config, downloadBeforeOpen: .always)
            print("Successfully opened realm: \(realm)")
            return realm
        }
        
        return realm
    }
    
    func addDataPoint() async {
        do {
            let realm = try await openSyncedRealm()
            let subscriptions = realm.subscriptions
            let foundSubscription = subscriptions.first(named: "all_leaderboards")
            try await subscriptions.update {
                if foundSubscription != nil {
                    foundSubscription!.updateQuery(toType: leaderboard.self)
                } else {
                    subscriptions.append(QuerySubscription<leaderboard>(name: "all_leaderboards"))
                }
            }
            
            gameAIManager.fetchLatestModelVersion()
            let newScore = leaderboard()
            newScore.aiVersion = "\(gameAIManager.latestModelVersion ?? -1)"
            newScore.beatTime = Date()
            newScore.userName = "placeholder" //await getUserName()
            try realm.write {
                realm.add(newScore)
            }
        } catch {
            print("Failed to write to realm: \(error.localizedDescription)")
        }
    }
    
    func getUserName() async -> String? {
        do {
            let realm = try await openSyncedRealm()
            let subscriptions = realm.subscriptions
            let foundSubscription = subscriptions.first(named: "all_users")
            try await subscriptions.update {
                if foundSubscription != nil {
                    foundSubscription!.updateQuery(toType: users.self)
                } else {
                    
                    subscriptions.append(
                        QuerySubscription<users>(name: "all_users") {
                            $0.user_id == app.currentUser?.id ?? ""
                        })
                }
            }
            
            return realm.objects(users.self).first?.username
        } catch {
            print("Failed to write to realm: \(error.localizedDescription)")
        }
        
        return ""
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
        
        func downloadAndLoadModel() {
            downloadLatestCoreMLModel { localURL in
                guard let url = localURL else {
                    print("Failed to download the model")
                    return
                }
                print("starting game. url of local model:", url)
                self.gameAIManager.loadModel(from: url)
            }
        }
        downloadAndLoadModel()
        
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
        //print("player: ", playerNode.position)
        
        // Update missile position if it exists
        if let missilePos = missilePosition {
            if missileNode == nil {
                missileNode = createMissileNode() // Method to create missile node
                addChild(missileNode!)
            }
            missileNode!.position = positionForGridPoint(missilePos)
            //print("missile: ", missileNode.position)
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
            //print("enemyMissile: ", enemyMissileNode.position)
        } else {
            enemyMissileNode?.removeFromParent()
            enemyMissileNode = nil
        }
        
        
        enemyNode.position = positionForGridPoint(enemyPosition)
        //print("enemy: ", enemyNode.position)
        
    }
    
    func positionForGridPoint(_ point: CGPoint) -> CGPoint {
        // Determine the size of each grid cell
        let cellWidth = size.width / CGFloat(gridSize)
        let cellHeight = cellWidth // Since the height should match the width
        
        // Calculate the x and y position
        let xPosition = (point.x * cellWidth) + (cellWidth / 2) // Center of the cell
        let yPosition = (point.y * cellHeight) + (cellHeight / 2) // Center of the cell
        
        // Return the calculated position
        let yOffset = (size.height - gridHeight) / 2 + 10
        return CGPoint(x: xPosition, y: yPosition + yOffset)
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
    
    
    func uploadGameData(_ gameData: [MoveData]) {
        let url = URL(string: flask_app_url + "/upload_game_data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            // Encode your array of MoveData to JSON
            let jsonData = try JSONEncoder().encode(gameData)
            request.httpBody = jsonData
        } catch {
            print("Error encoding game data: \(error)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error during upload: \(error)")
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool else {
                print("Failed to parse response or response missing 'success' key")
                return
            }
            
            if success {
                print("Upload was successful")
            } else {
                print("Upload failed")
            }
        }
        task.resume()
    }
    
    
    
    func downloadLatestCoreMLModel(completion: @escaping (URL?) -> Void) {
        let url = URL(string: flask_app_url + "/get_latest_coreml_model")!
        let task = URLSession.shared.downloadTask(with: url) { localURL, _, error in
            guard let localURL = localURL, error == nil else {
                print("Model download failed: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            completion(localURL)
        }
        task.resume()
    }
    
}

extension GameScene2: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        print(collision)
        
        if collision == PhysicsCategory.missile | PhysicsCategory.enemy {
            print("done")
            playKillSound()
            
            if let fire = SKEmitterNode(fileNamed: "Fire") {
                fire.position = enemyNode.position
                addChild(fire)
                
                // Remove the emitter after duration of the fireworks
                let wait = SKAction.wait(forDuration: 2.0)
                let remove = SKAction.removeFromParent()
                fire.run(SKAction.sequence([wait, remove]))
            }
            Task {
                await endGame(playerWon: true)
            }
            return
        }
        
        if (collision == PhysicsCategory.missile | PhysicsCategory.player) {
            Task {
                await endGame(playerWon: false)
            }
            return
        }
    }
}

class GameAIManager {
    var currentModel: MLModel?
    var latestModelVersion: Int?
    
    func fetchLatestModelVersion() {
        let realm = try! Realm()  // Make sure to handle errors in production code
        
        // Query the 'models' collection to find the latest version
        if let latestModel = realm.objects(model.self).sorted(byKeyPath: "version", ascending: false).first {
            latestModelVersion = latestModel.version
            print("Latest model version: \(latestModel.version ?? -1)")
        } else {
            print("No models found in the database.")
            latestModelVersion = nil
        }
    }
    
    func loadModel(from url: URL) {
        do {
            let coremlmodel = try MLModel(contentsOf: url)
            self.currentModel = coremlmodel
        } catch {
            print("Error loading model: \(error)")
        }
    }
    
    func predictBestMove(gameData: GameData) -> String {
        guard let _ = currentModel else {
            print("Model not loaded")
            return "left" // Default move
        }
        
        // Predict for both moves
        let predictionLeft = predictMove(gameData: gameData, move: "left")
        let predictionRight = predictMove(gameData: gameData, move: "right")
        
        // Decide the best move
        return chooseBestMove(predictionLeft: predictionLeft, predictionRight: predictionRight)
    }
    
    private func predictMove(gameData: GameData, move: String) -> Double {
        let featureProvider = prepareFeatureProvider(from: gameData, move: move)
        
        do {
            guard let predictionOutput = try currentModel?.prediction(from: featureProvider) else { return 0.5 }
            return handlePredictionResult(predictionOutput)
        } catch {
            print("Error during prediction: \(error)")
            return -1 // Indicate an error
        }
    }
    
    private func prepareFeatureProvider(from gameData: GameData, move: String) -> MLFeatureProvider {
        let featureValues: [String: MLFeatureValue] = [
            "playerX": MLFeatureValue(double: gameData.playerX),
            "playerY": MLFeatureValue(double: gameData.playerY),
            "enemyX": MLFeatureValue(double: gameData.enemyX),
            "enemyY": MLFeatureValue(double: gameData.enemyY),
            "missileX": MLFeatureValue(double: gameData.missileX),
            "missileY": MLFeatureValue(double: gameData.missileY),
            "enemyMissileX": MLFeatureValue(double: gameData.enemyMissileX),
            "enemyMissileY": MLFeatureValue(double: gameData.enemyMissileY),
            "enemyPotentialMove": MLFeatureValue(string: move)
        ]
        return try! MLDictionaryFeatureProvider(dictionary: featureValues)
    }
    
    
    private func handlePredictionResult(_ predictionOutput: MLFeatureProvider) -> Double {
        // Assuming the model outputs a feature named "enemyHitProbability"
        let hitProbability = predictionOutput.featureValue(for: "enemyHitProbability")?.doubleValue ?? 0.0
        return hitProbability
    }
    
    
    private func chooseBestMove(predictionLeft: Double, predictionRight: Double) -> String {
        // Choose the move with the lower probability of being hit
        return (predictionLeft < predictionRight) ? "left" : "right"
    }
    
}


class model: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    
    @Persisted var model_file_url: String?
    
    @Persisted var upload_date: String?
    
    @Persisted var version: Int?
}

