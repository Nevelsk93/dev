#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="${1:-$(basename "$PWD")-app}"
GH_REPO="${GH_REPO:-$REPO_NAME}"

echo "Repo name: $GH_REPO"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found. Install and authenticate 'gh' first. Exiting."
  exit 1
fi

if [ ! -d .git ]; then
  git init
  git add -A
  git commit -m "Initial commit"
fi

echo "Creating GitHub repository (if not exists)..."
if gh repo view "$GH_REPO" >/dev/null 2>&1; then
  echo "Repository github:/$GH_REPO already exists or is viewable. Skipping create."
else
  gh repo create "$GH_REPO" --public --source=. --remote=origin --push || true
fi

mkdir -p .github/workflows
cat > .github/workflows/android.yml <<'YML'
name: Android CI

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - name: Cache Gradle
        uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper/
          key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*','**/gradle-wrapper.properties') }}
          restore-keys: |
            ${{ runner.os }}-gradle-
      - name: Grant execute permission for gradlew
        run: chmod +x gradlew || true
      - name: Build debug APK
        run: |
          if [ -f gradlew ]; then
            ./gradlew assembleDebug --no-daemon
          else
            echo "No Gradle wrapper found — skipping build step"
          fi
      - name: Upload artifact (APK)
        if: success() && always()
        uses: actions/upload-artifact@v4
        with:
          name: app-apk
          path: '**/app/build/outputs/**/*.apk'
YML

git add .github/workflows/android.yml
if git diff --staged --quiet; then
  echo "No changes to commit for workflow."
else
  git commit -m "Add Android CI workflow"
  git push -u origin HEAD:main || true
fi

echo "Setup complete. If 'gh' created a repo and push succeeded, check Actions tab on GitHub."
echo "Next steps locally: open VS Code, press F5 to run extension, open your project folder and use @omniai MySuperApp in the OmniAI chat."

exit 0
