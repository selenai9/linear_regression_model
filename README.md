# Rwanda Smallholder Crop Yield Predictor

## Mission & Problem

Rwanda's smallholder farmers plant across three seasons a year with no forward-looking estimate of what a given plot is likely to yield. This project trains a regression model on NISR's 2025 Seasonal Agricultural Survey data to predict crop `Yield` for a plot (≤10 ha) from its size, crop, season, and location — giving farmers and extension programmes an early estimate to plan around, deployed as a public API and a mobile app (**TerraPredict**).

---

## Live API

- **Swagger UI:** `https://terrapredict-api.onrender.com/docs`
- **Predict endpoint:** `POST https://terrapredict-api.onrender.com/predict`
- **Retrain endpoint:** `POST https://terrapredict-api.onrender.com/retrain` (manual trigger, CSV upload)

### Example request

```json
{
  "Plot_area_ha": 0.15,
  "Crop_Area_ha": 0.12,
  "CropCategory": "Maize",
  "s1q1": "East",
  "s1q2": "Gatsibo",
  "Season": "A"
}
```

### Example response

```json
{
  "predicted_yield": 1620.03
}
```

---

## Video Demo

`https://youtu.be/pnYjd6Akdjw` 

---

## Repository Structure

```
linear_regression_model/
├── Microdata/                  # raw NISR survey data (not tracked in git — see below)
├── summative/
│   ├── linear_regression/
│   │   └── multivariate.ipynb  # data cleaning, EDA, model training/comparison
│   ├── API/
│   │   ├── prediction.py       # FastAPI app: /predict, /retrain
│   │   ├── requirements.txt
│   │   ├── best_model.pkl      # trained Random Forest (best performer)
│   │   ├── scaler.pkl
│   │   └── model_columns.pkl
│   └── FlutterApp/             # TerraPredict mobile app
├── pyproject.toml
└── uv.lock
```

---

## Model Summary

Four regression approaches were trained and compared on ~62,500 cleaned smallholder plot records (Seasons A, B, C combined):

| Model | Test R² |
|---|---|
| **Random Forest** (selected — lowest test MSE) | ~0.827 |
| Ridge Regression (SAG — gradient descent) | ~0.825 |
| SGD Regressor (gradient descent) | ~0.825 |
| Decision Tree | ~0.817 |

Features: `Plot_area_ha`, `Crop_Area_ha`, `CropCategory`, province, district, season. Farmer gender and age were tested and dropped — both had negligible-to-weak predictive value, and removing them keeps the app from asking for demographic information the model doesn't meaningfully use.

Full data cleaning, visualization, and model comparison steps are documented in `multivariate.ipynb`.

---

## Running the Mobile App (TerraPredict)

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install) installed, a device/emulator or Chrome available.

1. Clone the repo and navigate to the app:
   ```bash
   git clone https://github.com/selenai9/linear_regression_model.git
   cd linear_regression_model/summative/FlutterApp
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Confirm `lib/api_service.dart` points at the live Render URL (see `ApiConfig.baseUrl`).
4. Run:
   ```bash
   flutter run
   ```
   Select a connected device/emulator, or run on web with:
   ```bash
   flutter run -d chrome
   ```
5. Fill in the 6 fields (Plot Area, Crop Area, Crop, Season, Province, District) and tap **Predict Yield**.

---

## Known Limitations

- The `/retrain` endpoint retrains on the uploaded CSV batch alone (not merged with the original training set) — a small or unrepresentative upload can produce a weaker model. Suitable for periodic bulk updates, not single-row streaming.
- On Render's free tier, the filesystem resets on redeploy, so a retrain persists only until the next deploy.
- Some residual noise remains in the underlying survey data even after cleaning (see the notebook's outlier-handling section for details).
