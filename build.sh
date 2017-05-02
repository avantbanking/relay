# Based on https://gist.github.com/domenic/ec8b0fc8ab45f39403dd

#!/bin/bash
set -e # Exit with nonzero exit code if anything fails

echo "--------------------------------"
echo "Travis environmental variables:"
printenv
echo "--------------------------------"

# Get the deploy key by using Travis's stored variables to decrypt deploy_key.enc
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in deploy_key.enc -out deploy_key -d
chmod 600 deploy_key
eval `ssh-agent -s`
ssh-add deploy_key

function doCompile {
  sh compile.sh
}

doCompile

if [[ "${TRAVIS_TAG}" ]]; then
	bash generate-docs.sh
    exit 0
fi

