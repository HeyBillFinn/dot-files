#!/usr/bin/env python3
"""
Copy asset versions from a deploy group or deploy plan into a new deploy plan
on another group.

Source can be either:
  - A deploy group ID (tmddg_...): copies its current managed assets
  - A deploy plan ID (tmdp_...): copies the asset versions it deploys

Usage:
  ./copy_deploy_group.py <source> <target_ddg_id> [-v]

Requirements:
  sc-grpcurl, ~/stripe/mint/zoolander checked out
"""

import argparse
import json
import os
import subprocess
import sys

ZOOLANDER_IMPORT_PATH = os.path.expanduser("~/stripe/mint/zoolander")
FENDER_PROTO = "src/proto/com/stripe/terminal/terminal/pub/api/fender/internal_tools_service.proto"
FENDER_HOST = "fender.corp.stripe.com"
FENDER_SERVICE = "com.stripe.terminal.terminal.pub.api.fender.InternalToolsApi"
AMP_DEPLOY_PLAN_URL = "https://amp.corp.stripe.com/terminal/deploy-plans/{}"
AMP_DDG_URL = "https://amp.corp.stripe.com/terminal/deploy-groups/{}"


def run_grpcurl(method: str, data: dict, verbose: bool = False) -> dict:
    cmd = [
        "sc-grpcurl",
        "-plaintext",
        "-import-path", ZOOLANDER_IMPORT_PATH,
        "-proto", FENDER_PROTO,
        "-d", json.dumps(data),
        "-unix", FENDER_HOST,
        f"{FENDER_SERVICE}/{method}",
    ]
    if verbose:
        print(f"   [debug] {method} request: {json.dumps(data, indent=2)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if verbose:
        print(f"   [debug] {method} stdout: {result.stdout.strip()}")
        if result.stderr.strip():
            print(f"   [debug] {method} stderr: {result.stderr.strip()}")
    if result.returncode != 0:
        raise RuntimeError(f"sc-grpcurl failed:\n{result.stderr.strip()}")
    return json.loads(result.stdout)


def get_deploy_group_details(ddg_id: str, verbose: bool = False) -> dict:
    response = run_grpcurl("GetDeployGroupDetails", {"deploy_group_id": ddg_id}, verbose=verbose)
    return response["deployGroup"]


def get_deploy_plan(plan_id: str, verbose: bool = False) -> dict:
    response = run_grpcurl("GetProgressiveDeployPlan", {"id": plan_id}, verbose=verbose)
    return response["deployPlan"]


def get_device_types(deploy_group: dict) -> list:
    """Read compatible device types, falling back to the deprecated field."""
    compatible_device_types = deploy_group.get("compatibleDeviceTypes", [])
    if compatible_device_types:
        return compatible_device_types

    legacy_device_type = deploy_group.get("hardwareType")
    if legacy_device_type:
        return [legacy_device_type]
    return []


def device_type_keys(device_types: list) -> set[str]:
    return {
        json.dumps(device_type, sort_keys=True, separators=(",", ":"))
        for device_type in device_types
    }


def format_device_types(device_types: list) -> str:
    if not device_types:
        return "(none reported)"
    return ", ".join(
        json.dumps(device_type, sort_keys=True, separators=(",", ":"))
        for device_type in device_types
    )


def get_managed_assets(deploy_group: dict) -> list[dict]:
    """Extract managed asset versions from a deploy group's details."""
    assets = deploy_group.get("managedAssets", [])
    results = []
    for asset in assets:
        results.append({
            "asset_id": asset.get("assetId", ""),
            "asset_version_id": asset.get("assetVersionId", ""),
            "asset_name": asset.get("assetName", ""),
            "version": asset.get("assetVersionName", ""),
        })
    return results


def create_deploy_plan(target_ddg_id: str, name: str, asset_version_ids: list[str],
                       description: str,
                       verbose: bool = False) -> str:
    response = run_grpcurl("CreateProgressiveDeployPlan", {
        "deploy_group_id": target_ddg_id,
        "name": name,
        "description": description,
        "asset_version_ids_to_install": asset_version_ids,
        "rollout_plan": [0, 100],
        "mandatory_install_datetime": {"millis": "0"},
    }, verbose=verbose)
    return response["deployPlan"]["id"]


def main():
    parser = argparse.ArgumentParser(
        description="Copy a deploy group's asset versions into a new deploy plan on another group."
    )
    parser.add_argument("source", help="Source deploy group (tmddg_...) or deploy plan (tmdp_...)")
    parser.add_argument("target_ddg", help="Target deploy group ID to create deploy plan for")
    parser.add_argument("-v", "--verbose", action="store_true", help="Print debug info for gRPC calls")
    args = parser.parse_args()

    verbose = args.verbose

    source = args.source.strip()
    target_ddg = args.target_ddg.strip()

    if not source.startswith("tmddg_") and not source.startswith("tmdp_"):
        print(f"Error: source must be a deploy group (tmddg_...) or deploy plan (tmdp_...), got: {source!r}", file=sys.stderr)
        sys.exit(1)
    if not target_ddg.startswith("tmddg_"):
        print(f"Error: target must be a deploy group ID (tmddg_...), got: {target_ddg!r}", file=sys.stderr)
        sys.exit(1)

    if source.startswith("tmddg_"):
        print(f"\nFetching source deploy group...", end=" ", flush=True)
        try:
            source_group = get_deploy_group_details(source, verbose=verbose)
        except Exception as e:
            print(f"\nError fetching source group: {e}", file=sys.stderr)
            sys.exit(1)
        source_name = source_group.get("name", source)
        print(source_name)

        managed_assets = get_managed_assets(source_group)
        if not managed_assets:
            print(f"\nError: source group has no managed assets.", file=sys.stderr)
            sys.exit(1)
        asset_version_ids = [a["asset_version_id"] for a in managed_assets]
    else:
        print(f"\nFetching source deploy plan...", end=" ", flush=True)
        try:
            source_plan = get_deploy_plan(source, verbose=verbose)
        except Exception as e:
            print(f"\nError fetching source plan: {e}", file=sys.stderr)
            sys.exit(1)
        source_name = source_plan.get("name", source)
        print(source_name)

        source_group_id = source_plan.get("deployGroupId", "")
        if not source_group_id:
            print(
                "\nError: source deploy plan does not identify its owning deploy group.",
                file=sys.stderr,
            )
            sys.exit(1)
        print(f"Fetching source deploy group...", end=" ", flush=True)
        try:
            source_group = get_deploy_group_details(source_group_id, verbose=verbose)
        except Exception as e:
            print(f"\nError fetching source group: {e}", file=sys.stderr)
            sys.exit(1)
        print(source_group.get("name", source_group_id))

        asset_version_ids = source_plan.get("assetVersionIdsToInstall", [])
        if not asset_version_ids:
            print(f"\nError: source plan has no asset versions to install.", file=sys.stderr)
            sys.exit(1)
        managed_assets = [{"asset_name": "", "version": "", "asset_version_id": av} for av in asset_version_ids]

    print(f"Fetching target deploy group...", end=" ", flush=True)
    try:
        target_group = get_deploy_group_details(target_ddg, verbose=verbose)
    except Exception as e:
        print(f"\nError fetching target group: {e}", file=sys.stderr)
        sys.exit(1)
    target_name = target_group.get("name", target_ddg)
    print(target_name)

    source_device_types = get_device_types(source_group)
    target_device_types = get_device_types(target_group)
    device_types_differ = (
        device_type_keys(source_device_types) != device_type_keys(target_device_types)
    )

    plan_name = f"Copy of {source_name}"
    plan_description = f"Copied asset versions from {source_name}"

    print()
    print("=" * 62)
    print(f"  Copy Deploy Group Assets")
    print("=" * 62)
    print(f"  Source:  {source_name}")
    print(f"           {source}")
    print(f"  Target:  {target_name}")
    print(f"           {AMP_DDG_URL.format(target_ddg)}")
    print(f"  Name:    {plan_name}")
    print(f"  Description: {plan_description}")
    print(f"  Update:  FORCE_IMMEDIATE")
    print(f"  Source device types: {format_device_types(source_device_types)}")
    print(f"  Target device types: {format_device_types(target_device_types)}")
    if device_types_differ:
        print()
        print("  WARNING: Source and target deploy groups have different device types.")
        print("  The target may reject asset versions that are not compatible with its devices.")
    print()
    print(f"  Asset versions ({len(managed_assets)}):")
    for asset in managed_assets:
        print(f"    {asset['asset_name']:<40} {asset['version']}")
        print(f"      {asset['asset_version_id']}")
    print()
    print("  Will create deploy plan.")
    print()
    print(f"  Source:  {source_name} ({source})")
    print(f"  Target:  {target_name} ({target_ddg})")
    print()

    prompt = (
        "  Proceed despite the device-type mismatch? [y/N] "
        if device_types_differ
        else "  Proceed? [y/N] "
    )
    answer = input(prompt).strip().lower()
    if answer != "y":
        print("  Aborted.")
        sys.exit(0)

    print()
    print(f"-> Creating deploy plan on {target_name}...")
    try:
        plan_id = create_deploy_plan(
            target_ddg,
            plan_name,
            asset_version_ids,
            plan_description,
            verbose=verbose,
        )
        plan_url = AMP_DEPLOY_PLAN_URL.format(plan_id)
        print(f"   Created: {plan_id}")
        print(f"   {plan_url}")
    except Exception as e:
        print(f"   FAILED: {e}", file=sys.stderr)
        sys.exit(1)

    print()
    print(f"  {plan_url}")
    print()


if __name__ == "__main__":
    main()
