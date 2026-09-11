#!/usr/bin/env python3
"""
Compare the asset versions in two deploy groups or deploy plans.

Each operand can be either:
  - A deploy group ID (tmddg_...): compares its current managed assets
  - A deploy plan ID (tmdp_...): compares the asset versions in its
    asset_version_ids_to_install field

Deploy plans do not contain device types themselves, so this script resolves
the plan's owning deploy group before comparing device types. Asset comparison
only runs when both operands have the same compatible device types.

Usage:
  ./compare_deploy_groups.py <source> <other> [-v]

Exit codes:
  0  Device types match and no asset differences were found
  1  Device types match and asset differences were found
  2  The comparison could not be performed, including a device-type mismatch

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
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"sc-grpcurl returned invalid JSON: {result.stdout.strip()}") from error


def get_deploy_group_details(ddg_id: str, verbose: bool = False) -> dict:
    response = run_grpcurl("GetDeployGroupDetails", {"deploy_group_id": ddg_id}, verbose=verbose)
    return response["deployGroup"]


def get_deploy_plan(plan_id: str, verbose: bool = False) -> dict:
    response = run_grpcurl("GetProgressiveDeployPlan", {"id": plan_id}, verbose=verbose)
    return response["deployPlan"]


def get_asset_version_details(asset_version_id: str, verbose: bool = False) -> dict:
    response = run_grpcurl(
        "LoadAssetVersionDetails",
        {"asset_version_id": asset_version_id},
        verbose=verbose,
    )
    return response["apiAssetVersion"]


def get_asset_names(asset_ids: list[str], verbose: bool = False) -> dict[str, str]:
    """Return asset names in one request for plan assets that lack asset names."""
    if not asset_ids:
        return {}
    response = run_grpcurl("ListAssets", {"id": asset_ids}, verbose=verbose)
    return {
        asset.get("id", ""): asset.get("name", "")
        for asset in response.get("assets", [])
        if asset.get("id")
    }


def get_managed_assets(deploy_group: dict) -> list[dict]:
    """Extract normalized asset records from a deploy group's managed assets."""
    assets = deploy_group.get("managedAssets", [])
    return [
        {
            "asset_id": asset.get("assetId", ""),
            "asset_name": asset.get("assetName", ""),
            "asset_version_id": asset.get("assetVersionId", ""),
            "version": asset.get("assetVersionName", ""),
            "version_code": asset.get("assetVersionCode", ""),
        }
        for asset in assets
    ]


def get_plan_assets(plan: dict, verbose: bool = False) -> list[dict]:
    """Resolve and normalize the asset versions listed in a deploy plan."""
    asset_version_ids = plan.get("assetVersionIdsToInstall", [])
    version_details = [
        (asset_version_id, get_asset_version_details(asset_version_id, verbose=verbose))
        for asset_version_id in asset_version_ids
    ]
    asset_names = get_asset_names(
        [details.get("assetId", "") for _, details in version_details],
        verbose=verbose,
    )
    return [
        {
            "asset_id": details.get("assetId", ""),
            "asset_name": asset_names.get(details.get("assetId", ""), ""),
            "asset_version_id": details.get("id") or requested_asset_version_id,
            "version": details.get("version", ""),
            "version_code": details.get("versionCode", ""),
        }
        for requested_asset_version_id, details in version_details
    ]


def get_device_types(deploy_group: dict) -> list:
    """Read compatible device types, falling back to the deprecated field."""
    compatible_device_types = deploy_group.get("compatibleDeviceTypes", [])
    if compatible_device_types:
        return compatible_device_types

    legacy_device_type = deploy_group.get("hardwareType")
    if legacy_device_type:
        return [legacy_device_type]
    return []


def canonical_json(value) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def device_type_keys(device_types: list) -> set[str]:
    return {canonical_json(device_type) for device_type in device_types}


def format_device_types(device_types: list) -> str:
    if not device_types:
        return "(none reported)"
    return ", ".join(canonical_json(device_type) for device_type in device_types)


def index_assets(assets: list[dict], label: str) -> dict[str, dict]:
    indexed = {}
    for asset in assets:
        asset_id = asset["asset_id"]
        if not asset_id:
            raise RuntimeError(f"{label} contains an asset without an asset ID")
        if asset_id in indexed:
            raise RuntimeError(f"{label} contains multiple versions for asset {asset_id}")
        indexed[asset_id] = asset
    return indexed


def load_operand(identifier: str, verbose: bool = False) -> dict:
    if identifier.startswith("tmddg_"):
        print(f"Fetching deploy group {identifier}...", flush=True)
        deploy_group = get_deploy_group_details(identifier, verbose=verbose)
        return {
            "identifier": identifier,
            "kind": "deploy group",
            "name": deploy_group.get("name", identifier),
            "deploy_group": deploy_group,
        }

    if identifier.startswith("tmdp_"):
        print(f"Fetching deploy plan {identifier}...", flush=True)
        plan = get_deploy_plan(identifier, verbose=verbose)
        deploy_group_id = plan.get("deployGroupId", "")
        if not deploy_group_id:
            raise RuntimeError(f"Deploy plan {identifier} does not identify a deploy group")

        print(f"Fetching owning deploy group {deploy_group_id}...", flush=True)
        deploy_group = get_deploy_group_details(deploy_group_id, verbose=verbose)
        return {
            "identifier": identifier,
            "kind": "deploy plan",
            "name": plan.get("name", identifier),
            "deploy_group": deploy_group,
            "plan": plan,
        }

    raise ValueError(
        f"Identifier must be a deploy group (tmddg_...) or deploy plan (tmdp_...), got: {identifier!r}"
    )


def get_operand_assets(operand: dict, verbose: bool = False) -> list[dict]:
    """Load an operand's assets after its device types have been validated."""
    if operand["kind"] == "deploy group":
        return get_managed_assets(operand["deploy_group"])
    return get_plan_assets(operand["plan"], verbose=verbose)


def compare_assets(left: dict[str, dict], right: dict[str, dict]) -> list[dict]:
    differences = []
    for asset_id in sorted(set(left) | set(right)):
        left_asset = left.get(asset_id)
        right_asset = right.get(asset_id)
        if left_asset is None:
            differences.append({"kind": "only_right", "asset_id": asset_id, "right": right_asset})
        elif right_asset is None:
            differences.append({"kind": "only_left", "asset_id": asset_id, "left": left_asset})
        elif left_asset["asset_version_id"] != right_asset["asset_version_id"]:
            differences.append({
                "kind": "version_mismatch",
                "asset_id": asset_id,
                "left": left_asset,
                "right": right_asset,
            })
    return differences


def format_asset(asset: dict) -> str:
    version = asset.get("version") or "(version unavailable)"
    version_code = asset.get("version_code")
    if version_code:
        version = f"{version} [{version_code}]"
    return f"{version} ({asset['asset_version_id']})"


def table_cell(value: str) -> str:
    """Make a value safe for the simple pipe-delimited terminal tables."""
    return str(value).replace("|", "/").replace("\n", " ")


def print_table(headers: list[str], rows: list[list[str]]) -> None:
    values = [[table_cell(value) for value in row] for row in rows]
    widths = [len(header) for header in headers]
    for row in values:
        for index, value in enumerate(row):
            widths[index] = max(widths[index], len(value))

    separator = "+-" + "-+-".join("-" * width for width in widths) + "-+"
    print(separator)
    print("| " + " | ".join(header.ljust(width) for header, width in zip(headers, widths)) + " |")
    print(separator)
    for row in values:
        print("| " + " | ".join(value.ljust(width) for value, width in zip(row, widths)) + " |")
    print(separator)


def print_difference_section(title: str, headers: list[str], rows: list[list[str]]) -> None:
    print(f"\n{title} ({len(rows)}):")
    if rows:
        print_table(headers, rows)
    else:
        print("  None")


def print_differences(differences: list[dict], left: dict, right: dict) -> None:
    source_only = [difference for difference in differences if difference["kind"] == "only_left"]
    other_only = [difference for difference in differences if difference["kind"] == "only_right"]
    version_mismatches = [
        difference for difference in differences if difference["kind"] == "version_mismatch"
    ]

    print_difference_section(
        f"{left['name']} has the asset, {right['name']} does not",
        ["Asset", "Asset ID", "Source version", "Source version ID"],
        [
            [
                difference["left"].get("asset_name") or "(name unavailable)",
                difference["asset_id"],
                difference["left"].get("version") or "(version unavailable)",
                difference["left"]["asset_version_id"],
            ]
            for difference in source_only
        ],
    )
    print_difference_section(
        f"{right['name']} has the asset, {left['name']} does not",
        ["Asset", "Asset ID", "Other version", "Other version ID"],
        [
            [
                difference["right"].get("asset_name") or "(name unavailable)",
                difference["asset_id"],
                difference["right"].get("version") or "(version unavailable)",
                difference["right"]["asset_version_id"],
            ]
            for difference in other_only
        ],
    )
    print_difference_section(
        "Both have the asset, but the versions differ",
        ["Asset", "Asset ID", "Source version (ID)", "Other version (ID)"],
        [
            [
                difference["left"].get("asset_name")
                or difference["right"].get("asset_name")
                or "(name unavailable)",
                difference["asset_id"],
                format_asset(difference["left"]),
                format_asset(difference["right"]),
            ]
            for difference in version_mismatches
        ],
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compare assets in two deploy groups or deploy plans."
    )
    parser.add_argument(
        "source",
        help="Source deploy group (tmddg_...) or deploy plan (tmdp_...)",
    )
    parser.add_argument(
        "other",
        help="Other deploy group (tmddg_...) or deploy plan (tmdp_...)",
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="Print debug info for gRPC calls")
    args = parser.parse_args()

    source = args.source.strip()
    other = args.other.strip()
    if source == other:
        print("Error: source and other identifiers must be different.", file=sys.stderr)
        return 2

    try:
        left = load_operand(source, verbose=args.verbose)
        right = load_operand(other, verbose=args.verbose)
    except (RuntimeError, ValueError, KeyError) as error:
        print(f"Error loading comparison operands: {error}", file=sys.stderr)
        return 2

    left_group = left["deploy_group"]
    right_group = right["deploy_group"]
    left_device_types = get_device_types(left_group)
    right_device_types = get_device_types(right_group)

    print()
    print("=" * 72)
    print("  Compare Deploy Assets")
    print("=" * 72)
    print(f"  Source: {left['name']} ({left['kind']}, {left['identifier']})")
    print(f"           owning group: {left_group.get('name', left_group.get('id', '(unknown)'))}")
    print(f"  Other:  {right['name']} ({right['kind']}, {right['identifier']})")
    print(f"           owning group: {right_group.get('name', right_group.get('id', '(unknown)'))}")
    print()
    print(f"  Source device types: {format_device_types(left_device_types)}")
    print(f"  Other device types:  {format_device_types(right_device_types)}")

    if not left_device_types or not right_device_types:
        print("\nDevice types could not be verified; skipping asset comparison.", file=sys.stderr)
        return 2

    if device_type_keys(left_device_types) != device_type_keys(right_device_types):
        print("\nDevice types do not match; skipping asset comparison.", file=sys.stderr)
        return 2

    print("\nDevice types match; loading assets for comparison...")
    try:
        left_assets = index_assets(
            get_operand_assets(left, verbose=args.verbose),
            "Source",
        )
        right_assets = index_assets(
            get_operand_assets(right, verbose=args.verbose),
            "Other",
        )
    except (RuntimeError, KeyError) as error:
        print(f"\nError loading assets: {error}", file=sys.stderr)
        return 2

    print("Comparing assets...")
    differences = compare_assets(left_assets, right_assets)
    print_differences(differences, left, right)
    return 1 if differences else 0


if __name__ == "__main__":
    sys.exit(main())
