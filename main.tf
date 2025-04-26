  provider "google" {
    project = var.project_id
    region  = var.region
  }

  # GCS bucket for data storage
  resource "google_storage_bucket" "gcs_bucket" {
    name     = "testbucketforpoly"
    location = "EU"
    uniform_bucket_level_access  = true
  }

  resource "google_storage_bucket" "dataflow_temp_bucket" {
    name     = "dataflow-templates-temp-bucket"
    location = "EU"
    uniform_bucket_level_access = true
  }

  # BigQuery dataset
  resource "google_bigquery_dataset" "bigquery_dataset" {
    dataset_id = "test"
    project    = var.project_id
    location  = "EU"
  }

  # BigQuery table
  resource "google_bigquery_table" "bigquery_table" {
    dataset_id = google_bigquery_dataset.bigquery_dataset.dataset_id
    table_id   = "test"
    project    = var.project_id
    deletion_protection = false 

    schema = <<EOF
  [
    {
      "name": "name",
      "type": "STRING",
      "mode": "NULLABLE"
    },
    {
      "name": "age",
      "type": "INTEGER",
      "mode": "NULLABLE"
    }
  ]
  EOF
  }

  resource "google_storage_bucket_object" "dataflow_script" {
    name   = "dataflow_pipeline.js"
    bucket = google_storage_bucket.dataflow_temp_bucket.name
    source = "dataflow_pipeline.js"
  }

  
  resource "google_storage_bucket_object" "schema" {
    name   = "schema.json"
    bucket = google_storage_bucket.gcs_bucket.name
    source = "schema.json"
  }

  # Upload a mock CSV file to GCS (for testing purposes)
resource "google_storage_bucket_object" "mock_csv" {
  name   = "mock_data.csv"
  bucket = google_storage_bucket.gcs_bucket.name
  content = <<EOF
Alice,30
Bob,25
Charlie,35
  EOF
}

resource "google_dataflow_flex_template_job" "dataflow_streaming_job" {
  provider                = google-beta
  name      = "gcs-streaming"
  project = var.project_id
  enable_streaming_engine = true
  region = var.region
  container_spec_gcs_path = "gs://dataflow-templates-${var.region}/latest/flex/Stream_GCS_Text_to_BigQuery_Flex"
  parameters = {
    "JSONPath"                  = "gs://${google_storage_bucket.gcs_bucket.name}/schema.json"  # Path to your schema (if needed)
    "inputFilePattern" = "gs://${google_storage_bucket.gcs_bucket.name}/*.csv"  # Path to the files in GCS
    "outputTable"               = "${var.project_id}:${google_bigquery_dataset.bigquery_dataset.dataset_id}.${google_bigquery_table.bigquery_table.table_id}"  # Fully qualified table name
    "bigQueryLoadingTemporaryDirectory" = "gs://${google_storage_bucket.gcs_bucket.name}/bigquery_temp/"  # Temporary location for BigQuery loading
    "javascriptTextTransformFunctionName" = "process"
    "javascriptTextTransformGcsPath" = "gs://${google_storage_bucket.dataflow_temp_bucket.name}/${google_storage_bucket_object.dataflow_script.name}"
  }
  depends_on = [
    google_project_iam_member.dataflow_worker_permissions
  ]
}


resource "google_project_iam_member" "dataflow_worker_permissions" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = var.service_account
}

resource "google_project_iam_member" "dataflow_temp_bucket_permissions" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = var.service_account
}

resource "google_project_iam_member" "dataflow_gcs_permissions" {
  project = var.project_id
  role    = "roles/storage.objectViewer"  
  member  = var.service_account
}

resource "google_project_iam_member" "dataflow_temp_bucket_permissions_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = var.service_account
}

resource "google_project_iam_member" "dataflow_bigquery_permissions" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = var.service_account
}

resource "google_project_iam_member" "dataflow_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = var.service_account
}