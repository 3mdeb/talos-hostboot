# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/usr/targeting/common/xmltohb/common.mk $
#
# OpenPOWER HostBoot Project
#
# Contributors Listed Below - COPYRIGHT 2012,2017
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
################################################################################
#
#  @file targeting/common/xmltohb/common.mk
#
#  @brief Common attribute compiler makefile to be included in
#      targeting/xmltohb/makefile
#
################################################################################

XMLTOHB_HEADER_TARGETS += attributeenums.H
XMLTOHB_HEADER_TARGETS += attributestrings.H
XMLTOHB_HEADER_TARGETS += attributetraits.H
XMLTOHB_HEADER_TARGETS += attributestructs.H
XMLTOHB_HEADER_TARGETS += pnortargeting.H
XMLTOHB_HEADER_TARGETS += fapi2platattrmacros.H
XMLTOHB_HEADER_TARGETS += test_ep.H
XMLTOHB_HEADER_TARGETS += mapattrmetadata.H
XMLTOHB_HEADER_TARGETS += mapsystemattrsize.H

XMLTOHB_SOURCE_TARGETS += attributestrings.C
XMLTOHB_SOURCE_TARGETS += attributedump.C
XMLTOHB_SOURCE_TARGETS += errludattribute.C
XMLTOHB_SOURCE_TARGETS += errludtarget.C
XMLTOHB_SOURCE_TARGETS += mapattrmetadata.C
XMLTOHB_SOURCE_TARGETS += mapsystemattrsize.C

XMLTOHB_SYSTEM_BINARIES += vbu_NIMBUS_targeting.bin
XMLTOHB_SYSTEM_BINARIES += simics_NIMBUS_targeting.bin

XMLTOHB_SYSTEM_BINARIES += simics_CUMULUS_targeting.bin

XMLTOHB_TARGETS += ${XMLTOHB_HEADER_TARGETS}
XMLTOHB_TARGETS += ${XMLTOHB_SOURCE_TARGETS}

# Temp defaults XML sources used by updatetempsxml.pl script
TEMP_DEFAULTS_XML       += tempdefaults.xml
HB_TEMP_DEFAULTS_XML    += hb_temp_defaults.xml

ATTRIBUTE_SERVICE_H     += plat_attribute_service.H
HB_PLAT_ATTR_SRVC_H     += hb_plat_attr_srvc.H

TEMP_GENERIC_XML        += temp_generic.xml
XMLTOHB_GENERIC_XML     += generic.xml
XMLTOHB_FAPI_XML        += fapiattrs.xml
XMLTOHB_MERGE_SCRIPT    += mergexml.sh
XMLTOHB_TEMPS_MERGE_SCRIPT += updatetempsxml.pl
XMLTOHB_COMPILER_SCRIPT += xmltohb.pl
VMM_CONSTS_FILE         += vmmconst.h

GENERATED_CODE = ${XMLTOHB_TARGETS}
