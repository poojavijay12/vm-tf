variable "project_id" {}
variable "region" { default = "asia-south1" }
variable "zone"   { default = "asia-south1-a" }
variable "network_name" { default = "gke-private-vpc" }
variable "subnet_name"  { default = "gke-private-subnet" }
variable "subnet_cidr"  { default = "10.10.0.0/20" }
variable "cluster_name" { default = "gke-private-cluster" }
variable "node_count"   { default = 3 }
variable "machine_type" { default = "e2-standard-4" }
