#!/bin/bash

cd $SUME_FOLDER

if [[ -z "${P4_PROJECT_NAME}"  ]]; then
	source tools/settings.sh
fi

# Build Vivado core IP modules
cd $SUME_FOLDER/lib/hw/xilinx/cores/tcam_v1_1_0/ && make update && make
cd $SUME_FOLDER/lib/hw/xilinx/cores/cam_v1_1_0/ && make update && make
cd $SUME_SDNET/sw/sume && make
cd $SUME_FOLDER && make

# Generate verilog code and API/CLI tools
make -C $P4_PROJECT_DIR

#Run SDNet simulation
cd $P4_PROJECT_DIR/nf_sume_sdnet_ip/SimpleSumeSwitch
./forward_create_dat_file_for_sim.bash
./vivado_sim.bash
#./vivado_sim_waveform.bash

# Generate the scripts for NetFPGA SUME simulation
cd $P4_PROJECT_DIR
make config_writes

#Wrap SDNet output and install SUME library core
cd $P4_PROJECT_DIR
make uninstall_sdnet
make install_sdnet

#Setup SUME simulation
cd $NF_DESIGN_DIR/test/sim_switch_default
make

#cd $SUME_FOLDER
#./tools/scripts/nf_test.py sim --major switch --minor default
#./tools/scripts/nf_test.py sim --major switch --minor default --gui
#./tools/scripts/nf_test.py sim --major switch --minor checkRegs

#Compile bitstream
cd $NF_DESIGN_DIR
make

cd $NF_DESIGN_DIR/bitfiles
mv simple_sume_switch.bit ${P4_PROJECT_NAME}.bit
