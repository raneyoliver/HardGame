from flask import Flask, request, jsonify
import joblib
import os
from pymongo import MongoClient
import datetime
import coremltools
from google.cloud import storage
import re
from sklearn.ensemble import RandomForestClassifier  # Example classifier


app = Flask(__name__)
mongo_connection_string = "mongodb+srv://raneyoliver:Javalops7611@smu-hardgamecluster.2miille.mongodb.net/?retryWrites=true&w=majority"
bucket_name = 'bucket-hardgameflaskapp-models'

@app.route('/upload_game_data', methods=['POST'])
def upload_game_data():
    # Receive data
    game_data = request.json
    # Retrain model
    new_model = retrain_model(game_data)
    # Save and upload new model
    save_and_upload_model(new_model)
    return jsonify({"success": True})

@app.route('/get_latest_coreml_model', methods=['GET'])
def get_latest_coreml_model():
    # Get the latest sklearn model metadata
    latest_model_metadata = get_latest_model_metadata()

    if latest_model_metadata == None:
        new_model = initialize_new_model()
        save_and_upload_model(new_model)
        sklearn_model_url = "sklearn_model1.pkl"
    else:
        sklearn_model_url = latest_model_metadata.get("model_file_url")


    # Download the sklearn model
    sklearn_model_path = download_model_from_gcp(sklearn_model_url)

    # Convert the sklearn model to CoreML
    coreml_model_path = convert_to_coreml(sklearn_model_path)

    # Send the CoreML model file as a response
    return send_file(coreml_model_path, as_attachment=True)


def retrain_model(game_data, bucket_name, model_file_name):
    # Path for the local model file
    local_model_path = 'model.pkl'

    # Try to download the model from GCP
    downloaded_model_path = download_model_from_gcp(bucket_name, model_file_name, local_model_path)

    # Load the model if downloaded, otherwise initialize a new one
    if downloaded_model_path:
        model = joblib.load(downloaded_model_path)
    else:
        model = initialize_new_model()

    # Prepare the data for training
    X, y = preprocess_game_data(game_data)

    # Train or retrain the model
    model.fit(X, y)

    # Save the retrained model locally
    joblib.dump(model, local_model_path)

    # Optionally, upload the updated model back to GCP
    # upload_model_to_gcp(bucket_name, model_file_name, local_model_path)

    return model


def preprocess_game_data(game_data):
    # Initialize lists for features and labels
    X = []
    y = []

    for data_point in game_data:
        # Extract features and label from each data point
        features = [
            data_point['playerX'],
            data_point['playerY'],
            data_point['enemyX'],
            data_point['enemyY'],
            data_point['missileX'],
            data_point['missileY'],
            data_point['enemyMissileX'],
            data_point['enemyMissileY'],
            data_point['enemyMove']  # Assuming this is a numerical representation of the move
        ]
        label = data_point['outcome']  # Assuming 'outcome' is 1 for hit and 0 for not hit

        X.append(features)
        y.append(label)

    return X, y


def initialize_new_model():
    # Initialize your classifier
    # Here, we're using RandomForestClassifier as an example
    model = RandomForestClassifier()
    return model



def save_and_upload_model(sklearn_model):
    model_file = f"sklearn_model{generate_new_version_number()}.pkl"

    # Save the sklearn model locally
    joblib.dump(sklearn_model, model_file)

    # Upload the sklearn model to GCP
    model_file_url = upload_to_gcp(model_file, bucket_name)

    # Update MongoDB Realm with the new model metadata
    update_model_metadata_in_realm(model_file_url)

def update_model_metadata_in_realm(model_file_url):
    client = MongoClient(mongo_connection_string, tlsAllowInvalidCertificates=True)
    db = client.your_database
    models_collection = db.models

    model_metadata = {
        'version': generate_new_version_number(),  # Implement this
        'upload_date': datetime.datetime.utcnow(),
        'model_file_url': model_file_url
    }
    models_collection.insert_one(model_metadata)


def upload_to_gcp(file_path, bucket_name):
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_path)
    
    blob.upload_from_filename(file_path)

    # Return the public URL
    return f"gs://{bucket_name}/{file_path}"

def convert_to_coreml(sklearn_model):
    # Convert the SciKit-Learn model to CoreML format
    coreml_model = coremltools.converters.sklearn.convert(sklearn_model)
    coreml_model.save('model.mlmodel')
    return 'model.mlmodel'


def generate_new_version_number():
    client = MongoClient(mongo_connection_string, tlsAllowInvalidCertificates=True)
    db = client.HGDB
    models_collection = db.models
    last_version = models_collection.find_one(sort=[("version", -1)])
    if last_version is not None:
        return last_version["version"] + 1
    else:
        return 1  # Start from 1 if no models are in the collection


def get_latest_model_metadata():
    client = MongoClient(mongo_connection_string, tlsAllowInvalidCertificates=True)
    db = client.HGDB
    models_collection = db.models

    # Fetch the latest model metadata sorted by upload_date
    try:
        latest_model_metadata = models_collection.find().sort("upload_date", -1).limit(1).next()
    except:
        return None
    
    return latest_model_metadata

def download_model_from_gcp(bucket_name, local_path='model.pkl'):
    file_names = list_files_in_gcs(bucket_name)
    latest_file = get_latest_model_file(file_names)

    if latest_file is None:
        latest_file = initialize_new_model()

    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(latest_file)

    try:
        blob.download_to_filename(local_path)
        print("Model downloaded successfully.")
        return local_path
    except NotFound:
        print("Model file not found in GCP.")
        return None



def list_files_in_gcs(bucket_name, prefix="sklearn_model"):
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)

    blobs = bucket.list_blobs(prefix=prefix)
    return [blob.name for blob in blobs]



def get_latest_model_file(file_names):
    latest_version = -1
    latest_file = None

    for file_name in file_names:
        match = re.search(r'sklearn_model(\d+)\.pkl', file_name)
        if match:
            version = int(match.group(1))
            if version > latest_version:
                latest_version = version
                latest_file = file_name

    return latest_file


if __name__ == '__main__':
    app.run(debug=True)
