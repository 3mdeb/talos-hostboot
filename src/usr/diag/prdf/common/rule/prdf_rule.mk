# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/usr/diag/prdf/common/rule/prdf_rule.mk $
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

# P9 Nimbus Chip
PRDR_RULE_TABLES += p9_nimbus.prf
PRDR_RULE_TABLES += p9_eq.prf
PRDR_RULE_TABLES += p9_ex.prf
PRDR_RULE_TABLES += p9_ec.prf
PRDR_RULE_TABLES += p9_capp.prf
PRDR_RULE_TABLES += p9_pec.prf
PRDR_RULE_TABLES += p9_phb.prf
PRDR_RULE_TABLES += p9_obus.prf
PRDR_RULE_TABLES += p9_xbus.prf
PRDR_RULE_TABLES += p9_mcbist.prf
PRDR_RULE_TABLES += p9_mcs.prf
PRDR_RULE_TABLES += p9_mca.prf

# P9 Cumulus Chip
PRDR_RULE_TABLES += cumulus_proc.prf
PRDR_RULE_TABLES += cumulus_eq.prf
PRDR_RULE_TABLES += cumulus_ex.prf
PRDR_RULE_TABLES += cumulus_ec.prf
PRDR_RULE_TABLES += cumulus_capp.prf
PRDR_RULE_TABLES += cumulus_pec.prf
PRDR_RULE_TABLES += cumulus_phb.prf
PRDR_RULE_TABLES += cumulus_xbus.prf
PRDR_RULE_TABLES += cumulus_obus.prf
PRDR_RULE_TABLES += cumulus_mc.prf
PRDR_RULE_TABLES += cumulus_mi.prf
PRDR_RULE_TABLES += cumulus_dmi.prf

# Centaur Chip
PRDR_RULE_TABLES += cen_centaur.prf
PRDR_RULE_TABLES += cen_mba.prf

prd_rule_prf_targets  = ${PRDR_RULE_TABLES}
prd_rule_err_targets  = ${PRDR_RULE_TABLES:.prf=.prf.err.C}
prd_rule_disp_targets = ${PRDR_RULE_TABLES:.prf=.prf.disp.C}
prd_rule_reg_targets  = ${PRDR_RULE_TABLES:.prf=.prf.reg.C}
prd_rule_html_targets = ${PRDR_RULE_TABLES:.prf=.prf.html}

