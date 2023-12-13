import SwiftUI
import RealmSwift

/// Log in or register users using email/password authentication
struct LoginView: View {
    @State var email = ""
    @State var password = ""

    @State private var isLoggingIn = false
    @EnvironmentObject var errorHandler: ErrorHandler

    var body: some View {
        VStack {
            if isLoggingIn {
                ProgressView()
            }
            VStack {
                Text("Hard Game")
                    .font(.title)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                Button("Log In") {
                    // Button pressed, so log in
                    isLoggingIn = true
                    Task.init {
                        await login(email: email, password: password)
                        isLoggingIn = false
                    }
                }
                .disabled(isLoggingIn)
                .frame(width: 150, height: 50)
                .background(Color(red: 0.25, green: 0.59, blue: 0.22))
                .foregroundColor(.white)
                .clipShape(Capsule())
                Button("Create Account") {
                    // Button pressed, so create account and then log in
                    isLoggingIn = true
                    Task {
                        await handleUserSignup(email: email, password: password)
                        isLoggingIn = false
                    }
                }
                .disabled(isLoggingIn)
                .frame(width: 150, height: 50)
                .background(Color(red: 0.25, green: 0.59, blue: 0.22))
                .foregroundColor(.white)
                .clipShape(Capsule())
                Text("Create an account or Log in to share your wins on the leaderboard!")
                    .font(.footnote)
                    .padding(20)
                    .multilineTextAlignment(.center)
            }.padding(20)
        }
    }

    /// Logs in with an existing user.
    func login(email: String, password: String) async {
        do {
            let user = try await app.login(credentials: Credentials.emailPassword(email: email, password: password))
            print("Successfully logged in user: \(user)")
            await checkForUserDocument()
        } catch {
            print("Failed to log in user: \(error.localizedDescription)")
            errorHandler.error = error
        }
    }
    
    func handleUserSignup(email: String, password: String) async {
        // Example user sign-up process
        await signUp(email: email, password: password)

        // Now check for the user document
        await checkForUserDocument()
    }

    
    /// Registers a new user with the email/password authentication provider.
    func signUp(email: String, password: String) async {
        do {
            try await app.emailPasswordAuth.registerUser(email: email, password: password)
            print("Successfully registered user")

            let user = try await app.login(credentials: .emailPassword(email: email, password: password))
            print("Successfully logged in user")

            // Create a new user document
            let userDocument = UserDocument(user_id: user.id, username: nil, created: Date())
            
            // Insert the document into the 'users' collection
            await insertUserDocument(userDocument)
        } catch {
            print("Error occurred during sign up or document creation: \(error.localizedDescription)")
            errorHandler.error = error
        }
    }

    func insertUserDocument(_ document: UserDocument) async {
        do {
            // Manually create a BSON document from UserDocument
            var bsonDocument: [String: AnyBSON] = [:]
            bsonDocument["user_id"] = AnyBSON(document.user_id)
            bsonDocument["username"] = AnyBSON(document.username ?? "")
            bsonDocument["created"] = AnyBSON(document.created)
            

            guard let currentUser = app.currentUser else {
                print("No authenticated user found")
                return
            }
            
            //print(bsonDocument)

            // Call the Realm function with BSON document
            let result = try await currentUser.functions.insertUser([AnyBSON(bsonDocument)])

            //print(result)

            // Handle the result
            if let resultDict = result.documentValue, let success = resultDict["success"] as? Bool, success {
                print("Successfully inserted user document")
            } else {
                print("Failed to insert user document")
            }
        } catch let error as NSError {
            print("Error calling Realm function: \(error.localizedDescription), \(error.userInfo)")
        }
    }

    func checkForUserDocument() async {
        if let currentUser = app.currentUser {
            let userId = currentUser.id

            do {
                let realm = try await Realm()
                let allUsers = realm.objects(users.self)
                
                print("All users in Realm:")
                for user in allUsers {
                    print("User ID: \(user.user_id)")
                    if let username = user.username {
                        print("Username: \(username)")
                    } else {
                        print("Username: Not set")
                    }
                    // Print other fields as needed
                }
            } catch {
                print("Error initializing Realm: \(error)")
            }

            
            do {
                let realm = try await Realm()
                if let userDocument = realm.objects(users.self).filter("user_id == %@", userId).first {
                    if userDocument.username == "" || userDocument.username == nil {
                        print("User needs to set a username.")
                    } else {
                        print("Username is already set: \(userDocument.username!)")
                    }
                } else {
                    print("No user document found for the user \(userId).")
                }
            } catch {
                print("Error initializing Realm: \(error)")
            }
        }
    }


}


struct UserDocument: Codable {
    var user_id: String
    var username: String?
    var created: Date
}

@objcMembers class users: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var user_id: String  // MongoDB User ID
    @Persisted var username: String?
    @Persisted var created: Date
    
    override static func _realmObjectName() -> String {
            return "users"  // The name of your collection in MongoDB
        }
}
