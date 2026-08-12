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

variable "hub_service_account_email" {
  description = <<-EOT
    Email de sa-tf-hub-<university_code> (SA de Terraform del hub de esta
    universidad, infra-1-hub). Normalmente NO se fija en un .tfvars -- lo
    provee TF_VAR_hub_service_account_email desde el artefacto de outputs de
    infra-0-org (per_university_service_account_emails, ver paso 'Fetch org
    outputs artifact').

    CIERRE DE BRECHA #7-correccion (12-ago-2026): otorgamos aqui
    roles/compute.loadBalancerServiceUser a esta SA, a nivel del backend
    service que este mismo repo crea (google_compute_backend_service_iam_member,
    recurso especifico -- no el proyecto completo), para habilitar el
    cross-project referencing real del URL map del hub. Un intento anterior
    de otorgar este rol a nivel de folder de entorno (infra-0-org) fue
    revertido tras confirmar con un apply real que ese scope no satisface la
    verificacion de GCP para este chequeo (ver infra-0-org, commit 024ff03).

    Nullable con default null a proposito: a diferencia de folder_id (donde
    un valor incorrecto es costoso de deshacer), la ausencia de este valor
    simplemente deja sin crear el binding de IAM -- el resto del apply (Fase
    4, el propio Cloud Run) no debe bloquearse si el fetch de CI de este
    campo puntual fallara.
  EOT
  type        = string
  default     = null
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

variable "extra_allowed_ip_ranges" {
  description = <<-EOT
    CIERRE DE GAP DE SMOKE TEST (12-ago-2026): rangos IP/CIDR adicionales
    permitidos por Cloud Armor, ADEMAS de var.cloudflare_ip_ranges -- ver
    infra-modules/modules/public-exposure CHANGELOG [0.6.9]. Necesaria
    porque, sin dominio real todavia detras de Cloudflare, ningun origen
    externo real puede pasar el borde del LB para validar que la app
    responde. Normalmente NO se fija en un .tfvars -- se provee via
    TF_VAR_extra_allowed_ip_ranges desde el input de workflow_dispatch
    extra_allowed_ip_ranges (ver .github/workflows/terraform-oidc.yml),
    para poder agregar/quitar la IP de quien esta probando "a demanda",
    sin commitear IPs personales al repo.

    USO EXCLUSIVO DE DEV/PRUEBAS MANUALES -- NUNCA declarar esto para
    cert/prod (ver advertencia completa en la variable del modulo). Default
    vacio a proposito: sin override explicito, el comportamiento es
    identico al de antes de que existiera esta variable.
  EOT
  type        = list(string)
  default     = []
  nullable    = false
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
  description = <<-EOT
    Debe coincidir con el mismo valor usado en external-lb-edge de
    infra-1-hub para esta universidad (mismo load_balancing_scheme en
    ambos extremos del backend).

    CORRECCION (12-ago-2026, causa raiz real del gap #7): el comentario
    anterior de esta variable decia "confirmado: default true en ambos
    modulos, sin override" -- tratando la consistencia entre ambos
    extremos como suficiente. Era necesaria pero NO suficiente: un apply
    real de infra-1-hub con un backend cross-project fallo tres veces
    con "Cross-project references for this resource are not allowed",
    incluso con el IAM ya en el scope oficialmente correcto (recurso
    especifico, google-beta). Investigacion contra documentacion oficial
    de GCP confirmo que el modo Classic (EXTERNAL, true) nunca soporto
    cross-project service referencing -- la guia oficial de setup para
    esta feature en Global External ALB solo documenta EXTERNAL_MANAGED.
    Default cambiado a false; ver infra-1-hub/univ-upn/variables.tf
    (use_classic_version) para el detalle completo y la nota sobre
    revisar el terraform plan antes de aplicar este cambio contra
    recursos ya reales.
  EOT
  type        = bool
  default     = false
}

variable "external_managed_migration_state" {
  description = <<-EOT
    CIERRE DE BRECHA #7 (12-ago-2026): controla la migracion en fases de
    load_balancing_scheme de EXTERNAL (Classic) a EXTERNAL_MANAGED en el
    backend service de esta app. Necesaria porque un apply real (con
    use_classic_version ya en false) fallo:

      Error 400: Invalid value for field 'resource.loadBalancingScheme':
      'EXTERNAL_MANAGED'. Cannot change the load balancing scheme until
      the migration state is set to TEST_ALL_TRAFFIC., invalid

    GCP no permite cambiar el scheme de un backend service YA EXISTENTE de
    forma atomica -- exige el flujo oficial de migration state (ver
    docs.cloud.google.com/load-balancing/docs/https/migrate-from-classic-global):

      1) external_managed_migration_state = "PREPARE"          (use_classic_version aun true)
      2) esperar minutos reales de propagacion (GCP recomienda 6+)
      3) external_managed_migration_state = "TEST_ALL_TRAFFIC" (use_classic_version aun true)
      4) esperar minutos reales de propagacion
      5) use_classic_version = false, external_managed_migration_state = null (o sin fijar)

    Cada paso es un apply distinto y separado en el tiempo -- no se puede
    hacer en un solo terraform apply. Nullable con default null a proposito:
    un consumidor que crea el backend service por primera vez directamente
    en EXTERNAL_MANAGED (sin pasar nunca por EXTERNAL) no necesita fijar
    este campo. Ver infra-modules/modules/public-exposure CHANGELOG [0.6.7]
    y .github/workflows/terraform-oidc.yml (input migration_state) para el
    mecanismo de control por apply.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.external_managed_migration_state == null || contains(["PREPARE", "TEST_BY_PERCENTAGE", "TEST_ALL_TRAFFIC"], var.external_managed_migration_state)
    error_message = "external_managed_migration_state debe ser null, \"PREPARE\", \"TEST_BY_PERCENTAGE\" o \"TEST_ALL_TRAFFIC\"."
  }
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
