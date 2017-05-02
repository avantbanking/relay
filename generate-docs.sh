# Generate the docs
jazzy -o jazzy-docs/

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Clone the existing gh-pages for this repo into docs/
# Create a new empty branch if gh-pages doesn't exist yet (should only happen on first deply)
git clone $REPO docs
cd docs
git checkout $TARGET_BRANCH || git checkout --orphan gh-pages
cd ..

# Clean out existing contents if any
mkdir -p docs
rm -rf docs/**

echo ls
# And move the documentation over
mv jazzy-docs/* docs/

cd docs
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"


# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
git add .
git commit -m "Deploy to GitHub Pages: ${SHA}"


# Now that we're all set up, we can push.
git push -q -f $SSH_REPO HEAD:gh-pages