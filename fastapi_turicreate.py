#!/usr/bin/python
'''
In this example, we will use FastAPI as a gateway into a MongoDB database. We will use a REST style
interface that allows users to initiate GET, POST, PUT, and DELETE requests. These commands will
also be used to control certain functionalities with machine learning, using the ReST server to
function as a machine learning as a service, MLaaS provider.

Specifically, we are creating an app that can take in motion sampled data and labels for
segments of the motion data

The swift code for interacting with the interface is also available through the SMU MSLC class
repository.
Look for the https://github.com/SMU-MSLC/SwiftHTTPExample with branches marked for FastAPI and
turi create

To run this example in localhost mode only use the command:
fastapi dev fastapi_turicreate_motion.py

Otherwise, to run the app in deployment mode (allowing for external connections), use:
fastapi run fastapi_turicreate_motion.py

External connections will use your public facing IP, which you can find from the inet.
A useful command to find the right public facing ip is:
ifconfig |grep "inet "
which will return the ip for various network interfaces from your card. If you get something like this:
inet 10.9.181.129 netmask 0xffffc000 broadcast 10.9.191.255
then your app needs to connect to the netmask (the first ip), 10.9.181.129
'''

# For this to run properly, MongoDB should be running
#    To start mongo use this: brew services start mongodb-community@6.0
#    To stop it use this: brew services stop mongodb-community@6.0

# This App uses a combination of FastAPI and Motor (combining tornado/mongodb) which have documentation here:
# FastAPI:  https://fastapi.tiangolo.com
# Motor:    https://motor.readthedocs.io/en/stable/api-tornado/index.html

# Maybe the most useful SO answer for FastAPI parallelism:
# https://stackoverflow.com/questions/71516140/fastapi-runs-api-calls-in-serial-instead-of-parallel-fashion/71517830#71517830
# Chris knows what's up


import os
import io
from typing import Optional, List
from enum import Enum


# FastAPI imports
from fastapi import FastAPI, Body, HTTPException, status, File, UploadFile
from fastapi.responses import Response
from pydantic import ConfigDict, BaseModel, Field
from pydantic.functional_validators import BeforeValidator
from typing_extensions import Annotated
# Motor imports
from bson import ObjectId
import motor.motor_asyncio
from pymongo import ReturnDocument
# Machine Learning, Turi and Sklearn Imports
import turicreate as tc
from sklearn.neighbors import KNeighborsClassifier
from PIL import Image
import numpy as np
import base64
from joblib import dump, load
from sklearn.svm import SVC
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline


# define some things in API
async def custom_lifespan(app: FastAPI):
    app.mongo_client = motor.motor_asyncio.AsyncIOMotorClient()
    db = app.mongo_client.turidatabase
    app.collection = db.get_collection("labeledimages")
    app.clf = {}  # Classifiers storage
    yield
    app.mongo_client.close()


# Create the FastAPI app
app = FastAPI(
    title="Image Classification Service",
    summary="An application using FastAPI to handle image data, train models, and make predictions.",
    lifespan=custom_lifespan
)


# Helper function to process Base64 image data
def decode_base64_image(base64_str: str) -> np.ndarray:
    """
    Decodes a Base64 string into a NumPy array representing an image.
    """
    image_data = base64.b64decode(base64_str)
    image = Image.open(io.BytesIO(image_data)).convert("L").resize((128, 128))  # Grayscale and resize
    return np.array(image).flatten()


# Pydantic Models
class LabeledImage(BaseModel):
    id: Optional[str] = Field(alias="_id", default=None)
    image_base64: str = Field(...)  # Base64 encoded image data
    label: int = Field(...)  # Image label
    dsid: int = Field(..., le=50)  # Dataset ID
    model_config = ConfigDict(
        populate_by_name=True,
        arbitrary_types_allowed=True,
        json_schema_extra={
            "example": {
                "image_base64": "<Base64 encoded image>",
                "label": 1,
                "dsid": 1,
            }
        },
    )


class ImageDataset(BaseModel):
    datapoints: List[LabeledImage]


# API Endpoints
@app.post(
    "/labeled_data/",
    response_description="Add new labeled image",
    response_model=LabeledImage,
    status_code=status.HTTP_201_CREATED,
)
async def add_labeled_image(image: LabeledImage = Body(...)):
    """
    Add a new labeled image to the dataset.
    """
    if not image.label:
        raise HTTPException(status_code=400, detail="Label is missing in the uploaded data.")
    try:
        # 确保 label 是整数
        # image_data = image.model_dump(by_alias=True, exclude=["id"])
        # image_data["label"] = int(image_data["label"])

        new_image = await app.collection.insert_one(image.model_dump(by_alias=True, exclude=["id"]))
        created_image = await app.collection.find_one({"_id": new_image.inserted_id})

        # 将 `_id` 转换为字符串
        if created_image and "_id" in created_image:
            created_image["_id"] = str(created_image["_id"])

        return created_image
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error inserting data: {str(e)}")




@app.get(
    "/labeled_data/{dsid}",
    response_description="List all labeled images in a given dataset",
    response_model=ImageDataset,
)
async def list_images(dsid: int):
    """
    List all images in a dataset identified by `dsid`.
    """
    datapoints = await app.collection.find({"dsid": dsid}).to_list(1000)
    return ImageDataset(datapoints=datapoints)


@app.get(
    "/train_model_turi/{dsid}",
    response_description="Train an image classification model using Turi",
)
async def train_model_turi(dsid: int):
    """
    Train a TuriCreate model using images from the specified dataset.
    """
    datapoints = await app.collection.find({"dsid": dsid}).to_list(length=None)
    if len(datapoints) < 2:
        raise HTTPException(status_code=404, detail=f"Not enough data in DSID {dsid} to train a model.")

    labels = [datapoint["label"] for datapoint in datapoints]
    # features = [decode_base64_image(datapoint["image_base64"]) for datapoint in datapoints]
    features = [decode_base64_image(datapoint["image_base64"]).tolist() for datapoint in datapoints]

    # Train model
    data = tc.SFrame({"target": labels, "sequence": features})
    model = tc.classifier.create(data, target="target", verbose=0)
    model.save(f"../models/turi_model_dsid{dsid}")
    app.clf[dsid] = model

    return {"summary": f"Turi model trained for DSID {dsid}"}


@app.post(
    "/predict_turi/",
    response_description="Predict image label using Turi model",
)
async def predict_turi(image: str = Body(...), dsid: int = Body(...)):
    """
    Predict the label of a Base64 encoded image using a Turi model.
    """
    if dsid not in app.clf:
        try:
            app.clf[dsid] = tc.load_model(f"../models/turi_model_dsid{dsid}")
        except FileNotFoundError:
            raise HTTPException(status_code=404, detail=f"No trained model found for DSID {dsid}.")

    # feature = decode_base64_image(image)
    feature = decode_base64_image(image).tolist()
    data = tc.SFrame({"sequence": [feature]})
    prediction = app.clf[dsid].predict(data)

    
    print(f"DSID: {dsid}")
    print(f"Prediction result: {prediction}")

    return {"prediction": prediction[0]}


from sklearn.svm import SVC
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

@app.get(
    "/train_model_sklearn/{dsid}",
    response_description="Train an SVM model with standardized features",
)
async def train_model_sklearn_svm(dsid: int, kernel: str = "rbf", C: float = 1.0, gamma: str = "scale"):
    """
    Train an SVM model using standardized features to enhance feature differentiation.
    """

    datapoints = await app.collection.find({"dsid": dsid}).to_list(length=None)
    if len(datapoints) < 2:
        raise HTTPException(status_code=404, detail=f"Not enough data in DSID {dsid} to train a model.")

    labels = [datapoint["label"] for datapoint in datapoints]
    features = [decode_base64_image(datapoint["image_base64"]) for datapoint in datapoints]

    # SVM
    pipeline = Pipeline([
        ("scaler", StandardScaler()),  # standardize
        ("svm", SVC(kernel=kernel, C=C, gamma=gamma, random_state=42))
    ])

    # 模型训练
    pipeline.fit(features, labels)

    # 保存模型
    model_path = f"../models/sklearn_svm_model_dsid{dsid}.joblib"
    dump(pipeline, model_path)
    app.clf[dsid] = pipeline

    return {
        "summary": f"SVM model with standardized features trained for DSID {dsid}",
        "model_path": model_path,
        "kernel": kernel,
        "C": C,
        "gamma": gamma,
    }



@app.post(
    "/predict_sklearn/",
    response_description="Predict image label using Scikit-learn model",
)
async def predict_sklearn(image: str = Body(...), dsid: int = Body(...)):
    """
    Predict the label of a Base64 encoded image using a Scikit-learn model.
    """
    if dsid not in app.clf:
        try:
            app.clf[dsid] = load(f"../models/sklearn_model_dsid{dsid}.joblib")
        except FileNotFoundError:
            return {"error": f"No trained model found for DSID {dsid}"}

    try:
        feature = decode_base64_image(image).reshape(1, -1)
        print(f"Feature shape for prediction: {feature.shape}")

        prediction = app.clf[dsid].predict(feature)
        return {"prediction": int(prediction[0])}  # Return valid JSON with the prediction
    except Exception as e:
        print(f"Prediction failed: {e}")
        return {"error": f"Prediction failed: {str(e)}"}  # Return error message in JSON

# async def predict_sklearn(image: str = Body(...), dsid: int = Body(...)):
#     """
#     Predict the label of a Base64 encoded image using a Scikit-learn model.
#     """
#     if dsid not in app.clf:
#         try:
#             app.clf[dsid] = load(f"../models/sklearn_model_dsid{dsid}.joblib")
#         except FileNotFoundError:
#             raise HTTPException(status_code=404, detail=f"No trained model found for DSID {dsid}.")
#
#         try:
#             feature = decode_base64_image(image).reshape(1, -1)
#             # 调试输出
#             print(f"Feature shape for prediction: {feature.shape}")
#
#             prediction = app.clf[dsid].predict(feature)
#             return {"prediction": prediction[0]}
#         except Exception as e:
#             print(f"Prediction failed: {e}")  # 调试输出
#             # 返回明确的 JSON 格式错误响应
#             return {"error": f"Prediction failed: {str(e)}"}




