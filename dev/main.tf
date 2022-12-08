
terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "droplet_ssh_key" {
  name = "ATTEMPT1000"
}

data "digitalocean_project" "lab_project" {
  name = "first-project"
}

# Create a student tag
resource "digitalocean_tag" "student_tag" {
  name = "A01264858"
}

# Create an application tag
resource "digitalocean_tag" "application_tag" {
  name = "application"
}

# Create a frontend tag
resource "digitalocean_tag" "frontend_tag" {
  name = "frontend"
}

# Create a new vpc
resource "digitalocean_vpc" "web_vpc" {
  name     = "4640labs"
  region   = var.region
  ip_range = var.ip_range
}

# Create a new application Droplet
resource "digitalocean_droplet" "application-A01264858" {
  image  = "rockylinux-9-x64"
  name   = "application-A01264858"
  tags   = [digitalocean_tag.application_tag.id, digitalocean_tag.student_tag.id]
  region = var.region
  size   = "s-1vcpu-512mb-10gb"
  ssh_keys = [data.digitalocean_ssh_key.droplet_ssh_key.id]
  vpc_uuid = digitalocean_vpc.web_vpc.id

  lifecycle {
    create_before_destroy = true
  }

}

# Create a new frontend Droplet
resource "digitalocean_droplet" "frontend-A01264858" {
  image  = "rockylinux-9-x64"
  name   = "frontend-A01264858"
  tags   = [digitalocean_tag.frontend_tag.id, digitalocean_tag.student_tag.id]
  region = var.region
  size   = "s-1vcpu-512mb-10gb"
  ssh_keys = [data.digitalocean_ssh_key.droplet_ssh_key.id]
  vpc_uuid = digitalocean_vpc.web_vpc.id

  lifecycle {
    create_before_destroy = true
  }

}

# Add application firewall
resource "digitalocean_firewall" "application-A01264858" {
  name = "app-firewall"
  droplet_ids = [digitalocean_droplet.application-A01264858.id]

  inbound_rule {
    protocol = "tcp"
    port_range = "22"
  }
 
  inbound_rule {
    protocol = "icmp"
  }  

  outbound_rule {
    protocol = "tcp"
    port_range = "80"
    destination_addresses = ["10.46.40.0/24", "::/0"]
  }

  outbound_rule {
    protocol = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

}

# Add frontend firewall
resource "digitalocean_firewall" "frontend-A01264858" {
  name = "frontend-firewall"
  droplet_ids = [digitalocean_droplet.frontend-A01264858.id]

  inbound_rule {
    protocol = "tcp"
    port_range = "22"
  }

  inbound_rule {
    protocol = "icmp"
  }

  inbound_rule {
    protocol = "tcp"
    port_range = "80"
  }

  outbound_rule {
    protocol = "tcp"
    port_range = "80"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

}

# Add new web droplets to existing 4640_labs project
resource "digitalocean_project_resources" "project_attach" {
  project = data.digitalocean_project.lab_project.id
  resources = flatten([
    digitalocean_droplet.application-A01264858.*.urn,
    digitalocean_droplet.frontend-A01264858.*.urn
  ])
}

# Output IP addresses
output "application_ip" {
  value = digitalocean_droplet.application-A01264858.*.ipv4_address
}

output "frontend_ip" {
  value = digitalocean_droplet.frontend-A01264858.*.ipv4_address
}
