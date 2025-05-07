##
## provider
##
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

##
## server(s)
##

## www-server-01
resource "digitalocean_droplet" "www-server-01" {
  image  = var.server_image
  name   = "www-server-01"
  region = var.region
  size   = var.server_size
  ipv6   = true
  ssh_keys = [
    data.digitalocean_ssh_key.do_test.id
  ]

  lifecycle {
    create_before_destroy = true
  }
}

## www-server-02
resource "digitalocean_droplet" "www-server-02" {
  image  = var.server_image
  name   = "www-server-02"
  region = var.region
  size   = var.server_size
  ipv6   = true
  ssh_keys = [
    data.digitalocean_ssh_key.do_test.id
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# ## www-server-03
# resource "digitalocean_droplet" "www-server-03" {
#   image  = var.server_image
#   name   = "www-server-03"
#   region = var.region
#   size   = var.server_size
#   ipv6   = true
#   ssh_keys = [
#     data.digitalocean_ssh_key.do_test.id
#   ]
# 
#   lifecycle {
#     create_before_destroy = true
#   }
# }

##
## loadbalancer
##
resource "digitalocean_loadbalancer" "www" {
  name                   = "lb-www"
  region                 = var.region
  size_unit              = var.lb_size_unit
  redirect_http_to_https = true

  # 2 droplets
  droplet_ids = [
    digitalocean_droplet.www-server-01.id,
    digitalocean_droplet.www-server-02.id
  ]

  #  # 3 droplets
  #  droplet_ids = [
  #    digitalocean_droplet.www-server-01.id,
  #    digitalocean_droplet.www-server-02.id,
  #    digitalocean_droplet.www-server-03.id
  #  ]

  forwarding_rule {
    entry_port     = 443
    entry_protocol = "https"

    target_port     = 80
    target_protocol = "http"

    certificate_name = digitalocean_certificate.cert.name
  }

  healthcheck {
    port     = 80
    protocol = "http"
    path     = "/"
  }

  lifecycle {
    create_before_destroy = true
  }

}

##
## domain, records
##
# add domain
resource "digitalocean_domain" "default" {
  name = var.domain
}

# add an A record for www.domain
resource "digitalocean_record" "www" {
  domain = digitalocean_domain.default.id
  type   = "A"
  name   = "www"
  value  = digitalocean_loadbalancer.www.ip
}

##
## certficate
##
resource "digitalocean_certificate" "cert" {
  name    = "le-cert"
  type    = "lets_encrypt"
  domains = ["${var.domain}", "www.${var.domain}"]

  lifecycle {
    create_before_destroy = true
  }
}

##
## firewall for webservers
##
resource "digitalocean_firewall" "www" {
  name = "www-server-firewall"

  # 2 droplets
  droplet_ids = [
    digitalocean_droplet.www-server-01.id,
    digitalocean_droplet.www-server-02.id
  ]

  # 3 droplets
  #  droplet_ids = [
  #    digitalocean_droplet.www-server-01.id,
  #    digitalocean_droplet.www-server-02.id,
  #    digitalocean_droplet.www-server-03.id
  #  ]

  ## ssh from all sources
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  ## http inbound from loadbalancer
  inbound_rule {
    protocol                  = "tcp"
    port_range                = "80"
    source_load_balancer_uids = [digitalocean_loadbalancer.www.id]
  }

  ## ping
  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  ##
  ## open outbound traffic
  ##
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}


##
## output
##
# output server-01 ip
output "www-server-01" {
  value = digitalocean_droplet.www-server-01.ipv4_address
}
# output server-02 ip
output "www-server-02" {
  value = digitalocean_droplet.www-server-02.ipv4_address
}
# # output server-03 ip
# output "www-server-03" {
#   value = digitalocean_droplet.www-server-03.ipv4_address
# }

# output loadbalancer's ip
output "lb-www" {
  value = digitalocean_loadbalancer.www.ip
}

##
## data
##
# ssh key uploaded to digitalocean
data "digitalocean_ssh_key" "do_test" {
  name = "do_test"
}

##
## variables
##
variable "do_token" {
  type        = string
  description = "Personal access token setup at digitalocean."
}

variable "domain" {
  type        = string
  description = "The domain name for the server"
  default     = "example.com"
}

variable "region" {
  type        = string
  description = "Digitalocean region"
  default     = "nyc3"
}

variable "server_image" {
  type        = string
  description = "Image used as foundation for webservers"
  default     = "ubuntu-22-04-x64"
}

variable "server_size" {
  type        = string
  description = "Server size for webservers"
  default     = "s-1vcpu-1gb"
}

variable "server_count" {
  type        = number
  description = "Number of webservers to create"
  default     = 2
}

variable "lb_size_unit" {
  type        = number
  description = "Number of nodes in load balancer"
  default     = 1
}

