#!/bin/bash

branches=(
  "nwsde/B1-github-actions"
  "nwsde/B2-core-overrides"
  "nwsde/B3-templates-workspaces"
  "nwsde/B4-templates-guacamole"
  "nwsde/B5-templates-azuresql"
  "nwsde/B6-templates-adminvm"
  "nwsde/B7-templates-nexus"
)

merge_branch="develop"

echo ""

cherry_pick_command=""

for branch in "${branches[@]}"; do

  commits=$(git rev-list --reverse --abbrev-commit  "$merge_branch".."$branch" | tr '\n' ' ')

  echo "$branch"
  git show -s --format="%h %s" $commits

  cherry_pick_command+="git cherry-pick $commits\n"

  echo ""
done

echo "-------------------------------"
echo "Commands to perform the rebase:"
echo ""

echo -e "$cherry_pick_command"

