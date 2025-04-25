import os
from googleapiclient.discovery import build

def launch_dataflow(event, context):
    bucket = event['bucket']
    name = event['name']

    project = os.environ['GCP_PROJECT']
    region = os.environ['DATAFLOW_REGION']
    template_path = os.environ['FLEX_TEMPLATE_PATH']
    output_table = os.environ['BIGQUERY_TABLE']
    temp_location = os.environ['TEMP_LOCATION']

    input_file = f"gs://{bucket}/{name}"

    dataflow = build('dataflow', 'v1b3')

    job = {
        "launchParameter": {
            "jobName": f"parquet-ingest-{name.replace('.', '-')}",
            "parameters": {
                "inputFilePattern": input_file,
                "outputTable": output_table,
                "tempLocation": temp_location
            },
            "containerSpecGcsPath": template_path,
            "environment": {
                "tempLocation": temp_location
            }
        }
    }

    response = dataflow.projects().locations().flexTemplates().launch(
        projectId=project,
        location=region,
        body=job
    ).execute()

    print(f"Dataflow job launched for: {input_file}")