output "release" {
  value = {
    name          = helm_release.this.name
    namespace     = helm_release.this.namespace
    chart_version = helm_release.this.version
    status        = helm_release.this.status
  }
}

output "port_forward" {
  description = "Then open http://localhost:9898"
  value       = "kubectl -n ${helm_release.this.namespace} port-forward svc/${helm_release.this.name} 9898:9898"
}
