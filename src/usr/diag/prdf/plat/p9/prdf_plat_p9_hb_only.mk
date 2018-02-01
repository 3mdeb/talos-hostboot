# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/usr/diag/prdf/plat/p9/prdf_plat_p9_hb_only.mk $
#
# OpenPOWER HostBoot Project
#
# Contributors Listed Below - COPYRIGHT 2016,2018
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

# NOTE: PRD_SRC_PATH and PRD_INC_PATH must be defined before including this file

################################################################################
# Paths common to both IPL and runtime
################################################################################

prd_vpath += ${PRD_SRC_PATH}/plat/p9

prd_incpath += ${PRD_SRC_PATH}/plat/p9

################################################################################
# Hostboot only object files common to both IPL and runtime
################################################################################

# plat/p9/ (non-rule plugin related)

# plat/p9/ (rule plugin related)

################################################################################
# Hostboot only object files (IPL only)
################################################################################

ifneq (${HOSTBOOT_RUNTIME},1)

# plat/p9/ (non-rule plugin related)

endif

################################################################################
# Hostboot only object files (runtime only)
################################################################################

ifeq (${HOSTBOOT_RUNTIME},1)

# plat/p9/ (non-rule plugin related)
prd_obj += prdfP9PmRecovery.o

endif

