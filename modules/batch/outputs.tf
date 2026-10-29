output "kueue" {
  value = {
    namespace     = helm_release.kueue.namespace
    chart_version = helm_release.kueue.version
    status        = helm_release.kueue.status
  }
}

output "queues" {
  value = {
    namespace     = helm_release.queues.namespace
    chart_version = helm_release.queues.version
    status        = helm_release.queues.status
    submit_label  = "kueue.x-k8s.io/queue-name: batch"
  }
}
