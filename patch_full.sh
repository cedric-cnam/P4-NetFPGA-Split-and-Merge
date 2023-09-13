#!/bin/bash

mkdir -p "${P4_PROJECT_DIR}/src"
cp -r "Full/p4_src"/* "${P4_PROJECT_DIR}/src"

mkdir -p "${P4_PROJECT_DIR}/testdata"
cp -r "Full/testdata"/* "${P4_PROJECT_DIR}/testdata"

mkdir -p "${SUME_SDNET}/bin"
cp -r "Full/bin"/* "${SUME_SDNET}/bin"

mkdir -p "${SUME_SDNET}/templates/externs"
cp -r "Full/extern"/* "${SUME_SDNET}/templates/externs"
