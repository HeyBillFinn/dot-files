#!/usr/bin/env python3
"""
Deploy Standalone POS APK via progressive deploy plans.

By default, targets dev internal deploy groups (S700, S710, V660P) with a
fast rollout (0 -> 100%) that is automatically activated and advanced.

With --ga, uses a gradual rollout plan (0, 1, 5, 10, 25, 50, 100%) and stops
after sending the plan to review -- activation and advancement must be done
manually via the Amp UI.

Usage:
  ./deploy_standalone_apk.py [dav_id] [--groups DDG_ID [DDG_ID ...]] [--ga]

  If dav_id is omitted, the most recent DAV from the standalone deploy asset is used.
  If --groups is provided, only those deploy groups are targeted (by DDG ID, e.g. tmddg_...).
  If --ga is provided, uses a gradual rollout and requires manual activation.

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

GA_ROLLOUT_PLAN = [0, 1, 5, 10, 25, 50, 100]
DEV_ROLLOUT_PLAN = [0, 100]


@dataclass
class DeployGroup:
    name: str
    id: str
    rollout_plan: list


# Dev internal deploy groups for SPOS device types.
# DDG IDs sourced from bulk_create_deploy_plans.sh (S700/S710) and deploy_to_dev_internal.sh (V660P).
DEV_INTERNAL_GROUPS = [
    # S700
    DeployGroup("S700",         "tmddg_EwJgwgeQOD8LTJ", DEV_ROLLOUT_PLAN),
    # S710
    DeployGroup("S710",         "tmddg_FwoTAphB8z0pLu", DEV_ROLLOUT_PLAN),
    # V660P
    DeployGroup("V660P A Plus", "tmddg_GRnqdgLtuxcVV6", DEV_ROLLOUT_PLAN),
]


# ---------------------------------------------------------------------------
# DAV lookup
# ---------------------------------------------------------------------------

def get_deploy_group_name(ddg_id: str, verbose: bool = False) -> str:
    """Look up the display name for a deploy group ID."""
    response = run_grpcurl("GetDeployGroupDetails", {"deploy_group_id": ddg_id}, verbose=verbose)
    return response["deployGroup"]["name"]


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
# Deploy plan status lookup
# ---------------------------------------------------------------------------

# States that indicate a plan is NOT fully rolled out to 100%.
COMPLETED_STATES = {"COMPLETED", "CANCELED"}


def get_latest_deploy_plan(ddg_id: str, verbose: bool = False) -> dict | None:
    """Return the latest deploy plan for a deploy group, or None if no plans exist.

    Must pass states explicitly — without the filter the API returns nothing.
    """
    response = run_grpcurl("ListDeployPlans", {
        "deploy_group_id": ddg_id,
        "states": ["ACTIVE", "PAUSED"],
    }, verbose=verbose)
    plans = response.get("deployPlans", [])
    if not plans:
        return None
    return plans[0]


def get_in_review_plan(ddg_id: str, verbose: bool = False) -> dict | None:
    """Return the deploy plan currently IN_REVIEW for a deploy group, or None."""
    response = run_grpcurl("ListDeployPlans", {
        "deploy_group_id": ddg_id,
        "states": ["IN_REVIEW"],
    }, verbose=verbose)
    plans = response.get("deployPlans", [])
    if not plans:
        return None
    return plans[0]



def format_plan_status(plan: dict) -> str:
    """Format a deploy plan's state and rollout stage as a human-readable string."""
    state = plan.get("state", "UNKNOWN")
    stage = plan.get("rolloutStage", None)
    name = plan.get("name", "")
    if stage is not None:
        return f"{name} — {state} at {stage}%"
    return f"{name} — {state}"


def is_plan_fully_rolled_out(plan: dict) -> bool:
    """Return True if the plan has completed rollout to 100%."""
    state = plan.get("state", "")
    stage = plan.get("rolloutStage", None)
    if state in COMPLETED_STATES:
        return True
    if state == "ACTIVE" and str(stage) == "100":
        return True
    return False


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
        description="Deploy Standalone POS APK via progressive deploy plans."
    )
    parser.add_argument("dav_id", nargs="?", default=None, help="Device asset version ID (e.g. tmdav_...). If omitted, uses the most recent DAV.")
    parser.add_argument("-v", "--verbose", action="store_true", help="Print debug info for gRPC calls")
    parser.add_argument(
        "--groups", nargs="+", metavar="DDG_ID",
        help="Deploy group IDs to target (e.g. tmddg_...). If omitted, uses the default dev internal groups.",
    )
    parser.add_argument(
        "--ga", action="store_true",
        help="GA rollout: use gradual rollout plan (0,1,5,10,25,50,100%%) and skip activate/advance (requires manual review).",
    )
    args = parser.parse_args()
    verbose = args.verbose
    ga = args.ga

    rollout_plan = GA_ROLLOUT_PLAN if ga else DEV_ROLLOUT_PLAN

    if args.groups:
        known = {g.id: g for g in DEV_INTERNAL_GROUPS}
        groups = []
        for ddg_id in args.groups:
            if ddg_id in known:
                g = known[ddg_id]
                groups.append(DeployGroup(name=g.name, id=g.id, rollout_plan=rollout_plan))
            else:
                print(f"\nLooking up deploy group {ddg_id}...", end=" ", flush=True)
                try:
                    name = get_deploy_group_name(ddg_id, verbose=verbose)
                except Exception as e:
                    print(f"\nError looking up {ddg_id}: {e}", file=sys.stderr)
                    sys.exit(1)
                print(name)
                groups.append(DeployGroup(name=name, id=ddg_id, rollout_plan=rollout_plan))
    else:
        groups = [DeployGroup(name=g.name, id=g.id, rollout_plan=rollout_plan) for g in DEV_INTERNAL_GROUPS]

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
    rollout_label = "GA Rollout" if ga else "Dev Internal Rollout"

    # Print the rollout plan and prompt for confirmation.
    dav_url = AMP_DAV_URL.format(STANDALONE_ASSET_ID, dav_id)

    print()
    print("=" * 62)
    print(f"  Standalone POS -- {rollout_label}")
    print("=" * 62)
    print(f"  DAV:     {dav_id}")
    print(f"           {dav_url}")
    print(f"  Version: {version}")
    print(f"  Title:   {title}")
    # Look up latest deploy plan status for each group.
    print("\n  Checking latest deploy plan status...")
    has_warnings = False
    has_in_review = False
    group_plan_status = []
    for g in groups:
        try:
            plan = get_latest_deploy_plan(g.id, verbose=verbose)
        except Exception as e:
            group_plan_status.append((g, None, None, f"error: {e}"))
            continue
        try:
            in_review_plan = get_in_review_plan(g.id, verbose=verbose)
        except Exception as e:
            group_plan_status.append((g, plan, None, f"error checking in-review: {e}"))
            continue
        group_plan_status.append((g, plan, in_review_plan, None))
        if plan and not is_plan_fully_rolled_out(plan):
            has_warnings = True
        if in_review_plan:
            has_in_review = True

    print()
    print(f"  Deploy groups ({len(groups)}):")
    for g, plan, in_review_plan, err in group_plan_status:
        ddg_url = AMP_DDG_URL.format(g.id)
        print(f"    {g.name:<20}  {g.id}   rollout={g.rollout_plan}")
        print(f"    {'':20}  {ddg_url}")
        if err:
            print(f"    {'':20}  Latest plan: {err}")
        elif plan is None:
            print(f"    {'':20}  Latest plan: (none)")
        else:
            status_str = format_plan_status(plan)
            plan_url = AMP_DEPLOY_PLAN_URL.format(plan["id"])
            if is_plan_fully_rolled_out(plan):
                print(f"    {'':20}  Latest plan: {status_str}")
            else:
                print(f"    {'':20}  Latest plan: {status_str}")
                print(f"    {'':20}  ⚠️  WARNING: Previous plan not at 100%!")
                print(f"    {'':20}  {plan_url}")
        if in_review_plan:
            review_url = AMP_DEPLOY_PLAN_URL.format(in_review_plan["id"])
            print(f"    {'':20}  🚫 BLOCKER: Plan already in review: {in_review_plan['id']}")
            print(f"    {'':20}  {review_url}")
    print()
    if ga:
        print("  For each group, this script will:")
        print("    1. CreateProgressiveDeployPlan")
        print("    2. SendProgressiveDeployPlanToReview")
        print()
        print("  NOTE: Activate and advance steps are skipped for GA rollouts.")
        print("  You must manually activate and advance via the Amp UI.")
    else:
        print("  For each group, this script will:")
        print("    1. CreateProgressiveDeployPlan")
        print("    2. SendProgressiveDeployPlanToReview")
        print("    3. ActivateProgressiveDeployPlan")
        print("    4. AdvanceProgressiveDeployPlan -> 100%")
    print()

    if has_in_review:
        print("  🚫 One or more groups already have a deploy plan in review.")
        print("  You must cancel or approve those plans before creating new ones.")
        print()
        sys.exit(1)

    if has_warnings:
        print("  ⚠️  One or more groups have a deploy plan that hasn't reached 100%.")
        print("  Creating a new plan will supersede the in-progress rollout.")
        print()

    answer = input("  Proceed? [y/N] ").strip().lower()
    if answer != "y":
        print("  Aborted.")
        sys.exit(0)

    print()

    results = []
    for group in groups:
        print(f"-> {group.name} ({group.id})")
        url = None
        error = None
        try:
            plan_id = create_deploy_plan(group, dav_id, title, verbose=verbose)
            url = AMP_DEPLOY_PLAN_URL.format(plan_id)
            print(f"   Created:         {plan_id}")

            send_to_review(plan_id, verbose=verbose)
            print(f"   In review")

            if not ga:
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

    if ga:
        ok_results = [(name, url) for name, url, error in results if error is None]
        if ok_results:
            print("  Deploy plan links (activate manually):")
            for name, url in ok_results:
                print(f"    {name}: {url}")
            print()

    if any(error for _, _, error in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
