# main.tf -- Fase 3 (plan-tareas-hello-world-cloud-run-upn-dev-2026-08-10.md)
#
# Instancia los 3 modulos catalogados para una app publica (ADR-004):
#   service-project   -> crea el proyecto de la app y lo adjunta a la
#                         Shared VPC de infra-2-univ (networkUser acotado a
#                         sb-run, ya otorgado desde infra-2-univ).
#   cloud-run-service  -> Cloud Run con Direct VPC Egress a sb-run, ingress
#                         restringido a INTERNAL_LOAD_BALANCER.
#   public-exposure    -> NEG serverless + backend service + Cloud Armor +
#                         CDN, listo para el PR a exposed-apps.yaml de
#                         infra-1-hub (Fase 5).
#
# Wiring verificado contra las interfaces reales de los 3 modulos
# (variables.tf/outputs.tf leidos directamente el 11-ago-2026, no supuestos).

locals {
  project_id   = "prj-app-${var.university_code}-${var.environment}-${var.app_name}"
  service_name = "${var.app_name}-${var.environment}"

  cost_labels = merge(var.cost_labels, {
    cost_entity = var.university_code
    cost_env    = var.environment
    app         = var.app_name
  })

  # CORRECCION (12-ago-2026): un apply real de infra-3-apps-upn-hello-world
  # fallo creando el google_cloud_run_v2_service con:
  #   Error 400: Expected a subnetwork name like projects/*/regions/*/subnetworks/*,
  #   but obtained https://www.googleapis.com/compute/v1/projects/.../subnetworks/...
  # El campo real de la API (network_interface.subnetwork, dentro de
  # revision.vpc_access de fabric/cloud-run-v2, que cloud-run-service.vpc_subnetwork
  # pasa sin transformar) NO acepta un self-link completo con protocolo/host
  # -- pese a que el nombre de la variable (vpc_subnetwork) y su descripcion
  # en infra-modules/modules/cloud-run-service/variables.tf ("Subnetwork
  # self-link") sugerian lo contrario. Acepta solo el resource name corto
  # projects/<proj>/regions/<region>/subnetworks/<name>. service-project.run_subnetwork
  # (passthrough de var.run_subnetwork) usa el formato 'region/nombre' -- el
  # mismo formato que publica infra-2-univ -- se construye aqui el resource
  # name corto a partir de host_project_id + los dos componentes del string,
  # sin necesitar un data source adicional ni el prefijo
  # https://www.googleapis.com/compute/v1/.
  run_subnetwork_parts = split("/", module.app_project.run_subnetwork)
  run_subnetwork_short = "projects/${module.app_project.host_project_id}/regions/${local.run_subnetwork_parts[0]}/subnetworks/${local.run_subnetwork_parts[1]}"
}

module "app_project" {
  source = "git::https://github.com/edermon/infra-modules.git//modules/service-project?ref=v0.6.2"

  project_id         = local.project_id
  folder_id          = var.folder_id
  billing_account_id = var.billing_account_id
  host_project_id    = var.host_project_id
  run_subnetwork     = var.run_subnetwork
  deletion_policy    = var.deletion_policy
  labels             = local.cost_labels
}

module "service" {
  source = "git::https://github.com/edermon/infra-modules.git//modules/cloud-run-service?ref=v0.6.5"

  service_name   = local.service_name
  project_id     = module.app_project.project_id
  region         = var.region
  image          = var.image
  min_instances  = var.min_instances
  max_instances  = var.max_instances
  vpc_subnetwork = local.run_subnetwork_short
  cpu_limit      = var.cpu_limit
  memory_limit   = var.memory_limit
  env_vars       = var.env_vars
  iam_invokers   = var.iam_invokers

  depends_on = [module.app_project]
}

module "exposure" {
  source = "git::https://github.com/edermon/infra-modules.git//modules/public-exposure?ref=v0.6.4"

  app_name               = var.app_name
  project_id             = module.app_project.project_id
  region                 = var.region
  cloud_run_service_name = module.service.service_name
  cloudflare_ip_ranges   = var.cloudflare_ip_ranges
  enable_cdn             = var.enable_cdn
  cdn_cache_mode         = var.cdn_cache_mode
  use_classic_version    = var.use_classic_version

  depends_on = [module.service]
}
