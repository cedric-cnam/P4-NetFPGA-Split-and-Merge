#
# Copyright (c) 2022 Mario Patetta, Conservatoire National des Arts et Metiers
# All rights reserved.
#
# SBI_engine is free software: you can redistribute it and/or modify it under the terms of
# the GNU Affero General Public License as published by the Free Software Foundation, either 
# version 3 of the License, or any later version.
#
# SBI_engine is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
#

from scapy.all import *
import sys, os

SOUTHBOUND_TYPE = 0x1212

# Type ID
ROUTING_TYPE = 0x01
METRIC_TYPE  = 0x02
TCP_PORT_TYPE = 0x03
ALIVE_SWITCH = 0x50

# Port ID
NONE = 0
NF0  = 1
NF1  = 2
NF2  = 4
NF3  = 8

# Metric ID
SRC_IP_CARD     = 0
DST_IP_CARD     = 1
SRC_PORTS_CARD  = 2
COUNTERS        = 3


class Southbound(Packet):
    name = "Southbound"
    fields_desc = [
		BitField("ControllerID",0,16),
		BitField("SwitchID",0,16),
		ByteEnumField("SBtype", 0x50, {ROUTING_TYPE:"ROUTING_TYPE", METRIC_TYPE:"METRIC_TYPE", TCP_PORT_TYPE:"TCP_PORT_TYPE", ALIVE_SWITCH:"ALIVE_SWITCH"}),
		BitField("ACK",0,1),
		BitField("length",0,7),
    ]
    def mysummary(self):
        return self.sprintf("ControllerID=%ControllerID% SwitchID=%SwitchID% type=%type% ACK=%ACK% unused=%unused%")

bind_layers(Ether, Southbound, type=SOUTHBOUND_TYPE)


class SouthboundRouting(Packet):
    name = "SouthboundRouting"
    fields_desc = [
		IPField("key", "127.0.0.1"),
		BitField("mask",0,32),
		BitEnumField("port", 0, 4, {NONE:"NONE", NF0:"NF0", NF1:"NF1", NF2:"NF2", NF3:"NF3"}),
		BitField("address",0,8),
		BitField("check",0,1),                                        	    # If check = 1 -> port and address should be set to 0
		BitField("unused", 0,3),
    ]
    def mysummary(self):
        return self.sprintf("key=%key% mask=%mask% port=%port% address=%address% check=%check% unused=%unused%")

bind_layers(Southbound, SouthboundRouting, SBtype=ROUTING_TYPE, length=16)


class SouthboundMetric(Packet):
    name = "SouthboundMetric"                                       	    # Target dependant
    fields_desc = [
        BitField("reset",0,1),
        BitEnumField("metricID", 0, 7, {SRC_IP_CARD:"SRC_IP_CARD", DST_IP_CARD:"DST_IP_CARD", SRC_PORTS_CARD:"SRC_PORTS_CARD", COUNTERS:"COUNTERS"}),
        BitField("result1",0,24),
        BitField("result2",0,24),
        BitField("result3",0,24),
        BitField("result4",0,40),
    ]
    def mysummary(self):
        return self.sprintf("reset=%reset% metricID=%metricID% result1=%result1% result2=%result2% result3=%result3% result4=%result4%")

bind_layers(Southbound, SouthboundMetric, SBtype=METRIC_TYPE, length=19)

class SouthboundTCPPort(Packet):
    name = "SouthboundTCPPort"
    fields_desc = [
        BitField("port",0,16),
    ]
    def mysummary(self):
        return self.sprintf("port=%port%")

bind_layers(Southbound, SouthboundTCPPort, SBtype=TCP_PORT_TYPE, length=8)

