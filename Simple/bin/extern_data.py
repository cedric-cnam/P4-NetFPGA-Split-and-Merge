#
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


extern_data = {
"reg_rw" : {"hdl_template_file": "externs/reg_rw/hdl/EXTERN_reg_rw_template.v",
            "cpp_template_file": "externs/reg_rw/cpp/EXTERN_reg_rw_template.hpp",
            "replacements": {"@EXTERN_NAME@" : "extern_name",
                             "@MODULE_NAME@" : "module_name",
                             "@PREFIX_NAME@" : "prefix_name",
                             "@ADDR_WIDTH@" : "addr_width",
#                             "@NUM_CYCLES@" : "max_cycles",
                             "@INDEX_WIDTH@" : "input_width(index)",
                             "@REG_WIDTH@" : "input_width(newVal)"}
},

"reg_raw" : {"hdl_template_file": "externs/reg_raw/hdl/EXTERN_reg_raw_template.v",
             "cpp_template_file": "externs/reg_raw/cpp/EXTERN_reg_raw_template.hpp",
             "replacements": {"@EXTERN_NAME@" : "extern_name",
                              "@MODULE_NAME@" : "module_name",
                              "@PREFIX_NAME@" : "prefix_name",
                              "@ADDR_WIDTH@" : "addr_width",
#                              "@NUM_CYCLES@" : "max_cycles",
                              "@INDEX_WIDTH@" : "input_width(index)",
                              "@REG_WIDTH@" : "input_width(newVal)"}
},

"reg_praw": {"hdl_template_file": "externs/reg_praw/hdl/EXTERN_reg_praw_template.v",
             "cpp_template_file": "externs/reg_praw/cpp/EXTERN_reg_praw_template.hpp",
             "replacements": {"@EXTERN_NAME@" : "extern_name",
                              "@MODULE_NAME@" : "module_name",
                              "@PREFIX_NAME@" : "prefix_name",
                              "@ADDR_WIDTH@" : "addr_width",
#                              "@NUM_CYCLES@" : "max_cycles",
                              "@INDEX_WIDTH@" : "input_width(index)",
                              "@REG_WIDTH@" : "input_width(newVal)"}
},

"reg_ifElseRaw": {"hdl_template_file": "externs/reg_ifElseRaw/hdl/EXTERN_reg_ifElseRaw_template.v",
                  "replacements": {"@EXTERN_NAME@" : "extern_name",
                                   "@MODULE_NAME@" : "module_name",
                                   "@PREFIX_NAME@" : "prefix_name",
                                   "@ADDR_WIDTH@" : "addr_width",
#                                   "@NUM_CYCLES@" : "max_cycles",
                                   "@INDEX_WIDTH@" : "input_width(index_1)",
                                   "@REG_WIDTH@" : "output_width(result)"}
},

"reg_sub": {"hdl_template_file": "externs/reg_sub/hdl/EXTERN_reg_sub_template.v",
            "replacements": {"@EXTERN_NAME@" : "extern_name",
                             "@MODULE_NAME@" : "module_name",
                             "@PREFIX_NAME@" : "prefix_name",
                             "@ADDR_WIDTH@" : "addr_width",
#                             "@NUM_CYCLES@" : "max_cycles",
                             "@INDEX_WIDTH@" : "input_width(index_1)",
                             "@REG_WIDTH@" : "output_width(result)"}
},

"lrc": {"hdl_template_file": "externs/lrc/hdl/EXTERN_lrc_template.v",
        "cpp_template_file": "externs/lrc/cpp/EXTERN_lrc_template.hpp",
        "replacements": {"@DATA_WIDTH@": "input_width(in_data)",
                         "@RESULT_WIDTH@": "output_width(result)",
                         "@MODULE_NAME@": "module_name",
                         "@EXTERN_NAME@": "extern_name"}
},

"timestamp": {"hdl_template_file": "externs/timestamp/hdl/EXTERN_timestamp_template.v",
              "cpp_template_file": "externs/timestamp/cpp/EXTERN_timestamp_template.hpp",
              "replacements": {"@TIMER_WIDTH@": "output_width(result)",
                               "@MODULE_NAME@": "module_name",
                               "@EXTERN_NAME@": "extern_name"}
},

"ip_chksum": {"hdl_template_file": "externs/ip_chksum/hdl/EXTERN_ip_chksum_template.v",
              "cpp_template_file": "externs/ip_chksum/cpp/EXTERN_ip_chksum_template.hpp",
              "replacements": {"@MODULE_NAME@": "module_name",
                               "@EXTERN_NAME@": "extern_name"}
},

"bloom_filter" : {"hdl_template_file": "externs/bloom_filter/hdl/EXTERN_bloom_filter_template.v",
                  "replacements": {"@EXTERN_NAME@" : "extern_name",
                              "@MODULE_NAME@" : "module_name",
                              "@KEY_WIDTH@" : "input_width(index)",
                              "@HASH_WIDTH@" : "annotation(BloomFilterHashWidth)",
                              "@HASH_COUNT@" : "annotation(BloomFilterHashCount)"}
},

"reg_multi_raws" : {"hdl_template_file": "externs/reg_multi_raws/hdl/EXTERN_reg_multi_raws_template.v",
                    "replacements": {"@EXTERN_NAME@" : "extern_name",
                                     "@MODULE_NAME@" : "module_name",
                                     "@PREFIX_NAME@" : "prefix_name",
                                     "@ADDR_WIDTH@" : "addr_width",
                                     "@INDEX_WIDTH@" : "input_width(index_0)",
                                     "@REG_WIDTH@" : "input_width(data_0)"}
},

"shift_reg" : {"hdl_template_file": "externs/shift_reg/hdl/EXTERN_shift_reg_template.v",
               "replacements": {"@EXTERN_NAME@" : "extern_name",
                                "@MODULE_NAME@" : "module_name",
                                "@INDEX_WIDTH@" : "input_width(index_in)",
                                "@DATA_WIDTH@" : "input_width(data_in)",
                                "@L2_DEPTH@" : "annotation(ShiftRegDepthL2)",
                                "@NUM_SHIFT_REGS@" : "annotation(ShiftRegCount)"}
},


"lut_cam": {"hdl_template_file": "externs/lut/hdl_cam/EXTERN_lut_cam_template.v",
            "replacements": {"@EXTERN_NAME@" : "extern_name",
                             "@MODULE_NAME@" : "module_name",
                             "@PREFIX_NAME@" : "prefix_name",
                             "@KEY_WIDTH@" : "input_width(key)",
                             "@ADDRESS_WIDTH@" : "input_width(address)",
                             "@VALUE_WIDTH@" : "input_width(newPort)"}
},

"lut_tcam": {"hdl_template_file": "externs/lut/hdl_tcam/EXTERN_lut_tcam_template.v",
            "replacements": {"@EXTERN_NAME@" : "extern_name",
                             "@MODULE_NAME@" : "module_name",
                             "@PREFIX_NAME@" : "prefix_name",
                             "@KEY_WIDTH@" : "input_width(key)",
                             "@ADDRESS_WIDTH@" : "input_width(address)",
                             "@VALUE_WIDTH@" : "input_width(newPort)"}
},


"reg_simple_rw": {"hdl_template_file": "externs/reg_simple_rw/hdl/EXTERN_reg_simple_rw_template.v",
            "replacements": {"@EXTERN_NAME@" : "extern_name",
                             "@MODULE_NAME@" : "module_name",
                             "@PREFIX_NAME@" : "prefix_name",
                             "@REG_WIDTH@" : "input_width(newVal_in)"}
},

"hyperloglog": {"hdl_template_file": "externs/hyperloglog/hdl/EXTERN_hyperloglog_template.v",
            "replacements": {"@EXTERN_NAME@" : "extern_name",
                             "@MODULE_NAME@" : "module_name",
                             "@PREFIX_NAME@" : "prefix_name",
                             "@DATAIN_WIDTH@" : "input_width(data_in)",
                             "@RESULT_WIDTH@" : "output_width(result)",
                             "@BUCKET_INDEX_WIDTH@" : "output_width(empty_buckets)",
                             "@BUCKET_CONTENT_WIDTH@" : "annotation(HyperLogLogBucketContentWidth)"}
},

"welford": {"hdl_template_file": "externs/welford/hdl/EXTERN_welford_template.v",
            "replacements": {"@EXTERN_NAME@" : "extern_name",
                             "@MODULE_NAME@" : "module_name",
                             "@PREFIX_NAME@" : "prefix_name",
                             "@DATAIN_WIDTH@" : "input_width(newVal)",
                             "@RESULT_SHORT_WIDTH@" : "output_width(result_pkt_count)",
                             "@RESULT_LONG_WIDTH@" : "output_width(result_m2)"}
}

}
