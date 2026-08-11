output "project_id" {
  description = "Project ID de la app, creado por service-project."
  value       = module.app_project.project_id
}

output "service_name" {
  description = "Nombre del servicio Cloud Run."
  value       = module.service.service_name
}

output "service_uri" {
  description = <<-EOT
    URL *.run.app del servicio. NO es el punto de entrada publico real --
    el ingress restringido (INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER) bloquea
    el acceso directo a esta URL. El punto de entrada publico real es el LB
    general de la universidad (infra-1-hub) una vez registrado el backend
    via exposed-apps.yaml (Fase 5).
  EOT
  value = module.service.service_uri
}

output "service_account_email" {
  description = "Email de la SA dedicada del servicio Cloud Run."
  value       = module.service.service_account_email
}

output "backend_service_self_link" {
  description = "Self-link del backend service -- va al PR de exposed-apps.yaml en infra-1-hub (Fase 5, plan-terraform-landing-zone-v3.md seccion 13)."
  value       = module.exposure.backend_service_self_link
}

output "security_policy_self_link" {
  description = "Self-link de la politica de Cloud Armor de esta app."
  value       = module.exposure.security_policy_self_link
}
