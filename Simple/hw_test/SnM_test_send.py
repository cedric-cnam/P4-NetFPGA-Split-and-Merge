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


import os, sys, re, cmd, subprocess, shlex, time, csv, pandas, numpy, socket, struct, ipaddress
from threading import Thread
from collections import Counter

sys.path.append(os.path.expandvars('../../testdata/'))
from southbound_headers import *
from nf_sim_tools import *

IFACE = "eth1"

# MACS
SERVER_MAC = "11:11:11:11:11:11"
MAC3 = "33:33:33:33:33:33"

# SBI IDs
CONTROLLER_ID	= 1
SWITCH_ID	= 1

METRIC_MAP = {'SRC_IP_CARD':SRC_IP_CARD, 'DST_IP_CARD':DST_IP_CARD, 'SRC_PORTS_CARD':SRC_PORTS_CARD, 'COUNTERS':COUNTERS}
new_row = [0,0,0,0,0,0,0,0,0]

tcp_replay_fmat_string = "sudo tcpdump -nn -t -r {path_to_pcaps}/{pcap_name}.pcap -w-  '{subnet} and tcp dst port {port}' | tcpreplay -t -i {iface} -"

DATES = ['0331', '0407', '0414', '0421', '0428', '0505', '0512', '0519', '0526', '0602', '0609', '0616', '0622',
         '0630', '0707', '0714', '0721', '0728', '0804', '0811', '0818', '0825', '0901', '0908', '0915' ,'0922',
         '0929', '1006', '1013', '1020', '1027', '1103', '1110', '1117', '1124', '1201', '1208', '1215', '1222',
         '1229']

         
SUBNET_MAP = {'subnetA':1, 'subnetB':2, 'subnetC':3, 'subnetD':4, 'subnetE':5, 'subnetF':6,'subnetG':7, 'subnetH':8, 'subnetI':9}

ports_done = []


def f7(seq):
    seen = set()
    seen_add = seen.add
    return [x for x in seq if not (x in seen or seen_add(x))]

def makeMask(subnet):
    # Return ntw and mask given the subnet
    n = ipaddress.ip_network(subnet, False)
    netw = int(n.network_address)
    mask = int(n.netmask)
    return (netw,mask)

def fixSubnet(sub):
    (netw,mask) = makeMask(sub)
    netw = netw & mask
    netw_str = socket.inet_ntoa(struct.pack('!L', netw))
    mask_str = str(list(bin(mask))[2:].count('1'))
    return (netw_str + '/' + mask_str)

def send_new_port_sequence(tcp_port):
    pkt = Ether(dst=MAC3, src=SERVER_MAC) / Southbound(ControllerID=CONTROLLER_ID , SwitchID=SWITCH_ID) / SouthboundTCPPort(port=tcp_port)
    sendp(pkt, iface=IFACE)

def metric_reset_all():
    pkt = Ether(dst=MAC3, src=SERVER_MAC) / Southbound(ControllerID=CONTROLLER_ID , SwitchID=SWITCH_ID) / SouthboundMetric(metricID=SRC_IP_CARD, reset=1)
    sendp(pkt, iface=IFACE)
    pkt = Ether(dst=MAC3, src=SERVER_MAC) / Southbound(ControllerID=CONTROLLER_ID , SwitchID=SWITCH_ID) / SouthboundMetric(metricID=DST_IP_CARD, reset=1)
    sendp(pkt, iface=IFACE)
    pkt = Ether(dst=MAC3, src=SERVER_MAC) / Southbound(ControllerID=CONTROLLER_ID , SwitchID=SWITCH_ID) / SouthboundMetric(metricID=SRC_PORTS_CARD, reset=1)
    sendp(pkt, iface=IFACE)
    pkt = Ether(dst=MAC3, src=SERVER_MAC) / Southbound(ControllerID=CONTROLLER_ID , SwitchID=SWITCH_ID) / SouthboundMetric(metricID=COUNTERS, reset=1)
    sendp(pkt, iface=IFACE)

def metric_query_all():
    pkt = Ether(dst=MAC3, src=SERVER_MAC) / Southbound(ControllerID=CONTROLLER_ID , SwitchID=SWITCH_ID) / SouthboundMetric(metricID=SRC_IP_CARD)
    sendp(pkt, iface=IFACE)
    pkt = Ether(dst=MAC3, src=SERVER_MAC) / Southbound(ControllerID=CONTROLLER_ID , SwitchID=SWITCH_ID) / SouthboundMetric(metricID=DST_IP_CARD)
    sendp(pkt, iface=IFACE)
    pkt = Ether(dst=MAC3, src=SERVER_MAC) / Southbound(ControllerID=CONTROLLER_ID , SwitchID=SWITCH_ID) / SouthboundMetric(metricID=SRC_PORTS_CARD)
    sendp(pkt, iface=IFACE)
    pkt = Ether(dst=MAC3, src=SERVER_MAC) / Southbound(ControllerID=CONTROLLER_ID , SwitchID=SWITCH_ID) / SouthboundMetric(metricID=COUNTERS)
    sendp(pkt, iface=IFACE)

# Get port list data frame
usedPorts_df = pandas.read_csv('port_list.csv',dtype={'port_list':int,'date':str})
# Extract port list and filter for those that are used at least three days
port_list = usedPorts_df['port_list'].tolist()
port_list = [k for k,v in (Counter(port_list)).items() if v>2]
port_list_tmp = list(set(port_list))
# Remove the ports already analysed
port_list = [x for x in port_list_tmp if (x not in ports_done)]
# Create a list of days for each port
date_lists = [[] for i in range(len(port_list))]
for i in range(len(port_list)):
    dates = usedPorts_df[usedPorts_df['port_list']==port_list[i]]['date'].tolist()
    dates_tmp = []
    for day in DATES:
        if day in dates:
            try:
                dates_tmp.extend(DATES[DATES.index(day):DATES.index(day)+11])
                dates_tmp = f7(dates_tmp)
            except:
                None
    dates = f7(dates_tmp)
    date_lists[i] = dates

loop_cnt = 0
with open("subnets/subnets_2016.csv",'r') as f:
    df = pandas.read_csv(f)
    for k in range(len(port_list)):                                     # Loop over the ports
        tcp_port = port_list[k]
        results_name = 'results_all/results_' + str(tcp_port) + '.csv'
        # Set tcp port to analyse
        send_new_port_sequence(tcp_port) 
        for i in range(len(DATES)):                                     # Loop over the days
            date = DATES[i]
            print(date)
            if (date in date_lists[k]):
                send_traffic = True
            else:
                send_traffic = False
                print('No traffic')
            pcap_name = str(20160000 + int(date)) + "1400"
            for j in range(1,10):                                       # Loop over the subnets
                cel = df[df['date']==int(date)].iloc[0,j]
                print("tcp port : ", tcp_port)
                print("pcap name : ", pcap_name)
                print("subnet :", cel)
                # If the subnet is valid, submit the trace
                if ( cel == cel ):
                    cel = cel.split("|")
                    if ( len(cel) == 1 ):
                        cel[0] = fixSubnet(cel[0])
                        subnet = "net " + str(cel[0])
                    elif ( len(cel) == 2 ):
                        cel[0] = fixSubnet(cel[0])
                        cel[1] = fixSubnet(cel[1])
                        subnet = "net " + str(cel[0]) + " or net " + str(cel[1])
                    # Reset, submit traffic and query
                    metric_reset_all()
                    if (send_traffic):
                        os.system(tcp_replay_fmat_string.format( pcap_name=str(pcap_name), subnet=subnet, port=tcp_port, iface=IFACE ))
                    metric_query_all()
                # Otherwise just query all to trigger the receive program
                else:
                    metric_query_all()
    loop_cnt += 1
    if (loop_cnt%3==0):
        time.sleep(5*60)








