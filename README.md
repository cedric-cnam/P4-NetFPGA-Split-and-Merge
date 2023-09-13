# P4-NetFPGA-Split-and-Merge

Hardware implementation of Split-and-Merge metrics computation on the NetFPGA

## How to build the NetFPGA-Split-and-Merge design

1. Install the P4->NetFPGA development environment following the information available at https://github.com/NetFPGA/P4-NetFPGA-public/wiki/Getting-Started
2. Create the p4 projects related to the simple and full implementation of the NetFPGA-Split-and-Merge design.
```
$ $SUME_SDNET/bin/make_new_p4_proj.py split_and_merge_simple
$ $SUME_SDNET/bin/make_new_p4_proj.py split_and_merge_full
```
3. Modify `$SUME_FOLDER/tools/settings.sh` to ensure that the `P4_PROJECT_NAME` environment variable is set to either split_and_merge_simple or split_and_merge_full, depending on which version you want to build. Run `$ source settings.sh`.
4. Clone this repo and move to the main folder.
6. Run either `bash patch_simple.sh` or `bash patch_full.sh` to copy the source files of the respective design in the proper directories of the original repo.<br>
   **Note:** The patch must be applied everytime to switch between the simple and full versions, as some external modules must be updated accordingly.
7. Run `bash run.sh` to run the P4->NetFPGA workflow, generating the bitstream in `$NF_DESIGN_DIR/bitfiles`.
8. Control plane primitives to send control plane messages, process received ones and replay traffic traces are available for the Simple version in `${P4_PROJECT_DIR}/sw/hw_test`
