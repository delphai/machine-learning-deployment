#!/usr/bin/env bash

set -e

az account set --subscription common

az storage blob download-batch -d . -s page-classifier-binary --account-name tfdelphaicommon --connection-string DefaultEndpointsProtocol=https;AccountName=tfdelphaicommon;AccountKey=Yu+/+1StxWeY7ijwYQ8hXnOky6mD+R3Gy7XQVezNmlbqTJpYx4TA3GvhHA1fQ435OIkMN+wo31/7YFzJLGgjIA==;EndpointSuffix=core.windows.net
