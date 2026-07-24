"""
prediction.py -- FastAPI service for Rwandan smallholder crop Yield prediction.

Loads the Random Forest model (best performer from multivariate.ipynb) plus the
fitted StandardScaler and the exact training-time column order, then exposes a
POST /predict endpoint.
"""

from typing import Literal

import io

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

# ---------------------------------------------------------------------------
# Load the saved model artifacts (produced at the end of multivariate.ipynb)
# ---------------------------------------------------------------------------
model = joblib.load("best_model.pkl")
scaler = joblib.load("scaler.pkl")
model_columns = joblib.load("model_columns.pkl")

NUMERICAL_COLS = ["Plot_area_ha", "Crop_Area_ha"]

# ---------------------------------------------------------------------------
# Input schema -- every field typed and range/choice constrained
# ---------------------------------------------------------------------------
CropCategoryType = Literal[
    "Banana for beer", "Bush bean", "Cassava", "Climbing bean", "Cooking banana",
    "Dessert banana", "Fodder crops", "Fruits", "Groundnut", "Irish potato",
    "Maize", "Other cereals", "Other crops", "Paddy rice", "Pea", "Sorghum",
    "Soybean", "Sweet potato", "Taro & Yams", "Vegetables", "Wheat",
]

ProvinceType = Literal["East", "Kigali", "North", "South", "West"]

DistrictType = Literal[
    "Bugesera", "Burera", "Gakenke", "Gasabo", "Gatsibo", "Gicumbi", "Gisagara",
    "Huye", "Kamonyi", "Karongi", "Kayonza", "Kicukiro", "Kirehe", "Muhanga",
    "Musanze", "Ngoma", "Ngororero", "Nyabihu", "Nyagatare", "Nyamagabe",
    "Nyamasheke", "Nyanza", "Nyarugenege", "Nyarugenge", "Nyaruguru", "Rubavu",
    "Ruhango", "Rulindo", "Rusizi", "Rutsiro", "Rwamagana",
]

SeasonType = Literal["A", "B", "C"]


class PredictionRequest(BaseModel):
    Plot_area_ha: float = Field(
        ..., gt=0, le=10,
        description="Plot area in hectares. Smallholder scope: >0 and <=10 ha.",
    )
    Crop_Area_ha: float = Field(
        ..., gt=0, le=10,
        description="Area actually planted with this crop, in hectares.",
    )
    CropCategory: CropCategoryType = Field(..., description="Crop grown on the plot.")
    s1q1: ProvinceType = Field(..., description="Province where the plot is located.")
    s1q2: DistrictType = Field(..., description="District where the plot is located.")
    Season: SeasonType = Field(..., description="Agricultural season: A, B, or C.")


class PredictionResponse(BaseModel):
    predicted_yield: float


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Rwanda Smallholder Crop Yield Prediction API",
    description=(
        "Predicts crop Yield for a Rwandan smallholder plot (<=10 ha) using a "
        "Random Forest model trained on NISR Seasonal Agricultural Survey 2025 data."
    ),
    version="1.0.0",
)


@app.get("/")
def root():
    return {"message": "Yield Prediction API is running. See /docs for Swagger UI."}


# ---------------------------------------------------------------------------
# CORS configuration
#
# Reasoning: this API will be called by a Flutter mobile app (no browser
# "origin" restriction there) but also tested from Swagger UI and possibly a
# future web build, so we allow local development origins explicitly rather
# than a blanket "*". Only the methods/headers actually used are permitted --
# GET/POST (no DELETE/PUT, since this API never deletes or replaces data) and
# only the headers needed for a JSON POST request. Credentials (cookies/auth
# headers) are not needed for this public prediction endpoint, so left False.
# ---------------------------------------------------------------------------
ALLOWED_ORIGINS = [
    "http://localhost",
    "http://localhost:3000",
    "http://127.0.0.1",
    "http://127.0.0.1:3000",
    # Add your deployed Flutter web build / frontend domain here once known.
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


def preprocess(request: PredictionRequest) -> pd.DataFrame:
    """Turn a validated request into the exact encoded/scaled row the model expects."""
    input_df = pd.DataFrame([request.model_dump()])

    # One-hot encode the same way the training notebook did
    input_encoded = pd.get_dummies(input_df)

    # Align to the exact training-time column order, filling any missing
    # dummy columns (categories not present in this single row) with 0
    input_encoded = input_encoded.reindex(columns=model_columns, fill_value=0)

    # Scale only the numeric columns, using the SAME fitted scaler from training
    input_encoded[NUMERICAL_COLS] = scaler.transform(input_encoded[NUMERICAL_COLS])

    return input_encoded


@app.post("/predict", response_model=PredictionResponse)
def predict(request: PredictionRequest):
    processed = preprocess(request)
    prediction = model.predict(processed)[0]
    return PredictionResponse(predicted_yield=float(prediction))


# ---------------------------------------------------------------------------
# Retraining endpoint (manual trigger via CSV upload)
#
# Limitation, stated honestly: this retrains on the uploaded batch alone,
# not merged with the original training set, so a small or unrepresentative
# upload could produce a weaker model. Suitable for periodic bulk updates
# (e.g. a new survey season), not for single-row streaming updates.
# ---------------------------------------------------------------------------
REQUIRED_COLUMNS = [
    "Plot_area_ha", "Crop_Area_ha", "CropCategory",
    "s1q1", "s1q2", "Season", "Yield",
]


class RetrainResponse(BaseModel):
    message: str
    rows_used: int
    test_mse: float
    test_r2: float


@app.post("/retrain", response_model=RetrainResponse)
async def retrain(file: UploadFile = File(...)):
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file.")

    raw_bytes = await file.read()
    new_df = pd.read_csv(io.BytesIO(raw_bytes))

    missing_cols = [c for c in REQUIRED_COLUMNS if c not in new_df.columns]
    if missing_cols:
        raise HTTPException(
            status_code=400,
            detail=f"Uploaded CSV is missing required columns: {missing_cols}",
        )

    new_df = new_df[REQUIRED_COLUMNS].dropna(subset=["Yield"])
    if len(new_df) < 20:
        raise HTTPException(
            status_code=400,
            detail="Not enough valid rows to retrain (need at least 20 with a non-missing Yield).",
        )

    # Same preprocessing pipeline as the training notebook
    categorical_cols = ["CropCategory", "s1q1", "s1q2", "Season"]
    encoded = pd.get_dummies(new_df, columns=categorical_cols, drop_first=True)

    X_new = encoded.drop(columns=["Yield"])
    y_new = encoded["Yield"]

    X_train_r, X_test_r, y_train_r, y_test_r = train_test_split(
        X_new, y_new, test_size=0.2, random_state=42
    )

    new_scaler = StandardScaler()
    X_train_scaled_r = X_train_r.copy()
    X_test_scaled_r = X_test_r.copy()
    X_train_scaled_r[NUMERICAL_COLS] = new_scaler.fit_transform(X_train_r[NUMERICAL_COLS])
    X_test_scaled_r[NUMERICAL_COLS] = new_scaler.transform(X_test_r[NUMERICAL_COLS])

    new_model = RandomForestRegressor(n_estimators=200, max_depth=12, random_state=42, n_jobs=-1)
    new_model.fit(X_train_scaled_r, y_train_r)

    preds = new_model.predict(X_test_scaled_r)
    test_mse = mean_squared_error(y_test_r, preds)
    test_r2 = r2_score(y_test_r, preds)

    # Persist the retrained artifacts, overwriting the previous ones
    joblib.dump(new_model, "best_model.pkl")
    joblib.dump(new_scaler, "scaler.pkl")
    joblib.dump(list(X_new.columns), "model_columns.pkl")

    # Reload the in-memory globals so /predict immediately uses the new model,
    # without needing to restart the server
    global model, scaler, model_columns
    model = new_model
    scaler = new_scaler
    model_columns = list(X_new.columns)

    return RetrainResponse(
        message="Model retrained and reloaded successfully.",
        rows_used=len(new_df),
        test_mse=float(test_mse),
        test_r2=float(test_r2),
    )