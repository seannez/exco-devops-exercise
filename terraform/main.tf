terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.11.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.2"
    }
  }
}

provider "kind" {}

resource "kind_cluster" "exco" {
  name           = "exco"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = 30080
        host_port      = 8088
      }

      extra_port_mappings {
        container_port = 30443
        host_port      = 8443
      }
    }

    node {
      role = "worker"
    }

    node {
      role = "worker"
    }
  }
}


provider "helm" {
  kubernetes = {
    config_path    = pathexpand("~/.kube/config")
    config_context = "kind-exco"
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "oci://ghcr.io/argoproj/argo-helm"
  chart            = "argo-cd"
  version          = "10.15.0"
  namespace        = "argocd"
  create_namespace = true

  wait    = true
  timeout = 600

  depends_on = [kind_cluster.exco]
}

resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = "traefik"
  create_namespace = true

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      providers = {
        kubernetesIngress = {
          publishedService = {
            enabled = false
          }
          ingressEndpoint = {
            hostname = "localhost"
          }
        }
      }
      gateway = {
        enabled = false
      }

      gatewayClass = {
        enabled = false
      }

      service = {
        spec = {
          type = "NodePort"
        }
      }

      ports = {
        web = {
          nodePort = 30080
        }
        websecure = {
          nodePort = 30443
        }
      }
    })
  ]

  depends_on = [kind_cluster.exco]
}

