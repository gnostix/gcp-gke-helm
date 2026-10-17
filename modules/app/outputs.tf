output "release" {
  value = {
    name      = helm_release.this.name
    namespace = helm_release.this.namespace
    status    = helm_release.this.status
  }
}

output "port_forward" {
  description = "Open the app on http://localhost:8080"
  value       = "kubectl -n ${helm_release.this.namespace} port-forward svc/${helm_release.this.name} 8080:80"
}
