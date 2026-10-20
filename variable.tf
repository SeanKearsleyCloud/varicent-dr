variable "dr_direction" {
  description = "Direction of disaster recovery operation (PrimaryToRecovery or RecoveryToPrimary)."
  type        = string
  default     = "PrimaryToRecovery"

  validation {
    condition     = contains(["PrimaryToRecovery", "RecoveryToPrimary"], var.dr_direction)
    error_message = "dr_direction must be PrimaryToRecovery or RecoveryToPrimary."
  }
}

variable "dr_failover_action" {
  description = "Disaster recovery action to perform: backup, failover, test_failover, test_cleanup, commit, switch, or reset."
  type        = string

  validation {
    condition     = contains(["backup", "failover", "test_failover", "test_cleanup", "commit", "switch", "reset"], var.dr_failover_action)
    error_message = "dr_failover_action must be backup, failover, test_failover, test_cleanup, commit, switch, or reset."
  }
}

variable "backup_protected_item_ids" {
  description = "Existing Azure VM Backup protected-item IDs keyed by VM name for each site. Export dr_backup_configuration from varicent after apply."
  type = object({
    primary  = optional(map(string), {})
    recovery = optional(map(string), {})
  })
  default = {}

  validation {
    condition = alltrue([
      for id in concat(values(var.backup_protected_item_ids.primary), values(var.backup_protected_item_ids.recovery)) :
      can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.RecoveryServices/vaults/[^/]+/backupFabrics/Azure/protectionContainers/[^/]+/protectedItems/[^/]+$", id))
    ])
    error_message = "Supply full Azure Backup protected-item IDs, not VM or ASR protected-item IDs."
  }
}

variable "backup_request_id" {
  description = "Unique ID for each intentional backup execution; keep identical between plan and apply."
  type        = string
  default     = ""
}

variable "test_failover_network_id" {
  description = "Dedicated test VNet resource ID used only for a test failover."
  type        = string
  default     = null
}

variable "test_failover_network_type" {
  description = "Network type used for test failover."
  type        = string
  default     = "VmNetworkAsInput"
}

variable "test_failover_cleanup_comments" {
  description = "Optional comments recorded when cleaning up a test failover."
  type        = string
  default     = "Test failover cleanup"
}

variable "primary_protection_container_name" {
  description = "Name of the primary Site Recovery protection container."
  type        = string
}

variable "primary_fabric_name" {
  description = "Name of the primary Site Recovery fabric."
  type        = string
}

variable "secondary_protection_container_name" {
  description = "Name of the secondary Site Recovery protection container."
  type        = string
}

variable "secondary_fabric_name" {
  description = "Name of the secondary Site Recovery fabric."
  type        = string
}

variable "primary_staging_storage_account_name" {
  description = "Name of the primary staging Azure storage account."
  type        = string
}

variable "secondary_staging_storage_account_name" {
  description = "Name of the secondary staging Azure storage account."
  type        = string
}

variable "secondary_staging_resource_group_name" {
  description = "Name of the resource group containing the secondary staging storage account."
  type        = string
}

variable "recovery_plan_name" {
  description = "Name of the Site Recovery plan."
  type        = string
}


variable "replicated_vms" {
  description = "Map of VMs to protect. primary_disks are in base_rg; recovery_disks are in target_rg."
  type = map(object({
    target_rg                       = string
    base_rg                         = string
    recovery_vm_name                = string
    replication_protected_item_name = string
    replication_policy_name         = string
    primary_disks                   = list(string)
    recovery_disks                  = list(string)
  }))
}

variable "recovery_services_vault_name" {
  description = "Name of the Recovery Services Vault."
  type        = string
}

variable "recovery_services_vault_rg_name" {
  description = "Name of the resource group for the Recovery Services Vault."
  type        = string
}


variable "failed_over_backup_policy_name" {
  description = "Name of the backup policy to use for failed-over VMs."
  type        = string
}

variable "primary_staging_resource_group_name" {
  description = "Name of the resource group for the primary staging storage account."
  type        = string
}
