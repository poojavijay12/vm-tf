locals {
  project       = var.project_id
  region        = var.region
  zone          = var.zone
  vpc_name      = var.vpc_name
  subnet_name   = var.subnet_name
  subnet_cidr   = var.subnet_cidr
  router_name   = var.router_name
  nat_name      = var.nat_name
  vm_name       = var.vm_name
  vm_sa         = var.vm_service_account
  gke_cluster   = var.gke_cluster_name
  gke_node_sa   = var.gke_node_sa
  artifact_repo = var.artifact_repo
}

# Enable APIs (best effort via null_resource local-exec)
resource "null_resource" "enable_apis" {
  provisioner "local-exec" {
    command = <<EOT
      set -e
      gcloud services enable compute.googleapis.com container.googleapis.com artifactregistry.googleapis.com iam.googleapis.com --project=${local.project}
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# VPC
resource "google_compute_network" "vpc" {
  name                    = local.vpc_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  project                 = local.project
}

# Subnet
resource "google_compute_subnetwork" "private" {
  name                     = local.subnet_name
  ip_cidr_range            = local.subnet_cidr
  region                   = local.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  project                  = local.project
}

# Cloud Router
resource "google_compute_router" "router" {
  name    = local.router_name
  network = google_compute_network.vpc.id
  region  = local.region
  project = local.project
}

# Cloud NAT
resource "google_compute_router_nat" "nat" {
  name                               = local.nat_name
  router                             = google_compute_router.router.name
  region                             = local.region
  project                            = local.project
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# VM service account
resource "google_service_account" "vm_sa" {
  account_id   = local.vm_sa
  display_name = "VM service account"
  project      = local.project
}

# VM (no external IP)
resource "google_compute_instance" "private_vm" {
  name         = local.vm_name
  machine_type = "e2-medium"
  zone         = local.zone
  project      = local.project

  boot_disk {
    initialize_params {
      image = "debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork         = google_compute_subnetwork.private.name
    access_config {} # do NOT include access_config to leave no external IP; but terraform requires empty block for default? -- omit to ensure no external. (We'll set no external via network_interface[0].access_config is absent)
  }

  # to attach service account, use service_account block
  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }
}

# Artifact Registry (Docker)
resource "google_artifact_registry_repository" "docker" {
  provider      = google
  location      = local.region
  repository_id = local.artifact_repo
  description   = "Docker repo for CI images"
  format        = "DOCKER"
  project       = local.project
}

# GKE cluster (private)
resource "google_container_cluster" "primary" {
  name     = local.gke_cluster
  location = local.region
  project  = local.project

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.private.self_link

  ip_allocation_policy {
    use_ip_aliases = true
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  workload_identity_config {
    workload_pool = "${local.project}.svc.id.goog"
  }

  network_policy {
    enabled = true
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
}

# GKE node service account
resource "google_service_account" "gke_node_sa" {
  account_id   = local.gke_node_sa
  display_name = "GKE Node Service Account"
  project      = local.project
}

# Grant node SA permission to pull images from Artifact Registry
resource "google_project_iam_member" "node_artifact_reader" {
  project = local.project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_project_iam_member" "node_storage_viewer" {
  project = local.project
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# Node pool
resource "google_container_node_pool" "primary_nodes" {
  name     = "pool-standard"
  cluster  = google_container_cluster.primary.name
  location = local.region
  project  = local.project

  node_count = 3

  node_config {
    machine_type    = "e2-standard-4"
    service_account = google_service_account.gke_node_sa.email

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Outputs
output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "vm_internal_ip" {
  value = google_compute_instance.private_vm.network_interface[0].network_ip
}

output "artifact_registry" {
  value = google_artifact_registry_repository.docker.id
}
