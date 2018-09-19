/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/include/runtime/interface.h $                             */
/*                                                                        */
/* OpenPOWER HostBoot Project                                             */
/*                                                                        */
/* Contributors Listed Below - COPYRIGHT 2013,2018                        */
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
#ifndef __RUNTIME__INTERFACE_H
#define __RUNTIME__INTERFACE_H

/** @file interface.h
 *  @brief Interfaces between Hostboot Runtime and Sapphire.
 *
 *  This file has two structures of function pointers: hostInterfaces_t and
 *  runtimeInterfaces_t.  hostInterfaces are provided by Sapphire (or a
 *  similar environment, such as Hostboot IPL's CxxTest execution).
 *  runtimeInterfaces are provided by Hostboot Runtime to Sapphire.
 *
 *  @note This file must be in C rather than C++.
 */

/** Current interface version.
 *  0x9002:  9=P9, 002=Version 2
 */
#define HOSTBOOT_RUNTIME_INTERFACE_VERSION 0x9002

#ifndef __HOSTBOOT_RUNTIME_INTERFACE_VERSION_ONLY

#include <stdint.h>
#include <time.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include "generic_hbrt_fsp_message.H"

/** Memory error types defined for memory_error() interface. */
enum MemoryError_t
{
    /** Hardware has reported a solid memory CE that is correctable, but
     *  continues to report errors on subsequent reads. A second CE on that
     *  cache line will result in memory UE. Therefore, it is advised to
     *  migrate off of the address range as soon as possible. */
    MEMORY_ERROR_CE = 0,

    /** Hardware has reported an uncorrectable error in memory (memory UE,
     *  channel failure, etc). The hypervisor should migrate any partitions
     *  off this address range as soon as possible. Note that these kind of
     *  errors will most likely result in persistent partition failures. It
     *  is advised that the hypervisor gives firmware some time after
     *  partition failures to handle the hardware attentions so that the
     *  hypervisor will know all areas of memory that are impacted by the
     *  failure. */
    MEMORY_ERROR_UE = 1,

    /** Firmware has predictively requested service on a part in the memory
     *  subsystem. The partitions may not have been affected, but it is
     *  advised to migrate off of the address range as soon as possible to
     *  avoid potential partition outages. */
    MEMORY_ERROR_PREDICTIVE = 2,
};


/** Common return codes to translate into pib error codes. */
// RC for a piberr is equal to 0x1000 plus the pib error value,
//  made into a negative
enum HbrtRcPiberr_t
{
    HBRT_RC_PIBERR_MASK            = (0x00000000u - 0x00001007u), // 0xFFFF_EFF9

    HBRT_RC_PIBERR_001_BUSY        = (0x00000000u - 0x00001001u), // 0xFFFF_EFFF
    HBRT_RC_PIBERR_010_OFFLINE     = (0x00000000u - 0x00001002u), // 0xFFFF_EFFE
    HBRT_RC_PIBERR_011_PGOOD       = (0x00000000u - 0x00001003u), // 0xFFFF_EFFD
    HBRT_RC_PIBERR_100_INVALIDADDR = (0x00000000u - 0x00001004u), // 0xFFFF_EFFC
    HBRT_RC_PIBERR_101_CLOCKERR    = (0x00000000u - 0x00001005u), // 0xFFFF_EFFB
    HBRT_RC_PIBERR_110_PARITYERR   = (0x00000000u - 0x00001006u), // 0xFFFF_EFFA
    HBRT_RC_PIBERR_111_TIMEOUT     = (0x00000000u - 0x00001007u), // 0xFFFF_EFF9

    HBRT_RC_SOMEOTHERERROR         = (0x00000000u - 0x00001008u)  // 0xFFFF_EFF8
};


/**
 * I2C Master Description: chip, engine and port packed into
 * a single 64-bit argument
 *
 * ---------------------------------------------------
 * |         chip         |  reserved  |  eng | port |
 * |         (32)         |    (16)    |  (8) | (8)  |
 * ---------------------------------------------------
 */
#define HBRT_I2C_MASTER_CHIP_SHIFT        32
#define HBRT_I2C_MASTER_CHIP_MASK         (0xfffffffful << 32)
#define HBRT_I2C_MASTER_ENGINE_SHIFT      8
#define HBRT_I2C_MASTER_ENGINE_MASK       (0xfful << 8)
#define HBRT_I2C_MASTER_PORT_SHIFT        0
#define HBRT_I2C_MASTER_PORT_MASK         (0xfful)


/**
 *  Load types for the load_pm_complex() interface
 *      HBRT_PM_LOAD: initial load of all lids/sections from scratch,
 *                    preserve nothing
 *      HBRT_PM_RELOAD: concurrent reload of all lids/sections,
 *                      but preserve runtime updates
 */
#define HBRT_PM_LOAD    0
#define HBRT_PM_RELOAD  1

/**
 *  Wakeup mode for the wakeup() interface
 *      HBRT_WKUP_FORCE_AWAKE: force a core awake
 *      HBRT_WKUP_CLEAR_FORCE: clear a previous force
 *      HBRT_WKUP_CLEAR_FORCE_COMPLETELY: clear all previous forces, regardless
 *                                        of internal counts
 */
#define HBRT_WKUP_FORCE_AWAKE  0
#define HBRT_WKUP_CLEAR_FORCE  1
#define HBRT_WKUP_CLEAR_FORCE_COMPLETELY  2

/**
 *  Chip ID types included in the chip_id / proc_id / core_id
 *      passed to the host in several interfaces
 */
#define HBRT_PROC_TYPE          0x00000000 //!< PROC chip id type
#define HBRT_MEMBUF_TYPE        0x80000000 //!< MEMBUF chip id type
#define HBRT_CORE_TYPE          0x40000000 //!< CORE chip id type
#define HBRT_CHIPID_TYPE_MASK   0xFF000000 //!< TYPE field

/**
 *  Reserved memory labels - used by get_reserved_mem
 */
#define HBRT_RSVD_MEM__CODE               "ibm,hbrt-code-image"
#define HBRT_RSVD_MEM__PRIMARY            "ibm,hb-rsv-mem"
#define HBRT_RSVD_MEM__HOMER              "ibm,homer-image"
#define HBRT_RSVD_MEM__OCC_COMMON         "ibm,occ-common-area"
#define HBRT_RSVD_MEM__SBE_COMM           "ibm,sbe-comm"
#define HBRT_RSVD_MEM__SBE_FFDC           "ibm,sbe-ffdc"
#define HBRT_RSVD_MEM__SECUREBOOT         "ibm,secure-crypt-algo-code"
#define HBRT_RSVD_MEM__DATA               "ibm,hbrt-data"
#define HBRT_RSVD_MEM__ARCH_REG           "ibm,arch-reg-data"

// Aligned reserved memory size for Opal
#define HBRT_RSVD_MEM_OPAL_ALIGN  64*KILOBYTE

/**
 * Specifiers for get_interface_capabilities
 */

/* Common Features */
#define HBRT_CAPS_SET0_COMMON  0

/* OPAL fixes */
#define HBRT_CAPS_SET1_OPAL    1
#define HBRT_CAPS_OPAL_HAS_XSCOM_RC     (1ul << 0)
#define HBRT_CAPS_OPAL_HAS_WAKEUP       (1ul << 1)
#define HBRT_CAPS_OPAL_HAS_WAKEUP_CLEAR (1ul << 2)

/* PHYP fixes */
#define HBRT_CAPS_SET2_PHYP    2

/* FSP failed due to a a reset/reload. Only applicable when
 * hostInterfaces::hbrt_fw_msg::io_type is set to
 * HBRT_FW_MSG_HBRT_FSP_REQ
 */
#define HBRT_RC_FSPDEAD       -8193    //0x2001

/* FSP failed due to a a reset/reload */
#define HBRT_FW_REQUEST_RETRIES  1


/** @typedef hostInterfaces_t
 *  @brief Interfaces provided by the underlying environment (ex. Sapphire).
 *
 *  @note Some of these functions are not required (marked optional) and
 *        may be NULL.
 */
typedef struct hostInterfaces
{
    /** Interface version. */
    uint64_t interfaceVersion;

    /**
     *  @brief Put a string to the console
     *         Host must add newline to end of the string
     *  @param[in] i_str string to print
     *  @platform FSP, OpenPOWER
     */
    void (*puts)(const char* i_str);

    /**
     *  @brief Critical failure in runtime executeion
     *  @platform FSP, OpenPOWER
     */
    void (*assert)();

    /**
     *  @brief Hint to environment that the page may be executed
     *         OPTIONAL - may be implemented as a NO-OP
     *  @param[in] i_pageAddr aligned address of page that may be executed
     *  @return 0 on success else return code
     *  @platform FSP, OpenPOWER
     */
    int (*set_page_execute)(void* i_pageAddr);

    /**
     *  @brief Allocate a block of memory
     *  @param[in] i_blockSize size of the block to be allocated
     *  @return pointer to beginning of the block or NULL if allocation failed
     *  @platform FSP, OpenPOWER
     */
    void* (*malloc)(size_t i_blockSize);

    /**
     *  @brief Deallocate a block of memory
     *  @param[in] i_blockAddr address pointing to block of memory to deallocate
     *  @platform FSP, OpenPOWER
     */
    void (*free)(void* i_blockAddr);

    /**
     *  @brief Resize a block of memory
     *  @param[in] i_blockAddr address pointing to block of memory to resize
     *  @param[in] i_blockSize new size of the allocated block
     *  @return pointer to beginning of the block or NULL if resize failed
     *  @platform FSP, OpenPOWER
     */
    void* (*realloc)(void* i_blockAddr, size_t blockSize);

    /**
     *  @brief Send an error log to the FSP
     *  @param[in] i_plid     platform log identifier
     *  @param[in] i_errlSize data size in bytes
     *  @param[in] i_errlData pointer to data
     *  @return 0 on success else error code
     *  @platform FSP
     */
    int (*sendErrorLog)(uint32_t i_plid, uint32_t i_errlSize,
                        void* i_errlData);

    /**
     *  @brief Scan communication read
     *  @param[in]  i_chipId   processor chip ID
                               plus ID type, see defines at top
     *  @param[in]  i_scomAddr scom address to read
     *  @param[out] o_scomData pointer to 8-byte data buffer
     *  @return 0 on success else return code
     *  @platform FSP, OpenPOWER
     */
    int (*scom_read)(uint64_t i_chipId, uint64_t i_scomAddr,
                     void* o_scomData);

    /**
     *  @brief Scan communication write
     *  @param[in] i_chipId   processor chip ID
                              plus ID type, see defines at top
     *  @param[in] i_scomAddr scom address to write
     *  @param[in] i_scomData pointer to 8-byte data buffer
     *  @return 0 on success else return code
     *  @platform FSP, OpenPOWER
     */
    int (*scom_write)(uint64_t i_chipId, uint64_t i_scomAddr,
                      void* i_scomData);

    /**
     *  @brief Load a LID from PNOR, FSP, etc.
     *  @param[in]  i_lidId     LID number
     *  @param[out] o_lidBuffer allocated buffer for LID
     *  @param[out] o_lidSize   size of LID (in bytes)
     *  @return 0 on success, else RC.
     *  @platform FSP
     */
    int (*lid_load)(uint32_t i_lidId, void** o_lidBuffer,
                    size_t* o_lidSize);

    /**
     *  @brief Release memory from previously loaded LID.
     *  @param[in] i_lidBuffer allocated buffer for LID to release
     *  @return 0 on success, else return code
     *  @platform FSP
     */
    int (*lid_unload)(void* i_lidBuffer);

    /**
     *  @brief Get the address of a reserved memory region by its name
     *  @param[in] i_name     memory region name (ex. "ibm,hbrt-vpd-image")
     *  @param[in] i_instance instance number
     *  @return physical address of region or NULL
     *  @platform FSP, OpenPOWER
     **/
    uint64_t (*get_reserved_mem)(const char* i_name, uint32_t i_instance);

    /**
     *  @brief Force a core to be awake, or clear the force
     *  @param[in] i_core  Core to wake
                           plus ID type, see defines at top
     *  @param[in] i_mode  HBRT_WKUP_FORCE_AWAKE
     *                     HBRT_WKUP_CLEAR_FORCE
     *  @return non-zero return code on error
     *  @platform FSP, OpenPOWER
     */
    int (*wakeup)(uint32_t i_core, uint32_t i_mode );

    /**
     *  @brief Delay/sleep for at least the time given
     *  @param[in] i_seconds     seconds to sleep
     *  @param[in] i_nanoSeconds nano seconds to sleep
     *  @platform FSP, OpenPOWER
     */
    void (*nanosleep)(uint64_t i_seconds, uint64_t i_nanoSeconds);

    /**
     * DEPRECATED - remove when PHYP support new pm_complex functions
     * @brief Report an OCC error to the host
     * @param[in] Failing    status that identifies the nature of the fail
     * @param[in] Identifier that specifies the failing part
                             plus ID type, see defines at top
     * @platform FSP
     */
    void (*report_failure)( uint64_t i_status, uint64_t i_partId );

    /**
     *  @brief Reads the clock value from a POSIX clock
     *  @param[in]  i_clkId the clock ID to read
     *  @param[out] o_tp    the timespec struct to store the clock value in
     *  @return 0 or -(errno)
     *  @retval     0       SUCCESS
     *  @retval     -EINVAL invalid clock requested
     *  @retval     -EFAULT NULL ptr given for timespec struct
     *  @platform FSP, OpenPOWER
     */
    int (*clock_gettime)(clockid_t i_clkId, timespec_t* o_tp);

    /**
     *  @brief Read Pnor
     *  @param[in]  i_proc          processor Id
     *                              plus ID type, see defines at top
     *  @param[in]  i_partitionName name of the partition to read
     *  @param[in]  i_offset        offset within the partition
     *  @param[out] o_data          pointer to the data read
     *  @param[in]  i_sizeBytes     size of o_data buffer, maximum number
     *                              of bytes to read
     *  @retval     rc              negative on error, else number of
     *                              bytes actually read
     *  @platform OpenPOWER
     */
    int (*pnor_read) (uint32_t i_proc, const char* i_partitionName,
                      uint64_t i_offset, void* o_data, size_t i_sizeBytes);

    /**
     *  @brief Write Pnor
     *  @param[in] i_proc          processor Id
     *                             plus ID type, see defines at top
     *  @param[in] i_partitionName name of the partition to write
     *  @param[in] i_offset        offset withing the partition
     *  @param[in] i_data          pointer to the data to write
     *  @param[in] i_sizeBytes     size of i_data buffer, maximum number
     *                             of bytes to read
     *  @retval    rc              negative on error, else number of
     *                             bytes actually written
     */
    int (*pnor_write) (uint32_t i_proc, const char* i_partitionName,
                       uint64_t i_offset, void* i_data, size_t i_sizeBytes);

    /**
     *  @brief Read data from an i2c device
     *  @param[in] i_master     chip, engine and port packed into
     *                          a single 64-bit argument
     *                          chip includes ID type, see defines at top
     *     ---------------------------------------------------
     *     |         chip         |  reserved  |  eng | port |
     *     |         (32)         |    (16)    |  (8) | (8)  |
     *     ---------------------------------------------------
     *  @param[in] i_devAddr    I2C address of device
     *  @param[in] i_offsetSize length of offset (in bytes)
     *  @param[in] i_offset     offset within device to read
     *  @param[in] i_length     number of bytes to read
     *  @param[out] o_data      data that was read
     *  @return 0 on success else return code
     *  @platform OpenPOWER
     */
    int (*i2c_read)( uint64_t i_master, uint16_t i_devAddr,
                     uint32_t i_offsetSize, uint32_t i_offset,
                     uint32_t i_length, void* o_data );

    /**
     *  @brief Write data to an i2c device
     *  @param[in] i_master     chip, engine and port packed into
     *                          a single 64-bit argument
     *                          chip includes ID type, see defines at top
     *    ---------------------------------------------------
     *    |         chip         |  reserved  |  eng | port |
     *    |         (32)         |    (16)    |  (8) | (8)  |
     *    ---------------------------------------------------
     *  @param[in] i_devAddr    I2C address of device
     *  @param[in] i_offsetSize length of offset (in bytes)
     *  @param[in] i_offset     offset within device to write
     *  @param[in] i_length     number of bytes to write
     *  @param[in] i_data       data to write
     *  @return 0 on success else return code
     *  @platform OpenPOWER
     */
    int (*i2c_write)( uint64_t i_master, uint16_t i_devAddr,
                      uint32_t i_offsetSize, uint32_t i_offset,
                      uint32_t i_length, void* i_data );

    /**
     *  @brief Perform an IPMI transaction
     *  @param[in] netfn      the IPMI netfn byte
     *  @param[in] cmd        the IPMI cmd byte
     *  @param[in] tx_buf     the IPMI packet to send to the host
     *  @param[in] tx_size    the number of bytes to send
     *  @param[in] rx_buf     a buffer to be populated with the IPMI
     *                        response. First bytes will be the
     *                        IPMI completion code.
     *  @param[inout] rx_size The allocated size of the rx buffer on input
     *                        updated to the size of the response on output.
     *  @retval rc            non-zero on error
     *  @platform OpenPOWER
     */
    int (*ipmi_msg)(uint8_t netfn, uint8_t cmd,
                    void *tx_buf, size_t tx_size,
                    void *rx_buf, size_t *rx_size);

    /**
     * @brief Hardware has reported a memory error. This function requests the
     *        hypervisor to dynamically remove all pages within the address
     *        range given (including endpoints) from the available memory space.
     *
     * It is understood that the hypervisor may not be able to immediately
     * deallocate the memory because it is in use by a partition. Therefore, the
     * hypervisor should cache all requests and deallocate the memory once it
     * has been freed.
     *
     * Firmware does not know page boundaries so the addresses given could be
     * any address within a page. In some cases, the start and end address may
     * be the same address, indicating that only one page needs to be
     * deallocated.
     *
     * @param  i_startAddr The beginning address of the range.
     * @param  i_endAddr   The end address of the range.
     * @param  i_errorType See enum MemoryError_t.
     *
     * @return 0 if the request is successfully received. Any value other than 0
     *         on failure. The hypervisor should cache the request and return
     *         immediately. It should not wait for the request to be applied.
     *         See note above.
     * @platform FSP, OpenPOWER
     */
    int (*memory_error)( uint64_t i_startAddr, uint64_t i_endAddr,
                         enum MemoryError_t i_errorType );

    /**
     * @brief Query the HBRT host for a list of fixes/features
     *
     * There are times when workarounds need to be put into place to handle
     * issues with the hosting layer (e.g. opal-prd) while fixes are not yet
     * released.  This is especially true because of the disconnected release
     * streams for the firmware and the hosting environment.
     *
     * @param  i_set Indicates which set of fixes/features we're checking
     *               see HBRT_CAPS_SET...
     *
     * @return a bitmask containing the relevant flags for the current
     *         implementation, see HBRT_CAPS_FLAGS_...
     */
    uint64_t (*get_interface_capabilities)( uint64_t i_set );

    /**
     *  @brief Map a physical address space into usable memory
     *  @note Repeated calls to map the same memory should not return an error
     *  @param[in]  i_physMem  Physical address
     *  @param[in]  i_bytes    Number of bytes to map in
     *  @return NULL on error, else pointer to usable memory
     *  @platform FSP, OpenPOWER
     */
    void* (*map_phys_mem)(uint64_t i_physMem, size_t i_bytes);

    /**
     *  @brief Unmap a physical address space from usable memory
     *  @param[in]  i_ptr  Previously mapped pointer
     *  @return 0 on success, else RC
     *  @platform FSP, OpenPOWER
     */
    int (*unmap_phys_mem)(void* i_ptr);

    /**
     *  @brief Modify the SCOM restore section of the HCODE image with the
     *         given register data
     *
     *  @note The Hypervisor should perform the following actions:
     *        - insert the data into the HCODE image (p9_stop_api)
     *
     *  @pre HBRT is responsible for enabling special wakeup on the
     *       associated core(s) before calling this interface
     *
     *  @param  i_chipId    processor chip ID
                            plus ID type, always proc (0x0)
     *  @param  i_section   runtime section to update
     *                      (passthru to pore_gen_scom)
     *  @param  i_operation type of operation to perform
     *                      (passthru to pore_gen_scom)
     *  @param  i_scomAddr  fully qualified scom address
     *  @param  i_scomData  data for operation
     *
     *  @return 0 if the request is successfully received.
     *          Any value other than 0 on failure.
     *  @platform FSP, OpenPOWER
     */
    int (*hcode_scom_update)( uint64_t i_chipId,
                              uint32_t i_section,
                              uint32_t i_operation,
                              uint64_t i_scomAddr,
                              uint64_t i_scomData );

    /**
     *  @brief Structure to be sent and received in the
     *         firmware_request call
     */
    enum
    {
       HBRT_FW_MSG_TYPE_REQ_NOP = 0,
       HBRT_FW_MSG_TYPE_RESP_NOP = 1,
       HBRT_FW_MSG_TYPE_RESP_GENERIC = 2,
       HBRT_FW_MSG_TYPE_REQ_HCODE_UPDATE = 3,
       HBRT_FW_MSG_HBRT_FSP_REQ = 4,
       HBRT_FW_MSG_TYPE_ERROR_LOG = 5,
       HBRT_FW_MSG_HBRT_FSP_RESP = 6,
       HBRT_FW_MSG_TYPE_I2C_LOCK = 7,
       HBRT_FW_MSG_TYPE_SBE_STATE = 8,
    };

    struct hbrt_fw_msg   // define struct hbrt_fw_msg
    {
       hbrt_fw_msg() { req_hcode_update = { 0 }; };  // ctor

       uint64_t io_type;          // message type from HBRT_FW_MSG_TYPE enum
       union
       {
          // This struct is returned from skiboot with
          // io_type set to HBRT_FW_MSG_TYPE_RESP_GENERIC or
          // with HBRT_FW_MSG_TYPE_RESP_NOP
          struct
          {
             uint64_t o_status;      // return code for a generic response
          } resp_generic;

          // This struct is sent from HBRT with
          // io_type set to HBRT_FW_MSG_TYPE_REQ_HCODE_UPDATE
          struct
          {
             uint64_t i_chipId;     // processor chip ID plus ID type,
                                    // always proc (0x0)
             uint32_t i_section;    // runtime section to update
                                    // (passthru to pore_gen_scom)
             uint32_t i_operation;  // type of operation to perform
                                    // (passthru to pore_gen_scom)
             uint64_t i_scomAddr;   // fully qualified scom address
             uint64_t i_scomData;   // data for operation
          } req_hcode_update;

          // This struct is sent from HBRT with
          // io_type set to HBRT_FW_MSG_TYPE_ERR_LOG
          // Send an error log to FSP
          struct
          {
             uint32_t i_plid;     // platform log identifier
             uint32_t i_errlSize; // data size in bytes
             uint8_t  i_data;     // the error log data
                                  // uint8_t *myData =
                                  // (uint8_t*)&l_req_fw_msg->error_log.i_data;
          } __attribute__ ((packed)) error_log;


          // This struct is sent from HBRT with
          // io_type set to HBRT_FW_MSG_TYPE_I2C_LOCK
          struct
          {
             uint64_t i_chipId;     // processor chip ID plus ID type,
                                    // always proc (0x0)
             uint8_t i_i2cMaster;   // i2c master
                                    // B=0, C=1, D=2, E=3
             uint8_t i_operation;   // type of operation to perform
                                    // 1 = lock, 2 = unlock
          } __attribute__ ((packed)) req_i2c_lock;

          // This struct is sent from HBRT with
          // io_type set to  HBRT_FW_MSG_TYPE_SBE_STATE
          struct
          {
             uint64_t i_procId; // processor ID of the SBE that is disabled/enabled
             uint64_t i_state;  // state of the SBE; 0 = disabled, 1 = enabled
          } __attribute__ ((packed)) sbe_state;

          // This struct is sent from HBRT with
          // io_type set to HBRT_FW_MSG_HBRT_FSP_REQ or
          // HBRT_FW_MSG_HBRT_FSP_RESP
          // This struct sends/receives an MBox message to the FSP
          struct GenericFspMboxMessage_t generic_msg;

       }; // end union
    };  // end struct hbrt_fw_msg

    // Created a static constexpr to return the base size of hbrt_fw_msg
    // Can't do #define - sizeof not allowed to be used in #defines
    static constexpr size_t HBRT_FW_MSG_BASE_SIZE =
                                            sizeof(hbrt_fw_msg::io_type);

    /**
     * @brief Send a request to firmware, and receive a response
     * @details
     *   req_len bytes are sent to runtime firmware, and resp_len
     *   bytes received in response.
     *
     *   Both req and resp are allocated by the caller. If resp_len
     *   is not large enough to contain the full response, an error
     *   is returned.
     *
     * @param[in]  i_reqLen       length of request data
     * @param[in]  i_req          request data
     * @param[inout] o_respLen    in: size of request data buffer
     *                            out: length of request data
     * @param[in]  o_resp         response data
     * @return 0 on success, else RC
     * @platform FSP, OpenPOWER
     */
    int (*firmware_request)( uint64_t i_reqLen,
                             void *i_req,
                             uint64_t* o_respLen,
                             void *o_resp );

    // Reserve some space for future growth.
    // do NOT ever change this number, even if you add functions.
    //
    // The value of 32 was somewhat arbitrarily chosen.
    //
    // If either side modifies the interface.h file we're suppose to be able to
    // tolerate the other side not supporting the function yet.  The function
    // pointer can be NULL.  So if we require a new interface from OPAL, like
    // "read_iic", we need to be able to tolerate that function pointer being
    // NULL and do something sane (and erroring out is not consider sane).
    //
    // The purpose of this is to give us the ability to update Hostboot and
    // OPAL independently.  It is pretty rare that we both have function ready
    // at the same time.  The "reserve" is there so that the structures are
    // allocated with sufficient space and populated with NULL function
    // pointers.  32 is big enough that we should not likely add that many
    // functions from either direction in between any two levels of support.
    void (*reserved[27])(void);

} hostInterfaces_t;


typedef struct runtimeInterfaces
{
    /** Interface version. */
    uint64_t interfaceVersion;

    /**
     *  @brief Execute CxxTests that may be contained in the image.
     *  @param[in] i_stats pointer to CxxTestStats structure for
     *                     results reporting.
     *  @platform FSP, OpenPOWER
     */
    void (*cxxtestExecute)(void* i_stats);

    /**
     *  @brief Get a list of lid numbers for the lids known to HostBoot
     *  @param[out] o_num the number of lids in the list
     *  @return a pointer to the lid list
     *  @platform FSP
     */
    const uint32_t * (*get_lid_list)(size_t * o_num);

    /**
     * Space allocated for deprecated P8 interfaces
     */
    const uint32_t * (*occ_load__deprecated)(size_t * o_num);
    const uint32_t * (*occ_start__deprecated)(size_t * o_num);
    const uint32_t * (*occ_stop__deprecated)(size_t * o_num);

    /**
     *  @brief Notify HTMGT that an OCC has an error to report
     *
     *  @details  When an OCC has encountered an error that it wants to
     *            be reported, this interface will be called to trigger
     *            HTMGT to collect and commit the error.
     *
     *  @param[in] i_chipId ChipID which identifies the OCC reporting an error
     *  @platform FSP, OpenPOWER
     */
    void (*process_occ_error)(uint64_t i_chipId);

    /**
     *  @brief Enable chip attentions
     *  @return 0 on success else return code
     *  @platform FSP, OpenPOWER
     */
    int (*enable_attns)(void);

    /**
     *  @brief Disable chip attentions
     *  @return 0 on success else return code
     *  @platform FSP, OpenPOWER
     */
    int (*disable_attns)(void);

    /**
     *  @brief handle chip attentions
     *  @param[in] i_proc        processor chip id at attention
     *                           XSCOM chip id based on devtree defn
     *  @param[in] i_ipollStatus processor chip Ipoll status
     *  @param[in] i_ipollMask   processor chip Ipoll mask
     *  @return 0 on success else return code
     *  @platform FSP, OpenPOWER
     */
    int (*handle_attns)( uint64_t i_proc,
                         uint64_t i_ipollStatus,
                         uint64_t i_ipollMask );

    /**
     *  @brief Notify HTMGT that an OCC has failed and needs to be reset
     *
     *  @details  When BMC detects an OCC failure that requires a reset,
     *            this interface will be called to trigger the OCC reset.
     *            HTMGT maintains a reset count and if there are additional
     *            resets available, the OCCs get reset/reloaded.
     *            If the recovery attempts have been exhauseted or the OCC
     *            fails to go active, an unrecoverable error will be logged
     *            and the system will remain in safe mode.
     *
     *  @param[in]  i_chipId  ChipID which identifies the failing OCC
     *  @platform OpenPOWER
     */
    void (*process_occ_reset)(uint64_t  i_chipId);

    /**
     *  @brief Change the OCC state
     *
     *  @details  This is a blocking call that will change the OCC state.
     *            The OCCs will only actuate (update processor frequency/
     *            voltages) when in Active state.  The OCC will only be
     *            monitoring/observing when in Observation state.
     *
     *  @note     When the OCCs are initially started, the state will default
     *            to Active.  If the state is changed to Observation, that
     *            state will be retained until the next IPL. (If the OCC would
     *            get reset, it would return to the last requested state)
     *
     *  @param[in]  i_occ_activation  set to 0 to move OCC to Observation state
     *                           or any other value to move OCC to Active state
     *  @returns  0 on success, or return code if the state did not change
     *  @platform OpenPOWER
     */
    int (*enable_occ_actuation)(int i_occ_activation);

    /**
     * @brief Apply a set of attribute overrides
     * @param[in] i_data pointer to binary override data
     * @param[in] i_size length of override data (bytes)
     * @returns  0 on success, or return code if the command failed
     * @platform FSP, OpenPOWER
     */
    int (*apply_attr_override)(uint8_t* i_data,
                               size_t i_size );

    /**
     *  @brief Send a pass-through command to HTMGT
     *
     *  @details This is a blocking call that will send a command
     *           to HTMGT.
     *  @note   If o_rspLength is returned with a non-zero value,
     *          the data at the o_rspData should be dumped to
     *          stdout in a hex dump format.
     *  @note   The maximum response data returned will be 4096 bytes
     *
     *  @param[in]      i_cmdLength  number of bytes in pass-thru command data
     *  @param[in]   *i_cmdData   pointer to pass-thru command data
     *  @param[out]    *o_rspLength  pointer to number of bytes returned
     *                               in o_rspData
     *  @param[out]    *o_rspData   pointer to a 4096 byte buffer that will
     *                               contain the response data from the command
     *  @returns 0 on success, or return code if the command failed
     *  @platform OpenPOWER
     */
    int (*mfg_htmgt_pass_thru)( uint16_t   i_cmdLength,
                                uint8_t *  i_cmdData,
                                uint16_t * o_rspLength,
                                uint8_t *  o_rspData );

    /**
     *  @brief Execute an arbitrary command inside Hostboot Runtime
     *  @param[in]  argc        number of arguments (standard C args)
     *  @param[in]  argv        array of argument values (standard C args)
     *  @param[out] o_outString response message (NULL terminated), memory
     *                          allocated by hbrt, if o_outString is NULL
     *                          then no response will be sent
     *  @return 0 on success, else error code
     *  @platform FSP, OpenPOWER
     */
    int (*run_command)( int argc,
                        const char** argv,
                        char** o_outString );

    /**
     *  @brief Verify integrity of a secure container
     *  @param[in] i_pContainer Pointer to a valid secure container,
     *      Must not be NULL.  Container is assumed to be stripped of any ECC
     *      and must start with a valid secure header (which contains the
     *      container size information)
     *  @param[in] i_pHwKeyHash Pointer to a valid hardware keys' hash.
     *      Must not be NULL.
     *  @param[in] i_hwKeyHashSize Size of the hardware keys' hash.
     *      A value which incorrectly states the size of the hardware keys' hash
     *      will be detected as a verification error or worse, an illegal memory
     *      access.  Must not be 0.
     *  @note If secureboot is compiled out, the function pointer will be set to
     *      NULL.  If caller's secureboot support is compiled in and secureboot
     *      is enabled by policy, then caller should treat a NULL pointer as a
     *      verification failure.
     *  @return Integer error code indicating success or failure
     *  @retval 0 Container verified correctly
     *  @retval !0 API error or otherwise failed to verify container
     *  @platform FSP, OpenPOWER
     */
    int (*verify_container)(
        const void*  i_pContainer,
        const void*  i_pHwKeyHash,
              size_t i_hwKeyHashSize);

    /**
     *  @brief SBE message passing notification
     *
     *  @details
     *      This is a blocking call that is used to notify HBRT there is
     *      a SBE message available.  This should be called when the Host
     *      detects the appropriate PSU interrupt from the SBE.
     *
     *  @param[in] i_procChipId Chip ID of the processor whose SBE is passing
     *                          the message and sent the interrupt
     *
     *  @return 0 on success, or return code if the command failed
     *  @platform FSP, OpenPOWER
     */
    int (*sbe_message_passing)(uint32_t i_procChipId);

    /**
     *  @brief Load OCC/HCODE images into mainstore
     *
     *  @param[in] i_chip            the HW chip id (XSCOM chip ID)
     *  @param[in] i_homer_addr      the physical mainstore address of the
     *                               start of the HOMER image,
     *  @param[in] i_occ_common_addr the physical mainstore address of the
     *                               OCC common area, 8MB, used for
     *                               OCC-OCC communication (1 per node)
     *  @param[in] i_mode            selects initial load vs concurrent reloads
     *                               HBRT_PM_LOAD:
     *                                  load all lids/sections from scratch,
     *                                  preserve nothing
     *                               HBRT_PM_RELOAD:
     *                                  reload all lids/sections,
     *                                  but preserve runtime updates
     *  @return 0 on success else return code
     *  @platform FSP, OpenPOWER
     */
    int (*load_pm_complex)( uint64_t i_chip,
                            uint64_t i_homer_addr,
                            uint64_t i_occ_common_addr,
                            uint32_t i_mode );

    /**
     *  @brief Start OCC/HCODE on the specified chip
     *  @param[in] i_chip the HW chip id
     *  @return 0 on success else return code
     *  @platform FSP, OpenPOWER
     */
    int (*start_pm_complex)( uint64_t i_chip );

    /**
     *  @brief Reset OCC/HCODE on the specified chip
     *  @param[in] i_chip the HW chip id
     *  @return 0 on success else return code
     *  @platform FSP, OpenPOWER
     */
    int (*reset_pm_complex)( uint64_t i_chip );

    /**
     * @brief Query the IPOLL event mask supported by HBRT
     *
     * @details  This call allows the wrapper application to query
     * the ipoll event mask to set when the HBRT instance is running. Bits
     * that are *set* in this bitmask represent events that will be
     * forwarded to the handle_attn() callback.
     *
     * @return        The IPOLL event bits to enable during HBRT execution
     * @platform FSP, OpenPOWER
     */
    uint64_t (*get_ipoll_events)( void );

    /**
     * @brief Receive an async notification from firmware
     * @param[in] i_len   length of notification data
     * @param[in] i_data  notification data
     * @platform FSP, OpenPOWER
     */
    void (*firmware_notify)( uint64_t len,
                             void *data );

    /**
     *  @brief Prepare for HBRT concurrent code update
     *
     *  @details  This call allows the Host to inform HBRT that a concurrent
     *  code update has been initiated.  HBRT then prepares updated targeting
     *  data for use by the updated HBRT code.
     *
     *  @return        0 on success else return code
     *  @platform FSP
     */
    int (*prepare_hbrt_update)( void );

    // Reserve some space for future growth.
    // Currently are decrementing this number as we add functions.
    //
    // The initial value of 32 was somewhat arbitrarily chosen.
    //
    // If either side modifies the interface.h file we're suppose to be able to
    // tolerate the other side not supporting the function yet.  The function
    // pointer can be NULL.  So if we require a new interface from OPAL, like
    // "read_iic", we need to be able to tolerate that function pointer being
    // NULL and do something sane (and erroring out is not consider sane).
    //
    // The purpose of this is to give us the ability to update Hostboot and
    // OPAL independently.  It is pretty rare that we both have function ready
    // at the same time.  The "reserve" is there so that the structures are
    // allocated with sufficient space and populated with NULL function
    // pointers.  32 is big enough that we should not likely add that many
    // functions from either direction in between any two levels of support.
    void (*reserved[21])(void);

} runtimeInterfaces_t;


// For internal use. These routines are to be called after all other set up
// is complete.
// This approach is taken due to complication with linking to rt_main, the
// order of static global initializers, constructors, and vfs_module_init.

#ifdef __HOSTBOOT_RUNTIME
struct postInitCalls_t
{
    /**
     * @brief Apply ATTR_TMP overrides
     *
     */
    void (*callApplyTempOverrides)();

    /**
     * @brief Calls RtPnor::init() which loads section(s) into memory
     *        so PRD can access when PNOR is not accessible
     */
    void (*callInitPnor)();


    /**
     * @brief Sets up ErrlManager so it is ready for errors
     *
     */
    void (*callInitErrlManager)();

    /**
     * @brief Clear pending SBE messages
     *
     */
    void (*callClearPendingSbeMsgs)();

    /**
     * @brief Clear pending OCC messages
     *
     */
    void (*callClearPendingOccMsgs)();

    /** @brief Calls RsvdTraceBufService::init() which maps
     *      the Reserved Memory section to the circular buffer, which will keep
     *      track of all runtime traces
     */
    void (*callInitRsvdTraceBufService)();

    /** @brief Calls RsvdTraceBufService::commitRsvdMemTraceErrl(), which commits
     *      the ERRL with Rsved Mem Traces from previous boot, if created in
     *      RsvdTraceBufService::init()
     */
    void (*callCommitRsvdTraceBufErrl)();

};

extern hostInterfaces_t* g_hostInterfaces;
runtimeInterfaces_t* getRuntimeInterfaces();
postInitCalls_t* getPostInitCalls();
#endif

#endif //__HOSTBOOT_RUNTIME_INTERFACE_VERSION_ONLY
#endif //__RUNTIME__INTERFACE_H
