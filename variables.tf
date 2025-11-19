variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP zone"
  default     = "us-central1-a"
}

variable "vpc_name" {
  type    = string
  default = "my-vpc"
}

variable "subnet_name" {
  type    = string
  default = "private-subnet"
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}

variable "router_name" {
  type    = string
  default = "my-router"
}

variable "nat_name" {
  type    = string
  default = "my-nat"
}

variable "vm_name" {
  type    = string
  default = "private-vm"
}

variable "vm_service_account" {
  type    = string
  default = "vm-sa-01"
}


variable "gke_cluster_name" {
  type    = string
  default = "private-cluster"
}

variable "gke_node_sa" {
  type    = string
  default = "gke-node-sa"
}

variable "artifact_repo" {
  type    = string
  default = "my-docker-repo"
}
