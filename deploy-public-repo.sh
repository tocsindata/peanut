#!/bin/bash

# IMPORTANT DO NOT RUN THIS IN THE ROOT HOME, BUT IN THE HOME OF THE NEW DOMAIN USER
# This script clones a public GitHub repository, moves its contents to a specified directory,
# and sets the ownership to a specified user and group.

# chmod +x deploy-public-repo.sh
# Usage: ./deploy-public-repo.sh

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Variables
REPO_URL="https://github.com/mudmin/foobar.git"  # Replace with your public repo URL
TARGET_DIR="/home/foobar"  # The directory where the repo will be cloned
USER_GROUP="foobar"  # The user and group to set ownership to

# Clone the public repo (no token needed)
git clone ${REPO_URL} ${TARGET_DIR}/$(basename ${REPO_URL%.git})

# Change directory to the cloned repo
cd ${TARGET_DIR}/$(basename ${REPO_URL%.git}) || exit

# Move contents to target directory, overwriting existing files
rsync -av --remove-source-files ./ ${TARGET_DIR}/

# Remove the now-empty directory
rm -rf ${TARGET_DIR}/$(basename ${REPO_URL%.git})

# Change ownership to the specified user and group
chown -R ${USER_GROUP}:${USER_GROUP} ${TARGET_DIR}/*

echo "Process complete."
