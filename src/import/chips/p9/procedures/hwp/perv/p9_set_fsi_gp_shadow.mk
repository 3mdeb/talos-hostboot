# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: chips/p9/procedures/hwp/perv/p9_set_fsi_gp_shadow.mk $
#
# IBM CONFIDENTIAL
#
# EKB Project
#
# COPYRIGHT 2015,2016
# [+] International Business Machines Corp.
#
#
# The source code for this program is not published or otherwise
# divested of its trade secrets, irrespective of what has been
# deposited with the U.S. Copyright Office.
#
# IBM_PROLOG_END_TAG
PROCEDURE=p9_set_fsi_gp_shadow
lib$(PROCEDURE)_DEPLIBS += fapi2_utils
$(call BUILD_PROCEDURE)
