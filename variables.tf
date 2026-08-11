variable "university_code" {
  description = "Short code for the university (e.g. upn)."
  type        = string
  default     = "upn"
}

variable "app_name" {
  description = <<-EOT
    Nombre corto de la app (kebab-case) -- usado para el project_id
    (prj-app-<univ>-<env>-<app_name>), el nombre del servicio Cloud Run, el
    NEG y el backend. Debe coincidir con vars.APP_NAME del workflow
    (.github/workflows/terraform-oidc.yml) y, en un repo real de app, con el
    sufijo del nombre del repo (infra-3-apps-<univ>-<app_name>, ADR-005).
  EOT
  type        = string
  default     = "hello-world"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.app_name))
    error_message = "app_name must be lowercase kebab-case, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name (dev, cert, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "cert", "prod"], var.environment)
    error_message = "environment must be one of: dev, cert, prod."
  }
}

variable "region" {
  description = "GCP region for the Cloud Run service and su exposicion publica. Debe coincidir con la region de la subred sb-run de infra-2-univ."
  type        = string
  default     = "us-central1"
}

variable "folder_id" {
  description = <<-EOT
    Folder de ambiente (dev/cert/prod) de esta universidad, formato
    folders/<id> (ver infra-0-org, apps_environment_folder_grants).
    Normalmente NO se fija en un .tfvars -- lo provee TF_VAR_folder_id desde
    el artefacto de outputs de infra-0-org (ver
    .github/workflows/terraform-oidc.yml, paso 'Fetch org outputs
    artifact'). Sin default a proposito: a diferencia de host_project_id/
    run_subnetwork (que sí tienen un valor real conocido de fallback), un
    folder_id equivocado creyendo el proyecto en el lugar incorrecto es un
    error mas caro de deshacer -- se prefiere que falle explicito si el
    fetch de CI no corrio.
  EOT
  type        = string

  validation {
    condition     = can(regex("^folders/[0-9]+$", var.folder_id))
    error_message = "folder_id must be in the form folders/<id>."
  }
}

variable "billing_account_id" {
  description = "Cuenta de facturacion. Normalmente provista via TF_VAR_billing_account_id desde el artefacto de outputs de infra-0-org."
  type        = string
}

variable "host_project_id" {
  description = <<-EOT
    Project ID del host de la Shared VPC (net_project_id de infra-2-univ).
    Normalmente NO se fija en un .tfvars -- lo provee TF_VAR_host_project_id
    desde el artefacto de outputs de infra-2-univ (paso 'Fetch net outputs
    artifact'). Default: valor real conocido de este sandbox, mismo patron
    de fallback que infra-2-univ/variables.tf usa para hub_project_id.
  EOT
  type        = string
  default     = "prj-net-upn"

  validation {
    condition     = can(regex("^prj-[a-z0-9-]+$", var.host_project_id))
    error_message = "host_project_id must follow naming convention prj-<domain>-<purpose>."
  }
}

variable "run_subnetwork" {
  description = <<-EOT
    Subred sb-run en formato 'region/nombre', tal como la publica
    infra-2-univ (output run_subnetwork, ya en el formato exacto que espera
    service-project). Normalmente provista via TF_VAR_run_subnetwork.
    Default: valor real conocido de este sandbox para dev.
  EOT
  type        = string
  default     = "us-central1/sb-run-upn-dev"

  validation {
    condition     = can(regex("^[a-z0-9-]+/[a-z0-9-]+$", var.run_subnetwork))
    error_message = "run_subnetwork must be in the form '<region>/<subnet_name>'."
  }
}

variable "deletion_policy" {
  description = "Politica de borrado del proyecto de la app. PREVENT recomendado para cert/prod; DELETE es aceptable para dev (este hito)."
  type        = string
  default     = "DELETE"

  validation {
    condition     = contains(["ABANDON", "DELETE", "PREVENT"], var.deletion_policy)
    error_message = "deletion_policy must be one of: ABANDON, DELETE, PREVENT."
  }
}

variable "image" {
  description = <<-EOT
    Imagen del contenedor. Default: imagen publica de muestra de Cloud Run
    (ver plan-tareas-hello-world-cloud-run-upn-dev-2026-08-10.md, seccion
    2.3) -- valida el plumbing completo de la landing zone (red, LB, IAM,
    Cloud Armor) sin acoplar un pipeline de build propio a este hito.
  EOT
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "min_instances" {
  description = "Minimo de instancias de Cloud Run. 0 = scale-to-zero (recomendado para dev/hello-world)."
  type        = number
  default     = 0
}

variable "max_instances" {
  type    = number
  default = 10
}

variable "cpu_limit" {
  type    = string
  default = "1000m"
}

variable "memory_limit" {
  type    = string
  default = "512Mi"
}

variable "env_vars" {
  type    = map(string)
  default = {}
}

variable "iam_invokers" {
  description = <<-EOT
    IAM invokers del Cloud Run service, formato {ROLE => [MEMBERS]}.

    Default: allUsers via roles/run.invoker -- REQUERIDO para que el
    External HTTPS LB (via NEG serverless, modulo public-exposure) pueda
    reenviar trafico. Una Serverless NEG no adjunta ningun token de
    identidad Google al reenviar la peticion del LB -- sin este invoker
    publico, el LB recibiria 403 de Cloud Run en cada request y el hello
    world publico nunca funcionaria.

    Esto es seguro especificamente en este diseno porque:
    (1) ingress = INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER esta fijo en
        modules/cloud-run-service/main.tf -- bloquea el acceso directo a
        la URL publica *.run.app; todo trafico real DEBE pasar por el LB
        (arq-landing-zone-gcp-multiuniversidad-v3.md sec.7/8: "el ingress
        bloquea la URL *.run.app directa").
    (2) El LB tiene Cloud Armor con allow-list de rangos Cloudflare
        (modulo public-exposure, var.cloudflare_ip_ranges) como
        deny-by-default.
    (3) El Org Policy obligatorio (misma seccion 9 del doc de arquitectura)
        impide crear un backend externo sin securityPolicy/edgeSecurityPolicy.

    El comentario "gate de CI lo rechaza adicionalmente" en
    modules/cloud-run-service/main.tf se refiere a un gate de policy-as-code
    (OPA/tfsec) marcado como OPCIONAL en la seccion 9 del doc de
    arquitectura -- confirmado que ningun workflow de este landing zone lo
    tiene implementado todavia, asi que este default no deberia bloquearse
    en CI hoy.
  EOT
  type        = map(list(string))
  default = {
    "roles/run.invoker" = ["allUsers"]
  }
}

variable "cloudflare_ip_ranges" {
  description = <<-EOT
    Rangos IPv4 publicados por Cloudflare (verificados 11-ago-2026 contra
    https://www.cloudflare.com/ips-v4) -- sin este allow-list el borde
    publico queda abierto (ver modules/public-exposure). Cloudflare puede
    agregar/modificar rangos -- revisar periodicamente contra la fuente
    oficial, no asumir que este default se mantiene vigente indefinidamente.
  EOT
  type        = list(string)
  default = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22",
  ]
}

variable "enable_cdn" {
  type    = bool
  default = true
}

variable "cdn_cache_mode" {
  type    = string
  default = "USE_ORIGIN_HEADERS"
}

variable "use_classic_version" {
  description = "Debe coincidir con el mismo valor usado en external-lb-edge de infra-1-hub para esta universidad -- confirmado: default true en ambos modulos, sin override en infra-1-hub/univ-upn/main.tf (module \"lb\")."
  type        = bool
  default     = true
}

variable "cost_labels" {
  type = map(string)
  default = {
    managed_by = "terraform"
  }
}

variable "execution_service_account" {
  description = "Service account email a impersonar para Terraform en esta capa (sa-tf-apps-<univ>)."
  type        = string
  default     = null
}
