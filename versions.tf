# Mismo piso de versiones que infra-1-hub/infra-2-univ (Fase 1/2, ver
# CHANGELOG.md de infra-modules [0.5.0]/[0.6.0]): google/google-beta
# >= 7.40.0, < 8.0.0; terraform >= 1.12.2 -- requerido por
# cloud-foundation-fabric v57.0.0, del cual dependen los 3 modulos que
# instancia este repo (service-project, cloud-run-service, public-exposure).
terraform {
  required_version = ">= 1.12.2"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.40.0, < 8.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.40.0, < 8.0.0"
    }
  }
}
