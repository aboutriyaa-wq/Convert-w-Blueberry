# macOS deployment without a local build

## Recommended: use a prebuilt Mac release

You do **not** need Xcode to install a prebuilt app. Xcode is only needed if you compile the Swift source on your own Mac.

1. Open the project's [Mac releases](https://github.com/sintaxerrorpvtltd/Convert-w-Blueberry/releases).
2. Download the latest `Convert-w-Blueberry-...-macOS.zip` asset.
3. Double-click the ZIP in Downloads to extract `Convert w Blueberry.app`.
4. Drag the app into **Applications** in Finder. Quit an older copy first; choose **Replace** if Finder asks.
5. Open the app from Applications.

This project currently publishes an **ad-hoc-signed, not Apple-notarized developer trial**. macOS may warn or block the first launch. Follow the project's [official installation guidance](https://sintaxerrorpvtltd.github.io/Convert-w-Blueberry/#download). Do not disable Gatekeeper globally.

## If you need a fresh build from this source

A local source build requires a compatible Apple Swift compiler and macOS SDK. Your build script checks this pair before compiling all source files, then exits early with an explanation if they're incompatible.

### Option A: build on GitHub's macOS runner (no Xcode installation on your Mac)

1. Put this project in the `main` branch of your GitHub repository.
2. Open the repository's **Actions** tab.
3. Choose **macOS build and tests**.
4. Click **Run workflow** and select `main`.
5. Wait for the workflow to finish successfully.
6. Open that workflow run and download the `Convert-w-Blueberry-macOS` artifact.
7. Extract the artifact ZIP and move `Convert w Blueberry.app` into Applications.

The workflow builds on a clean macOS runner and uploads the packaged app as an artifact. The artifact is temporary (GitHub's normal artifact retention applies); use a published Release for a stable end-user download.

### Option B: build locally

Requires macOS 26+, a matching full Xcode installation or compatible Command Line Tools, and Python 3. Run:

```sh
cd ~/Downloads/Convert-w-Blueberry
./scripts/build-app.sh
open "dist/Convert w Blueberry.app"
```

If the script reports `No compatible Swift compiler + macOS SDK pair was found`, do not rerun it. Install/select a matching Apple toolchain first. Do not copy SDKs between Xcode versions or delete existing developer tools.

## Publishing a stable download

The repository's release workflow can package a versioned Mac ZIP after tests and build checks pass. Increment `CFBundleShortVersionString` and `CFBundleVersion` in `scripts/build-app.sh` before publishing a new version; GitHub Releases does not replace an existing version tag automatically.
