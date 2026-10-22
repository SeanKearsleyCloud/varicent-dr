locals {
  backup_items = var.dr_direction == "PrimaryToRecovery" ? var.backup_protected_item_ids.primary : var.backup_protected_item_ids.recovery

  active_vm_disks = {
    for vm_name, vm in var.replicated_vms :
    vm_name => var.dr_direction == "PrimaryToRecovery" ? vm.recovery_disks : vm.primary_disks
  }

  vm_disk_lookup = merge([
    for vm_name, disks in local.active_vm_disks : {
      for disk_name in disks : "${vm_name}|${disk_name}" => {
        vm_name   = vm_name
        disk_name = disk_name
      }
    }
  ]...)

  recovery_plan_id = "${data.azurerm_recovery_services_vault.vault.id}/replicationRecoveryPlans/${var.recovery_plan_name}"
}

resource "terraform_data" "backup_request" {
  count = var.dr_failover_action == "backup" ? 1 : 0

  triggers_replace = {
    request_id = var.backup_request_id
    direction  = var.dr_direction
  }

  lifecycle {
    precondition {
      condition     = length(trimspace(var.backup_request_id)) > 0
      error_message = "Set a unique backup_request_id to request a one-time backup."
    }

    precondition {
      condition     = length(local.backup_items) > 0
      error_message = "Export dr_backup_configuration from varicent or populate backup_protected_item_ids for the selected direction."
    }
  }
}

resource "azapi_resource_action" "backup_now" {
  for_each = var.dr_failover_action == "backup" ? local.backup_items : {}

  type        = "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2025-02-01"
  resource_id = each.value
  action      = "backup"
  method      = "POST"

  body = {
    properties = {
      objectType = "IaasVMBackupRequest"
    }
  }

  lifecycle {
    replace_triggered_by = [terraform_data.backup_request]
  }
}

output "backup_requested_items" {
  description = "Protected items requested for backup; not confirmation of completed recovery points."
  value       = var.dr_failover_action == "backup" ? local.backup_items : {}
}

data "azurerm_resource_group" "source_rg" {
  for_each = var.dr_failover_action == "switch" ? var.replicated_vms : {}
  name     = var.dr_direction == "PrimaryToRecovery" ? each.value.base_rg : each.value.target_rg
}

data "azurerm_managed_disk" "vm_disks" {
  for_each = var.dr_failover_action == "switch" ? local.vm_disk_lookup : {}

  name                = each.value.disk_name
  resource_group_name = var.dr_direction == "PrimaryToRecovery" ? var.replicated_vms[each.value.vm_name].target_rg : var.replicated_vms[each.value.vm_name].base_rg
}

data "azurerm_site_recovery_protection_container" "primary" {
  count                = var.dr_failover_action == "switch" ? 1 : 0
  name                 = var.dr_direction == "PrimaryToRecovery" ? var.primary_protection_container_name : var.secondary_protection_container_name
  recovery_fabric_name = var.dr_direction == "PrimaryToRecovery" ? var.primary_fabric_name : var.secondary_fabric_name
  resource_group_name  = var.recovery_services_vault_rg_name
  recovery_vault_name  = var.recovery_services_vault_name
}

data "azurerm_recovery_services_vault" "vault" {
  name                = var.recovery_services_vault_name
  resource_group_name = var.recovery_services_vault_rg_name
}

data "azurerm_site_recovery_replication_policy" "replication_policy" {
  for_each            = var.dr_failover_action == "switch" ? toset([for vm in values(var.replicated_vms) : vm.replication_policy_name]) : toset([])
  name                = each.value
  recovery_vault_name = var.recovery_services_vault_name
  resource_group_name = var.recovery_services_vault_rg_name
}

data "azurerm_storage_account" "staging_azure_storage_account" {
  count               = var.dr_failover_action == "switch" ? 1 : 0
  name                = var.dr_direction == "PrimaryToRecovery" ? var.secondary_staging_storage_account_name : var.primary_staging_storage_account_name
  resource_group_name = var.dr_direction == "PrimaryToRecovery" ? var.secondary_staging_resource_group_name : var.primary_staging_resource_group_name
}

resource "azapi_resource_action" "unplanned_failover" {
  count = var.dr_failover_action == "failover" ? 1 : 0

  type        = "Microsoft.RecoveryServices/vaults/replicationRecoveryPlans@2025-08-01"
  resource_id = local.recovery_plan_id
  action      = "unplannedFailover"
  method      = "POST"

  body = {
    properties = {
      failoverDirection = var.dr_direction
      providerSpecificDetails = [
        {
          instanceType      = "A2A"
          recoveryPointType = "LatestProcessed"
        }
      ]
      sourceSiteOperations = "Required"
    }
  }
}

resource "azapi_resource_action" "test_failover" {
  count = var.dr_failover_action == "test_failover" ? 1 : 0

  type        = "Microsoft.RecoveryServices/vaults/replicationRecoveryPlans@2025-08-01"
  resource_id = local.recovery_plan_id
  action      = "testFailover"
  method      = "POST"

  body = {
    properties = {
      failoverDirection = var.dr_direction
      networkId         = var.test_failover_network_id
      networkType       = var.test_failover_network_type
      providerSpecificDetails = [
        {
          instanceType = "A2A"
        }
      ]
    }
  }

  lifecycle {
    precondition {
      condition     = try(length(trimspace(var.test_failover_network_id)) > 0, false)
      error_message = "test_failover_network_id must be set to a dedicated test VNet ID when dr_failover_action is test_failover."
    }
  }
}

resource "azapi_resource_action" "test_failover_cleanup" {
  count = var.dr_failover_action == "test_cleanup" ? 1 : 0

  type        = "Microsoft.RecoveryServices/vaults/replicationRecoveryPlans@2025-08-01"
  resource_id = local.recovery_plan_id
  action      = "testFailoverCleanup"
  method      = "POST"

  body = {
    properties = {
      comments = var.test_failover_cleanup_comments
    }
  }
}

resource "azapi_resource_action" "commit" {
  count = var.dr_failover_action == "commit" ? 1 : 0

  type        = "Microsoft.RecoveryServices/vaults/replicationRecoveryPlans@2025-08-01"
  resource_id = local.recovery_plan_id
  action      = "failoverCommit"
  method      = "POST"

}

resource "azapi_resource_action" "switch_protection" {
  for_each = var.dr_failover_action == "switch" ? var.replicated_vms : {}

  type = "Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers@2025-08-01"

  resource_id = data.azurerm_site_recovery_protection_container.primary[0].id

  action = "switchProtection"
  method = "POST"

  body = {
    properties = {
      replicationProtectedItemName = each.value.replication_protected_item_name

      providerSpecificDetails = {
        instanceType = "A2A"

        policyId                = data.azurerm_site_recovery_replication_policy.replication_policy[each.value.replication_policy_name].id
        recoveryContainerId     = data.azurerm_site_recovery_protection_container.primary[0].id
        recoveryResourceGroupId = data.azurerm_resource_group.source_rg[each.key].id
        vmManagedDisks = [
          for disk_name in local.active_vm_disks[each.key] : {
            diskId                              = data.azurerm_managed_disk.vm_disks["${each.key}|${disk_name}"].id
            primaryStagingAzureStorageAccountId = data.azurerm_storage_account.staging_azure_storage_account[0].id
            recoveryResourceGroupId             = data.azurerm_resource_group.source_rg[each.key].id
          }
        ]
      }
    }
  }
}

data "azurerm_virtual_machine" "vms" {
  for_each            = var.dr_direction == "PrimaryToRecovery" && (var.dr_failover_action == "switch" || var.dr_failover_action == "commit") ? var.replicated_vms : {}
  name                = each.value.recovery_vm_name
  resource_group_name = each.value.target_rg
}

data "azurerm_backup_policy_vm" "backup_policy" {
  count               = var.dr_direction == "PrimaryToRecovery" && contains(["switch", "commit"], var.dr_failover_action) ? 1 : 0
  name                = var.failed_over_backup_policy_name
  resource_group_name = var.recovery_services_vault_rg_name
  recovery_vault_name = var.recovery_services_vault_name
}

# Backup for failed over VM
resource "azurerm_backup_protected_vm" "vm_bkp" {
  for_each            = var.dr_direction == "PrimaryToRecovery" && (var.dr_failover_action == "switch" || var.dr_failover_action == "commit") || var.dr_direction == "RecoveryToPrimary" && var.dr_failover_action == "backup" ? data.azurerm_virtual_machine.vms : {}
  resource_group_name = var.recovery_services_vault_rg_name
  recovery_vault_name = var.recovery_services_vault_name
  source_vm_id        = each.value.id
  backup_policy_id    = data.azurerm_backup_policy_vm.backup_policy[0].id

  depends_on = [
    azapi_resource_action.unplanned_failover,
    azapi_resource_action.commit,
    azapi_resource_action.switch_protection
  ]
}
