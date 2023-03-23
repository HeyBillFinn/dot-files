#!/usr/bin/env python3
import json
import subprocess



def add_all_for_team(members, team_handle):
    team = json.loads(
        subprocess.check_output(
            f"sc-curl -s https://home.corp.stripe.com/api/teams/{team_handle}?expand=members,children",
            shell=True
        )
    )
    if "error" in team:
        print(f"error fetching team ${team_handle}:")
        print(team)
        return
    add_members_for_team(members, team)
    add_members_for_child_teams(members, team)


def add_members_for_team(members, team):
    for member in team["members"]:
        members.append(member["username"])


def add_members_for_child_teams(members, team):
    for child_team in team["children"]:
        add_all_for_team(members, child_team["handle"])


members = []
# add_all_for_team(members, "terminal-parent")
add_all_for_team(members, "terminal")
sorted_members = sorted(list(set(members)))
print("\n".join(sorted_members))
