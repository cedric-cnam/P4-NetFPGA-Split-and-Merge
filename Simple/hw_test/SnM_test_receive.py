#!/usr/bin/env python

#
# Copyright (c) 2022 Mario Patetta, Conservatoire National des Arts et Metiers
# Copyright (c) 2017 Stephen Ibanez
# All rights reserved.
#
# This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
# as part of the DARPA MRC research programme.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#


import os, sys, re, cmd, subprocess, shlex, csv
import numpy as np
from threading import Thread

sys.path.append(os.path.expandvars('../../testdata/'))
from southbound_headers import *
from nf_sim_tools import *

IFACE = "eth1"
metric_map = {0:"SRC_IP_CARD", 1:"DST_IP_CARD", 2:"SRC_PORTS_CARD", 3:"COUNTERS",}

DATES = ['0331', '0407', '0414', '0421', '0428', '0505', '0512', '0519', '0526', '0602', '0609', '0616', '0622',
         '0630', '0707', '0714', '0721', '0728', '0804', '0811', '0818', '0825', '0901', '0908', '0915' ,'0922',
         '0929', '1006', '1013', '1020', '1027', '1103', '1110', '1117', '1124', '1201', '1208', '1215', '1222',
         '1229']
         
SUBNETS = ['subnetA', 'subnetB', 'subnetC', 'subnetD', 'subnetE', 'subnetF','subnetG', 'subnetH', 'subnetI']

os.system('sudo ifconfig {0} 10.0.0.11 netmask 255.255.255.0'.format(IFACE))

# HyperLogLog parameters
SCALING = 15
m  = 2**8
am = 0.7213/(1+ (1.079/m))
K = am*(m**2)
down_scale = ( 2**(-(SCALING-1)) )


# Global Variables
new_row = [np.nan,np.nan,0,0,0,0,0,0,0]
results_name = ''
day_cnt = 0
subnet_cnt = 0


def setup_new_results_file(port):
    global results_name, day_cnt, subnet_cnt
    results_name = 'results/results_' + str(port) + '.csv'
    day_cnt = 0
    subnet_cnt = 0
    print("new port to analyse: ", port)
    with open(results_name, 'w') as f1:
        header = ['Date','Subnet','Src IP Card', 'Dst IP Card', 'Src Port Card', 'SYN Count', 'Pkt Count', 'Mean Size', 'Size Std Dev']
        writer = csv.writer(f1)
        writer.writerow(header)
        f1.close()

def HyperLogLogResult(result_norm,empty_buckets):
    result = K / ( result_norm * down_scale )
    if (result_norm == 4194304 and empty_buckets == 0):
        # Correct the cardinality = 0 case
        result = 0
        empty_buckets = 256
    elif (result < 2.5*m and empty_buckets != 0):
        # Linear counting for low cardinalities
        result = m*math.log(float(m)/empty_buckets)
    return result

def receive_metric(pkt):
    global new_row, day_cnt, subnet_cnt
    if (pkt[SouthboundMetric].metricID == SRC_IP_CARD):
        # Post-process metrics
        result_norm = pkt[SouthboundMetric].result1
        empty_buckets = pkt[SouthboundMetric].result2
        result = HyperLogLogResult(result_norm,empty_buckets)
        # Update new_row
        new_row[2] = result
    elif (pkt[SouthboundMetric].metricID == DST_IP_CARD):
        # Post-process metrics
        result_norm = pkt[SouthboundMetric].result1
        empty_buckets = pkt[SouthboundMetric].result2
        result = HyperLogLogResult(result_norm,empty_buckets)
        # Update new_row
        new_row[3] = result
    elif (pkt[SouthboundMetric].metricID == SRC_PORTS_CARD):
        # Post-process metrics
        result_norm = pkt[SouthboundMetric].result1
        empty_buckets = pkt[SouthboundMetric].result2
        result = HyperLogLogResult(result_norm,empty_buckets)
        # Update new_row
        new_row[4] = result
    elif (pkt[SouthboundMetric].metricID == COUNTERS):
        # Post-process metrics
        synCount = pkt[SouthboundMetric].result1
        pktCount = pkt[SouthboundMetric].result2
        mean = pkt[SouthboundMetric].result3
        m2 = pkt[SouthboundMetric].result4
        if (pktCount > 1) :
            std = (m2 / (pktCount-1))**(0.5)
            # Update new_row
            new_row[5],new_row[6],new_row[7],new_row[8] = (synCount,pktCount,mean,std)
        else:
            # Set new_row to 0
            new_row[2],new_row[3],new_row[4],new_row[5],new_row[6],new_row[7],new_row[8] = (0,0,0,0,0,0,0)
        # Update day and subnet
        new_row[0] = DATES[day_cnt]
        new_row[1] = SUBNETS[subnet_cnt]
        subnet_cnt += 1
        if (subnet_cnt == 9):
            day_cnt += 1
            subnet_cnt = 0
        # Write new_row to file
        with open(results_name, 'a') as f1:
            writer = csv.writer(f1)
            writer.writerow(new_row)
            f1.close()


def parse_SB(pkt):
    if ( (Southbound in pkt) and (pkt[Southbound].ACK == 1) ):
        if ( (SouthboundMetric in pkt) and pkt[SouthboundMetric].reset == 0 ):
            receive_metric(pkt)
        elif ( SouthboundTCPPort in pkt ):
            setup_new_results_file(pkt[SouthboundTCPPort].port)
    else:
        return             


def main():
    sniff(iface=IFACE, prn=parse_SB, count=0, store=0)

if __name__ == "__main__":
    main()

