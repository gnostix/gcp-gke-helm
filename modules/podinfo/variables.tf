variable "namespace" {
  type    = string
  default = "podinfo"
}

variable "chart_version" {
  description = "Exact chart version. Pinned: a 3rd-party chart must never float to 'latest' on its own."
  type        = string
}

variable "message" {
  description = "Text shown in podinfo's UI (chart value ui.message)."
  type        = string
  default     = "Hello from a public chart, installed by Terraform"
}

variable "color" {
  description = "UI background colour (chart value ui.color)."
  type        = string
  default     = "#2f6fde"
}
