# Hard Game

## Notes for the grader

The third constraint is currently in a basic form. While the leaderboard successfully displays updates with new enemy defeats, the feature's refinement and polish are still in progress. However, the core functionality is operational.

Regarding the fourth constraint, the foundational code is in place, but integration challenges have prevented full functionality. The model utilizes the "enemyHit" label as a substitute for "successful" or "not successful" outcomes. However, issues have arisen in the loading and storage of model versions, primarily due to various unexpected errors.

Overall, the necessary code for the app's intended functions exists, but time constraints have hindered the seamless integration and error-free operation of these features. A significant portion of the development time was dedicated to mastering MongoDB functionalities, which limited the time available for implementing and storing the ML models in the cloud. The objective was to centralize all operations in the cloud, specifically using Google Cloud, to eliminate the need for users to run their own servers for ML training and to facilitate the app's deployment on the app store. Despite the challenges faced, this project has been a substantial learning experience, and it's hoped that the app's potential direction and progress are evident.


Features:

Login Screen: Allows users to create an account or log in. User data is managed using MongoDB Realm's Flexible Sync Realm.
Game Screen: A turn-based game where players combat an AI enemy. The enemy's movements are determined by predictions from a CoreML model.
Leaderboards Screen: Displays recent victors, showing usernames, the version of the ML model defeated, and the time/date of their victory. This data is stored in MongoDB Realm.
CoreML Model Integration:

The enemy's behavior is driven by a CoreML model.
After each defeat of the enemy, the model is retrained.
Model versions are stored on Google Cloud Platform (GCP).
Backend and Data Management:

A Flask app on GCP handles several key functions:
Retrieves the latest model metadata from MongoDB Realm.
Fetches the latest scikit-learn random forest classifier model from a GCP bucket and converts it to a CoreML format.
Manages the upload of game data for model retraining.
Leaderboard data is updated in MongoDB Realm via requests from the Swift app each time an enemy is defeated.
Model Retraining and Storage:

The CoreML model is retrained with new game data.
Updated models are stored on GCP for future use.
This architecture creates a dynamic gaming experience where player interactions directly influence the game's AI behavior, providing a continuously evolving challenge.

# Architectural Diagram

![mermaid-diagram-2023-12-12-182251](https://github.com/raneyoliver/HardGame/assets/40372643/a87ebf39-0d7e-4735-9c24-ca9c94f4b629)
