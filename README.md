# Varicent DR execution example

This root follows Frontier's backup/ASR execution setup using the private-tenant
resources created by [varicent](../varicent/README.md). It retains the local
reusable workflows, Terraform Cloud organization/project, test-failover actions,
and existing example pre-failover runbook. Production DNS/domain-controller
automation is intentionally not copied.

## Configuration

1. Apply the infrastructure root to enable primary-region VM backup protection.
2. From that root, export the backup configuration:

   ```powershell
   terraform output -json dr_backup_configuration |
     Set-Content -Encoding ascii ..\varicent-dr\backup.auto.tfvars.json
   ```

3. Remove the example `backup_protected_item_ids` block from
   [env/recovery.auto.tfvars](./env/recovery.auto.tfvars) when using the generated
   file; the explicitly passed environment file otherwise overrides it.
   Alternatively, replace that block's placeholder IDs with the exported values.
   Review and commit the generated file to this repository (resource IDs are not
   credentials), or inject the same `backup_protected_item_ids` object using the
   existing workflow variable mechanism. Terraform automatically loads the
   generated file from this root. Never use Frontier's subscription/resource IDs.
4. Review [env/recovery.auto.tfvars](./env/recovery.auto.tfvars). Each VM has
   `primary_disks` in `base_rg` and `recovery_disks` in `target_rg`.
   A `PrimaryToRecovery` switch uses recovery disks; `RecoveryToPrimary` uses
   primary disks. Confirm actual disk names after failover/failback before
   switching protection. The example's recovery VM name is `FCOCOMFSD1`, matching
   the source name ASR uses, not the ASR protected-item name.
5. Set `test_failover_network_id` using the infrastructure output before running
   `test_failover`. Staging storage resource groups are configured independently
   for both regions.

The Azure execution identity needs access to both backup vaults and the ASR
resources. No additional DNS subscription or domain-controller access is needed.

## Actions

Use **Perform a Disaster Recovery Step** in GitHub Actions:

| Action | Behavior |
| --- | --- |
| `backup` | Requests an on-demand backup of the selected site's protected items. |
| `failover` | Starts recovery-plan unplanned failover in the selected direction. |
| `test_failover` | Starts test failover into the configured isolated VNet. |
| `test_cleanup` | Cleans up a test failover. |
| `commit` | Commits failover and registers recovery VM backups for `PrimaryToRecovery`. |
| `switch` | Reprotects using the active site's disk names; also registers recovery VM backups for `PrimaryToRecovery`. |
| `reset` | Removes conditional action objects from Terraform state; does not undo Azure operations. |

`Plan` does not execute operations. `Apply` requires collaborator approval and
runs only on `main`. PRs plan `reset`, never apply, and never request a backup.
Workflow runs are serialized to avoid overlapping DR operations.

### On-demand backup

`PrimaryToRecovery` selects `backup_protected_item_ids.primary`;
`RecoveryToPrimary` selects `.recovery`. Only listed VMs receive requests.
The selected map must be nonempty and contain Azure Backup protected-item IDs,
not VM or ASR item IDs. This action does not enable backup protection.

The workflow supplies a unique `backup_request_id` per run/attempt and reuses it
for plan and apply. For CLI use:

```powershell
terraform init
terraform plan '-var-file=env\recovery.auto.tfvars' `
  '-var=dr_failover_action=backup' '-var=dr_direction=PrimaryToRecovery' `
  '-var=backup_request_id=planned-cutover-001' '-out=backup.tfplan'
terraform apply backup.tfplan
```

Use a new request ID for each intentional backup. The output
`backup_requested_items` lists requests, not completed recovery points. Confirm
successful backup jobs in the vault before a cutover requiring a fresh backup.
The exported recovery IDs are expected IDs only: verify those items exist after
`commit`/`switch` registers protection before requesting recovery-site backups.

### Backup ownership and action transitions

Recovery VM backup registrations have `prevent_destroy`, matching Frontier.
Once `commit`/`switch` creates them, selecting an action or direction that would
remove them causes planning to fail rather than disabling protection. Before
continuing, transfer their ownership to a persistent backup configuration and
remove only the transferred registrations from this execution state without
destroying them in Azure. Do not remove the guard just to force a DR action.
Likewise, source backup registrations remain owned by the infrastructure root.

Removing an on-demand backup action object from Terraform state does not delete
backup data. `reset` neither cancels in-flight Azure jobs nor reverses failover.

## Local checks

```powershell
terraform init -backend=false
terraform validate
terraform test
```

Tests mock Azure providers; no live backup or failover is performed.