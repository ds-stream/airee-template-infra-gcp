{
    "category": "CUSTOM",
    "dashboardFilters": [
      {
        "filterType": "RESOURCE_LABEL",
        "labelKey": "cluster_name",
        "stringValue": "${cluster_name}"
      },
      {
        "filterType": "USER_METADATA_LABEL",
        "labelKey": "app",
        "stringValue": "airflow-worker"
      }
    ],
    "displayName": "${cluster_name} dashboard",
    "mosaicLayout": {
      "columns": 12,
      "tiles": [
        {
          "height": 4,
          "widget": {
            "title": "Bytes received [SUM], Bytes transmitted [SUM]",
            "xyChart": {
              "chartOptions": {
                "mode": "COLOR"
              },
              "dataSets": [
                {
                  "minAlignmentPeriod": "60s",
                  "plotType": "LINE",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "apiSource": "DEFAULT_CLOUD",
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_NONE",
                        "perSeriesAligner": "ALIGN_RATE"
                      },
                      "filter": "metric.type=\"kubernetes.io/node/network/received_bytes_count\" resource.type=\"k8s_node\"",
                      "secondaryAggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "groupByFields": [
                          "resource.label.\"cluster_name\""
                        ],
                        "perSeriesAligner": "ALIGN_MEAN"
                      }
                    }
                  }
                },
                {
                  "minAlignmentPeriod": "60s",
                  "plotType": "LINE",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "apiSource": "DEFAULT_CLOUD",
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_NONE",
                        "perSeriesAligner": "ALIGN_RATE"
                      },
                      "filter": "metric.type=\"kubernetes.io/node/network/sent_bytes_count\" resource.type=\"k8s_node\"",
                      "secondaryAggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "groupByFields": [
                          "resource.label.\"cluster_name\""
                        ],
                        "perSeriesAligner": "ALIGN_MEAN"
                      }
                    }
                  }
                }
              ],
              "timeshiftDuration": "0s",
              "yAxis": {
                "label": "y1Axis",
                "scale": "LINEAR"
              }
            }
          },
          "width": 6,
          "xPos": 6,
          "yPos": 4
        },
        {
          "height": 4,
          "widget": {
            "title": "Memory",
            "xyChart": {
              "chartOptions": {
                "mode": "COLOR"
              },
              "dataSets": [
                {
                  "legendTemplate": "Used",
                  "minAlignmentPeriod": "60s",
                  "plotType": "LINE",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "apiSource": "DEFAULT_CLOUD",
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "perSeriesAligner": "ALIGN_MEAN"
                      },
                      "filter": "metric.type=\"kubernetes.io/container/memory/used_bytes\" resource.type=\"k8s_container\" metric.label.\"memory_type\"=\"non-evictable\""
                    }
                  }
                },
                {
                  "legendTemplate": "Requested",
                  "minAlignmentPeriod": "60s",
                  "plotType": "LINE",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "apiSource": "DEFAULT_CLOUD",
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "perSeriesAligner": "ALIGN_MEAN"
                      },
                      "filter": "metric.type=\"kubernetes.io/container/memory/request_bytes\" resource.type=\"k8s_container\""
                    }
                  }
                },
                {
                  "legendTemplate": "Limit",
                  "minAlignmentPeriod": "60s",
                  "plotType": "LINE",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "apiSource": "DEFAULT_CLOUD",
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "perSeriesAligner": "ALIGN_MEAN"
                      },
                      "filter": "metric.type=\"kubernetes.io/container/memory/limit_bytes\" resource.type=\"k8s_container\""
                    }
                  }
                }
              ],
              "timeshiftDuration": "0s",
              "yAxis": {
                "label": "y1Axis",
                "scale": "LINEAR"
              }
            }
          },
          "width": 6,
          "xPos": 0,
          "yPos": 0
        },
        {
          "height": 4,
          "widget": {
            "title": "CPU",
            "xyChart": {
              "chartOptions": {
                "mode": "COLOR"
              },
              "dataSets": [
                {
                  "legendTemplate": "Used",
                  "minAlignmentPeriod": "60s",
                  "plotType": "LINE",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "apiSource": "DEFAULT_CLOUD",
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "perSeriesAligner": "ALIGN_RATE"
                      },
                      "filter": "metric.type=\"kubernetes.io/container/cpu/core_usage_time\" resource.type=\"k8s_container\""
                    }
                  }
                },
                {
                  "legendTemplate": "Requested",
                  "minAlignmentPeriod": "60s",
                  "plotType": "LINE",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "apiSource": "DEFAULT_CLOUD",
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "perSeriesAligner": "ALIGN_MEAN"
                      },
                      "filter": "metric.type=\"kubernetes.io/container/cpu/request_cores\" resource.type=\"k8s_container\""
                    }
                  }
                },
                {
                  "legendTemplate": "Limit",
                  "minAlignmentPeriod": "60s",
                  "plotType": "LINE",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "apiSource": "DEFAULT_CLOUD",
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "perSeriesAligner": "ALIGN_MEAN"
                      },
                      "filter": "metric.type=\"kubernetes.io/container/cpu/limit_cores\" resource.type=\"k8s_container\""
                    }
                  }
                }
              ],
              "timeshiftDuration": "0s",
              "yAxis": {
                "label": "y1Axis",
                "scale": "LINEAR"
              }
            }
          },
          "width": 6,
          "xPos": 6,
          "yPos": 0
        },
        {
          "height": 4,
          "widget": {
            "title": "Disk",
            "xyChart": {
              "chartOptions": {
                "mode": "COLOR"
              },
              "dataSets": [
                {
                  "legendTemplate": "Used",
                  "minAlignmentPeriod": "60s",
                  "plotType": "LINE",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "apiSource": "DEFAULT_CLOUD",
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "perSeriesAligner": "ALIGN_MEAN"
                      },
                      "filter": "metric.type=\"kubernetes.io/pod/volume/used_bytes\" resource.type=\"k8s_pod\""
                    }
                  }
                },
                {
                  "legendTemplate": "Limit",
                  "minAlignmentPeriod": "60s",
                  "plotType": "LINE",
                  "targetAxis": "Y1",
                  "timeSeriesQuery": {
                    "apiSource": "DEFAULT_CLOUD",
                    "timeSeriesFilter": {
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "crossSeriesReducer": "REDUCE_SUM",
                        "perSeriesAligner": "ALIGN_MEAN"
                      },
                      "filter": "metric.type=\"kubernetes.io/pod/volume/total_bytes\" resource.type=\"k8s_pod\""
                    }
                  }
                }
              ],
              "timeshiftDuration": "0s",
              "yAxis": {
                "label": "y1Axis",
                "scale": "LINEAR"
              }
            }
          },
          "width": 6,
          "xPos": 0,
          "yPos": 4
        }
      ]
    }
}
