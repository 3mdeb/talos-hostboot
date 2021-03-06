/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/import/chips/p9/procedures/hwp/pm/p9_pm_recovery_ffdc_sgpe.H $ */
/*                                                                        */
/* OpenPOWER HostBoot Project                                             */
/*                                                                        */
/* Contributors Listed Below - COPYRIGHT 2015,2018                        */
/* [+] International Business Machines Corp.                              */
/*                                                                        */
/*                                                                        */
/* Licensed under the Apache License, Version 2.0 (the "License");        */
/* you may not use this file except in compliance with the License.       */
/* You may obtain a copy of the License at                                */
/*                                                                        */
/*     http://www.apache.org/licenses/LICENSE-2.0                         */
/*                                                                        */
/* Unless required by applicable law or agreed to in writing, software    */
/* distributed under the License is distributed on an "AS IS" BASIS,      */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or        */
/* implied. See the License for the specific language governing           */
/* permissions and limitations under the License.                         */
/*                                                                        */
/* IBM_PROLOG_END_TAG                                                     */
#ifndef __PM_RECOVERY_FFDC_SGPE_
#define __PM_RECOVERY_FFDC_SGPE_

///
/// @file   p9_pm_recovery_ffdc_sgpe.H
/// @brief  Models SGPE platform for the FFDC collection of PM complex
///
/// *HWP HWP Owner:      Greg Still <stillgs@us.ibm.com>
/// *HWP FW Owner:       Prem S Jha <premjha2@in.ibm.com>
/// *HWP Team:           PM
/// *HWP Level:          2
/// *HWP Consumed by:    Hostboot
//
// *INDENT-OFF*
//--------------------------------------------------------------------------
// Includes
//--------------------------------------------------------------------------
#include <fapi2.H>
#include <stdint.h>
#include <p9_pm_recovery_ffdc_base.H>

namespace p9_stop_recov_ffdc
{

    class PlatSgpe : public PlatPmComplex
    {
            public:
            /// @brief  constructor
            PlatSgpe( const fapi2::Target< fapi2::TARGET_TYPE_PROC_CHIP > i_procChipTgt );

            /// @brief  destructor
            virtual ~PlatSgpe() { };

            /// @brief      Initializes the SGPE FFDC Sub-Section in HOMER with default header
            /// @param[in]  i_pHomerBuf  points to base of P9 HOMER.
            ///  @return     fapi2 return code
            fapi2::ReturnCode init ( void* i_pHomerBuf );

            /// @brief      collects FFDC pertaining to all functional SGPEs in the chip.
            /// @param[in]  i_pHomerBuf   points to base of P9 HOMER.
            /// @param[in]  i_ffdcType    indicates the content type to collect
            /// @return     fapi2 return code.
            fapi2::ReturnCode collectFfdc( void*   i_pHomerBuf,
                                           uint8_t i_ffdcType = ALL );

            virtual fapi2::ReturnCode collectPartialFfdc( void * i_pHomerBuf, FfdcDataType i_ffdcType ,
                                                          uint32_t & o_ffdcLength );
            /// @brief      generates summary of FFDC pertaining to a given platform.
            /// @param[in]  i_pHomer    points to Homer base.
            /// @return     fapi2 return code
            fapi2::ReturnCode generateSummary( void * i_pHomer );

        private:
            /// @brief      collects trace info from SGPE's SRAM buffer.
            /// @param[in]  i_pHomerBuf     points to location of HOMER meant for SGPE Trace info.
            /// @return     fapi2 return code.
            fapi2::ReturnCode  collectTrace( uint8_t * i_pHomerBuf );

            /// @brief      collects  global variables from SGPE's's SRAM.
            /// @param[in]  i_pHomerBuf     points to location of HOMER meant for SGPE's global variable
            /// @return     fapi2 return code.
            fapi2::ReturnCode  collectGlobals( uint8_t * i_pHomerBuf );

            /// @brief      collects internal register info for a SGPE
            /// @param[in]  i_pHomerBuf     points to location of HOMER meant for SGPE internal register.
            /// @return     fapi2 return code.
            fapi2::ReturnCode  collectInternalReg( uint8_t * i_pHomerBuf );

            /// @brief      collects SGPE Image Header info from SGPE SRAM buffer.
            /// @param[in]  i_pHomerBuf     points to location of HOMER meant for SGPE's header.
            /// @return     fapi2 return code.
            fapi2::ReturnCode  collectImageHeader( uint8_t * i_pHomerBuf );

            /// @brief updates the SGPE FFDC Header
            ///@param[in]   i_pHomerBuf     points to a location in HOMER meant for SGPE FFDC Header
            ///param[in]    i_sectionsValid bit vector summarizing FFDC validity
            ///@return      fapi2 return code.
            fapi2::ReturnCode updateSgpeFfdcHeader( uint8_t* i_pHomerBuf,
                                                    uint16_t i_sectionsValid );

            ///@brief returns type of platform
            PmComplexPlatId getPlatType() { return iv_plat; }

            void initRegList();

        private:
            PmComplexPlatId iv_plat;
    };

    //---------------------------------------------------------------------------------------------

    // function pointer typedef definition for HWP call support
    typedef fapi2::ReturnCode( *p9_pm_recovery_ffdc_sgpe_FP_t )
            ( const fapi2::Target< fapi2::TARGET_TYPE_PROC_CHIP > & i_procChipTgt,
              void * i_sgpeFfdcBuf );
extern "C"
{
    // -----------------------------------------------------------------------------
    // Function prototypes
    // -----------------------------------------------------------------------------
    ///
    /// @brief Populatess the SGPE FFDC section with FFDC collected from SGPE.
    ///
    /// @param[in] i_procChipTarget Proc Chip target
    /// @param[in] i_pHomerImage    Pointer to the base of the chip HOMER region
    ///
    /// @return FAPI2_RC_SUCCESS on success or error return code
    ///
        fapi2::ReturnCode p9_pm_recovery_ffdc_sgpe
        ( const fapi2::Target<fapi2::TARGET_TYPE_PROC_CHIP>& i_procChipTarget,
          void* i_pHomerImage );
}

} //namespace p9_stop_recov_ffdc ends

#endif //__PM_RECOVERY_FFDC_SGPE_
