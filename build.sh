#!/bin/bash
# echo ************* diagnostics
# echo available devices
# instruments -s devices
# echo available sdk
# xcodebuild -showsdks
# echo available Xcode
# ls -ld /Applications/Xcode*
# echo ************* diagnostics end

# run this on a 2x device until we've updated snapshot images to 3x
PLATFORM="${TEXTURE_BUILD_PLATFORM:-platform=iOS Simulator,OS=17.4,name=iPhone SE (3rd generation)}"
SDK="${TEXTURE_BUILD_SDK:-iphonesimulator17.4}"
DERIVED_DATA_PATH="~/ASDKDerivedData"

# It is pitch black.
set -e
function trap_handler {
    echo -e "\n\nOh no! You walked directly into the slavering fangs of a lurking grue!"
    echo "**** You have died ****"
    exit 255
}
trap trap_handler INT TERM EXIT

# Derived data handling
eval [ ! -d $DERIVED_DATA_PATH ] && eval mkdir $DERIVED_DATA_PATH
function clean_derived_data {
    eval find $DERIVED_DATA_PATH -mindepth 1 -delete
}

# Build example
function build_example {
    example="$1"

    clean_derived_data

    if [ -f "${example}/Podfile" ]; then
        echo "Using CocoaPods"
        pod install --project-directory=$example

        workspace=$(ls -d ${example}/*.xcworkspace)
        filename=$(basename -- "$workspace")
        scheme="${filename%.*}"

        set -o pipefail && xcodebuild \
            -workspace "${workspace}" \
            -scheme "$scheme" \
            -sdk "$SDK" \
            -destination "$PLATFORM" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            build
    elif [ -f "${example}/Cartfile" ]; then
        echo "Using Carthage"
        local_repo=`pwd`
        current_branch=`git rev-parse --abbrev-ref HEAD`
        cd $example

        echo "git \"file://${local_repo}\" \"${current_branch}\"" > "Cartfile"
        carthage update --no-use-binaries --no-build --platform iOS
        carthage build --no-skip-current --use-xcframeworks

        set -o pipefail && xcodebuild \
            -project "Sample.xcodeproj" \
            -scheme Sample \
            -sdk "$SDK" \
            -destination "$PLATFORM" \
            build

        cd ../..
     else
        echo "Seems like there are no Cartfile or Podfile in the ${example}"
        echo "Build will be skipped."
    fi
}

# Lint subspec
function lint_subspec {
    set -o pipefail && pod env && pod lib lint --allow-warnings --subspec="$1"
}

function cleanup {
    # remove all Pods directories
    find . -name Pods -type d -exec rm -rf {} +
    find . -name Podfile.lock -type f -delete
}

MODE="$1"

cleanup

case "$MODE" in
tests|all)
    echo "Building & testing AsyncDisplayKit."
    pod install
    set -o pipefail && xcodebuild \
        -workspace AsyncDisplayKit.xcworkspace \
        -scheme AsyncDisplayKit \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        build-for-testing test
    success="1"
    ;;

tests_listkit)
    echo "Building & testing AsyncDisplayKit+IGListKit."
    pod install --project-directory=SubspecWorkspaces/ASDKListKit
    set -o pipefail && xcodebuild \
        -workspace SubspecWorkspaces/ASDKListKit/ASDKListKit.xcworkspace \
        -scheme ASDKListKitTests \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        build-for-testing test
    success="1"
    ;;

build_listkit_xcode_spm_integration)
    echo "Regenerate SPM layout"
    swift scripts/generate_spm_sources_layout.swift
    echo "Building AsyncDisplayKit+IGListKit via Xcode's Swift Package Manager"
    echo "Xcode 14.3.1+ required"
    set -o pipefail && xcodebuild clean \
        -project examples/ASIGListKitSPM/Sample.xcodeproj \
        -scheme Sample \
        -sdk "iphonesimulator" \
        -destination "platform=iOS Simulator,name=iPhone 14" \
        build
    success="1"
    ;;

examples|all)
    echo "Verifying that all AsyncDisplayKit examples compile."
    for example in examples/*/; do
        echo "Building (examples) $example."

        build_example $example
    done
    success="1"
    ;;

examples-pt1)
    echo "Verifying that all AsyncDisplayKit examples compile."
    for example in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | head -6); do
        echo "Building (examples-pt1) $example"

        build_example $example
    done
    success="1"
    ;;

examples-pt2)
    echo "Verifying that all AsyncDisplayKit examples compile."
    for example in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | head -11 | tail -5); do
        echo "Building (examples-pt2) $example"

        build_example $example
    done
    success="1"
    ;;

examples-pt3)
    echo "Verifying that all AsyncDisplayKit examples compile."
    for example in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | head -16 | tail -5); do
        echo "Building (examples-pt3) $example"

        build_example $example
    done
    success="1"
    ;;

examples-pt4)
    echo "Verifying that all AsyncDisplayKit examples compile."
    for example in $((find ./examples -type d -maxdepth 1 \( ! -iname ".*" \)) | tail -n +17); do
        echo "Building (examples-pt4) $example"

        build_example $example
    done
    success="1"
    ;;

examples-extras)
    echo "Verifying that all AsyncDisplayKit examples extras compile."
    for example in $(find ./examples_extra -type d -maxdepth 1 \( ! -iname ".*" \)); do
        echo "Building (examples-extra) $example"

        build_example $example
    done
    success="1"
    ;;

examples-extra-pt1)
    echo "Verifying that all AsyncDisplayKit examples compile."
    for example in $((find ./examples_extra -type d -maxdepth 1 \( ! -iname ".*" \)) | head -6); do
        echo "Building (examples-extra-pt1) $example"

        build_example $example
    done
    success="1"
    ;;

examples-extra-pt2)
    echo "Verifying that all AsyncDisplayKit examples compile."
    for example in $((find ./examples_extra -type d -maxdepth 1 \( ! -iname ".*" \)) | head -11 | tail -5); do
        echo "Building (examples-extra-pt2) $example"

        build_example $example
    done
    success="1"
    ;;

examples-extra-pt3)
    echo "Verifying that all AsyncDisplayKit examples compile."
    for example in $((find ./examples_extra -type d -maxdepth 1 \( ! -iname ".*" \)) | tail -n +12); do
        echo "Building (examples-extra-pt3) $example"

        build_example $example
    done
    success="1"
    ;;

example)
    # Support building a specific example: sh build.sh example examples/ASDKLayoutTransition
    echo "Verifying $2 compiles."
    build_example $2
    success="1"
    ;;

life-without-cocoapods|all)
    echo "Verifying that AsyncDisplayKit functions as a static library."

    set -o pipefail && xcodebuild \
        -workspace "smoke-tests/Life Without CocoaPods/Life Without CocoaPods.xcworkspace" \
        -scheme "Life Without CocoaPods" \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        build
    success="1"
    ;;

framework|all)
    echo "Verifying that AsyncDisplayKit functions as a dynamic framework (for Swift/Carthage users)."

    set -o pipefail && xcodebuild \
        -project "smoke-tests/Framework/Sample.xcodeproj" \
        -scheme Sample \
        -sdk "$SDK" \
        -destination "$PLATFORM" \
        build
    success="1"
    ;;

cocoapods-lint|all)
    echo "Verifying that podspec lints."

    set -o pipefail && pod env && pod lib lint --allow-warnings
    success="1"
    ;;

cocoapods-lint-default-subspecs)
    echo "Verifying that default subspecs lint."

    for subspec in 'Core' 'PINRemoteImage' 'Video' 'MapKit' 'AssetsLibrary' 'Photos'; do
        echo "Verifying that $subspec subspec lints."

        lint_subspec $subspec
    done
    success="1"
    ;;

cocoapods-lint-other-subspecs)
    echo "Verifying that other subspecs lint."

    for subspec in 'IGListKit' 'Yoga' 'TextNode2'; do
        echo "Verifying that $subspec subspec lints."

        lint_subspec $subspec
    done
    success="1"
    ;;

carthage|all)
    echo "Verifying carthage works."
    ## carthage workaround to slip spm based project
    spm_example_project="examples/ASIGListKitSPM/Sample.xcodeproj"
    carthge_example_project_workaround="examples/ASIGListKitSPM/Sample.carthageSkip"

    # apply workaround
    mv $spm_example_project $carthge_example_project_workaround

    # carthage job
    set -o pipefail && carthage update && carthage build --no-skip-current

    #revert back workaround
    mv $carthge_example_project_workaround $spm_example_project

    success="1"
    ;;

*)
    echo "Unrecognized mode '$MODE'."
    ;;
esac

if [ "$success" = "1" ]; then
  trap - EXIT
  exit 0
fi
