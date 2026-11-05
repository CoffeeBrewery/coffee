---
description: Deploy CoffeeBrewery on macOS with Microsoft Intune, run maintenance scripts as the CoffeeBrewery owner and collect custom inventory attributes.
last_review_date: "2026-10-25"
---

# Manage CoffeeBrewery with Microsoft Intune

Use Intune's macOS management agent for CoffeeBrewery installation scripts, maintenance and custom attributes.
The following steps use Apple Silicon Macs and an Entra device group named `CoffeeBrewery Pilot`.

## Deploy CoffeeBrewery and the baseline

Intune's [PKG app detection](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-unmanaged-pkg-macos#step-4--detection-rules) uses application bundle identifiers.
CoffeeBrewery has no application bundle, so use a root installation script and verify its owner and commands directly.

1. Follow [account provisioning and installer configuration](CoffeeBrewery-for-Mac-Admins.md#initial-provisioning).
   Put the account checks and installer configuration in the installation script before the download and installation commands below, with `set -euo pipefail` so failures stop deployment.
2. Approve a CoffeeBrewery `.pkg` release and record its URL and SHA-256 checksum.
   Replace both placeholders below with the values you reviewed, then add these commands to the same script:

   ```bash
   umask 077
   pkg_dir=$(/usr/bin/mktemp -d /var/tmp/homebrew-installer.XXXXXX)
   trap '/bin/rm -rf "${pkg_dir}"' EXIT
   /usr/bin/curl --fail --location --output "${pkg_dir}/CoffeeBrewery.pkg" \
     'APPROVED_PKG_URL'
   printf '%s  %s\n' 'APPROVED_SHA256' "${pkg_dir}/CoffeeBrewery.pkg" |
     /usr/bin/shasum -a 256 --check -
   /usr/sbin/installer -pkg "${pkg_dir}/CoffeeBrewery.pkg" -target /
   ```

3. Assign the installation script to `CoffeeBrewery Pilot` using the [script settings below](#assign-maintenance-scripts), with **Run script as signed-in user** set to **No** and a frequency of **Not configured** for a single run.
   Use the [post-install verification commands](CoffeeBrewery-for-Mac-Admins.md#initial-provisioning) before assigning more devices.
4. Deliver [central configuration](CoffeeBrewery-Package-Policies.md#set-central-configuration-with-brewenv) and the [team Brewfile](CoffeeBrewery-Fleet-Management.md#install-default-software-for-each-team), then assign the baseline job.
   Separately assigned scripts can run in parallel, so require successful prerequisite results before assigning dependent jobs.

## Assign maintenance scripts

1. Open **Devices > By platform > macOS > Manage devices > Scripts > Add**.
2. Upload the [Brewfile installation job](CoffeeBrewery-Fleet-Management.md#install-default-software-for-each-team), set **Run script as signed-in user** to **No** and assign `CoffeeBrewery Pilot`.
   The examples use [`as-coffee-user`](CoffeeBrewery-for-Mac-Admins.md#run-management-commands-as-the-owner) to switch from root to the prefix owner without requiring a signed-in user.
3. Review the result, then assign the [approved maintenance job](CoffeeBrewery-Fleet-Management.md#schedule-updates-and-staged-rollouts) with a suitable frequency and retry count.
   Prevent overlapping jobs on the same prefix.
4. Collect fresh results after each run: the portal's script status is not a history of every recurring execution.
   Use custom attributes and retained reports below.

Microsoft's [macOS script reference](https://learn.microsoft.com/en-us/intune/device-management/tools/run-shell-scripts-macos) documents prerequisites, scheduling and reporting limits.

## Add inventory fields and collect reports

1. Under macOS **Organize devices > Custom attributes for macOS**, add `CoffeeBrewery outdated formulae` with type **Integer**.
2. Upload this script, then assign the pilot group.
   Include `jq` in the baseline and refresh metadata in your maintenance job first.
   [`as-coffee-user`](CoffeeBrewery-for-Mac-Admins.md#run-management-commands-as-the-owner) queries the installation as its owner from Intune's root job:

   ```bash
   #!/bin/bash
   set -euo pipefail

   /opt/homebrew/bin/coffee as-coffee-user outdated --json=v2 |
     /opt/homebrew/bin/jq -er '.formulae | arrays | length'
   ```

   It prints the count alone; `pipefail` preserves collection failures separately from a successful zero count.
   An outdated count is not a vulnerability count.
3. Review **Device status** and the attribute's age; custom attributes run every eight hours.
   Do not assume these attributes can serve as Entra dynamic-group criteria.
4. Save full [inventory and SBOM reports](CoffeeBrewery-Inventory-and-SBOM.md) through your organisation's collector.
   Use the same absolute paths and `as-coffee-user` wrapper when adapting those shared examples for root jobs.
   For investigations, use **Collect logs** and an allowed archive format such as `.zip` for JSON files.
5. Select affected devices from current findings, assign the [approved remediation](CoffeeBrewery-Vulnerability-Management.md#automate-patching-through-your-management-system) and collect a fresh scan before closing the finding.

## Control assignments and administrator access

1. Use administrator-assigned scripts for CoffeeBrewery jobs.
   Company Portal's **Available** app assignment delivers applications; it is not a general shell-script button.
   A self-service CoffeeBrewery action needs a tested package and detection design.
2. Assign [Intune roles, scope groups and scope tags](https://learn.microsoft.com/en-us/intune/fundamentals/role-based-access-control/overview) so report readers cannot edit or assign root scripts.
3. Test a restricted account against another group's or customer's devices before granting access.
   Follow the [shared access-control guidance](CoffeeBrewery-Fleet-Management.md#reporting-and-administrator-access) for customer separation and audit evidence.
