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

SOUTHBOUND_TYPE = 144

# Type ID
SBI_ROUTING_TYPE        = 0x00
DST_IP_ROUTING_TYPE     = 0x01
SRC_IP_ROUTING_TYPE     = 0x02
DST_PORT_ROUTING_TYPE   = 0x03
SRC_PORT_ROUTING_TYPE   = 0x04
METRIC_TYPE             = 0x05
SNM_PORT_TYPE           = 0x06
SET_ID_TYPE             = 0x07
ALIVE_SWITCH_TYPE       = 0x50

# Port ID
NONE = 0b0000
NF0  = 0b0001
NF1  = 0b0010
NF2  = 0b0100
NF3  = 0b1000

# Metric ID
SRC_IP_CARD     = 0
DST_IP_CARD     = 1
SRC_PORTS_CARD  = 2
COUNTERS        = 3


class Southbound(Packet):
    name = "Southbound"
    fields_desc = [
		BitField("ControllerID",0,8),
		BitField("SwitchID",0,8),
		ByteEnumField("SBtype", ALIVE_SWITCH_TYPE, {SBI_ROUTING_TYPE:"SBI_ROUTING_TYPE", DST_IP_ROUTING_TYPE:"DST_IP_ROUTING_TYPE", SRC_IP_ROUTING_TYPE:"SRC_IP_ROUTING_TYPE", DST_PORT_ROUTING_TYPE:"DST_PORT_ROUTING_TYPE", SRC_PORT_ROUTING_TYPE:"SRC_PORT_ROUTING_TYPE", METRIC_TYPE:"METRIC_TYPE", SNM_PORT_TYPE:"SNM_PORT_TYPE", SET_ID_TYPE:"SET_ID_TYPE"}),
		BitField("ACK",0,1),
		BitField("length",4,7),
    ]
    def mysummary(self):
        return self.sprintf("ControllerID=%ControllerID% SwitchID=%SwitchID% SBtype=%SBtype% ACK=%ACK% length=%length% unused=%unused%")

bind_layers(IP, Southbound, proto=SOUTHBOUND_TYPE)

class SouthboundSBIRouting(Packet):
    name = "SouthboundSBIRouting"
    fields_desc = [
		BitField("key_h", "0", 1),                                           # The key is composed by the SwitchID and the ACK
		BitField("key_l", "0", 8),
		BitField("port", 0, 4),
		BitField("address",0,4),
		BitField("check",0,1),
		BitField("check_match",0,1),
		BitField("reset",0,1),
		BitField("unused", 0,4),
    ]
    def mysummary(self):
        return self.sprintf("key_h=%key_h% key_l=%key_l% port=%port% address=%address% check=%check% check_match=%check_match% reset=%reset% unused=%unused%")

bind_layers(Southbound, SouthboundSBIRouting, SBtype=SBI_ROUTING_TYPE, length=4+3)

class SouthboundDstIPRouting(Packet):
    name = "SouthboundDstIPRouting"
    fields_desc = [
		IPField("key", "127.0.0.1"),
		BitField("mask",0,32),
		BitField("port", 0, 4),
		BitField("address",0,7),
		BitField("unused", 0,2),
		BitField("check",0,1),
		BitField("check_match",0,1),
		BitField("reset",0,1),
    ]
    def mysummary(self):
        return self.sprintf("key=%key% mask=%mask% port=%port% address=%address% check=%check% check_match=%check_match% reset=%reset% unused=%unused%")

bind_layers(Southbound, SouthboundDstIPRouting, SBtype=DST_IP_ROUTING_TYPE, length=4+10)


class SouthboundSrcIPRouting(Packet):
    name = "SouthboundSrcIPRouting"
    fields_desc = [
		IPField("key", "127.0.0.1"),
		BitField("mask",0,32),
		BitField("port", 0, 4),
		BitField("address",0,7),
		BitField("unused", 0,2),
		BitField("check",0,1),
		BitField("check_match",0,1),
		BitField("reset",0,1),
    ]
    def mysummary(self):
        return self.sprintf("key=%key% mask=%mask% port=%port% address=%address% check=%check% check_match=%check_match% reset=%reset% unused=%unused%")

bind_layers(Southbound, SouthboundSrcIPRouting, SBtype=SRC_IP_ROUTING_TYPE, length=4+10)

class SouthboundDstPortRouting(Packet):
    name = "SouthboundDstPortRouting"
    fields_desc = [
		BitField("key",0,16),
		BitField("port", 0, 4),
		BitField("address",0,4),
		BitField("check",0,1),
		BitField("check_match",0,1),
		BitField("reset",0,1),
		BitField("unused", 0,5),
    ]
    def mysummary(self):
        return self.sprintf("key=%key% port=%port% address=%address% check=%check% check_match=%check_match% reset=%reset% unused=%unused%")

bind_layers(Southbound, SouthboundDstPortRouting, SBtype=DST_PORT_ROUTING_TYPE, length=4+4)


class SouthboundSrcPortRouting(Packet):
    name = "SouthboundSrcPortRouting"
    fields_desc = [
		BitField("key",0,16),
		BitField("port", 0, 4),
		BitField("address",0,4),
		BitField("check",0,1),
		BitField("check_match",0,1),
		BitField("reset",0,1),
		BitField("unused", 0,5),
    ]
    def mysummary(self):
        return self.sprintf("key=%key% port=%port% address=%address% check=%check% check_match=%check_match% reset=%reset% unused=%unused%")

bind_layers(Southbound, SouthboundSrcPortRouting, SBtype=SRC_PORT_ROUTING_TYPE, length=4+4)

class SouthboundMetric(Packet):
    name = "SouthboundMetric"
    fields_desc = [
        BitField("reset",0,1),
        BitEnumField("metricID", 0, 7, {SRC_IP_CARD:"SRC_IP_CARD", DST_IP_CARD:"DST_IP_CARD", SRC_PORTS_CARD:"SRC_PORTS_CARD", COUNTERS:"COUNTERS"}),
        BitField("result1",0,20),
        BitField("result2",0,20),
        BitField("result3",0,20),
        BitField("result4",0,20),
    ]
    def mysummary(self):
        return self.sprintf(" snm_port=%snm_port% reset=%reset% metricID=%metricID% result1=%result1% result2=%result2% result3=%result3% result4=%result4%")

bind_layers(Southbound, SouthboundMetric, SBtype=METRIC_TYPE, length=4+12)

class SouthboundSetSnmPort(Packet):
    name = "SouthboundSetSnmPort"
    fields_desc = [
        BitField("port",0,16),
    ]
    def mysummary(self):
        return self.sprintf("port=%port%")

bind_layers(Southbound, SouthboundSetSnmPort, SBtype=SNM_PORT_TYPE, length=4+2)

class SouthboundSetID(Packet):
    name = "SouthboundSetID"
    fields_desc = [
        BitField("NewID",0,8),
    ]
    def mysummary(self):
        return self.sprintf("NewID=%NewID%")

bind_layers(Southbound, SouthboundSetID, SBtype=SET_ID_TYPE, length=4+1)









