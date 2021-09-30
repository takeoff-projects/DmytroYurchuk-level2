terraform {
  required_version = ">= 0.14"

  required_providers {
    google = ">= 3.3"
  }
}

provider "google" {
  project = var.project_id
  region  = var.provider_region
}

locals {
  service_name   = "go-api"
  service-account  = "serviceAccount:${google_service_account.service-account.email}"
  url = google_cloud_run_service.service.status[0].url
}

# Enables the Identity and Access Management (IAM) API
resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

# Create a service account
resource "google_service_account" "service-account" {
  account_id   = "service-account"
  display_name = "Service Account"
}

# Create new SA key
resource "google_service_account_key" "sa_key" {
  service_account_id = google_service_account.service-account.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Set permissions
resource "google_project_iam_binding" "service_permissions" {
  for_each = toset([
    "run.invoker","appengine.appAdmin"
  ])

  role       = "roles/${each.key}"
  members    = [local.service-account]
  depends_on = [google_service_account.service-account]
}

# Enables the Cloud Build
resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Enables the Cloud Run
resource "google_project_service" "run" {
  service = "run.googleapis.com"
  disable_on_destroy = false
}

# Enables the Cloud Run API
resource "google_project_service" "run_api" {
  service = "run.googleapis.com"

  disable_on_destroy = false
}

data "google_container_registry_image" "image" {
  name = local.service_name
  tag = "v1.0"
}

# The Cloud Run service
resource "google_cloud_run_service" "service" {
  name                       = local.service_name
  location                   = var.provider_region

  template {
    spec {
      service_account_name = google_service_account.service-account.email

      containers {
        image = data.google_container_registry_image.image.image_url
        env {
          name = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.run]
}

# No auth
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

# Set no auth policy
resource "google_cloud_run_service_iam_policy" "noauth_policy" {
  location    = google_cloud_run_service.service.location
  project     = google_cloud_run_service.service.project
  service     = google_cloud_run_service.service.name

  policy_data = data.google_iam_policy.noauth.policy_data
  depends_on  = [google_cloud_run_service.service]
}

data "template_file" "openapi_config_file" {
  template = file("${path.module}/openapi_config_file.yml")
  vars = {
    host  = replace(local.url, "https://", "")
    address = local.url
  }
}

resource "google_endpoints_service" "openapi_service" {
  service_name   = replace(local.url, "https://", "")
  project        = var.project_id
  openapi_config = data.template_file.openapi_config_file.rendered

  depends_on  = [google_cloud_run_service.service]
}

output "service_url" {
  value = google_cloud_run_service.service.status[0].url
}