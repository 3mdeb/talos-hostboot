/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/usr/diag/prdf/common/plat/mem/prdfCenMbaDataBundle.H $    */
/*                                                                        */
/* OpenPOWER HostBoot Project                                             */
/*                                                                        */
/* Contributors Listed Below - COPYRIGHT 2017,2018                        */
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

#ifndef __prdfCenMbaDataBundle_H
#define __prdfCenMbaDataBundle_H

// Framework includes
#include <prdfExtensibleChip.H>

// Platform includes
#include <prdfMemCeTable.H>
#include <prdfMemRceTable.H>
#include <prdfMemUeTable.H>
#include <prdfPlatServices.H>

#ifdef __HOSTBOOT_MODULE

  #include <prdfMemTdCtlr.H>
  #include <prdfMemTdFalseAlarm.H>

  #ifdef __HOSTBOOT_RUNTIME
    #include <prdfMemScrubUtils.H>
  #else
    #include <prdfMemIplCeStats.H>
  #endif

#endif

namespace PRDF
{

/** @brief Centaur MBA data bundle. */
class MbaDataBundle : public DataBundle
{
  public: // functions

    /**
     * @brief Constructor.
     * @param i_chip The MBA chip.
     */
    explicit MbaDataBundle( ExtensibleChip * i_chip ) :
        iv_chip(i_chip), iv_ceTable(i_chip), iv_ueTable(i_chip),
        iv_rceTable(i_chip)
    {}

    /** @brief Destructor. */
    ~MbaDataBundle()
    {
        #ifdef __HOSTBOOT_MODULE

        delete iv_tdCtlr; iv_tdCtlr = nullptr;

        #ifdef __HOSTBOOT_RUNTIME

        delete iv_tpsFalseAlarmCounter;

        #else // IPL only

        delete iv_sfCmd; iv_sfCmd = nullptr;
        delete iv_iplCeStats; iv_iplCeStats = nullptr;

        #endif

        #endif
    }

    // Don't allow copy or assignment.
    MbaDataBundle( const MbaDataBundle & ) = delete;
    const MbaDataBundle & operator=( const MbaDataBundle & ) = delete;

    #ifdef __HOSTBOOT_MODULE

    /** @return The Targeted Diagnostics controller. */
    MemTdCtlr<TARGETING::TYPE_MBA> * getTdCtlr()
    {
        if ( nullptr == iv_tdCtlr )
        {
            iv_tdCtlr = new MemTdCtlr<TARGETING::TYPE_MBA>{iv_chip};
        }

        return iv_tdCtlr;
    }

    #ifdef __HOSTBOOT_RUNTIME

    /** @return The TPS false alarm counter. */
    TpsFalseAlarm * getTpsFalseAlarmCounter()
    {
        if ( nullptr == iv_tpsFalseAlarmCounter )
        {
            iv_tpsFalseAlarmCounter = new TpsFalseAlarm(
                TimeBasedThreshold{ 3, ThresholdResolution::ONE_DAY } );
        }

        return iv_tpsFalseAlarmCounter;
    }

    #else // IPL only

    /** @return The IPL CE statistics object. */
    MemIplCeStats<TARGETING::TYPE_MBA> * getIplCeStats()
    {
        if ( nullptr == iv_iplCeStats )
        {
            iv_iplCeStats = new MemIplCeStats<TARGETING::TYPE_MBA>( iv_chip );
        }

        return iv_iplCeStats;
    }

    #endif // __HOSTBOOT_RUNTIME

    #endif // __HOSTBOOT_MODULE

  private: // instance variables

    /** The MBA chip associated with this data bundle. */
    ExtensibleChip * const iv_chip;

    #ifdef __HOSTBOOT_MODULE

    /** The Targeted Diagnostics controller. */
    MemTdCtlr<TARGETING::TYPE_MBA> * iv_tdCtlr = nullptr;

    #ifdef __HOSTBOOT_RUNTIME

    /** TPS false alarm counter. */
    TpsFalseAlarm * iv_tpsFalseAlarmCounter = nullptr;

    #else // IPL only

    /** MNFG IPL CE statistics. */
    MemIplCeStats<TARGETING::TYPE_MBA> * iv_iplCeStats = nullptr;

    #endif // __HOSTBOOT_RUNTIME

    #endif // __HOSTBOOT_MODULE

  public: // instance variables

    MemCeTable<TARGETING::TYPE_MBA> iv_ceTable; ///< CE table for FFDC
    MemUeTable  iv_ueTable;                      ///< UE table for FFDC
    MemRceTable iv_rceTable;                     ///< RCE table for FFDC

    #if defined(__HOSTBOOT_MODULE) && !defined(__HOSTBOOT_RUNTIME)

    /** Super fast commands during Memory Diagnostics require a cleanup after
     *  the command has finished. After starting the command, we have to store
     *  the command object until we get the command complete attention. */
    mss_SuperFastRead * iv_sfCmd = nullptr;

    #endif

    #if defined(__HOSTBOOT_MODULE) && defined(__HOSTBOOT_RUNTIME)

    /** To prevent flooding during runtime scrub commands, this is used to limit
     *  the number of times a scrub command is resumed on a rank. */
    ScrubResumeCounter iv_scrubResumeCounter;

    #endif
};

/**
 * @brief  Wrapper function for the MbaDataBundle.
 * @param  i_mbaChip The MBA chip.
 * @return This MBA's data bundle.
 */
inline MbaDataBundle * getMbaDataBundle( ExtensibleChip * i_mbaChip )
{
    return static_cast<MbaDataBundle *>(i_mbaChip->getDataBundle());
}

} // end namespace PRDF

#endif // __prdfCenMbaDataBundle_H

