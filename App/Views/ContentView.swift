import SwiftUI
import RealmSwift

struct ContentView: View {
    @ObservedObject var app: RealmSwift.App
    @EnvironmentObject var errorHandler: ErrorHandler

    var body: some View {
        if app.currentUser != nil {
            StoryboardViewControllerRepresentable(storyboardName: "Storyboard", viewControllerID: "GameViewController")
        } else {
            LoginView()
        }
    }
}



struct StoryboardViewControllerRepresentable: UIViewControllerRepresentable {
    var storyboardName: String
    var viewControllerID: String
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Load the storyboard
        let storyboard = UIStoryboard(name: storyboardName, bundle: Bundle.main)
        // Instantiate the view controller with the given identifier
        let viewController = storyboard.instantiateViewController(identifier: viewControllerID)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Leave this empty
    }
}
