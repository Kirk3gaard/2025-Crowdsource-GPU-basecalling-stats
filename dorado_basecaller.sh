#!/usr/bin/env bash
# This BASH script is based on the template from https://github.com/kasperskytte/bash_template
# License is MIT, which means the author takes no responsibilities, but you can use it for anything you want

set -euo pipefail

VERSION="1.0"
DORADO_VERSION=${DORADO_VERSION:-"0.9.5"}
DORADO_MODEL=${DORADO_MODEL:-"sup"}
DORADO_DEVICE=${DORADO_DEVICE:-"cuda:0"}
DATASET_URL="https://zenodo.org/records/15180194/files/basecalling_benchmarks_5khz_pod5s.tar.gz?download=1"

printHelp() {
  echo "Script to benchmark the basecalling speed of your GPU using dorado. Everything will be run from the current folder. Please publish the results to the community as described here https://github.com/Kirk3gaard/2025-Crowdsource-GPU-basecalling-stats."
  echo "Version: $VERSION"
  echo "Options:"
  echo "  -h    Display this help text and exit."
  echo "  -v    Print version and exit."
  echo
  echo "Additional options can be set by exporting environment variables before running the script:"
  echo "  - DORADO_VERSION: dorado version to download and use. (Default: ${DORADO_VERSION})"
  echo "  - DORADO_MODEL: dorado version to download and use. (Default: ${DORADO_MODEL})"
  echo "  - DORADO_DEVICE: dorado version to download and use. (Default: ${DORADO_DEVICE})"
}

#function to print default error message if bad usage
usageError() {
  echo "Invalid usage: $1" 1>&2
  echo ""
  printHelp
  exit 1
}

#function to add timestamps to progress messages
scriptMessage() {
  #check user arguments
  if [ ! $# -eq 1 ]
  then
    echo "Error: function must be passed exactly 1 argument" >&2
    exit 1
  fi
  echo " *** [$(date '+%Y-%m-%d %H:%M:%S')] $(basename "$0"): $1"
}

#function to check if executable(s) are available in $PATH
#example usage: checkCommand minimap2 parallel somethirdprogram
checkCommand() {
  argsA=( "$@" )
  local exit=false
  for arg in "${argsA[@]}"
  do
    if ! which "$arg" &> /dev/null
    then
      echo "${arg}: command not found"
      exit=true
    fi
  done

  if $exit
  then
    echo
    echo "Please make sure the above command(s) are installed, \
executable, and available somewhere in the \$PATH variable."
    exit 1
  fi
}

#check for all required commands before doing anything else:
checkCommand wget tar #nvidia-smi

#fetch and check options provided by user and save as variables for use 
#throughout the script
while getopts ":hv" opt; do
case ${opt} in
  h )
    printHelp
    exit 1
    ;;
  v )
    echo "Version: $VERSION"
    exit 0
    ;;
  \? )
    usageError "Invalid Option: -$OPTARG"
    exit 1
    ;;
  : )
    usageError "Option -$OPTARG requires an argument"
    exit 1
    ;;
esac
done
shift $((OPTIND -1)) #reset option pointer

# let's not do anything if no GPUs are available
scriptMessage "Available GPUs:"
nvidia-smi -L

scriptMessage "Downloading dorado version ${DORADO_VERSION}"
dorado_dir="dorado-$DORADO_VERSION-linux-x64"
dorado_filename="${dorado_dir}.tar.gz"
if [ ! -d "$dorado_dir" ]
then
  rm -f "$dorado_filename"
  wget "https://cdn.oxfordnanoportal.com/software/analysis/${dorado_filename}"
  tar zxf "$dorado_filename"
  rm "$dorado_filename"
  pushd "$dorado_dir" 1> /dev/null
  mkdir -p models
  pushd models 1> /dev/null
  scriptMessage "Downloading models for dorado"
  ../bin/dorado download
  popd
  popd
else
  scriptMessage "${dorado_dir} folder already exists, assuming dorado is already installed"
fi

scriptMessage "Downloading benchmarking dataset"
data_dir="data"
data_filename="benchmarking_dataset.tar.gz"
if [ ! -d "$data_dir" ]
then
  mkdir -p "$data_dir"
  pushd "$data_dir" 1> /dev/null
  wget "$DATASET_URL" -O "$data_filename"
  tar zxf "$data_filename"
  popd
else
  scriptMessage "${data_dir} folder already exists, assuming it's already downloaded"
fi

scriptMessage "Running dorado"
./${dorado_dir}/bin/dorado basecaller -r "$DORADO_MODEL" "$data_dir" --device "$DORADO_DEVICE" > /dev/null
