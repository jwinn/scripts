#!/bin/sh
echo "updating..."
brew update
echo "upgrading..."
brew upgrade
echo "cleaning up..."
brew cleanup -s > /dev/null 2>&1
cache_dir=$(brew --cache)
echo "removing cache [${cache_dir}]"
[ -d ${cache_dir} ] && rm -rf ${cache_dir}
exit 0
