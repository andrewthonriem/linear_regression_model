# Internet Access Predictor

## Mission and problem
My mission is to leverage technology to empower my community. I aim to develop innovative solutions that address local challenges, promote education, and enhance access to resources. 
This project predicts the **% of a country's population using the internet** from its development indicators,
so education ministries and NGOs can decide whether to deliver learning and document services online or offline.

## Dataset
**World Bank World Development Indicators** (Kaggle, uploaded by Nicolás González Muñoz, built from the World Bank WDI database):
17,272 country-year rows and 50 columns, 1960 to 2023.
After cleaning: 2,862 rows from 187 countries (2000 to 2021), 9 numeric features plus 1 categorical feature (`region`).
Target: `internet_users` (% of population using the internet).
Source: https://www.kaggle.com/datasets/nicolasgonzalezmunoz/world-bank-world-development-indicators

## API (Swagger UI)
https://internet-access-predictor.onrender.com/docs

- `POST /predict`: returns the predicted % of internet users
- `POST /retrain`: upload a CSV with the training columns (for example `summative/linear_regression/new_data_2021.csv`) to retrain the model

The API is on Render's free plan, so the first request after a quiet period can take up to a minute.

## Video demo
YouTube: https://youtu.be/L9c2o1Fsqk8

## Run the mobile app
1. Install Flutter (https://docs.flutter.dev/get-started/install) and check it with `flutter doctor`.
2. Start an Android emulator (Android Studio > Device Manager) or connect a phone with USB debugging on.
3. Get the code and open the app folder:
   ```bash
   git clone https://github.com/andrewthonriem/linear_regression_model.git
   cd linear_regression_model/summative/FlutterApp
   ```
4. Install the packages: `flutter pub get`
5. Run the app: `flutter run`
6. Press **South Sudan 2015** to fill in example values (or type your own), then press **Predict**.

## Repository layout
```
summative/
├── linear_regression/multivariate.ipynb   data prep, visualisations, 4 models, best model
├── API/prediction.py                       FastAPI service (predict, retrain, CORS)
├── API/best_model.pkl                      saved random forest pipeline
└── FlutterApp/lib/
    ├── main.dart            app entry point, colours and theme
    ├── prediction_page.dart the page: fields, Predict button, result area
    ├── input_fields.dart    the 10 input fields and their ranges
    └── api_service.dart     the call to the /predict endpoint
```
