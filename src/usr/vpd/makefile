# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/usr/vpd/makefile $
#
# OpenPOWER HostBoot Project
#
# Contributors Listed Below - COPYRIGHT 2013,2018
# [+] International Business Machines Corp.
#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing
# permissions and limitations under the License.
#
# IBM_PROLOG_END_TAG
ROOTPATH = ../../..
MODULE = vpd

#include configuration defines
include $(ROOTPATH)/config.mk

#include common objects between hb and runtime
include vpd.mk

#include unique objects
OBJS += vpd.o
OBJS += dimmPres.o
OBJS += rtvpd_load.o

SUBDIRS += test.d
SUBDIRS += runtime.d


#Updated mvpd to contain VRML so that part/serial numbers can be
#found for procs CCIN 54E3
BINARY_FILES += $(IMGDIR)/procmvpd.dat:65759fa4aebd2e3b42b25309504a3007b3b51036
BINARY_FILES += $(IMGDIR)/procmvpd_ven.dat:dd8507bec946283260f82af212ed32feaeb3363a
BINARY_FILES += $(IMGDIR)/vpo_sysmvpd.dat:f83bbcdd56defb5d155399774c4d721de25a8e96
BINARY_FILES += $(IMGDIR)/vpo_djvpd.dat:eb4dce98f19ebfe77243be1c56d3d0eaa1889d90

# Nimbus Module VPD
# Copied from /afs/btv.ibm.com/u/sgrom/public/vpd_images/p9_dd10/module-p9-dd10-simics_v15_rs4v2.bin
#   on 1/3/2017
# Modified PG record to have proper XBUS data and only the first 4 cores
BINARY_FILES += $(IMGDIR)/procmvpd_p9n.dat:a351f3cd5ba8a81a50c3e5a0dea5fea03e55769d
BINARY_FILES += $(IMGDIR)/procmvpd_p9c.dat:d9299c4027c597c31337b46ed311edc131ec93bc

#Update to Centaur DD2.0 for CCIN 31E8

# CDIMM Format - download 4k cvpd file
BINARY_FILES += $(IMGDIR)/cvpd_cdimm.dat:b12431fbc14304edd31e74405cdcb27560a8e00b
BINARY_FILES += $(IMGDIR)/dimmspd_cdimm.dat:21b0da9354a588bb1247f1408bfce3111fbc4c82

# ISDIMM Format - download 8k cvpd file
BINARY_FILES += $(IMGDIR)/cvpd.dat:af41c35b5a10f309f2519a871204936a2129e5ea
BINARY_FILES += $(IMGDIR)/dimmspd.dat:9852a0ed166442ef69ecd91a0379f282419a371f

#Direct memory vpd
BINARY_FILES += $(IMGDIR)/dvpd.dat:9292032f653710f92bbeb56b39582b2d0e5296b7

include ${ROOTPATH}/config.mk
