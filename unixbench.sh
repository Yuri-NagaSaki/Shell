#!/bin/bash

AUTHOR="catcat"
BLOG_URL="https://catcat.blog"

echo "UnixBench Installer Script"
echo "Author: $AUTHOR"
echo "Blog: $BLOG_URL"
echo ""

PACKAGE_MANAGER=""

if command -v apt-get >/dev/null 2>&1; then
    PACKAGE_MANAGER="apt-get"
elif command -v yum >/dev/null 2>&1; then
    PACKAGE_MANAGER="yum"
elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
else
    echo "No package manager found. Please install 'make', 'gcc', and 'git' manually."
    exit 1
fi

sudo $PACKAGE_MANAGER install -y make gcc git

git clone https://github.com/kdlucas/byte-unixbench.git

cd byte-unixbench/UnixBench || { echo "Failed to enter UnixBench directory."; exit 1; }

make

sudo chmod u+x ./Run
sudo chmod u+x -R ./*

sudo ./Run
