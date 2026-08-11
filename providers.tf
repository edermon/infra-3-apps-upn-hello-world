# NOTA: local.project_id se referencia aqui aunque el proyecto todavia no
# existe en el primer apply -- es seguro porque (a) local.project_id solo
# depende de variables planas (university_code/environment/app_name), nunca
# de un recurso creado por este mismo apply, y (b) cada recurso real de los
# 3 modulos pasa su propio project_id explicito -- este default de provider
# solo se usaria para llamadas a la API que no especifiquen proyecto (no
# hay ninguna en este root). Mismo patron ya usado en infra-2-univ/providers.tf.
provider "google" {
  project = local.project_id
  region  = var.region
}

provider "google-beta" {
  project = local.project_id
  region  = var.region
}
