import logging
from typing import List

import azure.functions as func
import jwt
import json
import pandas as pd
from io import StringIO
from sklearn.preprocessing import LabelEncoder
import os

from azure.functions import HttpResponse

# Decree and declare our project as an Azure Function App subsidiary
app = func.FunctionApp()

# Configure logging
logging.basicConfig(level=logging.DEBUG)


@app.blob_trigger(arg_name="inbound", path="hvalfangstcontainer/in/input.csv", connection="AzureWebJobsStorage")
@app.blob_output(arg_name="outbound", path="hvalfangstcontainer/out/statistics.json", connection="AzureWebJobsStorage")
def blob_trigger(inbound: func.InputStream, outbound: func.Out[str]):
    try:
        logging.info("Triggered blob function with blob: %s", inbound.name)

        # Read CSV content from the blob
        csv_content = inbound.read().decode("utf-8")
        logging.info("Read CSV content from blob successfully")

        # Convert CSV content to a pandas DataFrame
        df = pd.read_csv(StringIO(csv_content))
        logging.info("Converted CSV content to DataFrame")

        # Label encode 'Gender' and 'State' columns
        label_encoder = LabelEncoder()
        df['Gender'] = label_encoder.fit_transform(df['Gender'])
        df['State'] = label_encoder.fit_transform(df['State'])
        logging.info("Label encoded 'Gender' and 'State' columns")

        # Calculate correlations
        gender_to_income_corr = df[['Gender', 'Income']].corr().iloc[0, 1]
        experience_to_income_corr = df[['Experience', 'Income']].corr().iloc[0, 1]
        state_to_income_corr = df[['State', 'Income']].corr().iloc[0, 1]
        logging.info("Calculated correlations")

        # Create statistics dictionary
        statistics = {
            "gender_to_income_corr": gender_to_income_corr,
            "experience_to_income_corr": experience_to_income_corr,
            "state_to_income_corr": state_to_income_corr
        }
        logging.info("Created statistics dictionary: %s", statistics)

        # Convert statistics to JSON format
        statistics_json = json.dumps(statistics, indent=2)
        logging.info("Converted statistics to JSON format")

        # Upload statistics JSON file to storage account container blob
        outbound.set(statistics_json)
        logging.info("File 'statistics.json' was uploaded")

    except Exception as e:
        logging.error("An error occurred: %s", str(e))
        return f"Error: {str(e)}"


def validate_jwt(token: str, audience: str, required_scopes: List[str]) -> bool:
    try:
        decoded = jwt.decode(token, audience=audience, options={"verify_signature": False})

        # Check if the required scopes are present
        token_scopes = decoded.get("scp", "").split(" ")
        if not all(scope in token_scopes for scope in required_scopes):
            logging.error(f"Required scopes {required_scopes} not found in token scopes {token_scopes}")
            return False

        logging.info("Required scopes found in token: %s", required_scopes)
        return True
    except Exception as e:
        logging.error(f"JWT validation failed: {e}")
        return False


@app.route(route="upload_csv", auth_level=func.AuthLevel.ANONYMOUS)
@app.blob_output(arg_name="outbound", path="hvalfangstcontainer/in/input.csv", connection="AzureWebJobsStorage")
def upload_csv(req: func.HttpRequest, outbound: func.Out[str]) -> HttpResponse:
    try:
        logging.info("Received HTTP request to upload CSV")

        # Validate JWT token
        auth_header = req.headers.get("Authorization")

        if not auth_header:
            return func.HttpResponse("Missing auth header", status_code=401)

        token = auth_header.split(" ")[1]  # Extract Bearer token
        audience = os.environ.get("FUNCTION_APP_CLIENT_ID")
        required_scopes = ["Csv.Writer"]

        if not validate_jwt(token, audience, required_scopes):
            return HttpResponse("Unauthorized", status_code=401)

        logging.info("Successfully validated JWT token")

        # Parse raw bytes derived from request body to string
        string_body = req.get_body().decode("utf-8")
        logging.info("Parsed request body to string")

        # Upload parsed string body, which conforms to CSV format
        outbound.set(string_body)
        logging.info("Successfully uploaded CSV content")
        return "Successfully uploaded CSV content"

    except Exception as e:
        logging.error("An error occurred: %s", str(e))
        return f"Error: {str(e)}"
