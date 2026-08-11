# infra-3-apps-template

Plantilla Terraform para una app publica de Cloud Run sobre la landing zone
de una universidad (Fase 3, ADR-004/ADR-005). Cada app real instancia su
propio repo copiando esta plantilla (`infra-3-apps-<univ>-<app_name>`) --
este repo se mantiene central y vacio de estado real.

## Que crea

1. **`service-project`** -- proyecto de servicio de la app, adjuntado a la
   Shared VPC de `infra-2-univ` (`networkUser` acotado a `sb-run`, ya
   otorgado desde `infra-2-univ`).
2. **`cloud-run-service`** -- Cloud Run con Direct VPC Egress a `sb-run`,
   ingress restringido a `INTERNAL_LOAD_BALANCER` (bloquea la URL publica
   `*.run.app` directa).
3. **`public-exposure`** -- NEG serverless + backend service + Cloud Armor
   (allow-list Cloudflare) + Cloud CDN, listo para el PR a
   `exposed-apps.yaml` de `infra-1-hub` (Fase 5) -- el LB general de la
   universidad, no uno por app.

## Que NO crea (fuera de alcance de este template)

- El LB en si (vive una sola vez por universidad en `infra-1-hub`).
- El registro en `exposed-apps.yaml` (Fase 5, vía PR manual/automatizado).
- Cualquier pieza de acceso interno/híbrido (DNS privada, ILB regional,
  FortiGate/VPN) -- ver el catálogo priorizado en el plan del proyecto.

## Variables que provee CI, no `.tfvars`

`host_project_id`, `run_subnetwork`, `folder_id` y `billing_account_id` los
inyecta el workflow (`terraform-oidc.yml`) como `TF_VAR_*` leyendo los
artefactos de outputs curados de `infra-2-univ`/`infra-0-org`. No fijarlos
en un `.tfvars`/`.auto.tfvars` -- ese valor siempre gana sobre el
`TF_VAR_*` de CI y anularía el mecanismo.

## Variables de GitHub que configurar en un repo real de app

`UNIVERSITY_CODE`, `APP_NAME`, `APP_ENVIRONMENT`, y opcionalmente
`TF_VARS_FILE` (p.ej. `dev.tfvars.example`) y overrides de bucket/prefix de
state si no aplica el default (`prj-cicd-sandbox-tfstate-apps-<univ>`,
prefix `<univ>/<app_name>`).

## Decisión de seguridad documentada: `allUsers` en `iam_invokers`

El default de `cloud_run_service.iam_invokers` otorga `roles/run.invoker` a
`allUsers` -- es **requerido** para que el LB (NEG serverless) pueda
reenviar tráfico sin recibir 403, y es seguro específicamente porque el
`ingress` restringido bloquea el acceso directo a la URL pública y Cloud
Armor (allow-list Cloudflare) es el perímetro real. Ver el comentario en
`variables.tf` para el detalle completo y las referencias al doc de
arquitectura.
