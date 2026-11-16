import io
import os
import threading
import time
from enum import Enum
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator
from sklearn.base import clone
from sklearn.linear_model import SGDRegressor
from sklearn.metrics import mean_squared_error

MODEL_PATH = Path(__file__).resolve().parent / "best_model.pkl"
MAX_UPLOAD_BYTES = 5 * 1024 * 1024


def load_bundle(path: Path = MODEL_PATH) -> dict:
    return joblib.load(path)


BUNDLE = load_bundle()
MODEL_VERSION = 1
MODEL_LOCK = threading.Lock()


def predict_internet_users(row: dict, bundle: dict | None = None) -> float:
    bundle = bundle or BUNDLE
    X = pd.DataFrame([{f: row[f] for f in bundle["features"]}])
    return float(np.clip(bundle["pipeline"].predict(X)[0], 0, 100))


class Region(str, Enum):
    east_asia_pacific = "East Asia & Pacific"
    europe_central_asia = "Europe & Central Asia"
    latin_america_caribbean = "Latin America & Caribbean"
    middle_east_north_africa = "Middle East & North Africa"
    north_america = "North America"
    south_asia = "South Asia"
    sub_saharan_africa = "Sub-Saharan Africa"


REGION_ALIASES = {"eap": Region.east_asia_pacific, "eca": Region.europe_central_asia,
                  "lac": Region.latin_america_caribbean, "mena": Region.middle_east_north_africa,
                  "na": Region.north_america, "sa": Region.south_asia, "ssa": Region.sub_saharan_africa}


class PredictionInput(BaseModel):
    model_config = ConfigDict(extra="forbid", json_schema_extra={"example": {
        "year": 2015, "access_to_electricity": 4.8, "gdp_per_capita": 1071.8,
        "urban_population": 18.9, "population_density": 17.7, "life_expectancy": 55.6,
        "birth_rate": 36.3, "education_expenditure": 1.47, "government_effectiveness": -2.15,
        "region": "Sub-Saharan Africa"}})

    year: int = Field(..., strict=True, ge=2000, le=2035,
                      description="Year of the data")
    access_to_electricity: float = Field(..., strict=True, ge=0, le=100,
                                         description="% of population with access to electricity")
    gdp_per_capita: float = Field(..., strict=True, ge=50, le=250_000,
                                  description="GDP per person, current US$")
    urban_population: float = Field(..., strict=True, ge=0, le=100,
                                    description="% of population living in urban areas")
    population_density: float = Field(..., strict=True, ge=0.1, le=30_000,
                                      description="People per square km of land")
    life_expectancy: float = Field(..., strict=True, ge=30, le=90,
                                   description="Life expectancy at birth, years")
    birth_rate: float = Field(..., strict=True, ge=3, le=60,
                              description="Births per 1,000 people per year")
    education_expenditure: float = Field(..., strict=True, ge=0, le=20,
                                         description="Government spending on education, % of GDP")
    government_effectiveness: float = Field(..., strict=True, ge=-2.5, le=2.5,
                                            description="World Bank governance score (-2.5 weak to 2.5 strong)")
    region: Region = Field(..., description="World Bank region (full name or code: EAP, ECA, LAC, MENA, NA, SA, SSA)")

    @field_validator("region", mode="before")
    @classmethod
    def normalise_region(cls, value):
        if isinstance(value, str):
            cleaned = " ".join(value.split()).lower()
            if cleaned in REGION_ALIASES:
                return REGION_ALIASES[cleaned]
            for region in Region:
                if region.value.lower() == cleaned:
                    return region
        return value


class PredictionOutput(BaseModel):
    predicted_internet_users_percent: float
    interpretation: str
    model: str
    model_version: int


def interpret(percent: float) -> str:
    if percent < 20:
        return "Low access: deliver learning and document services offline (radio, SMS, printed, community hubs)."
    if percent < 50:
        return "Partial access: combine offline delivery with mobile-first online services."
    return "Wide access: online learning and digital document services can reach most people."


app = FastAPI(
    title="Internet Access Predictor (Digital Education Planning in East Africa)",
    description="Predicts the % of a country's population using the internet, so education planners can choose "
                "online or offline delivery. Model: scikit-learn pipeline trained on World Bank indicators.",
    version="1.0.0",
)

# CORS controls which websites (browser origins) may call this API.
# Allowed: my Render URL (Swagger UI) and the local Flutter web debug server on port 8080.
# More origins can be added through the ALLOWED_ORIGINS environment variable on Render.
# Restricted: no wildcard "*", so other websites cannot use my free instance or trigger /retrain.
# Methods: only GET and POST, the only methods this API serves.
# Headers: only Content-Type and Accept, because no custom or auth headers are needed.
# Credentials: False, because the API uses no cookies or logins.
# The Flutter mobile app is not a browser, so CORS does not apply to it.
DEFAULT_ORIGINS = [
    "https://internet-access-predictor.onrender.com",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
]
extra_origins = [o.strip() for o in os.getenv("ALLOWED_ORIGINS", "").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=DEFAULT_ORIGINS + extra_origins,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Accept"],
    allow_credentials=False,
)


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")


@app.get("/health", tags=["status"])
def health():
    return {"status": "ok", "model": BUNDLE["model_name"], "model_version": MODEL_VERSION,
            "training_rows": len(BUNDLE["train_data"][BUNDLE["target"]])}


@app.post("/predict", response_model=PredictionOutput, tags=["prediction"])
def predict(payload: PredictionInput):
    row = payload.model_dump()
    row["region"] = payload.region.value
    with MODEL_LOCK:
        bundle, version = BUNDLE, MODEL_VERSION
    value = round(predict_internet_users(row, bundle), 2)
    return PredictionOutput(predicted_internet_users_percent=value, interpretation=interpret(value),
                            model=bundle["model_name"], model_version=version)


def clean_uploaded_rows(df: pd.DataFrame, bundle: dict) -> tuple[pd.DataFrame, list[str]]:
    features, target = bundle["features"], bundle["target"]
    good, errors = [], []
    for i, rec in enumerate(df.to_dict(orient="records"), start=2):
        try:
            values = {}
            for col in features + [target]:
                v = rec.get(col)
                if col == "region":
                    values[col] = v
                else:
                    try:
                        num = float(v)
                    except (TypeError, ValueError):
                        raise ValueError(f"{col} must be a number, got {v!r}")
                    if col == "year":
                        if np.isnan(num) or not num.is_integer():
                            raise ValueError("year must be a whole number")
                        num = int(num)
                    values[col] = num
                if col != "region" and np.isnan(values[col]):
                    raise ValueError(f"{col} is missing")
            if not 0 <= values[target] <= 100:
                raise ValueError(f"{target} must be between 0 and 100")
            checked = PredictionInput(**{k: values[k] for k in features})
            values["region"] = checked.region.value
            good.append(values)
        except ValidationError as exc:
            err = exc.errors()[0]
            field = err["loc"][0] if err["loc"] else "row"
            errors.append(f"row {i}: {field} - {err['msg']}")
        except (ValueError, TypeError) as exc:
            errors.append(f"row {i}: {exc}")
    return pd.DataFrame(good, columns=features + [target]), errors


def retrain_bundle(bundle: dict, new_rows: pd.DataFrame) -> dict:
    features, target = bundle["features"], bundle["target"]
    old = pd.DataFrame(bundle["train_data"])
    combined = pd.concat([old, new_rows], ignore_index=True)
    pipeline = bundle["pipeline"]

    if isinstance(pipeline.named_steps["model"], SGDRegressor):
        new_pipeline = joblib.load(io.BytesIO(_dumps(pipeline)))
        Xs = new_pipeline.named_steps["preprocess"].transform(new_rows[features])
        y = new_rows[target].to_numpy()
        rng = np.random.default_rng(0)
        for _ in range(20):
            order = rng.permutation(len(y))
            new_pipeline.named_steps["model"].partial_fit(Xs[order], y[order])
    else:
        new_pipeline = clone(pipeline).fit(combined[features], combined[target])

    return {**bundle, "pipeline": new_pipeline, "train_data": combined.to_dict(orient="list")}


def _dumps(obj) -> bytes:
    buf = io.BytesIO()
    joblib.dump(obj, buf)
    return buf.getvalue()


@app.post("/retrain", tags=["retraining"])
def retrain(file: UploadFile = File(..., description="CSV with the same columns as the training data "
                                                   "(9 numeric features, region, internet_users)")):
    global BUNDLE, MODEL_VERSION
    if not (file.filename or "").lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file.")
    content = file.file.read(MAX_UPLOAD_BYTES + 1)
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="File too large (max 5 MB).")
    try:
        df = pd.read_csv(io.BytesIO(content))
    except Exception:
        raise HTTPException(status_code=400, detail="Could not read the file as CSV.")

    with MODEL_LOCK:
        current = BUNDLE
    required = current["features"] + [current["target"]]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise HTTPException(status_code=400, detail=f"Missing columns: {missing}. Required: {required}")

    new_rows, errors = clean_uploaded_rows(df, current)
    if new_rows.empty:
        raise HTTPException(status_code=400, detail={"message": "No valid rows to train on.", "errors": errors[:20]})

    mse_before = mean_squared_error(new_rows[current["target"]],
                                    np.clip(current["pipeline"].predict(new_rows[current["features"]]), 0, 100))
    start = time.time()
    updated = retrain_bundle(current, new_rows)
    mse_after = mean_squared_error(new_rows[current["target"]],
                                   np.clip(updated["pipeline"].predict(new_rows[current["features"]]), 0, 100))

    with MODEL_LOCK:
        BUNDLE = updated
        MODEL_VERSION += 1
        version = MODEL_VERSION
    try:
        joblib.dump(updated, MODEL_PATH, compress=3)
        saved = True
    except Exception:
        saved = False

    return {
        "message": "Model retrained and now used by /predict.",
        "method": "partial_fit on new rows" if isinstance(updated["pipeline"].named_steps["model"], SGDRegressor)
                  else "refit on original + new rows",
        "model": updated["model_name"],
        "model_version": version,
        "rows_received": int(len(df)),
        "rows_used": int(len(new_rows)),
        "rows_rejected": len(errors),
        "rejected_examples": errors[:10],
        "total_training_rows": len(updated["train_data"][updated["target"]]),
        "mse_on_uploaded_rows_before": round(float(mse_before), 2),
        "mse_on_uploaded_rows_after": round(float(mse_after), 2),
        "seconds": round(time.time() - start, 1),
        "saved_to_disk": saved,
    }