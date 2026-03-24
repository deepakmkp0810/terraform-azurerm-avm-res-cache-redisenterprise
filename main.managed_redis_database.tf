# Azure Managed Redis Enterprise
# Creates a single Redis Enterprise cluster with its default database

# Redis Enterprise Cluster
resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = "Microsoft.Cache/redisEnterprise@2025-07-01"

  dynamic "identity" {
    for_each = var.managed_identities.system_assigned || length(var.managed_identities.user_assigned_resource_ids) > 0 ? [1] : []

    content {
      type = var.managed_identities.system_assigned && length(var.managed_identities.user_assigned_resource_ids) > 0 ? "SystemAssigned, UserAssigned" : var.managed_identities.system_assigned ? "SystemAssigned" : "UserAssigned"

      identity_ids = length(var.managed_identities.user_assigned_resource_ids) > 0 ? tolist(var.managed_identities.user_assigned_resource_ids) : null
    }
  }

  body = merge(
    {
      sku = {
        name = var.sku_name
      }
      properties = merge(
        {
          minimumTlsVersion   = var.minimum_tls_version
          publicNetworkAccess = var.public_network_access
        },
        var.high_availability != null ? {
          highAvailability = var.high_availability
        } : {},
        var.customer_managed_key_encryption != null ? {
          encryption = {
            customerManagedKeyEncryption = {
              keyEncryptionKeyIdentity = {
                identityType                   = var.customer_managed_key_encryption.identity_type
                userAssignedIdentityResourceId = var.customer_managed_key_encryption.user_assigned_identity_resource_id
              }
              keyEncryptionKeyUrl = var.customer_managed_key_encryption.key_encryption_key_url
            }
          }
        } : {}
      )
    },
    length(var.zones) > 0 ? {
      zones = var.zones
    } : {}
  )
  create_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers              = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values    = ["properties.hostName", "properties.redisVersion"]
  schema_validation_enabled = false
  tags                      = var.tags
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# Redis Database within the cluster
# Note: Each Redis Enterprise cluster supports exactly one database named "default"
resource "azapi_resource" "database" {
  name      = "default"
  parent_id = azapi_resource.this.id
  type      = "Microsoft.Cache/redisEnterprise/databases@2025-07-01"
  body = {
    properties = {
      clientProtocol   = var.enable_non_ssl_port ? "Plaintext" : "Encrypted"
      evictionPolicy   = var.eviction_policy
      clusteringPolicy = var.clustering_policy
      modules          = var.redis_modules
    }
  }
  create_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers              = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  schema_validation_enabled = false
  update_headers            = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}