variable "dr_direction" {
  description = "Direction of disaster recovery operation (PrimaryToRecovery or RecoveryToPrimary)."
  type        = string
  default     = "PrimaryToRecovery"
}

variable "dr_failover_action" {
  description = "Disaster recovery action to perform: failover, test_failover, test_cleanup, commit, switch, or reset."
  type        = string
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

variable "recovery_plan_name" {
  description = "Name of the Site Recovery plan."
  type        = string
}


variable "replicated_vms" {
  description = "Map of VMs to protect, keyed by VM name, with recovery details and replication policy."
  type = map(object({
    target_rg                       = string
    base_rg                         = string
    recovery_vm_name                = string
    replication_protected_item_name = string
    replication_policy_name         = string
    disks                           = list(string)
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
