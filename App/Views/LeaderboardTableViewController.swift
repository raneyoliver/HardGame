//
//  LeaderboardTableViewController.swift
//  App
//
//  Created by Oliver Raney on 12/9/23.
//

import UIKit
import RealmSwift

class LeaderboardTableViewController: UITableViewController {
    var leaderboards: Results<leaderboard>!
    var sortedLeaderboards: Results<leaderboard>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("Leaderboard loaded")
        
        //        let config = Realm.Configuration(
        //            // Increment the schema version whenever the schema changes
        //            schemaVersion: 2,
        //
        //            // Set the block to execute when a migration is needed
        //            migrationBlock: { migration, oldSchemaVersion in
        //                if oldSchemaVersion < 2 {
        //                    // If you've renamed or changed the type of any property,
        //                    // you need to handle the data migration here
        //
        //                    // For changing 'beatTime' from double to date
        //                    migration.enumerateObjects(ofType: leaderboard.className()) { oldObject, newObject in
        //                        if let beatTime = oldObject?["beatTime"] as? Double {
        //                            newObject?["beatTime"] = Date(timeIntervalSince1970: beatTime)
        //                        }
        //                    }
        //
        //                    // Since '_id' and 'additionalStats' are new properties,
        //                    // they will be automatically added by Realm
        //                }
        //            }
        //        )
        
        Task {
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
            
            leaderboards = realm.objects(leaderboard.self)
            sortedLeaderboards = leaderboards.sorted(byKeyPath: "beatTime", ascending: true)
            
            
            print("All leaderboard docs in Realm: \(leaderboards.count)")
            for doc in leaderboards {
                print("playerName: \(doc.userName ?? "")")
            }
            // Update UI on the main thread if needed
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        
        let button = UIButton(frame: CGRect(x: 20, y: 500, width: 100, height: 50))
        button.setTitle("Back", for: .normal)
        button.backgroundColor = .blue
        button.addTarget(self, action: #selector(navigateBackToGame), for: .touchUpInside)
        self.view.addSubview(button)
    }
    
    @objc func navigateBackToGame() {
        dismiss(animated: true)
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return leaderboards?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LeaderboardCell", for: indexPath)
        
        let leaderboard = sortedLeaderboards[indexPath.row]
        cell.textLabel?.text = leaderboard.userName
        cell.detailTextLabel?.text = "AI: \(leaderboard.aiVersion ?? ""), Beaten: \(leaderboard.beatTime ?? Date())"
        
        return cell
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
}


class leaderboard: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var additionalStats: leaderboard_additionalStats?
    @Persisted var aiVersion: String?
    @Persisted var beatTime: Date?
    @Persisted var userName: String?
}



class leaderboard_additionalStats: EmbeddedObject {
    @Persisted var gameDuration: String?
    @Persisted var score: Int?
}

