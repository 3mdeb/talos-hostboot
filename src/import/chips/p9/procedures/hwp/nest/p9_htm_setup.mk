# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: chips/p9/procedures/hwp/nest/p9_htm_setup.mk $
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
PROCEDURE=p9_htm_setup
OBJS+=p9_htm_start.o
OBJS+=p9_htm_reset.o
OBJS+=p9_htm_adu_ctrl.o
OBJS+=p9_adu_coherent_utils.o
OBJS+=p9_fbc_utils.o
$(call BUILD_PROCEDURE)
