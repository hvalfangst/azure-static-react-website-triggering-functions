import logging
import json
import pandas as pd
import azure.functions as func
from io import StringIO
from sklearn.preprocessing import LabelEncoder

# Decree and declare our project as an Azure Function App subsidiary
app = func.FunctionApp()

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)


@app.blob_trigger(arg_name="inbound", path="hvalfangstcontainer/in/input.csv", connection="")
@app.blob_output(arg_name="outbound", path="hvalfangstcontainer/out/statistics.json", connection="")
def blob_trigger(inbound: func.InputStream, outbound: func.Out[str]):
    try:
        # Read CSV content from the blob
        csv_content = inbound.read().decode("utf-8")

        # Convert CSV content to a pandas DataFrame
        df = pd.read_csv(StringIO(csv_content))

        # Label encode 'Gender' and 'State' columns
        label_encoder = LabelEncoder()
        df['Gender'] = label_encoder.fit_transform(df['Gender'])
        df['State'] = label_encoder.fit_transform(df['State'])

        # Calculate correlations
        gender_to_income_corr = df[['Gender', 'Income']].corr().iloc[0, 1]
        experience_to_income_corr = df[['Experience', 'Income']].corr().iloc[0, 1]
        state_to_income_corr = df[['State', 'Income']].corr().iloc[0, 1]

        # Create statistics dictionary
        statistics = {
            "gender_to_income_corr": gender_to_income_corr,
            "experience_to_income_corr": experience_to_income_corr,
            "state_to_income_corr": state_to_income_corr
        }

        # Convert statistics to JSON format
        statistics_json = json.dumps(statistics, indent=2)

        # Upload statistics JSON file to storage account container blob
        outbound.set(statistics_json)
        logging.info("- - - - - |File 'statistics.json' was uploaded| - - - - - ")

    except Exception as e:
        logging.error(f"An error occurred: {str(e)}")
        return f"Error: {str(e)}"


@app.route(route="upload_csv", auth_level=func.AuthLevel.ANONYMOUS)
@app.blob_output(arg_name="outbound", path="hvalfangstcontainer/in/input.csv", connection="")
def upload_csv(req: func.HttpRequest, outbound: func.Out[str]) -> str:
    try:
        # Parse raw bytes derived from request body to string
        string_body = req.get_body().decode("utf-8")

        # Upload parsed string body, which conforms to CSV format
        outbound.set(string_body)
        logging.info("- - - - -  |Successfully uploaded CSV content| - - - - - ")
        return "Successfully uploaded CSV content"

    except Exception as e:
        logging.error(f"An error occurred: {str(e)}")
        return f"Error: {str(e)}"
