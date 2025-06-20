#!/bin/bash

# IMPORTANT DO NOT RUN THIS IN THE ROOT HOME, BUT IN THE HOME OF THE NEW DOMAIN USER
# This script clones a GitHub repository, moves its contents to a specified directory,
# and sets the ownership to a specified user and group.

# git clone https://github_pat_pkXKw6QX96gbKsJGwG328Yd36DEFGvJC@github.com/tocsindata/snoopy.example.com.git

# chmod +x deploy-private-repo.sh
# Usage: ./deploy-private-repo.sh
set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Variables
GITHUB_USER="tocsindata"  # Replace with your GitHub username
TOKEN="github_pat_pkXKw6QX96gbKsJGwG328Yd36DEFGvJC" # Replace with your GitHub token
REPO_NAME="snoopy.example.com" # example: UserSpice5
TARGET_DIR="/home/snoopy"  # The directory where the repo will be cloned
USER_GROUP="snoopy"  # The user and group to set ownership to

# Clone the repo using the token
git clone https://${GITHUB_USER}:${TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git ${TARGET_DIR}/${REPO_NAME}

# Change directory to the cloned repo
cd ${TARGET_DIR}/${REPO_NAME} || exit

# Move contents to target directory, overwriting existing files
rsync -av --remove-source-files ./ ${TARGET_DIR}/

# Remove the now-empty directory
rm -rf ${TARGET_DIR}/${REPO_NAME}

# Change ownership to the specified user and group
chown -R ${USER_GROUP}:${USER_GROUP} ${TARGET_DIR}/*

echo "Process complete."
