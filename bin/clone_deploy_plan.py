#!/usr/bin/env python3
"""
Clone a deploy plan into a new, editable deploy plan.

The CloneProgressiveDeployPlan RPC copies the plan configuration, including
all install/uninstall assets, rollout stages, canaries, dependencies, kiosk
app, mandatory-update settings, and deployment metadata. The new plan is
created in DRAFT state and is not submitted for review.

If the target deploy group is omitted, the source plan's deploy group is used.
The clone RPC rejects same-group clones, so that case uses the equivalent
CreateProgressiveDeployPlan request with the source plan's configuration.

Usage:
  ./clone_deploy_plan.py <source_plan_id> [<source_plan_id> ...] [target_ddg_id] [-y] [-v]

The source plan argument may be repeated to clone multiple plans. For
backward compatibility, a trailing tmddg_... argument is treated as the
target deploy group for every source plan.

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

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(
            f"sc-grpcurl returned invalid JSON: {result.stdout.strip()}"
        ) from error


def get_deploy_plan(plan_id: str, verbose: bool = False) -> dict:
    response = run_grpcurl(
        "GetProgressiveDeployPlan",
        {"id": plan_id},
        verbose=verbose,
    )
    try:
        return response["deployPlan"]
    except KeyError as error:
        raise RuntimeError("GetProgressiveDeployPlan returned no deploy plan") from error


def get_deploy_group(ddg_id: str, verbose: bool = False) -> dict:
    response = run_grpcurl(
        "GetDeployGroupDetails",
        {"deploy_group_id": ddg_id},
        verbose=verbose,
    )
    try:
        return response["deployGroup"]
    except KeyError as error:
        raise RuntimeError("GetDeployGroupDetails returned no deploy group") from error


def clone_deploy_plan(
    source_plan_id: str,
    target_ddg_id: str,
    verbose: bool = False,
) -> dict:
    response = run_grpcurl(
        "CloneProgressiveDeployPlan",
        {
            "source_deploy_plan_id": source_plan_id,
            "deploy_group_id": target_ddg_id,
        },
        verbose=verbose,
    )
    try:
        return response["deployPlan"]
    except KeyError as error:
        raise RuntimeError("CloneProgressiveDeployPlan returned no deploy plan") from error


def clone_name(source_plan: dict, source_plan_id: str) -> str:
    return f"Clone of {source_plan.get('name', source_plan_id)}"


def create_same_group_clone(
    source_plan: dict,
    source_plan_id: str,
    target_ddg_id: str,
    verbose: bool = False,
) -> dict:
    """Create a DRAFT clone when source and target are the same deploy group."""
    request = {
        "deploy_group_id": target_ddg_id,
        "name": clone_name(source_plan, source_plan_id),
        "description": source_plan.get("description", ""),
        "asset_version_ids_to_install": source_plan.get("assetVersionIdsToInstall", []),
        "asset_ids_to_uninstall": source_plan.get("assetIdsToUninstall", []),
        "rollout_plan": source_plan.get("rolloutPlan", []),
        "preferred_kiosk_app": source_plan.get("preferredKioskApp", ""),
        "dependencies": source_plan.get("dependencies", []),
        "canaries": source_plan.get("canaries", []),
        "is_bundle_emergency_deploy": source_plan.get("isEmergencyBundleDeployment", False),
    }

    release_id = source_plan.get("releaseId")
    if release_id:
        request["release_id"] = release_id

    deployment_reason = source_plan.get("deploymentReason")
    if deployment_reason:
        request["deployment_reason"] = deployment_reason

    target_rollout_date = source_plan.get("targetRolloutDate")
    if target_rollout_date:
        request["target_rollout_date"] = target_rollout_date

    update_argument = source_plan.get("updateArgument", {})
    if update_argument.get("upgradePredicate") == "CUSTOM":
        time_to_upgrade = update_argument.get("timeToUpgrade")
        if time_to_upgrade:
            request["mandatory_install_datetime"] = time_to_upgrade
        mandatory_after_rollout_millis = update_argument.get("mandatoryAfterRolloutMillis")
        if mandatory_after_rollout_millis:
            request["mandatory_after_rollout_millis"] = mandatory_after_rollout_millis

    response = run_grpcurl("CreateProgressiveDeployPlan", request, verbose=verbose)
    try:
        return response["deployPlan"]
    except KeyError as error:
        raise RuntimeError("CreateProgressiveDeployPlan returned no deploy plan") from error


def count(plan: dict, field: str) -> int:
    value = plan.get(field, [])
    return len(value) if isinstance(value, list) else 0


def print_plan_summary(
    source_plan: dict,
    source_plan_id: str,
    target_ddg: dict,
    target_ddg_id: str,
) -> None:
    source_group_id = source_plan.get("deployGroupId", "(unknown)")
    source_name = source_plan.get("name", source_plan_id)
    target_name = target_ddg.get("name", target_ddg_id)
    rollout_plan = source_plan.get("rolloutPlan", [])

    print()
    print("=" * 68)
    print("  Clone Deploy Plan")
    print("=" * 68)
    print(f"  Source:       {source_name}")
    print(f"                {source_plan_id}")
    print(f"  Source group: {source_group_id}")
    print(f"  Target group: {target_name}")
    print(f"                {target_ddg_id}")
    print(f"                {AMP_DDG_URL.format(target_ddg_id)}")
    print(f"  New name:     {clone_name(source_plan, source_plan_id)}")
    print(f"  Current state: {source_plan.get('state', 'UNKNOWN')}")
    print(f"  Rollout plan: {rollout_plan or '(not reported)'}")
    print(f"  Assets to install:   {count(source_plan, 'assetVersionIdsToInstall')}")
    print(f"  Assets to uninstall: {count(source_plan, 'assetIdsToUninstall')}")
    print(f"  Canaries:             {count(source_plan, 'canaries')}")
    print(f"  Dependencies:         {count(source_plan, 'dependencies')}")
    print()
    print("  The clone will be created in DRAFT (idle) state.")
    print("  It will not be submitted for review or activated.")
    print()


def print_cloned_plan_links(cloned_plan_ids: list[str]) -> None:
    if not cloned_plan_ids:
        return

    print("\n  Created deploy plan links:")
    for cloned_plan_id in cloned_plan_ids:
        print(f"    {cloned_plan_id}: {AMP_DEPLOY_PLAN_URL.format(cloned_plan_id)}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Clone one or more deploy plans into new editable DRAFT plans."
    )
    parser.add_argument(
        "source_plans",
        nargs="+",
        metavar="SOURCE_PLAN",
        help="Source deploy plan ID(s) (tmdp_...). A trailing tmddg_... is the target group.",
    )
    parser.add_argument(
        "-y", "--yes",
        action="store_true",
        help="Create the clone without prompting for confirmation",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Print debug info for gRPC calls",
    )
    args = parser.parse_args()

    source_plan_ids = [source_plan.strip() for source_plan in args.source_plans]
    target_ddg_id = None
    if len(source_plan_ids) > 1 and source_plan_ids[-1].startswith("tmddg_"):
        target_ddg_id = source_plan_ids.pop()

    invalid_source_plan = next(
        (source_plan_id for source_plan_id in source_plan_ids
         if not source_plan_id.startswith("tmdp_")),
        None,
    )
    if invalid_source_plan is not None:
        print(
            f"Error: source must be a deploy plan ID (tmdp_...), got: {invalid_source_plan!r}",
            file=sys.stderr,
        )
        return 1
    plans_to_clone = []
    target_ddgs = {}
    try:
        for source_plan_id in source_plan_ids:
            print(f"Fetching source deploy plan {source_plan_id}...", flush=True)
            source_plan = get_deploy_plan(source_plan_id, verbose=args.verbose)
            source_group_id = source_plan.get("deployGroupId")
            if not source_group_id:
                raise RuntimeError(
                    f"source deploy plan {source_plan_id} does not identify its owning deploy group"
                )

            plan_target_ddg_id = target_ddg_id or source_group_id
            if target_ddg_id is None:
                print(
                    f"No target DDG supplied; using source plan's DDG {plan_target_ddg_id}."
                )

            if plan_target_ddg_id not in target_ddgs:
                print(f"Fetching target deploy group {plan_target_ddg_id}...", flush=True)
                target_ddgs[plan_target_ddg_id] = get_deploy_group(
                    plan_target_ddg_id,
                    verbose=args.verbose,
                )

            plans_to_clone.append(
                (source_plan_id, source_plan, plan_target_ddg_id)
            )
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    for source_plan_id, source_plan, plan_target_ddg_id in plans_to_clone:
        print_plan_summary(
            source_plan,
            source_plan_id,
            target_ddgs[plan_target_ddg_id],
            plan_target_ddg_id,
        )

    if not args.yes:
        answer = input("  Proceed? [y/N] ").strip().lower()
        if answer != "y":
            print("  Aborted.")
            return 0

    failed = False
    created_plan_ids = []
    successful_plan_ids = []
    for source_plan_id, source_plan, plan_target_ddg_id in plans_to_clone:
        try:
            if source_plan.get("deployGroupId") == plan_target_ddg_id:
                print(f"\n-> Creating same-group deploy plan clone for {source_plan_id}...")
                cloned_plan = create_same_group_clone(
                    source_plan,
                    source_plan_id,
                    plan_target_ddg_id,
                    verbose=args.verbose,
                )
            else:
                print(f"\n-> Cloning deploy plan {source_plan_id}...")
                cloned_plan = clone_deploy_plan(
                    source_plan_id,
                    plan_target_ddg_id,
                    verbose=args.verbose,
                )

            cloned_plan_id = cloned_plan.get("id")
            cloned_state = cloned_plan.get("state", "UNKNOWN")
            if not cloned_plan_id:
                raise RuntimeError("clone response did not include a plan ID")
            created_plan_ids.append(cloned_plan_id)
            if cloned_state != "DRAFT":
                print(
                    f"   FAILED: expected cloned plan to be DRAFT, got {cloned_state!r}",
                    file=sys.stderr,
                )
                print(f"   Created: {cloned_plan_id}", file=sys.stderr)
                failed = True
                continue

            successful_plan_ids.append(cloned_plan_id)
            print(f"   Created: {cloned_plan_id}")
            print(f"   State:   {cloned_state}")
        except Exception as error:
            print(f"   FAILED: {error}", file=sys.stderr)
            failed = True

    if failed:
        print_cloned_plan_links(created_plan_ids)
        print(
            f"\n  Completed {len(successful_plan_ids)} of {len(plans_to_clone)} deploy plan clones.",
            file=sys.stderr,
        )
        return 1

    print_cloned_plan_links(created_plan_ids)
    print(f"\n  Created {len(successful_plan_ids)} deploy plan clone(s).")
    print("  The plans are ready for a human to edit and submit for review.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
