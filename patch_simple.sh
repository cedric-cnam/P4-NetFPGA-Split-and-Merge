#!/bin/bash

mkdir -p "${P4_PROJECT_DIR}/src"
cp -r "Simple/p4_src"/* "${P4_PROJECT_DIR}/src"

mkdir -p "${P4_PROJECT_DIR}/testdata"
cp -r "Simple/testdata"/* "${P4_PROJECT_DIR}/testdata"

mkdir -p "${SUME_SDNET}/bin"
cp -r "Simple/bin"/* "${SUME_SDNET}/bin"

mkdir -p "${SUME_SDNET}/templates/externs"
cp -r "Simple/extern"/* "${SUME_SDNET}/templates/externs"

mkdir -p "${P4_PROJECT_DIR}/sw/hw_test"
cp -r "Simple/hw_test"/* "${P4_PROJECT_DIR}/sw/hw_test"
