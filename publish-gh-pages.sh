#!/bin/bash
set -e # Exit with nonzero exit code if anything fails

SOURCE_BRANCH="master"
TARGET_BRANCH="gh-pages"

#This function needs to do some stuff and store all the artifacts in the out directory
function doStuff {
  	#generate documentation
  	jazzy --clean --author Alberto Irurueta --github_url https://github.com/albertoirurueta/swift-protocols-and-generics-workshop --xcodebuild-arguments -project,./swiftProtocolsAndGenerics/swiftProtocolsAndGenerics.xcodeproj,-scheme,swiftProtocolsAndGenerics --module swiftProtocolsAndGenerics --output out/docs
  	#move result of xcpretty to out directory
  	mv build out
}

# Pull requests and commits to other branches shouldn't try to deploy, just build to verify
if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Skipping deploy; just doing a build."
    doStuff
    exit 0
fi

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Clone the existing gh-pages for this repo into out/
# Create a new empty branch if gh-pages doesn't exist yet (should only happen on first deply)
git clone $REPO out
cd out
git checkout $TARGET_BRANCH || git checkout --orphan $TARGET_BRANCH
cd ..

# Clean out existing contents
rm -rf out/**/* || exit 0

# Get the deploy key by using Travis's stored variables to decrypt github_key.enc
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in github_key.enc -out github_key -d
chmod 600 github_key
eval `ssh-agent -s`
ssh-add github_key


# Run our compile script
doStuff

# Now let's go have some fun with the cloned repo
cd out
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"

# If there are no changes to the compiled out (e.g. this is a README update) then just bail.
#(lines below are commented because it can fail with too many arguments
#if [ -z `git diff --exit-code` ]; then
#    echo "No changes to the output on this push; exiting."
#    exit 0
#fi

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
git add .
git commit -m "Deploy to GitHub Pages: ${SHA}"

# Now that we're all set up, we can push.
echo "Pushing to $SSH_REPO on branch $TARGET_BRANCH"
#git push $SSH_REPO $TARGET_BRANCH
git push https://jlmari:$GITHUB_OAUTH_TOKEN@github.com/jlmari/https://github.com/jlmari/swiftProtocolsAndGenericsJL.git $TARGET_BRANCH

