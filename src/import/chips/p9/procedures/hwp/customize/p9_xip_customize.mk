# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/import/chips/p9/procedures/hwp/customize/p9_xip_customize.mk $
#
# OpenPOWER HostBoot Project
#
# Contributors Listed Below - COPYRIGHT 2016,2019
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
PROCEDURE = p9_xip_customize
lib$(PROCEDURE)_DEPLIBS+=p9_xip_image
lib$(PROCEDURE)_DEPLIBS+=p9_xip_section_append
lib$(PROCEDURE)_DEPLIBS+=p9_ring_identification
lib$(PROCEDURE)_DEPLIBS+=p9_scan_compression
lib$(PROCEDURE)_DEPLIBS+=p9_get_mvpd_ring
lib$(PROCEDURE)_DEPLIBS+=p9_mvpd_ring_funcs
lib$(PROCEDURE)_DEPLIBS+=p9_tor
lib$(PROCEDURE)_DEPLIBS+=common_ringId
lib$(PROCEDURE)_DEPLIBS+=p9_ringId
lib$(PROCEDURE)_DEPLIBS+=cen_ringId
lib$(PROCEDURE)_DEPLIBS+=p9_dd_container
$(call ADD_MODULE_INCDIR,$(PROCEDURE),$(ROOTPATH)/chips/p9/xip)
$(call ADD_MODULE_INCDIR,$(PROCEDURE),$(ROOTPATH)/chips/p9/utils/imageProcs)
$(call ADD_MODULE_INCDIR,$(PROCEDURE),$(ROOTPATH)/chips/p9/procedures/hwp/accessors/)
$(call BUILD_PROCEDURE)
