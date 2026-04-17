#!/usr/bin/env python3
"""
Create and roll out progressive deploy plans for Standalone POS dev internal groups.

Targets S700, S710, and V660P device types. For each deploy group, the script will:
  1. CreateProgressiveDeployPlan
  2. SendProgressiveDeployPlanToReview
  3. ActivateProgressiveDeployPlan
  4. AdvanceProgressiveDeployPlan -> 100%

Usage:
  ./create_standalone_deploy_plans.py [dav_id]

  If dav_id is omitted, the most recent DAV from the standalone deploy asset is used.

Requirements:
  sc-grpcurl, ~/stripe/mint/zoolander checked out
"""

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass

ZOOLANDER_IMPORT_PATH = os.path.expanduser("~/stripe/mint/zoolander")
FENDER_PROTO = "src/proto/com/stripe/terminal/terminal/pub/api/fender/internal_tools_service.proto"
FENDER_HOST = "fender.corp.stripe.com"
FENDER_SERVICE = "com.stripe.terminal.terminal.pub.api.fender.InternalToolsApi"
AMP_DEPLOY_PLAN_URL = "https://amp.corp.stripe.com/terminal/deploy-plans/{}"
AMP_DAV_URL = "https://amp.corp.stripe.com/terminal/deploy-assets/{}/versions/{}"
AMP_DDG_URL = "https://amp.corp.stripe.com/terminal/deploy-groups/{}"
STANDALONE_ASSET_ID = "tmda_5300MCyJb00076SByvr000000000000"


@dataclass
class DeployGroup:
    name: str
    id: str
    rollout_plan: list


# Dev internal deploy groups for SPOS device types.
# DDG IDs sourced from bulk_create_deploy_plans.sh (S700/S710) and deploy_to_dev_internal.sh (V660P).
DEV_INTERNAL_GROUPS = [
    # S700
    DeployGroup("S700",         "tmddg_EwJgwgeQOD8LTJ", [0, 100]),
    # S710
    DeployGroup("S710",         "tmddg_FwoTAphB8z0pLu", [0, 100]),
    # V660P
    DeployGroup("V660P A Plus", "tmddg_GRnqdgLtuxcVV6", [0, 100]),
]


# ---------------------------------------------------------------------------
# DAV lookup
# ---------------------------------------------------------------------------

def get_latest_dav(verbose: bool = False) -> tuple[str, str]:
    """Return (dav_id, version) for the most recent asset version."""
    response = run_grpcurl("ListAssetVersions", {"asset_id": STANDALONE_ASSET_ID}, verbose=verbose)
    versions = response.get("assetVersions", [])
    if not versions:
        raise RuntimeError("No asset versions found for standalone deploy asset")
    latest = versions[0]
    return latest["id"], latest["version"]


def get_dav_version(dav_id: str, verbose: bool = False) -> str:
    """Find the version name for a DAV ID by paginating through ListAssetVersions."""
    page_token = None
    while True:
        req = {"asset_id": STANDALONE_ASSET_ID}
        if page_token:
            req["pagination"] = {"page_token": page_token}
        response = run_grpcurl("ListAssetVersions", req, verbose=verbose)
        for av in response.get("assetVersions", []):
            if av["id"] == dav_id:
                return av["version"]
        pagination = response.get("pagination", {})
        if not pagination.get("hasMore"):
            break
        page_token = pagination["nextPageToken"]
    raise RuntimeError(f"DAV {dav_id!r} not found in ListAssetVersions for asset {STANDALONE_ASSET_ID}")


# ---------------------------------------------------------------------------
# gRPC helpers
# ---------------------------------------------------------------------------

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


def create_deploy_plan(group: DeployGroup, dav_id: str, title: str, verbose: bool = False) -> str:
    response = run_grpcurl("CreateProgressiveDeployPlan", {
        "deploy_group_id": group.id,
        "name": title,
        "asset_version_ids_to_install": [dav_id],
        "rollout_plan": group.rollout_plan,
    }, verbose=verbose)
    return response["deployPlan"]["id"]


def send_to_review(plan_id: str, verbose: bool = False) -> None:
    response = run_grpcurl("SendProgressiveDeployPlanToReview", {"deploy_plan_id": plan_id}, verbose=verbose)
    state = response["deployPlan"]["state"]
    if state != "IN_REVIEW":
        raise RuntimeError(f"Expected IN_REVIEW, got {state!r}")


def activate(plan_id: str, verbose: bool = False) -> None:
    response = run_grpcurl("ActivateProgressiveDeployPlan", {"deploy_plan_id": plan_id}, verbose=verbose)
    state = response["deployPlan"]["state"]
    if state != "ACTIVE":
        raise RuntimeError(f"Expected ACTIVE, got {state!r}")


def advance_to_100(plan_id: str, verbose: bool = False) -> None:
    response = run_grpcurl("AdvanceProgressiveDeployPlan", {
        "deploy_plan_id": plan_id,
        "next_stage": 100,
    }, verbose=verbose)
    state = response["deployPlan"]["state"]
    stage = str(response["deployPlan"].get("rolloutStage", ""))
    if state != "ACTIVE" or stage != "100":
        raise RuntimeError(f"Expected ACTIVE at stage 100, got state={state!r} stage={stage!r}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Create and roll out Standalone POS deploy plans for dev internal groups (S700, S710, V660P)"
    )
    parser.add_argument("dav_id", nargs="?", default=None, help="Device asset version ID (e.g. tmdav_...). If omitted, uses the most recent DAV.")
    parser.add_argument("-v", "--verbose", action="store_true", help="Print debug info for gRPC calls")
    args = parser.parse_args()
    verbose = args.verbose

    if args.dav_id:
        dav_id = args.dav_id.strip()
        if not dav_id.startswith("tmdav_"):
            print(f"Error: expected a DAV ID starting with 'tmdav_', got: {dav_id!r}", file=sys.stderr)
            sys.exit(1)
        print("\nLooking up DAV version...", end=" ", flush=True)
        try:
            version = get_dav_version(dav_id, verbose=verbose)
        except Exception as e:
            print(f"\nError: {e}", file=sys.stderr)
            sys.exit(1)
        print(version)
    else:
        print("\nNo DAV ID provided, looking up most recent...", end=" ", flush=True)
        try:
            dav_id, version = get_latest_dav(verbose=verbose)
        except Exception as e:
            print(f"\nError: {e}", file=sys.stderr)
            sys.exit(1)
        print(f"{version} ({dav_id})")

    title = f"Standalone app {version}"

    # Print the rollout plan and prompt for confirmation.
    dav_url = AMP_DAV_URL.format(STANDALONE_ASSET_ID, dav_id)

    print()
    print("=" * 62)
    print("  Standalone POS -- Dev Internal Rollout")
    print("=" * 62)
    print(f"  DAV:     {dav_id}")
    print(f"           {dav_url}")
    print(f"  Version: {version}")
    print(f"  Title:   {title}")
    print()
    print(f"  Deploy groups ({len(DEV_INTERNAL_GROUPS)}):")
    for g in DEV_INTERNAL_GROUPS:
        ddg_url = AMP_DDG_URL.format(g.id)
        print(f"    {g.name:<20}  {g.id}   rollout={g.rollout_plan}")
        print(f"    {'':20}  {ddg_url}")
    print()
    print("  For each group, this script will:")
    print("    1. CreateProgressiveDeployPlan")
    print("    2. SendProgressiveDeployPlanToReview")
    print("    3. ActivateProgressiveDeployPlan")
    print("    4. AdvanceProgressiveDeployPlan -> 100%")
    print()

    answer = input("  Proceed? [y/N] ").strip().lower()
    if answer != "y":
        print("  Aborted.")
        sys.exit(0)

    print()

    results = []
    for group in DEV_INTERNAL_GROUPS:
        print(f"-> {group.name} ({group.id})")
        url = None
        error = None
        try:
            plan_id = create_deploy_plan(group, dav_id, title, verbose=verbose)
            url = AMP_DEPLOY_PLAN_URL.format(plan_id)
            print(f"   Created:         {plan_id}")

            send_to_review(plan_id, verbose=verbose)
            print(f"   In review")

            activate(plan_id, verbose=verbose)
            print(f"   Activated")

            advance_to_100(plan_id, verbose=verbose)
            print(f"   Rolled out 100%")
            print(f"   {url}")
        except Exception as e:
            error = str(e)
            print(f"   FAILED: {error}", file=sys.stderr)

        results.append((group.name, url, error))
        print()

    # Summary
    print("=" * 62)
    print("  Summary")
    print("=" * 62)
    for name, url, error in results:
        if error is None:
            print(f"  OK  {name}: {url}")
        else:
            print(f"  ERR {name}: {error}")
    print()

    if any(error for _, _, error in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
