#!/bin/bash

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DOWNLOAD_FOLDER="$THIS_SCRIPT_DIR/.downloads"

METRICBEAT_VERSION="7.8.1"
BLOB_FILENAME="metricbeat-$METRICBEAT_VERSION.tar.gz"
METRICBEAT_DOWNLOAD_URL="https://artifacts.elastic.co/downloads/beats/metricbeat/metricbeat-$METRICBEAT_VERSION-linux-x86_64.tar.gz"

function blob_exists {
    local blob_path=$1

    [[ -f "$blob_path" ]] || return 1
}

if ! blob_exists "$DOWNLOAD_FOLDER/$BLOB_FILENAME"; then
    mkdir -p "$DOWNLOAD_FOLDER"
    curl -L -J -o "$DOWNLOAD_FOLDER/$BLOB_FILENAME" "$METRICBEAT_DOWNLOAD_URL"
    bosh add-blob --dir="$THIS_SCRIPT_DIR" "$DOWNLOAD_FOLDER/$BLOB_FILENAME" "metricbeat/$BLOB_FILENAME"
fi