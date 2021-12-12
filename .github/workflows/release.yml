---
name: 💌 Release Notes Preview

on:
  pull_request_target:
    branches: [ main ]
  issue_comment:
    types: [ edited ]
  workflow_dispatch:
    
jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - run: |
        git fetch --prune --unshallow --tags
    - uses: snyk/release-notes-preview@v1.6.1
      with:
        releaseBranch: main
      env:
        GITHUB_PR_USERNAME: ${{ github.actor }}
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
