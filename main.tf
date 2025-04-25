provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "parquet_bucket" {
  name          = "${var.project_id}-parquet-bucket"
  location      = var.region
  force_destroy = true
}

resource "google_bigquery_dataset" "dataset" {
  dataset_id = "parquet_dataset"
  location   = var.region
}

resource "google_bigquery_table" "table" {
  table_id   = "parquet_table"
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  deletion_protection = false
}

# GCS bucket to store the Dataflow Flex Template spec
resource "google_storage_bucket" "template_bucket" {
  name          = "${var.project_id}-df-template"
  location      = var.region
  force_destroy = true
}


resource "google_dataflow_flex_template_job" "parquet_pipeline" {

  name   = "parquet-ingest-pipeline"
  region = var.region

  container_spec_gcs_path = "gs://${google_storage_bucket.template_bucket.name}/template-spec.json"

  parameters = {
    inputFilePattern = "gs://${google_storage_bucket.parquet_bucket.name}/*.parquet"
    outputTable      = "${var.project_id}:${google_bigquery_dataset.dataset.dataset_id}.${google_bigquery_table.table.table_id}"
    tempLocation     = "gs://${google_storage_bucket.parquet_bucket.name}/temp"
  }

  on_delete = "cancel"
}

resource "google_storage_bucket_object" "parquet_file" {
  depends_on = [ google_dataflow_flex_template_job.parquet_pipeline ]
  name   = "data.parquet"
  bucket = google_storage_bucket.parquet_bucket.name
  source = "${path.module}/data.parquet"
}

resource "google_cloudfunctions_function" "trigger_dataflow" {
  name        = "launch-dataflow-on-gcs"
  runtime     = "python310"
  entry_point = "launch_dataflow"

  source_archive_bucket = google_storage_bucket.template_bucket.name
  source_archive_object = google_storage_bucket_object.function_zip.name

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.parquet_bucket.name
  }

  environment_variables = {
    GCP_PROJECT        = var.project_id
    DATAFLOW_REGION    = var.region
    FLEX_TEMPLATE_PATH = "gs://${google_storage_bucket.template_bucket.name}/template-spec.json"
    BIGQUERY_TABLE     = "${var.project_id}:${google_bigquery_dataset.dataset.dataset_id}.${google_bigquery_table.table.table_id}"
    TEMP_LOCATION      = "gs://${google_storage_bucket.parquet_bucket.name}/temp"
  }
}