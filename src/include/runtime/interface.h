/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/include/runtime/interface.h $                             */
/*                                                                        */
/* OpenPOWER HostBoot Project                                             */
/*                                                                        */
/* Contributors Listed Below - COPYRIGHT 2013,2015                        */
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
/** Current interface version. */
#define HOSTBOOT_RUNTIME_INTERFACE_VERSION 1
#ifndef __HOSTBOOT_RUNTIME_INTERFACE_VERSION_ONLY

#include <stdint.h>
#include <time.h>

/** Memory error types defined for memory_error() interface. */
enum MemoryError_t
{
    /** Hardware has reported a solid memory CE that is correctable, but
     *  continues to report errors on subsequent reads. A second CE on that
     *  cache line will result in memory UE. Therefore, it is advised to migrate
     *  off of the address range as soon as possible. */
    MEMORY_ERROR_CE,

    /** Hardware has reported an uncorrectable error in memory (memory UE,
     *  channel failure, etc). The hypervisor should migrate any partitions off
     *  this address range as soon as possible. Note that these kind of errors
     *  will most likely result in partition failures. It is advised that the
     *  hypervisor waits some time for PRD to handle hardware attentions so that
     *  the hypervisor will know all areas of memory that are impacted by the
     *  failure. */
    MEMORY_ERROR_UE,
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

    /** Put a string to the console. */
    void (*puts)(const char*);
    /** Critical failure in runtime execution. */
    void (*assert)();

    /** OPTIONAL. Hint to environment that the page may be executed. */
    int (*set_page_execute)(void*);

    /** malloc */
    void* (*malloc)(size_t);
    /** free */
    void (*free)(void*);
    /** realloc */
    void* (*realloc)(void*, size_t);

    /** sendErrorLog
     * @param[in] plid Platform Log identifier
     * @param[in] data size in bytes
     * @param[in] pointer to data
     * @return 0 on success else error code
     */
    int (*sendErrorLog)(uint32_t,uint32_t,void *);

    /** Scan communication read
     * @param[in] chip_id (based on devtree defn)
     * @param[in] address
     * @param[in] pointer to 8-byte data buffer
     * @return 0 on success else return code
     */
    int (*scom_read)(uint64_t, uint64_t, void*);

    /** Scan communication write
     * @param[in] chip_id (based on devtree defn)
     * @param[in] address
     * @param[in] pointer to 8-byte data buffer
     * @return 0 on success else return code
     */
    int (*scom_write)(uint64_t, uint64_t, void* );

    /** lid_load
     *  Load a LID from PNOR, FSP, etc.
     *
     *  @param[in] LID number.
     *  @param[out] Allocated buffer for LID.
     *  @param[out] Size of LID (in bytes).
     *
     *  @return 0 on success, else RC.
     */
    int (*lid_load)(uint32_t, void**, size_t*);

    /** lid_unload
     *  Release memory from previously loaded LID.
     *
     *  @param[in] Allocated buffer for LID to release.
     *
     *  @return 0 on success, else RC.
     */
    int (*lid_unload)(void*);

    /** Get the address of a reserved memory region by its devtree name.
     *
     *  @param[in] Devtree name (ex. "ibm,hbrt-vpd-image")
     *  @return physical address of region (or NULL).
     **/
    uint64_t (*get_reserved_mem)(const char*);

    /**
     * @brief  Force a core to be awake, or clear the force
     * @param[in] i_core  Core to wake (based on devtree defn)
     * @param[in] i_mode  0=force awake
     *                    1=clear force
     *                    2=clear all previous forces
     * @return rc non-zero on error
     */
    int (*wakeup)(uint32_t i_core, uint32_t i_mode );

    /**
     * @brief Delay/sleep for at least the time given
     * @param[in] seconds
     * @param[in] nano seconds
     */
    void (*nanosleep)(uint64_t i_seconds, uint64_t i_nano_seconds);

    /**
     * @brief Report an OCC error to the host
     * @param[in] Failing status that identifies the nature of the fail
     * @param[in] Identifier that specifies the failing part
     * @platform FSP
     */
    void (*report_failure)( uint64_t i_status, uint64_t i_partId );

    /**
     *  @brief Reads the clock value from a POSIX clock.
     *  @param[in]  i_clkId - The clock ID to read.
     *  @param[out] o_tp - The timespec struct to store the clock value in.
     *
     *  @return 0 or -(errno).
     *  @retval 0 - SUCCESS.
     *  @retval -EINVAL - Invalid clock requested.
     *  @retval -EFAULT - NULL ptr given for timespec struct.
     *
     */
    int (*clock_gettime)(clockid_t i_clkId, timespec_t* o_tp);

    /**
     * @brief Read Pnor
     * @param[in] i_proc: processor Id
     * @param[in] i_partitionName: name of the partition to read
     * @param[in] i_offset: offset within the partition
     * @param[out] o_data: pointer to the data read
     * @param[in] i_sizeBytes: size of data to read
     * @retval rc - non-zero on error
     */
    int (*pnor_read) (uint32_t i_proc, const char* i_partitionName,
                   uint64_t i_offset, void* o_data, size_t i_sizeBytes);

    /**
     * @brief Write to Pnor
     * @param[in] i_proc: processor Id
     * @param[in] i_partitionName: name of the partition to write
     * @param[in] i_offset: offset withing the partition
     * @param[in] i_data: pointer to the data to write
     * @param[in] i_sizeBytes: size of data to write
     * @retval rc - non-zero on error
     */
    int (*pnor_write) (uint32_t i_proc, const char* i_partitionName,
                   uint64_t i_offset, void* i_data, size_t i_sizeBytes);


    /**
     * @brief Read data from an i2c device
     * @param[in] i_master - chip, engine and port packed into
     *    a single 64-bit argument
     *    ---------------------------------------------------
     *    |         chip         |  reserved  |  eng | port |
     *    |         (32)         |    (16)    |  (8) | (8)  |
     *    ---------------------------------------------------
     * @param[in] i_devAddr - I2C address of device
     * @param[in] i_offsetSize - Length of offset (in bytes)
     * @param[in] i_offset - Offset within device to read
     * @param[in] i_length - Number of bytes to read
     * @param[out] o_data - Data that was read
     * @return 0 on success else return code
     * @platform OpenPOWER
     */
    int (*i2c_read)( uint64_t i_master, uint16_t i_devAddr,
                     uint32_t i_offsetSize, uint32_t i_offset,
                     uint32_t i_length, void* o_data );

    /**
     * @brief Write data to an i2c device
     * @param[in] i_master - chip, engine and port packed into
     *    a single 64-bit argument
     *    ---------------------------------------------------
     *    |         chip         |  reserved  |  eng | port |
     *    |         (32)         |    (16)    |  (8) | (8)  |
     *    ---------------------------------------------------
     * @param[in] i_devAddr - I2C address of device
     * @param[in] i_offsetSize - Length of offset (in bytes)
     * @param[in] i_offset - Offset within device to write
     * @param[in] i_length - Number of bytes to write
     * @param[in] Data to write
     * @return 0 on success else return code
     * @platform OpenPOWER
     */
    int (*i2c_write)( uint64_t i_master, uint16_t i_devAddr,
                      uint32_t i_offsetSize, uint32_t i_offset,
                      uint32_t i_length, void* i_data );

    /**
     * @brief Perform an IPMI transaction
     * @param[in] netfn The IPMI netfn byte
     * @param[in] cmd The IPMI cmd byte
     * @param[in] tx_buf The IPMI packet to send to the host
     * @param[in] tx_size The number of bytes to send
     * @param[in] rx_buf A buffer to be populated with the IPMI
     *                       response. First bytes will be the
     *                       IPMI completion code.
     * @param[inout] rx_size The allocated size of the rx buffer on input
     *                       updated to the size of the response on output.
     * @retval rc - non-zero on error
     * @platform OpenPower
     */
    int (*ipmi_msg)(uint8_t netfn, uint8_t cmd,
                    void *tx_buf, size_t tx_size,
                    void *rx_buf, size_t *rx_size);


    /**
     * @brief Hardware has reported a memory error. This function requests the
     *        hypervisor to remove the all addresses within the address range given
     *        (including endpoints) from the available memory space.
     *
     * It is understood that the hypervisor may not be able to immediately
     * deallocate the memory because it may be in use by a partition. Therefore, the
     * hypervisor should cache all requests and deallocate the memory once it has
     * been freed.
     *
     * @param  i_startAddr The beginning address of the range.
     * @param  i_endAddr   The end address of the range.
     * @param  i_errorType See enum MemoryError_t.
     *
     * @return 0 if the request is successfully received. Any value other than 0 on
     *         failure. The hypervisor should cache the request and return
     *         immediately. It should not wait for the request to be applied. See
     *         note above.
     */
    int32_t (*memory_error)( uint64_t i_startAddr, uint64_t i_endAddr,
                             MemoryError_t i_errorType );


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
    void (*reserved[32])(void);

} hostInterfaces_t;

typedef struct runtimeInterfaces
{
    /** Interface version. */
    uint64_t interfaceVersion;

    /** Execute CxxTests that may be contained in the image.
     *
     *  @param[in] - Pointer to CxxTestStats structure for results reporting.
     */
    void (*cxxtestExecute)(void*);

    /** Get a list of lids numbers of the lids known to HostBoot
     *
     * @param[out] o_num - the number of lids in the list
     * @return a pointer to the list
     */
    const uint32_t * (*get_lid_list)(size_t * o_num);

    /** Load OCC Image and common data into mainstore, also setup OCC BARSs
     *
     * @param[in] i_homer_addr_phys - The physical mainstore address of the
     *                                start of the HOMER image
     * @param[in] i_homer_addr_va - Virtual memory address of the HOMER image
     * @param[in] i_common_addr_phys - The physical mainstore address of the
     *                                 OCC common area.
     * @param[in] i_common_addr_va - Virtual memory address of the common area
     * @param[in] i_chip - XSCOM chip id of processor based on devtree defn
     * @return 0 on success else return code
     */
    int(*occ_load)(uint64_t i_homer_addr_phys,
                  uint64_t i_homer_addr_va,
                  uint64_t i_common_addr_phys,
                  uint64_t i_common_addr_va,
                  uint64_t i_chip);

    /** Start OCC on all chips, by module
     *
     *  @param[in] i_chip - Array of functional processor chip ids
     *                      XSCOM chip id based on devtree defn
     *  @Note The caller must include a complete modules worth of chips
     *  @param[in] i_num_chips - Number of chips in the array
     *  @return 0 on success else return code
     */
    int (*occ_start)(uint64_t* i_chip,
                     size_t i_num_chips);

    /** Stop OCC hold OCCs in reset
     *
     *  @param[in] i_chip - Array of functional processor chip ids
     *                      XSCOM chip id based on devtree defn
     *  @Note The caller must include a complete modules worth of chips
     *  @param[in] i_num_chips - Number of chips in the array
     *  @return 0 on success else return code
     */
    int (*occ_stop)(uint64_t* i_chip,
                    size_t i_num_chips);

    /**
     * @brief Notify HTMGT that an OCC has an error to report
     *
     * @details  When an OCC has encountered an error that it wants to
     *           be reported, this interface will be called to trigger
     *           HTMGT to collect and commit the error.
     *
     * @param[in]  i_chipId  ChipID which identifies the OCC reporting an error
     */
    void (*process_occ_error)(uint64_t  i_chipId);

    /** Enable chip attentions
     *
     *  @return 0 on success else return code
     */
    int (*enable_attns)(void);

    /** Disable chip attentions
     *
     *  @return 0 on success else return code
     */
    int (*disable_attns)(void);

    /** brief handle chip attentions
     *
     *  @param[in] i_proc - processor chip id at attention
     *                      XSCOM chip id based on devtree defn
     *  @param[in] i_ipollStatus - processor chip Ipoll status
     *  @param[in] i_ipollMask   - processor chip Ipoll mask
     *  @return 0 on success else return code
     */
    int (*handle_attns)(uint64_t i_proc,
                        uint64_t i_ipollStatus,
                        uint64_t i_ipollMask);

    /**
     * @brief Notify HTMGT that an OCC has failed and needs to be reset
     *
     * @details  When BMC detects an OCC failure that requires a reset,
     *           this interface will be called to trigger the OCC reset.
     *           HTMGT maintains a reset count and if there are additional
     *           resets available, the OCCs get reset/reloaded.
     *           If the recovery attempts have been exhauseted or the OCC
     *           fails to go active, an unrecoverable error will be logged
     *           and the system will remain in safe mode.
     *
     * @param[in]  i_chipId  ChipID which identifies the failing OCC
     */
    void (*process_occ_reset)(uint64_t  i_chipId);

    /**
     * @brief Change the OCC state
     *
     * @details  This is a blocking call that will change the OCC state.
     *           The OCCs will only actuate (update processor frequency/
     *           voltages) when in Active state.  The OCC will only be
     *           monitoring/observing when in Observation state.
     *
     * @note     When the OCCs are initially started, the state will default
     *           to Active.  If the state is changed to Observation, that
     *           state will be retained until the next IPL. (If the OCC would
     *           get reset, it would return to the last requested state)
     *
     *
     * @param[in]  i_occ_activation  set to 0 to move OCC to Observation state
     *                          or any other value to move OCC to Active state
     *
     * @returns  0 on success, or return code if the state did not
     *           change.
     */
    int (*enable_occ_actuation)(int i_occ_activation);

    // Reserve some space for future growth.
    void (*reserved[32])(void);

} runtimeInterfaces_t;

#ifdef __HOSTBOOT_RUNTIME
extern hostInterfaces_t* g_hostInterfaces;
runtimeInterfaces_t* getRuntimeInterfaces();
#endif

#endif //__HOSTBOOT_RUNTIME_INTERFACE_VERSION_ONLY
#endif //__RUNTIME__INTERFACE_H
