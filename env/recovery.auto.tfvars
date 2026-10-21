# Primary Site Configuration
primary_protection_container_name = "asr-a2a-default-canadacentral-container"
primary_fabric_name               = "asr-a2a-default-canadacentral"

# Secondary Site Configuration
secondary_protection_container_name = "asr-a2a-default-canadaeast-container"
secondary_fabric_name               = "asr-a2a-default-canadaeast"

# Staging Storage Accounts
primary_staging_storage_account_name   = "dq4cj1rsvcenonasrcache1"
primary_staging_resource_group_name    = "RG-CE-NONPRD-IGM-LGCY-RSV"
secondary_staging_storage_account_name = "l8inoorsvcenonasrcache1"
secondary_staging_resource_group_name  = "RG-CE-NONPRD-IGM-LGCY-RSV"

# Recovery Services Vault (RSV) Configuration
recovery_services_vault_name    = "RSV-CE-NONPRD-IGM-LGCY"
recovery_services_vault_rg_name = "RG-CE-NONPRD-IGM-LGCY-RSV"

# Replication and Recovery Plan
recovery_plan_name = "IBMCognIncvCompMgt-NONPRD-DR"

# Backup and Protection Items
failed_over_backup_policy_name = "RSV-CE-NONPRD-IGM-LGCY-BACKUP-POLICY"

backup_protected_item_ids = {
  primary = {
    "FCOCOMFSD1" = "/subscriptions/cef264a3-c295-4f8f-a3f2-a44ac311a44d/resourceGroups/RG-CC-NONPRD-IGM-LGCY-RSV/providers/Microsoft.RecoveryServices/vaults/RSV-CC-NONPRD-IGM-LGCY/backupFabrics/Azure/protectionContainers/IaasVMContainer;iaasvmcontainerv2;RG-CC-IG-LGCY-NONPRD-CMOD-APPS-01;FCOCOMFSD1/protectedItems/VM;iaasvmcontainerv2;RG-CC-IG-LGCY-NONPRD-CMOD-APPS-01;FCOCOMFSD1"
  }
  recovery = {
    "FCOCOMFSD1" = "/subscriptions/cef264a3-c295-4f8f-a3f2-a44ac311a44d/resourceGroups/RG-CE-NONPRD-IGM-LGCY-RSV/providers/Microsoft.RecoveryServices/vaults/RSV-CE-NONPRD-IGM-LGCY/backupFabrics/Azure/protectionContainers/IaasVMContainer;iaasvmcontainerv2;RG-CE-IG-LGCY-NONPRD-CMOD-APPS-01;FCOCOMFSD1/protectedItems/VM;iaasvmcontainerv2;RG-CE-IG-LGCY-NONPRD-CMOD-APPS-01;FCOCOMFSD1"
  }
}

# Set test_failover_network_id to a dedicated test VNet resource ID for test_failover.

replicated_vms = {
  "FCOCOMFSD1" = {
    target_rg                       = "RG-CE-IG-LGCY-NONPRD-CMOD-APPS-01"
    base_rg                         = "RG-CC-IG-LGCY-NONPRD-CMOD-APPS-01"
    recovery_vm_name                = "fcocomfsd1-replicated"
    replication_protected_item_name = "FCOCOMFSD1-replicated"
    replication_policy_name         = "12HR-Replication-Policy"
    primary_disks = [
      "FCOCOMFSD1-OSdisk-00",
      "FCOCOMFSD1-datadisk-01",
    ]
    # Confirm actual ASR-created disk names after failover before switch.
    recovery_disks = [
      "FCOCOMFSD1-OSdisk-00",
      "FCOCOMFSD1-datadisk-01",
    ]
  }
}

# dr_direction and dr_failover_action are set by the workflow.
