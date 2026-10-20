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

# Recovery Services Vault (RSV) Configuration
recovery_services_vault_name    = "RSV-CE-NONPRD-IGM-LGCY"
recovery_services_vault_rg_name = "RG-CE-NONPRD-IGM-LGCY-RSV"

# Replication and Recovery Plan
recovery_plan_name = "IBMCognIncvCompMgt-NONPRD-DR"

# Backup and Protection Items
# Confirm this is the Azure Backup policy in the vault; details.txt identifies the replication policy only.
failed_over_backup_policy_name = "RSV-CE-NONPRD-IGM-LGCY-BACKUP-POLICY"

# Set test_failover_network_id to a dedicated test VNet resource ID for test_failover.

replicated_vms = {
  "FCOCOMFSD1" = {
    target_rg                       = "RG-CE-IG-LGCY-NONPRD-CMOD-APPS-01"
    base_rg                         = "RG-CC-IG-LGCY-NONPRD-CMOD-APPS-01"
    recovery_vm_name                = "FCOCOMFSD1-replicated"
    replication_protected_item_name = "FCOCOMFSD1-replicated"
    replication_policy_name         = "12HR-Replication-Policy"
    disks = [
      "FCOCOMFSD1-OSdisk-00",
      "FCOCOMFSD1-datadisk-01",
    ]
  }
}

# dr_direction and dr_failover_action are set by the workflow.