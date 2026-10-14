locals {
  vm_disk_lookup = merge([
    for vm_name, vm in var.replicated_vms : {
      for disk_name in vm.disks : "${vm_name}|${disk_name}" => {
        vm_name   = vm_name
        disk_name = disk_name
      }
    }
  ]...)

  recovery_plan_id = "${data.azurerm_recovery_services_vault.vault.id}/replicationRecoveryPlans/${var.recovery_plan_name}"
}

data "azurerm_resource_group" "target_rg" {
  for_each = var.replicated_vms
  name     = var.dr_direction == "PrimaryToRecovery" ? each.value.target_rg : each.value.base_rg
}

data "azurerm_resource_group" "source_rg" {
  for_each = var.replicated_vms
  name     = var.dr_direction == "PrimaryToRecovery" ? each.value.base_rg : each.value.target_rg
}

data "azurerm_managed_disk" "vm_disks" {
  for_each = var.dr_failover_action == "switch" ? local.vm_disk_lookup : {}

  name                = each.value.disk_name
  resource_group_name = var.dr_direction == "PrimaryToRecovery" ? var.replicated_vms[each.value.vm_name].target_rg : var.replicated_vms[each.value.vm_name].base_rg
}

data "azurerm_site_recovery_protection_container" "primary" {
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
  for_each            = toset([for vm in values(var.replicated_vms) : vm.replication_policy_name])
  name                = each.value
  recovery_vault_name = var.recovery_services_vault_name
  resource_group_name = var.recovery_services_vault_rg_name
}

data "azurerm_storage_account" "staging_azure_storage_account" {
  name                = var.dr_direction == "PrimaryToRecovery" ? var.secondary_staging_storage_account_name : var.primary_staging_storage_account_name
  resource_group_name = var.dr_direction == "PrimaryToRecovery" ? var.recovery_services_vault_rg_name : var.primary_staging_resource_group_name
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
      condition     = var.test_failover_network_id != null && length(trimspace(var.test_failover_network_id)) > 0
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

  resource_id = data.azurerm_site_recovery_protection_container.primary.id

  action = "switchProtection"
  method = "POST"

  body = {
    properties = {
      replicationProtectedItemName = each.value.replication_protected_item_name

      providerSpecificDetails = {
        instanceType = "A2A"

        policyId                = data.azurerm_site_recovery_replication_policy.replication_policy[each.value.replication_policy_name].id
        recoveryContainerId     = data.azurerm_site_recovery_protection_container.primary.id
        recoveryResourceGroupId = data.azurerm_resource_group.source_rg[each.key].id
        vmManagedDisks = [
          for disk_name in each.value.disks : {
            diskId                              = data.azurerm_managed_disk.vm_disks["${each.key}|${disk_name}"].id
            primaryStagingAzureStorageAccountId = data.azurerm_storage_account.staging_azure_storage_account.id
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
  name                = var.failed_over_backup_policy_name
  resource_group_name = var.recovery_services_vault_rg_name
  recovery_vault_name = var.recovery_services_vault_name
}

# Backup for failed over VM
resource "azurerm_backup_protected_vm" "vm_bkp" {
  for_each            = var.dr_direction == "PrimaryToRecovery" && (var.dr_failover_action == "switch" || var.dr_failover_action == "commit") ? data.azurerm_virtual_machine.vms : {}
  resource_group_name = var.recovery_services_vault_rg_name
  recovery_vault_name = var.recovery_services_vault_name
  source_vm_id        = each.value.id
  backup_policy_id    = data.azurerm_backup_policy_vm.backup_policy.id

  depends_on = [
    azapi_resource_action.unplanned_failover,
    azapi_resource_action.commit,
    azapi_resource_action.switch_protection
  ]
}
