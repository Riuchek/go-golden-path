resource "google_monitoring_notification_channel" "email" {
  count = var.platform == "cloud_run" && var.notification_email != "" ? 1 : 0

  project      = var.project_id
  display_name = "${var.service_name} alerts"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_alert_policy" "error_ratio" {
  count = var.platform == "cloud_run" ? 1 : 0

  project      = var.project_id
  display_name = "${var.service_name} Cloud Run 5xx ratio"
  combiner     = "OR"
  enabled      = true

  notification_channels = var.notification_email == "" ? [] : [google_monitoring_notification_channel.email[0].name]

  conditions {
    display_name = "5xx ratio above 5% for 5 minutes"

    condition_monitoring_query_language {
      duration                = "300s"
      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"

      query = <<-EOT
        fetch cloud_run_revision
        | metric 'run.googleapis.com/request_count'
        | filter resource.service_name == '${var.service_name}' && resource.location == '${var.region}'
        | align rate(1m)
        | every 1m
        | group_by [resource.service_name, metric.response_code_class],
            [requests: sum(value.request_count)]
        | group_by [resource.service_name],
            [error_ratio: sum(if(metric.response_code_class == '5xx', requests, 0)) / sum(requests)]
        | condition error_ratio > 0.05
      EOT
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    mime_type = "text/markdown"
    content   = "More than 5% of Cloud Run responses for `${var.service_name}` are 5xx. Open the Cloud Run dashboard and Cloud Trace before scaling anything."
  }

  user_labels = {
    platform = "golden-path"
  }
}

resource "google_monitoring_alert_policy" "latency" {
  count = var.platform == "cloud_run" ? 1 : 0

  project      = var.project_id
  display_name = "${var.service_name} Cloud Run p95 latency"
  combiner     = "OR"
  enabled      = true

  notification_channels = var.notification_email == "" ? [] : [google_monitoring_notification_channel.email[0].name]

  conditions {
    display_name = "p95 latency above 500ms for 5 minutes"

    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_latencies\" AND resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND resource.labels.location=\"${var.region}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 500

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MAX"
        group_by_fields      = ["resource.label.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    mime_type = "text/markdown"
    content   = "`run.googleapis.com/request_latencies` is in milliseconds. 500 is the demo threshold, not an SLO."
  }

  user_labels = {
    platform = "golden-path"
  }
}
