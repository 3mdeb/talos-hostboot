#!/usr/bin/perl
# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/usr/targeting/common/genHwsvMrwXml.pl $
#
# OpenPOWER HostBoot Project
#
# Contributors Listed Below - COPYRIGHT 2013,2016
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
#
# Usage:
#
# genHwsvMrwXml.pl --system=systemname --mrwdir=pathname
#                  [--build=hb] [--outfile=XmlFilename]
#        --system=systemname
#              Specify which system MRW XML to be generated
#        --systemnodes=systemnodesinbrazos
#              Specify number of nodes for brazos system, by default it is 4
#        --mrwdir=pathname
#              Specify the complete dir pathname of the MRW. Colon-delimited
#              list accepted to specify multiple directories to search.
#        --build=hb
#              Specify HostBoot build (hb)
#        --outfile=XmlFilename
#              Specify the filename for the output XML. If omitted, the output
#              is written to STDOUT which can be saved by redirection.
#
# Purpose:
#
#   This perl script processes the various xml files of the MRW to
#   extract the needed information for generating the final xml file.
#
use strict;
use XML::Simple;
use Data::Dumper;

# Enables the state variable feature
use feature "state";

################################################################################
# Set PREFERRED_PARSER to XML::Parser. Otherwise it uses XML::SAX which contains
# bugs that result in XML parse errors that can be fixed by adjusting white-
# space (i.e. parse errors that do not make sense).
################################################################################
$XML::Simple::PREFERRED_PARSER = 'XML::Parser';

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------
use constant CHIP_NODE_INDEX => 0; # Position in array of chip's node
use constant CHIP_POS_INDEX => 1; # Position in array of chip's position
use constant CHIP_ATTR_START_INDEX => 2; # Position in array of start of attrs

use constant
{
    MAX_PROC_PER_NODE => 8,
    MAX_CORE_PER_PROC => 24,
    MAX_EX_PER_PROC => 12,
    MAX_EQ_PER_PROC => 6,
    MAX_ABUS_PER_PROC => 3,
    MAX_XBUS_PER_PROC => 3,
    MAX_MCS_PER_PROC => 4,
    MAX_MCA_PER_PROC => 8,
    MAX_MCBIST_PER_PROC => 2,
    MAX_PEC_PER_PROC => 3,    # PEC is same as PBCQ
    MAX_PHB_PER_PROC => 6,    # PHB is same as PCIE
    MAX_MBA_PER_MEMBUF => 2,
    MAX_OBUS_PER_PROC => 4,
    MAX_PPE_PER_PROC => 51,   #Only 21, but they are sparsely populated
    MAX_PERV_PER_PROC => 56,  #Only 42, but they are sparsely populated
    MAX_CAPP_PER_PROC => 2,
    MAX_SBE_PER_PROC => 1,
    MAX_NV_PER_PROC => 1,     # FW only for GARD purposes
    MAX_MI_PER_PROC => 4,
};

# Architecture limits, for the purpose of calculating FAPI_POS.
# This sometimes differs subtley from the max constants above
# due to trying to account for worst case across all present and
# future designs for a processor generation, as well as to account for
# holes in the mapping.  It is also more geared towards parent/child
# maxes. Some constants pass through to the above.
use constant
{
    ARCH_LIMIT_DIMM_PER_MCA => 2,
    ARCH_LIMIT_DIMM_PER_MBA => 4,
    # Note: this is proc per fabric group, vs. physical node
    ARCH_LIMIT_PROC_PER_FABRIC_GROUP => 8,
    ARCH_LIMIT_MEMBUF_PER_DMI => 1,
    ARCH_LIMIT_EX_PER_EQ => MAX_EX_PER_PROC / MAX_EQ_PER_PROC,
    ARCH_LIMIT_MBA_PER_MEMBUF => MAX_MBA_PER_MEMBUF,
    ARCH_LIMIT_MCS_PER_PROC => MAX_MCS_PER_PROC,
    ARCH_LIMIT_XBUS_PER_PROC => MAX_XBUS_PER_PROC,
    ARCH_LIMIT_ABUS_PER_PROC => MAX_ABUS_PER_PROC,
    ARCH_LIMIT_L4_PER_MEMBUF => 1,
    ARCH_LIMIT_CORE_PER_EX => MAX_CORE_PER_PROC / MAX_EX_PER_PROC,
    ARCH_LIMIT_EQ_PER_PROC => MAX_EQ_PER_PROC,
    ARCH_LIMIT_MCA_PER_MCS => MAX_MCA_PER_PROC / MAX_MCS_PER_PROC,
    ARCH_LIMIT_MCBIST_PER_PROC => MAX_MCBIST_PER_PROC,
    ARCH_LIMIT_MI_PER_PROC => MAX_MI_PER_PROC,
    ARCH_LIMIT_CAPP_PER_PROC => MAX_CAPP_PER_PROC,
    ARCH_LIMIT_DMI_PER_MI => 2,
    ARCH_LIMIT_OBUS_PER_PROC => MAX_OBUS_PER_PROC,
    ARCH_LIMIT_NV_PER_PROC => MAX_NV_PER_PROC,
    ARCH_LIMIT_SBE_PER_PROC => MAX_SBE_PER_PROC,
    # There are 20+ PPE, but lots of holes in the mapping.   Further the
    # architecture supports potentially many more PPEs.  So, for now we'll pick
    # power of 2 value larger than largest pervasive unit of 50
    ARCH_LIMIT_PPE_PER_PROC => 64,
    # Pervasives are numbered 1..55.  0 Is not possible but acts as a hole.
    # Some pervasives within the range are holes as well
    ARCH_LIMIT_PERV_PER_PROC => 56,
    ARCH_LIMIT_PEC_PER_PROC => MAX_PEC_PER_PROC,
    # There are only 6 PHBs per chip, but they are unbalanced across the 3
    # PECs.  To make the math easy, we'll assume there are potentially 3 PHBs
    # per PEC, but PEC0 and PEC1 will have 2 and 1 holes respectively
    ARCH_LIMIT_PHB_PER_PEC => 3,
};

# for SPI connections in the @SPIs array
use constant SPI_PROC_PATH_FIELD => 0;
use constant SPI_NODE_FIELD => 1;
use constant SPI_POS_FIELD  => 2;
use constant SPI_ENDPOINT_PATH_FIELD => 3;
use constant SPI_APSS_POS_FIELD => 4;
use constant SPI_APSS_ORD_FIELD => 5;
use constant SPI_APSS_RID_FIELD => 6;

our $mrwdir = "";
my $sysname = "";
my $sysnodes = "";
my $usage = 0;
my $DEBUG = 0;
my $outFile = "";
my $build = "fsp";

use Getopt::Long;
GetOptions( "mrwdir:s"  => \$mrwdir,
            "system:s"  => \$sysname,
            "systemnodes:s"  => \$sysnodes,
            "outfile:s" => \$outFile,
            "build:s"   => \$build,
            "DEBUG"     => \$DEBUG,
            "help"      => \$usage, );

if ($usage || ($mrwdir eq ""))
{
    display_help();
    exit 0;
}

our %hwsvmrw_plugins;
# FSP-specific functions
if ($build eq "fsp")
{
    eval("use genHwsvMrwXml_fsp; return 1;");
    genHwsvMrwXml_fsp::return_plugins();
}

if ($outFile ne "")
{
    open OUTFILE, '+>', $outFile ||
                die "ERROR: unable to create $outFile\n";
    select OUTFILE;
}

my $SYSNAME = uc($sysname);
my $CHIPNAME = "";
my $MAXNODE = 0;
if ($sysname =~ /brazos/)
{
    $MAXNODE = 4;
}

my $NODECONF = "";
if( ($sysnodes) && ($sysnodes =~ /2/) )
{
    $NODECONF = "2-node";
}
else
{
    $NODECONF = "3-and-4-node";
}

my $mru_ids_file = open_mrw_file($mrwdir, "${sysname}-mru-ids.xml");
my $mruAttr = parse_xml_file($mru_ids_file);
#------------------------------------------------------------------------------
# Process the system-policy MRW file
#------------------------------------------------------------------------------
my $system_policy_file = open_mrw_file($mrwdir, "${sysname}-system-policy.xml");
my $sysPolicy = parse_xml_file($system_policy_file,
    forcearray=>['proc_r_loadline_vdd','proc_r_distloss_vdd',
        'proc_vrm_voffset_vdd','proc_r_loadline_vcs','proc_r_distloss_vcs',
        'proc_vrm_voffset_vcs']);

my $reqPol = $sysPolicy->{"required-policy-settings"};

my @systemAttr; # Repeated {ATTR, VAL, ATTR, VAL, ATTR, VAL...}
my @nodeAttr; # Repeated {ATTR, VAL, ATTR, VAL, ATTR, VAL...}

#No mirroring supported yet so the policy is just based on multi-node or not
my $placement = 0x0; #NORMAL
if ($sysname =~ /brazos/)
{
    $placement = 0x3; #DRAWER
}

push @systemAttr,
[
    "FREQ_PROC_REFCLOCK", $reqPol->{'processor-refclock-frequency'}->{content},
    "FREQ_PROC_REFCLOCK_KHZ",
        $reqPol->{'processor-refclock-frequency-khz'}->{content},
    "FREQ_MEM_REFCLOCK", $reqPol->{'memory-refclock-frequency'}->{content},
    "BOOT_FREQ_MHZ", $reqPol->{'boot-frequency'}->{content},
    "FREQ_A_MHZ", $reqPol->{'proc_a_frequency'}->{content},
    "FREQ_PB_MHZ", $reqPol->{'proc_pb_frequency'}->{content},
    "ASYNC_NEST_FREQ_MHZ", $reqPol->{'proc_pb_frequency'}->{content},
    "FREQ_PCIE_MHZ", $reqPol->{'proc_pcie_frequency'}->{content},
    "FREQ_X_MHZ", $reqPol->{'proc_x_frequency'}->{content},
    "MSS_MBA_ADDR_INTERLEAVE_BIT", $reqPol->{'mss_mba_addr_interleave_bit'},
    "MSS_MBA_CACHELINE_INTERLEAVE_MODE",
        $reqPol->{'mss_mba_cacheline_interleave_mode'},
    "PROC_EPS_TABLE_TYPE", $reqPol->{'proc_eps_table_type'},
    "PROC_FABRIC_PUMP_MODE", $reqPol->{'proc_fabric_pump_mode'},
    "PROC_X_BUS_WIDTH", $reqPol->{'proc_x_bus_width'},
    "X_EREPAIR_THRESHOLD_FIELD", $reqPol->{'x-erepair-threshold-field'},
    "A_EREPAIR_THRESHOLD_FIELD", $reqPol->{'a-erepair-threshold-field'},
    "DMI_EREPAIR_THRESHOLD_FIELD", $reqPol->{'dmi-erepair-threshold-field'},
    "X_EREPAIR_THRESHOLD_MNFG", $reqPol->{'x-erepair-threshold-mnfg'},
    "A_EREPAIR_THRESHOLD_MNFG", $reqPol->{'a-erepair-threshold-mnfg'},
    "DMI_EREPAIR_THRESHOLD_MNFG", $reqPol->{'dmi-erepair-threshold-mnfg'},
    "MRW_SAFEMODE_MEM_THROTTLE_NUMERATOR_PER_MBA",
        $reqPol->{'safemode_mem_throttle_numerator_per_mba'},
    "MRW_SAFEMODE_MEM_THROTTLE_NUMERATOR_PER_CHIP",
        $reqPol->{'safemode_mem_throttle_numerator_per_chip'},
    "MSS_MRW_THERMAL_MEMORY_POWER_LIMIT", $reqPol->{'thermal_memory_power_limit'},
    "MSS_MBA_ADDR_INTERLEAVE_BIT", $reqPol->{'mss_mba_addr_interleave_bit'},
    "MSS_MBA_CACHELINE_INTERLEAVE_MODE", $reqPol->{'mss_mba_cacheline_interleave_mode'},
    "PM_EXTERNAL_VRM_STEPSIZE", $reqPol->{'pm_external_vrm_stepsize'},
    "PM_EXTERNAL_VRM_STEPDELAY", $reqPol->{'pm_external_vrm_stepdelay'},
    "PM_SPIVID_FREQUENCY", $reqPol->{'pm_spivid_frequency'}->{content},
    "PM_SAFE_FREQUENCY", $reqPol->{'pm_safe_frequency'}->{content},
    "PM_RESONANT_CLOCK_FULL_CLOCK_SECTOR_BUFFER_FREQUENCY",
        $reqPol->{'pm_resonant_clock_full_clock_sector_buffer_frequency'}->
            {content},
    "PM_RESONANT_CLOCK_LOW_BAND_LOWER_FREQUENCY",
        $reqPol->{'pm_resonant_clock_low_band_lower_frequency'}->{content},
    "PM_RESONANT_CLOCK_LOW_BAND_UPPER_FREQUENCY",
        $reqPol->{'pm_resonant_clock_low_band_upper_frequency'}->{content},
    "PM_RESONANT_CLOCK_HIGH_BAND_LOWER_FREQUENCY",
        $reqPol->{'pm_resonant_clock_high_band_lower_frequency'}->{content},
    "PM_RESONANT_CLOCK_HIGH_BAND_UPPER_FREQUENCY",
        $reqPol->{'pm_resonant_clock_high_band_upper_frequency'}->{content},
    "PM_SPIPSS_FREQUENCY", $reqPol->{'pm_spipss_frequency'}->{content},
    "MEM_MIRROR_PLACEMENT_POLICY", $placement,
    "MSS_MRW_DIMM_POWER_CURVE_PERCENT_UPLIFT",
        $reqPol->{'dimm_power_curve_percent_uplift'},
    "MSS_MRW_DIMM_POWER_CURVE_PERCENT_UPLIFT_IDLE",
        $reqPol->{'dimm_power_curve_percent_uplift_idle'},
    "MRW_MEM_THROTTLE_DENOMINATOR",
        $reqPol->{'mem_throttle_denominator'},
    "MSS_MRW_MAX_DRAM_DATABUS_UTIL",
        $reqPol->{'max_dram_databus_util'},
    "MRW_CDIMM_MASTER_I2C_TEMP_SENSOR_ENABLE",
        $reqPol->{'cdimm_master_i2c_temp_sensor_enable'},
    "MRW_CDIMM_SPARE_I2C_TEMP_SENSOR_ENABLE",
        $reqPol->{'cdimm_spare_i2c_temp_sensor_enable'},
    "MSS_MRW_VMEM_REGULATOR_POWER_LIMIT_PER_DIMM_ADJ_ENABLE",
        $reqPol->{'vmem_regulator_memory_power_limit_per_dimm_adjustment_enable'},
    "MSS_MRW_MAX_NUMBER_DIMMS_POSSIBLE_PER_VMEM_REGULATOR",
        $reqPol->{'max_number_dimms_possible_per_vmem_regulator'},
    "MRW_VMEM_REGULATOR_MEMORY_POWER_LIMIT_PER_DIMM",
        $reqPol->{'vmem_regulator_memory_power_limit_per_dimm'},
    "PM_SYSTEM_IVRMS_ENABLED", $reqPol->{'pm_system_ivrms_enabled'},
    "PM_SYSTEM_IVRM_VPD_MIN_LEVEL", $reqPol->{'pm_system_ivrm_vpd_min_level'},
    "MRW_ENHANCED_GROUPING_NO_MIRRORING", $reqPol->{'mcs_enhanced_grouping_no_mirroring'},
    "MRW_STRICT_MBA_PLUG_RULE_CHECKING", $reqPol->{'strict_mba_plug_rule_checking'},
    "MNFG_DMI_MIN_EYE_WIDTH", $reqPol->{'mnfg-dmi-min-eye-width'},
    "MNFG_DMI_MIN_EYE_HEIGHT", $reqPol->{'mnfg-dmi-min-eye-height'},
    "MNFG_ABUS_MIN_EYE_WIDTH", $reqPol->{'mnfg-abus-min-eye-width'},
    "MNFG_ABUS_MIN_EYE_HEIGHT", $reqPol->{'mnfg-abus-min-eye-height'},
    "MNFG_XBUS_MIN_EYE_WIDTH", $reqPol->{'mnfg-xbus-min-eye-width'},
    "REDUNDANT_CLOCKS", $reqPol->{'redundant-clocks'},
    "MSS_DRAMINIT_RESET_DISABLE", $reqPol->{'mss_draminit_reset_disable'},
    "MSS_MRW_POWER_CONTROL_REQUESTED", (uc $reqPol->{'mem_power_control_usage'}),
    "MNFG_TH_P8EX_L2_CACHE_CES", $reqPol->{'mnfg_th_p8ex_l2_cache_ces'},
    "MNFG_TH_P8EX_L2_DIR_CES", $reqPol->{'mnfg_th_p8ex_l2_dir_ces'},
    "MNFG_TH_P8EX_L3_CACHE_CES", $reqPol->{'mnfg_th_p8ex_l3_cache_ces'},
    "MNFG_TH_P8EX_L3_DIR_CES", $reqPol->{'mnfg_th_p8ex_l3_dir_ces'},
    "FIELD_TH_P8EX_L2_LINE_DELETES", $reqPol->{'field_th_p8ex_l2_line_deletes'},
    "FIELD_TH_P8EX_L3_LINE_DELETES", $reqPol->{'field_th_p8ex_l3_line_deletes'},
    "FIELD_TH_P8EX_L2_COL_REPAIRS", $reqPol->{'field_th_p8ex_l2_col_repairs'},
    "FIELD_TH_P8EX_L3_COL_REPAIRS", $reqPol->{'field_th_p8ex_l3_col_repairs'},
    "MNFG_TH_P8EX_L2_LINE_DELETES", $reqPol->{'mnfg_th_p8ex_l2_line_deletes'},
    "MNFG_TH_P8EX_L3_LINE_DELETES", $reqPol->{'mnfg_th_p8ex_l3_line_deletes'},
    "MNFG_TH_P8EX_L2_COL_REPAIRS", $reqPol->{'mnfg_th_p8ex_l2_col_repairs'},
    "MNFG_TH_P8EX_L3_COL_REPAIRS", $reqPol->{'mnfg_th_p8ex_l3_col_repairs'},
    "MNFG_TH_CEN_MBA_RT_SOFT_CE_TH_ALGO",
                                $reqPol->{'mnfg_th_cen_mba_rt_soft_ce_th_algo'},
    "MNFG_TH_CEN_MBA_IPL_SOFT_CE_TH_ALGO",
                               $reqPol->{'mnfg_th_cen_mba_ipl_soft_ce_th_algo'},
    "MNFG_TH_CEN_MBA_RT_RCE_PER_RANK",
                                   $reqPol->{'mnfg_th_cen_mba_rt_rce_per_rank'},
    "MNFG_TH_CEN_L4_CACHE_CES", $reqPol->{'mnfg_th_cen_l4_cache_ces'},
    "OPT_MEMMAP_GROUP_POLICY", $reqPol->{'memmap_group_policy'},
    "BRAZOS_RX_FIFO_OVERRIDE", $reqPol->{'rx_fifo_final_l2u_dly_override'},
];

my %procLoadline = ();
$procLoadline{PROC_R_LOADLINE_VDD}{sys}  = $reqPol->{'proc_r_loadline_vdd' }[0];
$procLoadline{PROC_R_DISTLOSS_VDD}{sys}  = $reqPol->{'proc_r_distloss_vdd' }[0];
$procLoadline{PROC_VRM_VOFFSET_VDD}{sys} = $reqPol->{'proc_vrm_voffset_vdd'}[0];
$procLoadline{PROC_R_LOADLINE_VCS}{sys}  = $reqPol->{'proc_r_loadline_vcs' }[0];
$procLoadline{PROC_R_DISTLOSS_VCS}{sys}  = $reqPol->{'proc_r_distloss_vcs' }[0];
$procLoadline{PROC_VRM_VOFFSET_VCS}{sys} = $reqPol->{'proc_vrm_voffset_vcs'}[0];

my $optPol = $sysPolicy->{"optional-policy-settings"};
if(defined $optPol->{'loadline-overrides'})
{
    foreach my $attr (keys %procLoadline)
    {
        my $mrwPolicy = lc $attr;
        foreach my $pol (@ {$optPol->{'loadline-overrides'}{$mrwPolicy}} )
        {
            if(defined $pol->{target})
            {
                if(defined $procLoadline{$attr}{ $pol->{target} })
                {
                    die "Multiple overrides of $attr specified for same target "
                        . "proc $pol->{target}\n";
                }
                $procLoadline{$attr}{ $pol->{target} } = $pol->{content} ;
            }
        }
    }
}

if ($reqPol->{'mba_cacheline_interleave_mode_control'} eq 'required')
{
   push @systemAttr, ["MRW_MBA_CACHELINE_INTERLEAVE_MODE_CONTROL", 1];
}
elsif ($reqPol->{'mba_cacheline_interleave_mode_control'} eq 'requested')
{
   push @systemAttr, ["MRW_MBA_CACHELINE_INTERLEAVE_MODE_CONTROL", 2];
}
else
{
   push @systemAttr, ["MRW_MBA_CACHELINE_INTERLEAVE_MODE_CONTROL", 0];
}

if ($MAXNODE > 1 && $sysname !~ m/mfg/)
{
    push @systemAttr, ["DO_ABUS_DECONFIG", 0];
}

# Process optional policies related to dyanmic VID
my $optMrwPolicies = $sysPolicy->{"optional-policy-settings"};
use constant MRW_NAME => 'mrw-name';

my %optSysPolicies = ();
my %optNodePolicies = ();

# Add the optional system-level attributes
$optSysPolicies{'MIN_FREQ_MHZ'}{MRW_NAME}
    = "minimum-frequency" ;
$optSysPolicies{'NOMINAL_FREQ_MHZ'}{MRW_NAME}
    = "nominal-frequency" ;
$optSysPolicies{'FREQ_CORE_MAX'}{MRW_NAME}
    = "maximum-frequency" ;
$optSysPolicies{'MSS_CENT_AVDD_OFFSET_DISABLE'}{MRW_NAME}
    = "mem_avdd_offset_disable" ;
$optSysPolicies{'MSS_CENT_VDD_OFFSET_DISABLE'}{MRW_NAME}
    = "mem_vdd_offset_disable" ;
$optSysPolicies{'MSS_CENT_VCS_OFFSET_DISABLE'}{MRW_NAME}
    = "mem_vcs_offset_disable" ;
$optSysPolicies{'MSS_VOLT_VPP_OFFSET_DISABLE'}{MRW_NAME}
    = "mem_vpp_offset_disable" ;
$optSysPolicies{'MSS_VOLT_VDDR_OFFSET_DISABLE'}{MRW_NAME}
    = "mem_vddr_offset_disable" ;
$optSysPolicies{'MSS_CENT_AVDD_SLOPE_ACTIVE'}{MRW_NAME}
    = "mem_avdd_slope_active" ;
$optSysPolicies{'MSS_CENT_AVDD_SLOPE_INACTIVE'}{MRW_NAME}
    = "mem_avdd_slope_inactive" ;
$optSysPolicies{'MSS_CENT_AVDD_INTERCEPT'}{MRW_NAME}
    = "mem_avdd_intercept" ;
$optSysPolicies{'MSS_VOLT_VPP_SLOPE'}{MRW_NAME}
    = "mem_vpp_slope" ;
$optSysPolicies{'MSS_VOLT_VPP_INTERCEPT'}{MRW_NAME}
    = "mem_vpp_intercept" ;
$optSysPolicies{'MSS_VOLT_DDR3_VDDR_SLOPE'}{MRW_NAME}
    = "mem_ddr3_vddr_slope" ;
$optSysPolicies{'MSS_VOLT_DDR3_VDDR_INTERCEPT'}{MRW_NAME}
    = "mem_ddr3_vddr_intercept" ;
$optSysPolicies{'MSS_VOLT_DDR4_VDDR_SLOPE'}{MRW_NAME}
    = "mem_ddr4_vddr_slope" ;
$optSysPolicies{'MSS_VOLT_DDR4_VDDR_INTERCEPT'}{MRW_NAME}
    = "mem_ddr4_vddr_intercept" ;
$optSysPolicies{'MRW_DDR3_VDDR_MAX_LIMIT'}{MRW_NAME}
    = "mem_ddr3_vddr_max_limit" ;
$optSysPolicies{'MRW_DDR4_VDDR_MAX_LIMIT'}{MRW_NAME}
    = "mem_ddr4_vddr_max_limit" ;


# Add the optional node-level attributes
$optNodePolicies{'MSS_CENT_VDD_SLOPE_ACTIVE'}{MRW_NAME}
    = "mem_vdd_slope_active" ;
$optNodePolicies{'MSS_CENT_VDD_SLOPE_INACTIVE'}{MRW_NAME}
    = "mem_vdd_slope_inactive" ;
$optNodePolicies{'MSS_CENT_VDD_INTERCEPT'}{MRW_NAME}
    = "mem_vdd_intercept" ;
$optNodePolicies{'MSS_CENT_VCS_SLOPE_ACTIVE'}{MRW_NAME}
    = "mem_vcs_slope_active" ;
$optNodePolicies{'MSS_CENT_VCS_SLOPE_INACTIVE'}{MRW_NAME}
    = "mem_vcs_slope_inactive" ;
$optNodePolicies{'MSS_CENT_VCS_INTERCEPT'}{MRW_NAME}
    = "mem_vcs_intercept" ;


# Add System Attributes
foreach my $policy ( keys %optSysPolicies )
{
    if(exists $optMrwPolicies->{ $optSysPolicies{$policy}{MRW_NAME}})
    {
        push @systemAttr, [ $policy ,
          $optMrwPolicies->{$optSysPolicies{$policy}{MRW_NAME}}];
    }
}

# Add Node Attribues
foreach my $policy ( keys %optNodePolicies )
{
    if(exists $optMrwPolicies->{ $optNodePolicies{$policy}{MRW_NAME}})
    {
        push @nodeAttr, [ $policy ,
          $optMrwPolicies->{$optNodePolicies{$policy}{MRW_NAME}}];
    }
}


#OpenPOWER policies
foreach my $policy (keys %{$optMrwPolicies->{"open_power"}})
{
        push(@systemAttr,[ uc($policy),
            $optMrwPolicies->{"open_power"}->{$policy} ] );
}




#------------------------------------------------------------------------------
# Process the pm-settings MRW file
#------------------------------------------------------------------------------
my $pm_settings_file = open_mrw_file($mrwdir, "${sysname}-pm-settings.xml");
my $pmSettings = parse_xml_file($pm_settings_file,
                       forcearray=>['processor-settings']);

my @pmChipAttr; # Repeated [NODE, POS, ATTR, VAL, ATTR, VAL, ATTR, VAL...]

foreach my $i (@{$pmSettings->{'processor-settings'}})
{
    push @pmChipAttr,
    [
        $i->{target}->{node}, $i->{target}->{position},
        "PM_UNDERVOLTING_FRQ_MINIMUM",
            $i->{pm_undervolting_frq_minimum}->{content},
        "PM_UNDERVOLTING_FREQ_MAXIMUM",
            $i->{pm_undervolting_frq_maximum}->{content},
        "PM_SPIVID_PORT_ENABLE", $i->{pm_spivid_port_enable},
        "PM_APSS_CHIP_SELECT", $i->{pm_apss_chip_select},
        "PM_PBAX_NODEID", $i->{pm_pbax_nodeid},
        "PM_PBAX_CHIPID", $i->{pm_pbax_chipid},
        "PM_PBAX_BRDCST_ID_VECTOR", $i->{pm_pbax_brdcst_id_vector},
        "PM_SLEEP_ENTRY", $i->{pm_sleep_entry},
        "PM_SLEEP_EXIT", $i->{pm_sleep_exit},
        "PM_SLEEP_TYPE", $i->{pm_sleep_type},
        "PM_WINKLE_ENTRY", $i->{pm_winkle_entry},
        "PM_WINKLE_EXIT", $i->{pm_winkle_exit},
        "PM_WINKLE_TYPE", $i->{pm_winkle_type},
    ]
}

my @SortedPmChipAttr = sort byNodePos @pmChipAttr;

if ((scalar @SortedPmChipAttr) == 0)
{
    # For all systems without a populated <sys>-pm-settings file, this script
    # defaults the values.
    # Orlena: Platform dropped so there will never be a populated
    #         orlena-pm-settings file
    # Brazos: SW231069 raised to get brazos-pm-settings populated
    print STDOUT "WARNING: No data in mrw dir(s): $mrwdir with ".
                  "filename:${sysname}-pm-settings.xml. Defaulting values\n";
}

#------------------------------------------------------------------------------
# Process the proc-pcie-settings MRW file
#------------------------------------------------------------------------------
my $proc_pcie_settings_file = open_mrw_file($mrwdir,
                                           "${sysname}-proc-pcie-settings.xml");
my $ProcPcie = parse_xml_file($proc_pcie_settings_file,
                    forcearray=>['processor-settings']);

my %procPcieTargetList = ();
my $pcieInit = 0;

# MAX Phb values Per PROC is 4 and is hard coded here
use constant MAX_NUM_PHB_PER_PROC => 4;

# MAX lane settings value is 32 bytes per phb and is hard coded here
use constant MAX_LANE_SETTINGS_PER_PHB => 32;

################################################################################
# If value is hex, convert to regular number
###############################################################################

sub unhexify {
    my($val) = @_;
    if($val =~ m/^0[xX][01234567890A-Fa-f]+$/)
    {
        $val = hex($val);
    }
    return $val;
}

# Determine values of proc pcie attributes
# Currently
#   PROC_PCIE_LANE_EQUALIZATION PROC_PCIE_IOP_CONFIG PROC_PCIE_PHB_ACTIVE
sub pcie_init ($)
{
    my $proc = $_[0];

    # Used for handling shifting operations of hex values read from mrw
    # done in scope to not affect sort functions
    use bigint;

    my $procPcieKey = "";
    my @phb_value = ();
    my $procPcieIopConfig = 0;
    my $procPciePhbActive = 0;
    $procPcieKey = sprintf("n%dp%d\,", $proc->{'target'}->{'node'},
                            $proc->{'target'}->{'position'});

    if(!(exists($procPcieTargetList{$procPcieKey})))
    {
        # Loop through each PHB which each contain 32 Bytes of EQ
        foreach my $Phb (@{$proc->{'phb-settings'}})
        {
            my $phb_number = 0;
            # Each PHB has 16 lanes (Each lane containing 2 total bytes of EQ)
            foreach my $Lane (@{$Phb->{'lane-settings'}})
            {
                my $lane_number = 0;
                foreach my $Equ (@{$Lane->{'equalization-setting'}})
                {
                    if(exists($Phb->{'phb-number'}))
                    {
                        $phb_number = $Phb->{'phb-number'};
                    }
                    else
                    {
                        die "ERROR: phb-number does not exist for
                              proc:$procPcieKey\n";
                    }
                    if(exists($Lane->{'lane-number'}))
                    {
                        $lane_number = $Lane->{'lane-number'};
                    }
                    else
                    {
                        die "ERROR: lane-number does not exist for
                              proc:$procPcieKey\n";
                    }

                    # Accumulate all values for each of the lanes from the MRW
                    # (2 Bytes)
                    # First Byte:
                    #       - Nibble 1: up_rx_hint (bit 0 reserved)
                    #       - Nibble 2: up_tx_preset
                    # Second Byte:
                    #       - Nibble 1: dn_rx_hint (bit 0 reserved)
                    #       - Nibble 2: dn_tx_preset
                    if($Equ->{'type'} eq 'up_rx_hint')
                    {
                        $phb_value[$phb_number][$lane_number*2] =
                                   $phb_value[$phb_number][$lane_number*2] |
                                    (($Equ->{value} & 0x07) << 4);
                        if($Equ->{value} > 0x7)
                        {
                            die "ERROR: Attempting to modify the
                                 reserved bit\n";
                        }
                    }
                    if($Equ->{'type'} eq 'up_tx_preset')
                    {
                        $phb_value[$phb_number][$lane_number*2] =
                                   $phb_value[$phb_number][$lane_number*2] |
                                    ($Equ->{value} & 0x0F);
                    }
                    if($Equ->{'type'} eq 'dn_rx_hint')
                    {
                        $phb_value[$phb_number][($lane_number*2)+1] =
                               $phb_value[$phb_number][($lane_number*2)+1] |
                               (($Equ->{value} & 0x07) << 4);
                        if($Equ->{value} > 0x7)
                        {
                            die "ERROR: Attempting to modify the
                                 reserved bit\n";
                        }
                    }
                    if($Equ->{'type'} eq 'dn_tx_preset')
                    {
                        $phb_value[$phb_number][($lane_number*2)+1] =
                               $phb_value[$phb_number][($lane_number*2)+1] |
                                ($Equ->{value} & 0x0F);
                    }
                }
            }
        }

        # Produce a 32 byte output hex value per PHB
        my $phbvalue = "";
        for (my $phbnumber = 0; $phbnumber < MAX_NUM_PHB_PER_PROC;
             ++$phbnumber)
        {
            for(my $lane_settings_count = 0;
                $lane_settings_count < MAX_LANE_SETTINGS_PER_PHB;
                ++$lane_settings_count)
            {
                $phbvalue = sprintf("%s0x%02X\,", $phbvalue,
                              $phb_value[$phbnumber][$lane_settings_count]);
            }
        }

        if ( exists($proc->{proc_pcie_iop_config}) )
        {
            $procPcieIopConfig = $proc->{proc_pcie_iop_config};
        }
        if ( exists($proc->{proc_pcie_phb_active}) )
        {
            $procPciePhbActive = $proc->{proc_pcie_phb_active};
        }

        $procPcieTargetList{$procPcieKey} = {
            'procName' => $proc->{'target'}->{'name'},
            'procPosition' => $proc->{'target'}->{'position'},
            'nodePosition' => $proc->{'target'}->{'node'},
            'phbValue'  => substr($phbvalue, 0, -1),
            'phbActive' => $procPciePhbActive,
            'iopConfig' => $procPcieIopConfig,
        };
    }
}

# Repeated [NODE, POS, ATTR, IOP0-VAL, IOP1-VAL, ATTR, IOP0-VAL, IOP1-VAL]
my @procPcie;
foreach my $proc (@{$ProcPcie->{'processor-settings'}})
{
    # determine values of proc pcie attributes
    pcie_init($proc);

    push @procPcie, [$proc->{target}->{node},
                     $proc->{target}->{position},
                     "PROC_PCIE_IOP_G2_PLL_CONTROL0",
                     $proc->{proc_pcie_iop_g2_pll_control0_iop0},
                     $proc->{proc_pcie_iop_g2_pll_control0_iop1},
                     "PROC_PCIE_IOP_G3_PLL_CONTROL0",
                     $proc->{proc_pcie_iop_g3_pll_control0_iop0},
                     $proc->{proc_pcie_iop_g3_pll_control0_iop1},
                     "PROC_PCIE_IOP_PCS_CONTROL0",
                     $proc->{proc_pcie_iop_pcs_control0_iop0},
                     $proc->{proc_pcie_iop_pcs_control0_iop1},
                     "PROC_PCIE_IOP_PCS_CONTROL1",
                     $proc->{proc_pcie_iop_pcs_control1_iop0},
                     $proc->{proc_pcie_iop_pcs_control1_iop1},
                     "PROC_PCIE_IOP_PLL_GLOBAL_CONTROL0",
                     $proc->{proc_pcie_iop_pll_global_control0_iop0},
                     $proc->{proc_pcie_iop_pll_global_control0_iop1},
                     "PROC_PCIE_IOP_PLL_GLOBAL_CONTROL1",
                     $proc->{proc_pcie_iop_pll_global_control1_iop0},
                     $proc->{proc_pcie_iop_pll_global_control1_iop1},
                     "PROC_PCIE_IOP_RX_PEAK",
                     $proc->{proc_pcie_iop_rx_peak_iop0},
                     $proc->{proc_pcie_iop_rx_peak_iop1},
                     "PROC_PCIE_IOP_RX_SDL",
                     $proc->{proc_pcie_iop_rx_sdl_iop0},
                     $proc->{proc_pcie_iop_rx_sdl_iop1},
                     "PROC_PCIE_IOP_RX_VGA_CONTROL2",
                     $proc->{proc_pcie_iop_rx_vga_control2_iop0},
                     $proc->{proc_pcie_iop_rx_vga_control2_iop1},
                     "PROC_PCIE_IOP_TX_BWLOSS1",
                     $proc->{proc_pcie_iop_tx_bwloss1_iop0},
                     $proc->{proc_pcie_iop_tx_bwloss1_iop1},
                     "PROC_PCIE_IOP_TX_FIFO_OFFSET",
                     $proc->{proc_pcie_iop_tx_fifo_offset_iop0},
                     $proc->{proc_pcie_iop_tx_fifo_offset_iop1},
                     "PROC_PCIE_IOP_TX_RCVRDETCNTL",
                     $proc->{proc_pcie_iop_tx_rcvrdetcntl_iop0},
                     $proc->{proc_pcie_iop_tx_rcvrdetcntl_iop1},
                     "PROC_PCIE_IOP_ZCAL_CONTROL",
                     $proc->{proc_pcie_iop_zcal_control_iop0},
                     $proc->{proc_pcie_iop_zcal_control_iop1},
                     "PROC_PCIE_IOP_TX_FFE_GEN1",
                     $proc->{proc_pcie_iop_tx_ffe_gen1_iop0},
                     $proc->{proc_pcie_iop_tx_ffe_gen1_iop1},
                     "PROC_PCIE_IOP_TX_FFE_GEN2",
                     $proc->{proc_pcie_iop_tx_ffe_gen2_iop0},
                     $proc->{proc_pcie_iop_tx_ffe_gen2_iop1}];
}

my @SortedPcie = sort byNodePos @procPcie;

#------------------------------------------------------------------------------
# Process the chip-ids MRW file
#------------------------------------------------------------------------------
my $chip_ids_file = open_mrw_file($mrwdir, "${sysname}-chip-ids.xml");
my $chipIds = parse_xml_file($chip_ids_file, forcearray=>['chip-id']);

use constant CHIP_ID_NODE => 0;
use constant CHIP_ID_POS  => 1;
use constant CHIP_ID_PATH => 2;
use constant CHIP_ID_NXPX => 3;

my @chipIDs;
foreach my $i (@{$chipIds->{'chip-id'}})
{
    push @chipIDs, [ $i->{node}, $i->{position}, $i->{'instance-path'},
                     "n$i->{target}->{node}:p$i->{target}->{position}" ];
}

#------------------------------------------------------------------------------
# Process the power-busses MRW file
#------------------------------------------------------------------------------
my $power_busses_file = open_mrw_file($mrwdir, "${sysname}-power-busses.xml");
my $powerbus = parse_xml_file($power_busses_file);

my @pbus;
use constant PBUS_FIRST_END_POINT_INDEX => 0;
use constant PBUS_SECOND_END_POINT_INDEX => 1;
use constant PBUS_DOWNSTREAM_INDEX => 2;
use constant PBUS_UPSTREAM_INDEX => 3;
use constant PBUS_TX_MSB_LSB_SWAP => 4;
use constant PBUS_RX_MSB_LSB_SWAP => 5;
use constant PBUS_ENDPOINT_INSTANCE_PATH => 6;
use constant PBUS_NODE_CONFIG_FLAG => 7;
foreach my $i (@{$powerbus->{'power-bus'}})
{
    # Pull out the connection information from the description
    # example: n0:p0:A2 to n0:p2:A2

    my $endp1 = $i->{'description'};
    my $endp2 = "null";
    my $dwnstrm_swap = 0;
    my $upstrm_swap = 0;
    my $nodeconfig = "null";

    my $present = index $endp1, 'not connected';
    if ($present eq -1)
    {
        $endp2 = $endp1;
        $endp1 =~ s/^(.*) to.*/$1/;
        $endp2 =~ s/.* to (.*)\s*$/$1/;

        # Grab the lane swap information
        $dwnstrm_swap = $i->{'downstream-n-p-lane-swap-mask'};
        $upstrm_swap =  $i->{'upstream-n-p-lane-swap-mask'};

        # Abort if node config information is not found
        if(!(exists $i->{'include-for-node-config'}))
        {
            die "include-for-node-config element not found ";
        }
        $nodeconfig = $i->{'include-for-node-config'};
    }
    else
    {
        $endp1 =~ s/^(.*) unit.*/$1/;
        $endp2 = "invalid";


        # Set the lane swap information to 0 to avoid junk
        $dwnstrm_swap = 0;
        $upstrm_swap =  0;
    }

    my $bustype = $endp1;
    $bustype =~ s/.*:p.*:(.).*/$1/;
    my $tx_swap = 0;
    my $rx_swap = 0;
    if (lc($bustype) eq "a")
    {
        $tx_swap =  $i->{'tx-msb-lsb-swap'};
        $rx_swap =  $i->{'rx-msb-lsb-swap'};
        $tx_swap = ($tx_swap eq "false") ? 0 : 1;
        $rx_swap = ($rx_swap eq "false") ? 0 : 1;
    }

    my $endpoint1_ipath = $i->{'endpoint'}[0]->{'instance-path'};
    my $endpoint2_ipath = $i->{'endpoint'}[1]->{'instance-path'};
    #print STDOUT "powerbus: $endp1, $endp2, $dwnstrm_swap, $upstrm_swap\n";

    # Brazos: Populate power bus list only for "2-node", 3-and-4-node  & "all"
    #         configuration for ABUS. Populate all entries for other bus type.

    # Other targets(tuleta, alphine..etc) : nodeconfig will be "all".

    if ( (lc($bustype) ne "a") || ($nodeconfig eq $NODECONF) ||
            ($nodeconfig eq "all") )
    {
        push @pbus, [ lc($endp1), lc($endp2), $dwnstrm_swap,
                      $upstrm_swap, $tx_swap, $rx_swap, $endpoint1_ipath,
                      $nodeconfig ];
        push @pbus, [ lc($endp2), lc($endp1), $dwnstrm_swap,
                      $upstrm_swap, $tx_swap, $rx_swap, $endpoint2_ipath,
                      $nodeconfig ];
    }
}

#------------------------------------------------------------------------------
# Process the dmi-busses MRW file
#------------------------------------------------------------------------------
my $dmi_busses_file = open_mrw_file($mrwdir, "${sysname}-dmi-busses.xml");
my $dmibus = parse_xml_file($dmi_busses_file, forcearray=>['dmi-bus']);

my @dbus_mcs;
use constant DBUS_MCS_NODE_INDEX => 0;
use constant DBUS_MCS_PROC_INDEX => 1;
use constant DBUS_MCS_UNIT_INDEX => 2;
use constant DBUS_MCS_DOWNSTREAM_INDEX => 3;
use constant DBUS_MCS_TX_SWAP_INDEX => 4;
use constant DBUS_MCS_RX_SWAP_INDEX => 5;
use constant DBUS_MCS_SWIZZLE_INDEX => 6;

my @dbus_centaur;
use constant DBUS_CENTAUR_NODE_INDEX => 0;
use constant DBUS_CENTAUR_MEMBUF_INDEX => 1;
use constant DBUS_CENTAUR_UPSTREAM_INDEX => 2;
use constant DBUS_CENTAUR_TX_SWAP_INDEX => 3;
use constant DBUS_CENTAUR_RX_SWAP_INDEX => 4;
foreach my $dmi (@{$dmibus->{'dmi-bus'}})
{
    # First grab the MCS information
    # MCS is always master so it gets downstream
    my $node = $dmi->{'mcs'}->{'target'}->{'node'};
    my $proc = $dmi->{'mcs'}->{'target'}->{'position'};
    my $mcs = $dmi->{'mcs'}->{'target'}->{'chipUnit'};
    my $swap = $dmi->{'downstream-n-p-lane-swap-mask'};
    my $tx_swap = $dmi->{'tx-msb-lsb-swap'};
    my $rx_swap = $dmi->{'rx-msb-lsb-swap'};
    $tx_swap = ($tx_swap eq "false") ? 0 : 1;
    $rx_swap = ($rx_swap eq "false") ? 0 : 1;
    my $swizzle = $dmi->{'mcs-refclock-enable-mapping'};
    #print STDOUT "dbus_mcs: n$node:p$proc:mcs:$mcs swap:$swap\n";
    push @dbus_mcs, [ $node, $proc, $mcs, $swap, $tx_swap, $rx_swap, $swizzle ];

    # Now grab the centuar chip information
    # Centaur is always slave so it gets upstream
    my $node = $dmi->{'centaur'}->{'target'}->{'node'};
    my $membuf = $dmi->{'centaur'}->{'target'}->{'position'};
    my $swap = $dmi->{'upstream-n-p-lane-swap-mask'};
    my $tx_swap = $dmi->{'rx-msb-lsb-swap'};
    my $rx_swap = $dmi->{'tx-msb-lsb-swap'};
    $tx_swap = ($tx_swap eq "false") ? 0 : 1;
    $rx_swap = ($rx_swap eq "false") ? 0 : 1;
    #print STDOUT "dbus_centaur: n$node:cen$membuf swap:$swap\n";
    push @dbus_centaur, [ $node, $membuf, $swap, $tx_swap, $rx_swap ];
}

#------------------------------------------------------------------------------
# Process the cent-vrds MRW file
#------------------------------------------------------------------------------
my $cent_vrds_file = open_mrw_file($mrwdir, "${sysname}-cent-vrds.xml");
my $mrwMemVoltageDomains = parse_xml_file($cent_vrds_file,
                                 forcearray=>['centaur-vrd-connection']);

our %vrmHash = ();
my %membufVrmUuidHash = ();
my %vrmIdHash = ();
my %validVrmTypes
    = ('VMEM' => 1,'AVDD' => 1,'VCS' => 1,'VPP' => 1,'VDD' => 1);
use constant VRM_I2C_DEVICE_PATH => 'vrmI2cDevicePath';
use constant VRM_I2C_ADDRESS => 'vrmI2cAddress';
use constant VRM_DOMAIN_TYPE => 'vrmDomainType';
use constant VRM_DOMAIN_ID => 'vrmDomainId';
use constant VRM_UUID => 'vrmUuid';

foreach my $mrwMemVoltageDomain (
    @{$mrwMemVoltageDomains->{'centaur-vrd-connection'}})
{
    if(   (!exists $mrwMemVoltageDomain->{'vrd'}->{'i2c-dev-path'})
       || (!exists $mrwMemVoltageDomain->{'vrd'}->{'i2c-address'})
       || (ref($mrwMemVoltageDomain->{'vrd'}->{'i2c-dev-path'}) eq "HASH")
       || (ref($mrwMemVoltageDomain->{'vrd'}->{'i2c-address'}) eq "HASH")
       || ($mrwMemVoltageDomain->{'vrd'}->{'i2c-dev-path'} eq "")
       || ($mrwMemVoltageDomain->{'vrd'}->{'i2c-address'} eq ""))
    {
        next;
    }

    my $vrmDev  = $mrwMemVoltageDomain->{'vrd'}->{'i2c-dev-path'};
    my $vrmAddr = $mrwMemVoltageDomain->{'vrd'}->{'i2c-address'};
    my $vrmType = uc $mrwMemVoltageDomain->{'vrd'}->{'type'};
    my $membufInstance =
        "n"  . $mrwMemVoltageDomain->{'centaur'}->{'target'}->{'node'} .
        ":p" . $mrwMemVoltageDomain->{'centaur'}->{'target'}->{'position'};

    if(!exists $validVrmTypes{$vrmType})
    {
        die "Illegal VRM type of $vrmType used\n";
    }

    if(!exists $vrmIdHash{$vrmType})
    {
        $vrmIdHash{$vrmType} = 0;
    }

    my $uuid = -1;
    foreach my $vrm ( keys %vrmHash )
    {
        if(   ($vrmHash{$vrm}{VRM_I2C_DEVICE_PATH} eq $vrmDev )
           && ($vrmHash{$vrm}{VRM_I2C_ADDRESS}     eq $vrmAddr)
           && ($vrmHash{$vrm}{VRM_DOMAIN_TYPE}     eq $vrmType) )
        {
            $uuid = $vrm;
            last;
        }

    }

    if($uuid == -1)
    {
        my $vrm = scalar keys %vrmHash;
        $vrmHash{$vrm}{VRM_I2C_DEVICE_PATH} = $vrmDev;
        $vrmHash{$vrm}{VRM_I2C_ADDRESS} = $vrmAddr;
        $vrmHash{$vrm}{VRM_DOMAIN_TYPE} = $vrmType;
        $vrmHash{$vrm}{VRM_DOMAIN_ID} =
            $vrmIdHash{$vrmType}++;
        $uuid = $vrm;
    }

    $membufVrmUuidHash{$membufInstance}{$vrmType}{VRM_UUID} = $uuid;
}

my $vrmDebug = 0;
if($vrmDebug)
{
    foreach my $membuf ( keys %membufVrmUuidHash)
    {
        print STDOUT "Membuf instance: " . $membuf . "\n";

        foreach my $vrmType ( keys %{$membufVrmUuidHash{$membuf}} )
        {
            print STDOUT "VRM type: " . $vrmType . "\n";
            print STDOUT "VRM UUID: " .
                $membufVrmUuidHash{$membuf}{$vrmType}{VRM_UUID} . "\n";
        }
    }

    foreach my $vrm ( keys %vrmHash)
    {
        print STDOUT "VRM UUID: " . $vrm . "\n";
        print STDOUT "VRM type: " . $vrmHash{$vrm}{VRM_DOMAIN_TYPE} . "\n";
        print STDOUT "VRM id: " . $vrmHash{$vrm}{VRM_DOMAIN_ID} . "\n";
        print STDOUT "VRM dev: " . $vrmHash{$vrm}{VRM_I2C_DEVICE_PATH} . "\n";
        print STDOUT "VRM addr: " .  $vrmHash{$vrm}{VRM_I2C_ADDRESS} . "\n";
    }
}

#------------------------------------------------------------------------------
# Process the cec-chips and pcie-busses MRW files
#------------------------------------------------------------------------------
my $cec_chips_file = open_mrw_file($mrwdir, "${sysname}-cec-chips.xml");
my $devpath = parse_xml_file($cec_chips_file,
                        KeyAttr=>'instance-path');

my $pcie_busses_file = open_mrw_file($mrwdir, "${sysname}-pcie-busses.xml");
my $pcie_buses = parse_xml_file($pcie_busses_file);

our %pcie_list;

foreach my $pcie_bus (@{$pcie_buses->{'pcie-bus'}})
{
    if(!exists($pcie_bus->{'switch'}))
    {
        foreach my $lane_set (0,1)
        {
            $pcie_list{$pcie_bus->{source}->{'instance-path'}}->{$pcie_bus->
                                            {source}->{iop}}->{$lane_set}->
                                            {'lane-mask'} = 0;
            $pcie_list{$pcie_bus->{source}->{'instance-path'}}->{$pcie_bus->
                                            {source}->{iop}}->{$lane_set}->
                                            {'dsmp-capable'} = 0;
            $pcie_list{$pcie_bus->{source}->{'instance-path'}}->{$pcie_bus->
                                            {source}->{iop}}->{$lane_set}->
                                            {'lane-swap'} = 0;
            $pcie_list{$pcie_bus->{source}->{'instance-path'}}->{$pcie_bus->
                                            {source}->{iop}}->{$lane_set}->
                                            {'lane-reversal'} = 0;
            $pcie_list{$pcie_bus->{source}->{'instance-path'}}->{$pcie_bus->
                                            {source}->{iop}}->{$lane_set}->
                                            {'is-slot'} = 0;
        }
    }
}

foreach my $pcie_bus (@{$pcie_buses->{'pcie-bus'}})
{
    if(!exists($pcie_bus->{'switch'}))
    {
        my $dsmp_capable = 0;
        my $is_slot = 0;
        if((exists($pcie_bus->{source}->{'dsmp-capable'}))&&
          ($pcie_bus->{source}->{'dsmp-capable'} eq 'Yes'))
        {

            $dsmp_capable = 1;
        }

        if((exists($pcie_bus->{endpoint}->{'is-slot'}))&&
          ($pcie_bus->{endpoint}->{'is-slot'} eq 'Yes'))
        {

            $is_slot = 1;
        }
        my $lane_set = 0;
        if(($pcie_bus->{source}->{'lane-mask'} eq '0xFFFF')||
           ($pcie_bus->{source}->{'lane-mask'} eq '0xFF00'))
        {
            $lane_set = 0;
        }
        else
        {
            if($pcie_bus->{source}->{'lane-mask'} eq '0x00FF')
            {
                $lane_set = 1;
            }

        }
        $pcie_list{$pcie_bus->{source}->{'instance-path'}}->
            {$pcie_bus->{source}->{iop}}->{$lane_set}->{'lane-mask'}
                = $pcie_bus->{source}->{'lane-mask'};
        $pcie_list{$pcie_bus->{source}->{'instance-path'}}->
            {$pcie_bus->{source}->{iop}}->{$lane_set}->{'dsmp-capable'}
                = $dsmp_capable;
        $pcie_list{$pcie_bus->{source}->{'instance-path'}}->
            {$pcie_bus->{source}->{iop}}->{$lane_set}->{'lane-swap'}
                = oct($pcie_bus->{source}->{'lane-swap-bits'});
        $pcie_list{$pcie_bus->{source}->{'instance-path'}}->
            {$pcie_bus->{source}->{iop}}->{$lane_set}->{'lane-reversal'}
                = oct($pcie_bus->{source}->{'lane-reversal-bits'});
        $pcie_list{$pcie_bus->{source}->{'instance-path'}}->
            {$pcie_bus->{source}->{iop}}->{$lane_set}->{'is-slot'} = $is_slot;
    }
}
our %bifurcation_list;
foreach my $pcie_bus (@{$pcie_buses->{'pcie-bus'}})
{
    if(!exists($pcie_bus->{'switch'}))
    {
        foreach my $lane_set (0,1)
        {
            $bifurcation_list{$pcie_bus->{source}->{'instance-path'}}->
                {$pcie_bus->{source}->{iop}}->{$lane_set}->{'lane-mask'}= 0;
            $bifurcation_list{$pcie_bus->{source}->{'instance-path'}}->
                {$pcie_bus->{source}->{iop}}->{$lane_set}->{'lane-swap'}= 0;
            $bifurcation_list{$pcie_bus->{source}->{'instance-path'}}->
                {$pcie_bus->{source}->{iop}}->{$lane_set}->{'lane-reversal'}= 0;
        }
    }
}
foreach my $pcie_bus (@{$pcie_buses->{'pcie-bus'}})
{
    if(   (!exists($pcie_bus->{'switch'}))
       && (exists($pcie_bus->{source}->{'bifurcation-settings'})))
    {
        my $bi_cnt = 0;
        foreach my $bifurc (@{$pcie_bus->{source}->{'bifurcation-settings'}->
                                                   {'bifurcation-setting'}})
        {
            my $lane_swap = 0;
            $bifurcation_list{$pcie_bus->{source}->{'instance-path'}}->
                             {$pcie_bus->{source}->{iop}}{$bi_cnt}->
                             {'lane-mask'} =  $bifurc->{'lane-mask'};
            $bifurcation_list{$pcie_bus->{source}->{'instance-path'}}->
                             {$pcie_bus->{source}->{iop}}{$bi_cnt}->
                             {'lane-swap'} =  oct($bifurc->{'lane-swap-bits'});
            $bifurcation_list{$pcie_bus->{source}->{'instance-path'}}->
                             {$pcie_bus->{source}->{iop}}{$bi_cnt}->
                             {'lane-reversal'} = oct($bifurc->
                             {'lane-reversal-bits'});
            $bi_cnt++;

        }


    }
}

#------------------------------------------------------------------------------
# Process the targets MRW file
#------------------------------------------------------------------------------
my $targets_file = open_mrw_file($mrwdir, "${sysname}-targets.xml");
my $eTargets = parse_xml_file($targets_file);

# Capture all targets into the @Targets array
use constant NAME_FIELD => 0;
use constant NODE_FIELD => 1;
use constant POS_FIELD  => 2;
use constant UNIT_FIELD => 3;
use constant PATH_FIELD => 4;
use constant LOC_FIELD  => 5;
use constant ORDINAL_FIELD  => 6;
use constant FRU_PATH => 7;
use constant PLUG_POS => 8;
my @Targets;
foreach my $i (@{$eTargets->{target}})
{
    my $plugPosition = $i->{'plug-xpath'};
    my $frupath = "";
    $plugPosition =~ s/.*mrw:position\/text\(\)=\'(.*)\'\]$/$1/;
    if (exists $devpath->{chip}->{$i->{'instance-path'}}->{'fru-instance-path'})
    {
        $frupath = $devpath->{chip}->{$i->{'instance-path'}}->
                                          {'fru-instance-path'};
    }

    push @Targets, [ $i->{'ecmd-common-name'}, $i->{node}, $i->{position},
                     $i->{'chip-unit'}, $i->{'instance-path'}, $i->{location},
                      0,$frupath, $plugPosition ];

    if (($i->{'ecmd-common-name'} eq "pu") && ($CHIPNAME eq ""))
    {
        $CHIPNAME = $i->{'description'};
        $CHIPNAME =~ s/Instance of (.*) cpu/$1/g;
        $CHIPNAME = lc($CHIPNAME);
    }
}

# For open-power there is an MRW change which leads the venice to be called
# opnpwr_venice. Hostboot doesn't care - it's the same PVR. So, to keep the
# rest of the tools happy (e.g., those which use target_types.xml) lets map
# the open-power venice to a regular venice. Note: not just removing the
# opnpwr_ prefix as I think we want this to be a cannary if other opnpwr_
# "processors" get created.
$CHIPNAME =~ s/opnpwr_venice/venice/g;

#------------------------------------------------------------------------------
# Process the fsi-busses MRW file
#------------------------------------------------------------------------------
my $fsi_busses_file = open_mrw_file($mrwdir, "${sysname}-fsi-busses.xml");
my $fsiBus = parse_xml_file($fsi_busses_file, forcearray=>['fsi-bus']);

# Build all the FSP chip targets / attributes
my %FSPs = ();
foreach my $fsiBus (@{$fsiBus->{'fsi-bus'}})
{
    # FSP always has master type of FSP master; Add unique ones
    my $instancePathKey = $fsiBus->{master}->{'instance-path'};
    if (    (lc($fsiBus->{master}->{type}) eq "fsp master")
        && !(exists($FSPs{$instancePathKey})))
    {
        my $node = $fsiBus->{master}->{target}->{node};
        my $position = $fsiBus->{master}->{target}->{position};
        my $huid = sprintf("0x%02X15%04X",$node,$position);
        my $rid = sprintf("0x%08X", 0x200 + $position);
        my $sys = "0";
        $FSPs{$instancePathKey} = {
            'sys'         => $sys,
            'node'        => $node,
            'position'    => $position,
            'ordinalId'   => $position,
            'instancePath'=> $fsiBus->{master}->{'instance-path'},
            'huid'        => $huid,
            'rid'         => $rid,
        };
    }
}

# Keep the knowledge of whether we have FSPs or not.
my $haveFSPs = keys %FSPs != 0;

# Build up FSI paths
# Capture all FSI connections into the @Fsis array
my @Fsis;
use constant FSI_TYPE_FIELD   => 0;
use constant FSI_LINK_FIELD   => 1;
use constant FSI_TARGET_FIELD => 2;
use constant FSI_MASTERNODE_FIELD => 3;
use constant FSI_MASTERPOS_FIELD => 4;
use constant FSI_TARGET_TYPE_FIELD  => 5;
use constant FSI_SLAVE_PORT_FIELD => 6;
use constant FSI_UNIT_ID_FIELD => 7;
use constant FSI_MASTER_TYPE_FIELD => 8;
use constant FSI_INSTANCE_FIELD => 9;
#Master procs have FSP as their master
#<fsi-bus>
#  <master>
#    <type>FSP Master</type>
#    <part-id>BRAZOS_FSP2</part-id>
#    <unit-id>FSIM_CLK[23]</unit-id>
#    <target><name>fsp</name><node>4</node><position>1</position></target>
#    <engine>0</engine>
#    <link>23</link>
#  </master>
#  <slave>
#    <part-id>VENICE</part-id>
#    <unit-id>FSI_SLAVE0</unit-id>
#    <target><name>pu</name><node>3</node><position>1</position></target>
#    <port>0</port>
#  </slave>
#</fsi-bus>
#Non-master chips have a MURANO/VENICE as their master
#<fsi-bus>
#  <master>
#    <part-id>VENICE</part-id>
#    <unit-id>FSI_CASCADE3</unit-id>
#    <target><name>pu</name><node>0</node><position>0</position></target>
#    <engine>12</engine>
#    <link>3</link>
#    <type>Cascaded Master</type>
#  </master>
#  <slave>
#    <part-id>CENTAUR</part-id>
#    <unit-id>FSI_SLAVE0</unit-id>
#    <target><name>memb</name><node>0</node><position>0</position></target>
#    <fsp-device-path-segments>L02C0E12:L3C0</fsp-device-path-segments>
#    <port>0</port>
#  </slave>
#</fsi-bus>
foreach my $fsiBus (@{$fsiBus->{'fsi-bus'}})
{
    #skip slaves that we don't care about
    if( !($fsiBus->{'slave'}->{'target'}->{'name'} eq "pu")
       && !($fsiBus->{'slave'}->{'target'}->{'name'} eq "memb") )
    {
        next;
    }

    push @Fsis, [
      #TYPE :: 'fsp master','hub master','cascaded master'
      $fsiBus->{'master'}->{'type'},
      #LINK :: coming out of master
      $fsiBus->{'master'}->{'link'},
      #TARGET :: Slave chip
        "n$fsiBus->{slave}->{target}->{node}:"
        . "p$fsiBus->{slave}->{target}->{position}",
      #MASTERNODE :: Master chip node
        "$fsiBus->{master}->{target}->{node}",
      #MASTERPOS :: Master chip position
        "$fsiBus->{master}->{target}->{position}",
      #TARGET_TYPE :: Slave chip type 'pu','memb'
      $fsiBus->{'slave'}->{'target'}->{'name'},
      #SLAVE_PORT :: mproc->'fsi_slave0',altmproc->'fsi_slave1'
      $fsiBus->{'slave'}->{'unit-id'},
      #UNIT_ID :: FSI_CASCADE, MFSI
      $fsiBus->{'master'}->{'unit-id'},
      #MASTER_TYPE :: Master chip type 'pu','memb'
      $fsiBus->{'master'}->{'target'}->{'name'},
      #INSTANCE_FIELD :: palmetto_board-assembly-0/...
      $fsiBus->{'master'}->{'instance-path'}
        ];

   #print "\nTARGET=$Fsis[$#Fsis][FSI_TARGET_FIELD]\n";
   #print "TYPE=$Fsis[$#Fsis][FSI_TYPE_FIELD]\n";
   #print "LINK=$Fsis[$#Fsis][FSI_LINK_FIELD]\n";
   #print "MASTERNODE=$Fsis[$#Fsis][FSI_MASTERNODE_FIELD]\n";
   #print "MASTERPOS=$Fsis[$#Fsis][FSI_MASTERPOS_FIELD]\n";
   #print "TARGET_TYPE=$Fsis[$#Fsis][FSI_TARGET_TYPE_FIELD]\n";
   #print "SLAVE_PORT=$Fsis[$#Fsis][FSI_SLAVE_PORT_FIELD]\n";
}
#print "Fsis = $#Fsis\n";

#------------------------------------------------------------------------------
# Process the psi-busses MRW file
#------------------------------------------------------------------------------

my @hbPSIs;
our $psiBus;

if ($haveFSPs)
{
    my $psi_busses_file = open_mrw_file($mrwdir, "${sysname}-psi-busses.xml");
    $psiBus = parse_xml_file($psi_busses_file,
                                 forcearray=>['psi-bus']);

    # Capture all PSI connections into the @hbPSIs array
    use constant HB_PSI_MASTER_CHIP_POSITION_FIELD  => 0;
    use constant HB_PSI_MASTER_CHIP_UNIT_FIELD      => 1;
    use constant HB_PSI_PROC_NODE_FIELD             => 2;
    use constant HB_PSI_PROC_POS_FIELD              => 3;

    foreach my $i (@{$psiBus->{'psi-bus'}})
    {
        push @hbPSIs, [
            $i->{fsp}->{'psi-unit'}->{target}->{position},
            $i->{fsp}->{'psi-unit'}->{target}->{chipUnit},
            $i->{processor}->{target}->{node},
            $i->{processor}->{target}->{position},
        ];
    }
}

#
#------------------------------------------------------------------------------
# Process the memory-busses MRW file
#------------------------------------------------------------------------------
my $memory_busses_file = open_mrw_file($mrwdir, "${sysname}-memory-busses.xml");
my $memBus = parse_xml_file($memory_busses_file);

# Capture all memory buses info into the @Membuses array
use constant MCS_TARGET_FIELD     =>  0;
use constant MCA_TARGET_FIELD     =>  1;
use constant CENTAUR_TARGET_FIELD =>  2;
use constant DIMM_TARGET_FIELD    =>  3;
use constant DIMM_PATH_FIELD      =>  4;
use constant BUS_NODE_FIELD       =>  5;
use constant BUS_POS_FIELD        =>  6;
use constant BUS_ORDINAL_FIELD    =>  7;
use constant DIMM_POS_FIELD       =>  8;
use constant MBA_SLOT_FIELD       =>  9;
use constant MBA_PORT_FIELD       => 10;

use constant CDIMM_RID_NODE_MULTIPLIER => 32;

my @Membuses;
foreach my $i (@{$memBus->{'memory-bus'}})
{
    push @Membuses, [
         "n$i->{mcs}->{target}->{node}:p$i->{mcs}->{target}->{position}:mcs" .
         $i->{mcs}->{target}->{chipUnit},
         "n$i->{mca}->{target}->{node}:p$i->{mca}->{target}->{position}:mca" .
         $i->{mca}->{target}->{chipUnit},
         "n$i->{mba}->{target}->{node}:p$i->{mba}->{target}->{position}:mba" .
         $i->{mba}->{target}->{chipUnit},
         "n$i->{dimm}->{target}->{node}:p$i->{dimm}->{target}->{position}",
         $i->{dimm}->{'instance-path'},
         $i->{mcs}->{target}->{node},
         $i->{mcs}->{target}->{position}, 0,
         $i->{dimm}->{'instance-path'},
         $i->{mba}->{'mba-slot'},
         $i->{mba}->{'mba-port'}];
}

# Determine if the DIMMs are CDIMM or JDIMM (IS-DIMM). Check for "not
# centaur dimm" rather than "is ddr3 dimm" so ddr4 etc will work.
my $isISDIMM = 1
   if $memBus->{'drams'}->{'dram'}[0]->{'dram-instance-path'} !~ /centaur_dimm/;

# Sort the memory busses, based on their Node, Pos & instance paths
my @SMembuses = sort byDimmNodePos @Membuses;
my $BOrdinal_ID = 0;

# Increment the Ordinal ID in sequential order for dimms.
for my $i ( 0 .. $#SMembuses )
{
    $SMembuses[$i] [BUS_ORDINAL_FIELD] = $BOrdinal_ID;
    $BOrdinal_ID += 1;
}

# Rewrite each DIMM instance path's DIMM instance to be indexed from 0
for my $i ( 0 .. $#SMembuses )
{
    $SMembuses[$i][DIMM_PATH_FIELD] =~ s/[0-9]*$/$i/;
}

#------------------------------------------------------------------------------
# Process VDDR GPIO enables
#------------------------------------------------------------------------------

my %vddrEnableHash = ();
my $useGpioToEnableVddr = 0;

if(!$haveFSPs)
{
    $useGpioToEnableVddr = 1;
}

if($useGpioToEnableVddr)
{
    my $vddrEnablesFile = open_mrw_file($mrwdir, "${sysname}-vddr.xml");
    my $vddrEnables = parse_xml_file(
        $vddrEnablesFile,
        forcearray=>['vddr-enable']);

    foreach my $vddrEnable (@{$vddrEnables->{'vddr-enable'}})
    {
        # Get dependent Centaur info
        my $centaurNode = $vddrEnable->{'centaur-target'}->{node};
        my $centaurPosition = $vddrEnable->{'centaur-target'}->{position};

        # Get I2C master which drives the GPIO for this Centaur
        my $i2cMasterNode     = $vddrEnable->{i2c}->{'master-target'}->{node};
        my $i2cMasterPosition
            = $vddrEnable->{i2c}->{'master-target'}->{position};
        my $i2cMasterPort     = $vddrEnable->{i2c}->{port};
        my $i2cMasterEngine   = $vddrEnable->{i2c}->{engine};

        # Get GPIO expander info.  For now these are pca9535 specific
        # Targeting requires real i2c address to be shifted left one bit
        my $i2cAddress        = unhexify( $vddrEnable->{i2c}->{address} ) << 1;
        my $i2cAddressHexStr  = sprintf("0x%X",$i2cAddress);
        my $vddrPort          = $vddrEnable->{'io-expander'}->{port};
        my $vddrPortPin       = $vddrEnable->{'io-expander'}->{pin};
        my $vddrPin           = $vddrPort * 8 + $vddrPortPin;

        # Build foreign keys to the Centaur targets
        my $vddrKey = "n" . $centaurNode . "p" . $centaurPosition;
        my $i2cMasterKey = "n" . $i2cMasterNode . "p" . $i2cMasterPosition;
        my $i2cMasterEntityPath =
            "physical:sys-0/node-$i2cMasterNode/membuf-$i2cMasterPosition";

        # Populate the key => value pairs for a given Centaur
        $vddrEnableHash{$vddrKey} = {
            'i2cMasterKey'        => $i2cMasterKey,
            'i2cMasterEntityPath' => $i2cMasterEntityPath,
            'i2cMasterNode'       => $i2cMasterNode,
            'i2cMasterPosition'   => $i2cMasterPosition,
            'i2cMasterPort'       => $i2cMasterPort,
            'i2cMasterEngine'     => $i2cMasterEngine,
            'i2cAddress'          => $i2cAddress,
            'i2cAddressHexStr'    => $i2cAddressHexStr,
            'vddrPin'             => $vddrPin,
        };
    }
}

#------------------------------------------------------------------------------
# Process the i2c-busses MRW file
#------------------------------------------------------------------------------
my $i2c_busses_file = open_mrw_file($mrwdir, "${sysname}-i2c-busses.xml");
my $i2cBus = XMLin($i2c_busses_file);

# Capture all i2c buses info into the @I2Cdevices array
my @I2Cdevices;
my @I2CHotPlug;
foreach my $i (@{$i2cBus->{'i2c-device'}})
{

    push @I2Cdevices, {
         'i2cm_name'=>$i->{'i2c-master'}->{target}->{name},
         'i2cm_node'=>$i->{'i2c-master'}->{target}->{node},
         'i2cm_pos' =>$i->{'i2c-master'}->{target}->{position},
         'i2cm_uid' =>$i->{'i2c-master'}->{'unit-id'},
         'i2c_content_type'=>$i->{'content-type'},
         'i2c_part_id'=>$i->{'part-id'},
         'i2c_port'=>$i->{'i2c-master'}->{'i2c-port'},
         'i2c_devAddr'=>$i->{'address'},
         'i2c_engine'=>$i->{'i2c-master'}->{'i2c-engine'},
         'i2c_speed'=>$i->{'speed'},
         'i2c_size'=>$i->{'size'},
# @todo RTC 119382 - will eventually read these values from this file
         'i2c_byte_addr_offset'=> "0x02",
         'i2c_max_mem_size' => "0x40",
         'i2c_write_page_size' =>"0x80",
         'i2c_write_cycle_time' => "0x05" };

    if(( ($i->{'part-type'} eq 'hotplug-controller') &&
             ($i->{'part-id'} eq 'MAX5961')) ||
       ( ($i->{'part-id'} eq 'PCA9551') &&
             ($i->{'i2c-master'}->{'host-connected'} eq '1' )))
    {
        push @I2CHotPlug, {
             'i2cm_node'=>$i->{'i2c-master'}->{target}->{node},
             'i2cm_pos' =>$i->{'i2c-master'}->{target}->{position},
             'i2c_port'=>$i->{'i2c-master'}->{'i2c-port'},
             'i2c_engine'=>$i->{'i2c-master'}->{'i2c-engine'},
             'i2c_speed'=>$i->{'speed'},
             'i2c_part_id'=>$i->{'part-id'},
             'i2c_slaveAddr'=>$i->{'address'},
             'i2c_instPath'=>$i->{'instance-path'}};
     }
}

my $i2c_host_file = open_mrw_file($mrwdir, "${sysname}-host-i2c.xml");
my $i2cHost = XMLin($i2c_host_file);

my @I2CHotPlug_Host;
foreach my $i (@{$i2cHost->{'host-i2c-connection'}})
{
    my $instancePath = $i->{'slave-device'}->{'instance-path'};

    if( index($instancePath,'MAX5961') != -1 ||
        index($instancePath,'PCA9551') != -1 )
    {
        push @I2CHotPlug_Host, {
             'i2c_slave_path'=>$i->{'slave-device'}->{'instance-path'},
             'i2c_proc_node'=>$i->{'processor'}->{'target'}->{'node'},
             'i2c_proc_pos'=>$i->{'processor'}->{'target'}->{'position'}};
    }
}

# Generate @STargets array from the @Targets array to have the order as shown
# belows. The rest of the codes assume that this order is in place
#
#   pu
#   ex  (one or more EX of pu before it)
#   eq  (one or more EQ of pu before it)
#   core (one or more CORE of pu before it)
#   mcbist (one or more MCBIST of pu before it)
#   mcs (one or more MCS of pu before it)
#   mca (one or more MCA of pu before it)
#   pec (one or more PEC of pu before it)
#   phb (one or more PHB of pu before it)
#   obus (one or more OBUS of pu before it)
#   xbus (one or more XBUS of pu before it)
#   ppe (one or more PPE of pu before it)
#   perv (one or more PERV of pu before it)
#   capp (one or more CAPP of pu before it)
#   sbe (one or more SBE of pu before it)
#   (Repeat for remaining pu)
#   memb
#   mba (to for membuf before it)
#   L4
#   (Repeat for remaining membuf)
#

# Sort the target array based on Target Type,Node,Position and Chip-Unit.
my @SortedTargets = sort byTargetTypeNodePosChipunit @Targets;
my $Type = $SortedTargets[0][NAME_FIELD];
my $ordinal_ID = 0;

# Increment the Ordinal ID in sequential order for same family Type.
for my $i ( 0 .. $#SortedTargets )
{
    if($SortedTargets[$i][NAME_FIELD] ne $Type)
    {
       $ordinal_ID = 0;
    }
    $SortedTargets[$i] [ORDINAL_FIELD] = $ordinal_ID;
    $Type = $SortedTargets[$i][NAME_FIELD];
    $ordinal_ID += 1;
}

my @fields;
my @STargets;
for my $i ( 0 .. $#SortedTargets )
{
    if ($SortedTargets[$i][NAME_FIELD] eq "pu")
    {
        for my $k ( 0 .. PLUG_POS )
        {
            $fields[$k] = $SortedTargets[$i][$k];
        }
        push @STargets, [ @fields ];

        my $node = $SortedTargets[$i][NODE_FIELD];
        my $position = $SortedTargets[$i][POS_FIELD];

        my @targetOrder = ("eq","ex","core","mcbist","mcs","mca","pec",
                "phb","obus","xbus","ppe","perv","capp","sbe");
        for my $m (0 .. $#targetOrder)
        {
            for my $j ( 0 ..$#SortedTargets)
            {
                if(($SortedTargets[$j][NAME_FIELD] eq $targetOrder[$m]) &&
                   ($SortedTargets[$j][NODE_FIELD] eq $node) &&
                   ($SortedTargets[$j][POS_FIELD] eq $position))
                {
                    for my $n ( 0 .. PLUG_POS )
                    {
                        $fields[$n] = $SortedTargets[$j][$n];
                    }
                    push @STargets, [@fields];
                }
            }
        }
    }
}

for my $i ( 0 .. $#SortedTargets )
{
    if ($SortedTargets[$i][NAME_FIELD] eq "memb")
    {
        for my $k ( 0 .. PLUG_POS )
        {
           $fields[$k] = $SortedTargets[$i][$k];
        }
        push @STargets, [ @fields ];

        my $node = $SortedTargets[$i][NODE_FIELD];
        my $position = $SortedTargets[$i][POS_FIELD];

        my @targetOrder = ("mba","L4");
        for my $m (0 .. $#targetOrder)
        {
            for my $j ( 0 ..$#SortedTargets)
            {
                if(($SortedTargets[$j][NAME_FIELD] eq $targetOrder[$m]) &&
                   ($SortedTargets[$j][NODE_FIELD] eq $node) &&
                   ($SortedTargets[$j][POS_FIELD] eq $position))
                {
                    for my $n ( 0 .. PLUG_POS )
                    {
                        $fields[$n] = $SortedTargets[$j][$n];
                    }
                    push @STargets, [@fields ];
                }
            }
        }
    }
}

# Finally, generate the xml file.
print "<!-- Source path(s) = $mrwdir -->\n";

print "<attributes>\n";

# First, generate system target (always sys0)
my $sys = 0;
generate_sys();

my $node = 0;
my @mprocs;
my $altMproc = 0;
my $fru_id = 0;
my @fru_paths;
my $hasProc = 0;
my $hash_ax_buses;
my $axBusesHuidInit = 0;

for (my $curnode = 0; $curnode <= $MAXNODE; $curnode++)
{

$node = $curnode;

my @Mfsis;
my %Pus;

# find master proc of this node
for my $i ( 0 .. $#Fsis )
{
    my $nodeId = lc($Fsis[$i][FSI_TARGET_FIELD]);
    $nodeId =~ s/.*n(.*):.*$/$1/;

    if ($nodeId eq $node)
    {
        # Keep track of MSFI connections
        push @Mfsis, $Fsis[$i][FSI_TARGET_FIELD]
            if $Fsis[$i][FSI_UNIT_ID_FIELD] =~ /mfsi/i;

        # Keep track of the of pu's, too.
        $Pus{$Fsis[$i][FSI_INSTANCE_FIELD]} =
            "n$Fsis[$i][FSI_MASTERNODE_FIELD]:p$Fsis[$i][FSI_MASTERPOS_FIELD]"
            if $Fsis[$i][FSI_MASTER_TYPE_FIELD] =~ /pu/;

        # Check for fsp master, if so - we have a master proc.
        if ((lc($Fsis[$i][FSI_TYPE_FIELD]) eq "fsp master") &&
            (($Fsis[$i][FSI_TARGET_TYPE_FIELD]) eq "pu"))
        {
            push @mprocs, $Fsis[$i][FSI_TARGET_FIELD];
            #print "Mproc = $Fsis[$i][FSI_TARGET_FIELD]\n";
        }
    }
}

# fsp-less systems won't have an fsp master, so we use an augmented algorithm.
if ($#mprocs < 0)
{
    # If there are no FSPs, no mfsi links and one pu, this is the master proc
    if ((!$haveFSPs) && ($#Mfsis < 0) && (keys %Pus == 1))
    {
        push @mprocs, values %Pus;
    }
}

# Second, generate system node

generate_system_node();

# Third, generate the FSP chip(s)
foreach my $fsp ( keys %FSPs )
{
    if( $FSPs{$fsp}{node} eq $node )
    {
        my $fspChipHashRef = (\%FSPs)->{$fsp};
        do_plugin('fsp_chip', $fspChipHashRef);
    }
}

# Node has no master processor, maybe it is just a control node?
if ($#mprocs < 0)
{
    next;
}

#preCalculate HUID for A-Bus
if($axBusesHuidInit == 0)
{
    $axBusesHuidInit = 1;
    for (my $my_curnode = 0; $my_curnode <= $MAXNODE; $my_curnode++)
    {
        for (my $do_core = 0, my $i = 0; $i <= $#STargets; $i++)
        {
            if ($STargets[$i][NODE_FIELD] != $my_curnode)
            {
                next;
            }
            if ($STargets[$i][NAME_FIELD] eq "mcs")
            {
                my $proc = $STargets[$i][POS_FIELD];
                if (($STargets[$i+1][NAME_FIELD] eq "pu") ||
                        ($STargets[$i+1][NAME_FIELD] eq "memb"))
                {
                    preCalculateAxBusesHUIDs($my_curnode, $proc, "A");
                }
            }
        }
    }
}

# Fourth, generate the proc, occ, ex-chiplet, mcs-chiplet
# unit-tp (if on fsp), pcie bus and A/X-bus.
my $ex_count = 0;
my $ex_core_count = 0;
my $eq_count = 0;
my $mcbist_count = 0;
my $mcs_count = 0;
my $mca_count = 0;
my $pec_count = 0;
my $phb_count = 0;
my $obus_count = 0;
my $xbus_count = 0;
my $ppe_count = 0;
my $perv_count = 0;
my $capp_count = 0;
my $sbe_count = 0;
my $proc_ordinal_id =0;
#my $fru_id = 0;
#my @fru_paths;
my $hwTopology =0;

# A hash mapping an affinity path to a FAPI_POS
my %fapiPosH;

for (my $do_core = 0, my $i = 0; $i <= $#STargets; $i++)
{
    if ($STargets[$i][NODE_FIELD] != $node)
    {
        next;
    }

    my $ipath = $STargets[$i][PATH_FIELD];
    if ($STargets[$i][NAME_FIELD] eq "pu")
    {
        my $fru_found = 0;
        my $fru_path = $STargets[$i][FRU_PATH];
        my $proc = $STargets[$i][POS_FIELD];
        $proc_ordinal_id = $STargets[$i][ORDINAL_FIELD];

        use constant FRU_PATHS => 0;
        use constant FRU_ID => 1;

        $hwTopology = $STargets[$i][NODE_FIELD] << 12;
        $fru_path  =~ m/.*-([0-9]*)$/;
        $hwTopology |= $1 <<8;
        $ipath =~ m/.*-([0-9]*)$/;
        $hwTopology |= $1 <<4;
        my $lognode;
        my $logid;
        for (my $j = 0; $j <= $#chipIDs; $j++)
        {
            if ($chipIDs[$j][CHIP_ID_PATH] eq $ipath)
            {
                $lognode = $chipIDs[$j][CHIP_ID_NODE];
                $logid = $chipIDs[$j][CHIP_ID_POS];
                last;
            }
        }

        if($#fru_paths < 0)
        {
            $fru_id = 0;
            push @fru_paths, [ $fru_path, $fru_id ];
        }
        else
        {
            for (my $k = 0; $k <= $#fru_paths; $k++)
            {
                if ( $fru_paths[$k][FRU_PATHS] eq $fru_path)
                {
                    $fru_id =  $fru_paths[$k][FRU_ID];
                    $fru_found = 1;
                    last;
                }

            }
            if ($fru_found == 0)
            {
                $fru_id = $#fru_paths + 1;
                push @fru_paths, [ $fru_path, $fru_id ];
            }
        }

        my @fsi;
        for (my $j = 0; $j <= $#Fsis; $j++)
        {
            if (($Fsis[$j][FSI_TARGET_FIELD] eq "n${node}:p$proc") &&
                ($Fsis[$j][FSI_TARGET_TYPE_FIELD] eq "pu") &&
                (lc($Fsis[$j][FSI_MASTERPOS_FIELD]) eq "0") &&
                (lc($Fsis[$j][FSI_TYPE_FIELD]) eq "hub master") )
            {
                @fsi = @{@Fsis[$j]};
                last;
            }
        }

        my @altfsi;
        for (my $j = 0; $j <= $#Fsis; $j++)
        {
            if (($Fsis[$j][FSI_TARGET_FIELD] eq "n${node}:p$proc") &&
                ($Fsis[$j][FSI_TARGET_TYPE_FIELD] eq "pu") &&
                (lc($Fsis[$j][FSI_MASTERPOS_FIELD]) eq "1") &&
                (lc($Fsis[$j][FSI_TYPE_FIELD]) eq "hub master") )
            {
                @altfsi = @{@Fsis[$j]};
                last;
            }
        }

        my $is_master = 0;
        foreach my $m (@mprocs)
        {
            if ($m eq "n${node}:p$proc")
            {
                $is_master = 1;
            }
        }

        generate_proc($proc, $is_master, $ipath, $lognode, $logid,
                      $proc_ordinal_id, \@fsi, \@altfsi, $fru_id, $hwTopology,
                      \%fapiPosH);

        generate_occ($proc, $proc_ordinal_id);
        generate_nx($proc,$proc_ordinal_id,$node);
        generate_nv($proc,$proc_ordinal_id,$node);

        # call to do any fsp per-proc targets (ie, occ, psi)
        do_plugin('fsp_proc_targets', $proc, $i, $proc_ordinal_id,
                    $STargets[$i][NODE_FIELD], $STargets[$i][POS_FIELD]);
    }
    elsif ($STargets[$i][NAME_FIELD] eq "ex")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $ex = $STargets[$i][UNIT_FIELD];

        if ($ex_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc EX units -->\n";
        }
        generate_ex($proc, $ex, $STargets[$i][ORDINAL_FIELD], $ipath,
            \%fapiPosH);
        $ex_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "core")
        {
            $ex_count = 0;
        }
    }
    elsif ($STargets[$i][NAME_FIELD] eq "core")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $core = $STargets[$i][UNIT_FIELD];

        if ($ex_core_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc core units -->\n";
        }
        generate_core($proc,$core,$STargets[$i][ORDINAL_FIELD],
                      $STargets[$i][PATH_FIELD],\%fapiPosH);
        $ex_core_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "mcs")
        {
            $ex_core_count = 0;
        }
    }
    elsif ($STargets[$i][NAME_FIELD] eq "eq")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $eq = $STargets[$i][UNIT_FIELD];

        if ($eq_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc EQ units -->\n";
        }
        generate_eq($proc, $eq, $STargets[$i][ORDINAL_FIELD], $ipath,
            \%fapiPosH);
        $eq_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "core")
        {
            $eq_count = 0;
        }

    }
    elsif ($STargets[$i][NAME_FIELD] eq "mcs")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $mcs = $STargets[$i][UNIT_FIELD];
        if ($mcs_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc MCS units -->\n";
        }
        generate_mcs($proc,$mcs, $STargets[$i][ORDINAL_FIELD],
            $ipath,\%fapiPosH);
        $mcs_count++;
        if (($STargets[$i+1][NAME_FIELD] eq "pu") ||
            ($STargets[$i+1][NAME_FIELD] eq "memb"))
        {
            $mcs_count = 0;
        }
    }
    elsif ( $STargets[$i][NAME_FIELD] eq "mca")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $mca = $STargets[$i][UNIT_FIELD];
        if ($mca_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc MCA units -->\n";
        }
        generate_mca($proc,$mca, $STargets[$i][ORDINAL_FIELD], $ipath,
            \%fapiPosH);
        $mca_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "pu")
        {
            $mca_count = 0;
        }
    }
    elsif ( $STargets[$i][NAME_FIELD] eq "mcbist")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $mcbist = $STargets[$i][UNIT_FIELD];
        if ($mcbist_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc MCBIST units -->\n";
        }
        generate_mcbist($proc,$mcbist,$STargets[$i][ORDINAL_FIELD],$ipath,
            \%fapiPosH);
        $mcbist_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "pu")
        {
            $mcbist_count = 0;
        }
    }
    elsif ( $STargets[$i][NAME_FIELD] eq "pec")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $pec = $STargets[$i][UNIT_FIELD];
        if ($pec_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc PEC units -->\n";
        }
        generate_pec($proc,$pec,$STargets[$i][ORDINAL_FIELD],$ipath,
            \%fapiPosH);
        $pec_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "pu")
        {
            $pec_count = 0;
        }
    }
    elsif ( $STargets[$i][NAME_FIELD] eq "phb")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $phb = $STargets[$i][UNIT_FIELD];
        if ($phb_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc PHB units -->\n";
        }
        generate_phb_chiplet($proc,$phb,$STargets[$i][ORDINAL_FIELD],$ipath,
            \%fapiPosH);
        $phb_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "pu")
        {
            $phb_count = 0;
        }
    }
    elsif ( $STargets[$i][NAME_FIELD] eq "obus")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $obus = $STargets[$i][UNIT_FIELD];
        if ($obus_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc OBUS units -->\n";
        }
        generate_obus($proc,$obus,$STargets[$i][ORDINAL_FIELD],$ipath,
            \%fapiPosH);
        $obus_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "pu")
        {
            $obus_count = 0;
        }
    }
    elsif ( $STargets[$i][NAME_FIELD] eq "xbus")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $xbus = $STargets[$i][UNIT_FIELD];
        if ($xbus_count == 0)
        {
           print "\n<!-- $SYSNAME n${node}p$proc XBUS units -->\n";
        }
        generate_xbus($proc,$xbus,$STargets[$i][ORDINAL_FIELD],$ipath,
            \%fapiPosH);
        $xbus_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "pu")
        {
           $xbus_count = 0;
        }
    }
    elsif ( $STargets[$i][NAME_FIELD] eq "ppe")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $ppe = $STargets[$i][UNIT_FIELD];
        if ($ppe_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc PPE units -->\n";
        }
        generate_ppe($proc,$ppe,$STargets[$i][ORDINAL_FIELD],$ipath,
            \%fapiPosH);
        $ppe_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "pu" )
        {
            $ppe_count = 0;
        }
    }
    elsif ( $STargets[$i][NAME_FIELD] eq "perv")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $perv = $STargets[$i][UNIT_FIELD];
        if ($perv_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc PERV units -->\n";
        }
        generate_perv($proc,$perv,$STargets[$i][ORDINAL_FIELD],$ipath,
            \%fapiPosH);
        $perv_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "pu")
        {
            $perv_count = 0;
        }
    }
    elsif ( $STargets[$i][NAME_FIELD] eq "capp")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $capp = $STargets[$i][UNIT_FIELD];
        if ($capp_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc CAPP units -->\n";
        }
        generate_capp($proc,$capp,$STargets[$i][ORDINAL_FIELD],$ipath,
            \%fapiPosH);
        $capp_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "pu")
        {
            $capp_count = 0;
        }
    }
    elsif ( $STargets[$i][NAME_FIELD] eq "sbe")
    {
        my $proc = $STargets[$i][POS_FIELD];
        my $sbe = $STargets[$i][UNIT_FIELD];
        if ($sbe_count == 0)
        {
            print "\n<!-- $SYSNAME n${node}p$proc SBE units -->\n";
        }
        generate_sbe($proc,$sbe,$STargets[$i][ORDINAL_FIELD],$ipath,
            \%fapiPosH);
        $sbe_count++;
        if ($STargets[$i+1][NAME_FIELD] eq "pu")
        {
            $sbe_count = 0;
        }
    }
}

# Fifth, generate the Centaur, L4, and MBA

my $memb;
my $membMcs;
my $mba_count = 0;

for my $i ( 0 .. $#STargets )
{
    if ($STargets[$i][NODE_FIELD] != $node)
    {
        next;
    }

    my $ipath = $STargets[$i][PATH_FIELD];
    if ($STargets[$i][NAME_FIELD] eq "memb")
    {
        $memb = $STargets[$i][POS_FIELD];
        my $centaur = "n${node}:p${memb}";
        my $found = 0;
        my $cfsi;
        for my $j ( 0 .. $#Membuses )
        {
            my $mba = $Membuses[$j][CENTAUR_TARGET_FIELD];
            $mba =~ s/(.*):mba.*$/$1/;
            if ($mba eq $centaur)
            {
                $membMcs = $Membuses[$j][MCS_TARGET_FIELD];
                $found = 1;
                last;
            }
        }
        if ($found == 0)
        {
            die "ERROR. Can't locate Centaur from memory bus table\n";
        }

        my @fsi;
        for (my $j = 0; $j <= $#Fsis; $j++)
        {
            if (($Fsis[$j][FSI_TARGET_FIELD] eq "n${node}:p${memb}") &&
                ($Fsis[$j][FSI_TARGET_TYPE_FIELD] eq "memb") &&
                (lc($Fsis[$j][FSI_SLAVE_PORT_FIELD]) eq "fsi_slave0") &&
                (lc($Fsis[$j][FSI_TYPE_FIELD]) eq "cascaded master") )
            {
                @fsi = @{@Fsis[$j]};
                last;
            }
        }

        my @altfsi;
        for (my $j = 0; $j <= $#Fsis; $j++)
        {
            if (($Fsis[$j][FSI_TARGET_FIELD] eq "n${node}:p${memb}") &&
                ($Fsis[$j][FSI_TARGET_TYPE_FIELD] eq "memb") &&
                (lc($Fsis[$j][FSI_SLAVE_PORT_FIELD]) eq "fsi_slave1") &&
                (lc($Fsis[$j][FSI_TYPE_FIELD]) eq "cascaded master") )
            {
                @altfsi = @{@Fsis[$j]};
                last;
            }
        }

        my $relativeCentaurRid = $STargets[$i][PLUG_POS]
            + (CDIMM_RID_NODE_MULTIPLIER * $STargets[$i][NODE_FIELD]);

        generate_centaur( $memb, $membMcs, \@fsi, \@altfsi, $ipath,
                          $STargets[$i][ORDINAL_FIELD],$relativeCentaurRid,
                          $ipath, $membufVrmUuidHash{"n${node}:p${memb}"},
                          \%fapiPosH);
    }
    elsif ($STargets[$i][NAME_FIELD] eq "mba")
    {
        if ($mba_count == 0)
        {
            print "\n";
            print "<!-- $SYSNAME Centaur MBAs affiliated with membuf$memb -->";
            print "\n";
        }
        my $mba = $STargets[$i][UNIT_FIELD];
        generate_mba( $memb, $membMcs, $mba,
            $STargets[$i][ORDINAL_FIELD], $ipath,\%fapiPosH);
        $mba_count += 1;
        if ($mba_count == 2)
        {
            $mba_count = 0;
            print "\n<!-- $SYSNAME Centaur n${node}p${memb} : end -->\n"
        }
    }
    elsif ($STargets[$i][NAME_FIELD] eq "L4")
    {
        print "\n";
        print "<!-- $SYSNAME Centaur L4 affiliated with membuf$memb -->";
        print "\n";

        my $l4 = $STargets[$i][UNIT_FIELD];
        generate_l4( $memb, $membMcs, $l4, $STargets[$i][ORDINAL_FIELD],
                     $ipath,\%fapiPosH );

        print "\n<!-- $SYSNAME Centaur n${node}p${l4} : end -->\n"
    }
}

# Sixth, generate DIMM targets

generate_is_dimm(\%fapiPosH) if ($isISDIMM);
generate_centaur_dimm(\%fapiPosH) if (!$isISDIMM);


# call to do pnor attributes
do_plugin('all_pnors', $node);

# call to do refclk attributes
do_plugin('all_refclk');
}

print "\n</attributes>\n";

# All done!
#close ($outFH);
exit 0;

##########   Subroutines    ##############

################################################################################
# utility function used to preCalculate the AX Buses HUIDs
################################################################################

sub preCalculateAxBusesHUIDs
{
    my ($my_node, $proc, $type) = @_;

    my ($minbus, $maxbus, $numperchip, $typenum, $type) =
            getBusInfo($type, $CHIPNAME);

    for my $i ( $minbus .. $maxbus )
    {
        my $uidstr = sprintf( "0x%02X%02X%04X",
            ${my_node},
            $typenum,
            $proc*$numperchip + $i);
        my $phys_path =
            "physical:sys-$sys/node-$my_node/proc-$proc/${type}bus-$i";
        $hash_ax_buses->{$phys_path} = $uidstr;
        #print STDOUT "Phys Path = $phys_path, HUID = $uidstr\n";
    }
}

################################################################################
# utility function used to call plugins. if none exists, call is skipped.
################################################################################

sub do_plugin
{
    my $step = shift;
    if (exists($hwsvmrw_plugins{$step}))
    {
        $hwsvmrw_plugins{$step}(@_);
    }
    elsif ($DEBUG && ($build eq "fsp"))
    {
        print STDERR "build is $build but no plugin for $step\n";
    }
}

################################################################################
# Compares two MRW Targets based on the Type,Node,Position & Chip-Unit #
################################################################################

sub byTargetTypeNodePosChipunit ($$)
{
    # Operates on two Targets, based on the following parameters Targets will
    # get sorted,
    # 1.Type of the Target.Ex; pu , ex , mcs ,mba etc.
    # 2.Node of the Target.Node instance number, integer 0,1,2 etc.
    # 3.Position of the Target, integer 0,1,2 etc.
    # 4.ChipUnit of the Target , integer 0,1,2 etc.
    # Note the above order is sequential & comparison is made in the same order.

    #Assume always $lhsInstance < $rhsInstance, will reduce redundant coding.
    my $retVal = -1;

    # Get just the instance path for each supplied memory bus
    my $lhsInstance_Type = $_[0][NAME_FIELD];
    my $rhsInstance_Type = $_[1][NAME_FIELD];

    if($lhsInstance_Type eq $rhsInstance_Type)
    {
       my $lhsInstance_Node = $_[0][NODE_FIELD];
       my $rhsInstance_Node = $_[1][NODE_FIELD];

       if(int($lhsInstance_Node) eq int($rhsInstance_Node))
       {
           my $lhsInstance_Pos = $_[0][POS_FIELD];
           my $rhsInstance_Pos = $_[1][POS_FIELD];

           if(int($lhsInstance_Pos) eq int($rhsInstance_Pos))
           {
               my $lhsInstance_ChipUnit = $_[0][UNIT_FIELD];
               my $rhsInstance_ChipUnit = $_[1][UNIT_FIELD];

               if(int($lhsInstance_ChipUnit) eq int($rhsInstance_ChipUnit))
               {
                   die "ERROR: Duplicate Targets: 2 Targets with same \
                    TYPE: $lhsInstance_Type NODE: $lhsInstance_Node \
                    POSITION: $lhsInstance_Pos \
                    & CHIP-UNIT: $lhsInstance_ChipUnit\n";
               }
               elsif(int($lhsInstance_ChipUnit) > int($rhsInstance_ChipUnit))
               {
                   $retVal = 1;
               }
           }
           elsif(int($lhsInstance_Pos) > int($rhsInstance_Pos))
           {
               $retVal = 1;
           }
         }
         elsif(int($lhsInstance_Node) > int($rhsInstance_Node))
         {
            $retVal = 1;
         }
    }
    elsif($lhsInstance_Type gt $rhsInstance_Type)
    {
        $retVal = 1;
    }
    return $retVal;
}

################################################################################
# Compares two MRW DIMMs based on the Node,Position & DIMM instance #
################################################################################

sub byDimmNodePos($$)
{
    # Operates on two Targets, based on the following parameters Targets will
    # get sorted,
    # 1.Node of the Target.Node instance number, integer 0,1,2 etc.
    # 2.Position of the Target, integer 0,1,2 etc.
    # 3.On two DIMM instance paths, each in the form of:
    #     assembly-0/shilin-0/dimm-X
    #
    # Assumes that "X is always a decimal number, and that every DIMM in the
    # system has a unique value of "X", including for multi-node systems and for
    # systems whose DIMMs are contained on different parts of the system
    # topology
    #
    # Note, in the path example above, the parts leading up to the dimm-X could
    # be arbitrarily deep and have different types/instance values
    #
    # Note the above order is sequential & comparison is made in the same order.

    #Assume always $lhsInstance < $rhsInstance, will reduce redundant coding.
    my $retVal = -1;

    my $lhsInstance_node = $_[0][BUS_NODE_FIELD];
    my $rhsInstance_node = $_[1][BUS_NODE_FIELD];
    if(int($lhsInstance_node) eq int($rhsInstance_node))
    {
         my $lhsInstance_pos = $_[0][BUS_POS_FIELD];
         my $rhsInstance_pos = $_[1][BUS_POS_FIELD];
         if(int($lhsInstance_pos) eq int($rhsInstance_pos))
         {
            # Get just the instance path for each supplied memory bus
            my $lhsInstance = $_[0][DIMM_PATH_FIELD];
            my $rhsInstance = $_[1][DIMM_PATH_FIELD];
            # Replace each with just its DIMM instance value (a string)
            $lhsInstance =~ s/.*-([0-9]*)$/$1/;
            $rhsInstance =~ s/.*-([0-9]*)$/$1/;

            if(int($lhsInstance) eq int($rhsInstance))
            {
                die "ERROR: Duplicate Dimms: 2 Dimms with same TYPE, \
                    NODE: $lhsInstance_node POSITION: $lhsInstance_pos & \
                    PATH FIELD: $lhsInstance\n";
            }
            elsif(int($lhsInstance) > int($rhsInstance))
            {
               $retVal = 1;
            }
         }
         elsif(int($lhsInstance_pos) > int($rhsInstance_pos))
         {
             $retVal = 1;
         }
    }
    elsif(int($lhsInstance_node) > int($rhsInstance_node))
    {
        $retVal = 1;
    }
    return $retVal;
}

################################################################################
# Compares two MRW DIMM instance paths based only on the DIMM instance #
################################################################################

sub byDimmInstancePath ($$)
{
    # Operates on two DIMM instance paths, each in the form of:
    #     assembly-0/shilin-0/dimm-X
    #
    # Assumes that "X is always a decimal number, and that every DIMM in the
    # system has a unique value of "X", including for multi-node systems and for
    # systems whose DIMMs are contained on different parts of the system
    # topology
    #
    # Note, in the path example above, the parts leading up to the dimm-X could
    # be arbitrarily deep and have different types/instance values

    # Get just the instance path for each supplied memory bus
    my $lhsInstance = $_[0][DIMM_PATH_FIELD];
    my $rhsInstance = $_[1][DIMM_PATH_FIELD];

    # Replace each with just its DIMM instance value (a string)
    $lhsInstance =~ s/.*-([0-9]*)$/$1/;
    $rhsInstance =~ s/.*-([0-9]*)$/$1/;

    # Convert each DIMM instance value string to int, and return comparison
    return int($lhsInstance) <=> int($rhsInstance);
}

################################################################################
# Compares two arrays based on chip node and position
################################################################################
sub byNodePos($$)
{
    my $retVal = -1;

    my $lhsInstance_node = $_[0][CHIP_NODE_INDEX];
    my $rhsInstance_node = $_[1][CHIP_NODE_INDEX];
    if(int($lhsInstance_node) eq int($rhsInstance_node))
    {
         my $lhsInstance_pos = $_[0][CHIP_POS_INDEX];
         my $rhsInstance_pos = $_[1][CHIP_POS_INDEX];
         if(int($lhsInstance_pos) eq int($rhsInstance_pos))
         {
                die "ERROR: Duplicate chip positions: 2 chip with same
                    node and position, \
                    NODE: $lhsInstance_node POSITION: $lhsInstance_pos\n";
         }
         elsif(int($lhsInstance_pos) > int($rhsInstance_pos))
         {
             $retVal = 1;
         }
    }
    elsif(int($lhsInstance_node) > int($rhsInstance_node))
    {
        $retVal = 1;
    }
    return $retVal;
}

sub generate_sys
{
    my $plat = 0;

    if ($build eq "fsp")
    {
        $plat = 2;
    }
    elsif ($build eq "hb")
    {
        $plat = 1;
    }

    print "
<!-- $SYSNAME System with new values-->

<targetInstance>
    <id>sys$sys</id>
    <type>sys-sys-power9</type>
    <attribute>
        <id>FAPI_NAME</id>
        <default>k0</default>
    </attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>0</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:sys-$sys</default>
    </compileAttribute>
    <attribute>
        <id>EXECUTION_PLATFORM</id>
        <default>$plat</default>
    </attribute>\n";

    #TODO CQ:SW352246 Replace hardcoded defaults with MRW values
    print "    <attribute>
      <id>MEMVPD_FREQS_MHZ</id>
      <default>
        1866,
        2133,
        2400,
        2667,
      </default>
    </attribute>\n";

    print "    <!-- System Attributes from MRW -->\n";
    addSysAttrs();

    print "    <!-- End System Attributes from MRW -->";

    # If we don't have any FSPs (open-power) then we don't need any SP_FUNCTIONS
    my $HaveSPFunctions = $haveFSPs ? 1 : 0;
    print "
    <attribute>
        <id>SP_FUNCTIONS</id>
        <default>
            <field><id>baseServices</id><value>$HaveSPFunctions</value></field>
            <field><id>fsiSlaveInit</id><value>$HaveSPFunctions</value></field>
            <field><id>mailboxEnabled</id><value>$HaveSPFunctions</value></field>
            <field><id>fsiMasterInit</id><value>$HaveSPFunctions</value></field>
            <field><id>hardwareChangeDetection</id><value>$HaveSPFunctions</value></field>
            <field><id>powerLineDisturbance</id><value>$HaveSPFunctions</value></field>
            <field><id>reserved</id><value>0</value></field>
        </default>
    </attribute>
        <attribute>
        <id>HB_SETTINGS</id>
        <default>
            <field><id>traceContinuous</id><value>0</value></field>
            <field><id>traceScanDebug</id><value>0</value></field>
            <field><id>reserved</id><value>0</value></field>
        </default>
    </attribute>
    <attribute>
        <id>PAYLOAD_KIND</id>\n";

    # If we have FSPs, we setup the default as PHYP, and the FSP
    # will set this up correctly. We can't just add the SAPPHIRE as a
    # default because the FSP assumes the PAYLOAD_BASE comes via
    # attribute_types.xml
    if ($haveFSPs)
    {
        print "        <default>PHYP</default>\n";
    }
    else
    {
        print "
        <default>SAPPHIRE</default>
    </attribute>
    <attribute>
        <id>PAYLOAD_BASE</id>
        <default>0</default>
    </attribute>
    <attribute>
        <id>PAYLOAD_ENTRY</id>
        <default>0x10</default>\n";
    }
    print "    </attribute>";

    generate_max_config();

    # HDAT drawer number (physical node) to
    # HostBoot Instance number (logical node) map
    # Index is the hdat drawer number, value is the HB instance number
    # Only the max drawer system needs to be represented.
    if ($sysname =~ /brazos/)
    {
        print "
    <!-- correlate HDAT drawer number to Hostboot Instance number -->
    <attribute><id>FABRIC_TO_PHYSICAL_NODE_MAP</id>
        <default>0,1,2,3,255,255,255,255</default>
    </attribute>
";
    }
    else # single drawer
    {
        print "
    <!-- correlate HDAT drawer number to Hostboot Instance number -->
    <attribute><id>FABRIC_TO_PHYSICAL_NODE_MAP</id>
        <default>0,255,255,255,255,255,255,255</default>
    </attribute>
";
    }

    # Tuletas can now support multiple nest frequencies
    if ($sysname =~ /tuleta/)
    {
        print "
    <attribute><id>MRW_NEST_CAPABLE_FREQUENCIES_SYS</id>
        <default>2000_MHZ_OR_2400_MHZ</default>
    </attribute>
";
    }
    else
    {
        print "
    <attribute><id>MRW_NEST_CAPABLE_FREQUENCIES_SYS</id>
        <default>UNSUPPORTED_FREQ</default>
    </attribute>
";
    }

    #adding XSCOM_BASE_ADDRESS to the system target for HDAT
    print "
    <attribute><id>XSCOM_BASE_ADDRESS</id>
        <default>0x000603FC00000000</default>
    </attribute>
";

    if( $haveFSPs == 0 )
    {
        generate_apss_adc_config()
    }

    # call to do any fsp per-sys attributes
    do_plugin('fsp_sys', $sys, $sysname, 0);

print "
</targetInstance>

";
}

sub generate_max_config
{
    my $maxMcs_Per_System = 0;
    my $maxChiplets_Per_Proc = 0;
    my $maxProcChip_Per_Node =0;
    my $maxEx_Per_Proc =0;
    my $maxDimm_Per_MbaPort =0;
    my $maxMbaPort_Per_Mba =0;
    my $maxMba_Per_MemBuf =0;

    # MBA Ports Per MBA is 2 in P8 and is hard coded here
    use constant MBA_PORTS_PER_MBA => 2;

    # MAX Chiplets Per Proc is 32 and is hard coded here
    use constant CHIPLETS_PER_PROC => 32;

    # MAX Mba Per MemBuf is 2 and is hard coded here
    # PNEW_TODO to change if P9 different
    use constant MAX_MBA_PER_MEMBUF => 2;

    # MAX Dimms Per MBA PORT is 2 and is hard coded here
    # PNEW_TODO to change if P9 different
    use constant MAX_DIMMS_PER_MBAPORT => 2;

    for (my $i = 0; $i < $#STargets; $i++)
    {
        if ($STargets[$i][NAME_FIELD] eq "pu")
        {
            if ($node == 0)
            {
                $maxProcChip_Per_Node += 1;
            }
        }
        elsif ($STargets[$i][NAME_FIELD] eq "ex")
        {
            my $proc = $STargets[$i][POS_FIELD];
            if (($proc == 0) && ($node == 0))
            {
                $maxEx_Per_Proc += 1;
            }
        }
        elsif ($STargets[$i][NAME_FIELD] eq "mcs")
        {
            $maxMcs_Per_System += 1;
        }
    }

    # loading the hard coded value
    $maxMbaPort_Per_Mba = MBA_PORTS_PER_MBA;

    # loading the hard coded value
    $maxChiplets_Per_Proc = CHIPLETS_PER_PROC;

    # loading the hard coded value
    $maxMba_Per_MemBuf = MAX_MBA_PER_MEMBUF;

    # loading the hard coded value
    $maxDimm_Per_MbaPort = MAX_DIMMS_PER_MBAPORT;

    print "
    <attribute>
        <id>MAX_PROC_CHIPS_PER_NODE</id>
        <default>$maxProcChip_Per_Node</default>
    </attribute>
    <attribute>
        <id>MAX_EXS_PER_PROC_CHIP</id>
        <default>$maxEx_Per_Proc</default>
    </attribute>
    <attribute>
        <id>MAX_CHIPLETS_PER_PROC</id>
        <default>$maxChiplets_Per_Proc</default>
    </attribute>
    <attribute>
        <id>MAX_MCS_PER_SYSTEM</id>
        <default>$maxMcs_Per_System</default>
    </attribute>";
}

sub generate_apss_adc_config
{
    my $uc_sysname = uc $sysname;
    my $apss_xml_file = open_mrw_file($::mrwdir,"${uc_sysname}_APSS.xml");
    my $xmlData = parse_xml_file($apss_xml_file,forcearray=>['id']);
    my $adc_cfg = $xmlData->{part}
                          ->{"internal-attributes"}
                          ->{configurations}
                          ->{configuration}
                          ->{'configuration-entries'}
                          ->{'configuration-entry'};

    my @channel_id;
    my $gain = {};
    my $func_id = {};
    my $offset = {};
    my $gnd = {};

    my @gpio_mode;
    my @gpio_pin;
    my $gpio_fid = {};

    foreach my $i (@{$adc_cfg})
    {
        if( $i->{'unit-type'} eq 'adc-unit' )
        {
            foreach my $id (@{$i->{'id'}})
            {
                if( $id eq "CHANNEL")
                {
                    $channel_id[$i->{value}] = $i->{'unit-id'};
                }
                if( $id eq "GND")
                {
                    if(ref($i->{value}) ne "HASH")
                    {
                        $gnd->{$i->{'unit-id'}} = $i->{value};
                    }
                    else
                    {
                        $gnd->{$i->{'unit-id'}} = 0;
                    }
                }
                if( $id eq "GAIN")
                {
                    $gain->{$i->{'unit-id'}} = $i->{value} * 1000;
                }
                if( $id eq "OFFSET")
                {
                    if(ref($i->{value}) ne "HASH")
                    {
                        $offset->{$i->{'unit-id'}} = $i->{value} * 1000;
                    }
                    else
                    {
                        $offset->{$i->{'unit-id'}} = 0;
                    }
                }
                if( $id eq "FUNCTION_ID" )
                {
                    if(ref($i->{value}) ne "HASH")
                    {
                        $func_id->{$i->{'unit-id'}} = $i->{value};
                    }
                    else
                    {
                        $func_id->{$i->{'unit-id'}} = 0;
                    }
                }
            }
        }
        if( $i->{'unit-type'} eq 'gpio-global' )
        {
            foreach my $id (@{$i->{'id'}})
            {
                if( $id eq "GPIO_P0_MODE")
                {
                    $gpio_mode[0] = $i->{value};
                }
                if( $id eq "GPIO_P1_MODE")
                {
                    $gpio_mode[1] = $i->{value};
                }
            }
        }
        if( $i->{'unit-type'} eq 'gpio-unit' )
        {
            my $unit_id = $i->{'unit-id'};
            if($unit_id =~ /^GPIO/)
            {
                foreach my $id (@{$i->{'id'}})
                {
                    if( $id eq "FUNCTION_ID")
                    {
                        $gpio_fid->{$unit_id} = $i->{value};
                    }
                }
            }
        }
    }

    my @func_id_a;
    my @gain_a;
    my @offset_a;
    my @gnd_a;

    foreach my $i (@channel_id)
    {
        push @func_id_a, $func_id->{$i};
        push @gain_a, $gain->{$i};
        push @offset_a, $offset->{$i};
        push @gnd_a, $gnd->{$i};
    }

    foreach my $i (0..15)
    {
        my $unit = "GPIO[$i]";
        if($gpio_fid->{$unit} ne "#N/A")
        {
            $gpio_pin[$i] = $gpio_fid->{$unit};
        }
        else
        {
            $gpio_pin[$i] = 0;
        }
    }

    print "
    <attribute>
        <id>ADC_CHANNEL_FUNC_IDS</id>
        <default> ";

    print join(',',@func_id_a);

    print " </default>
    </attribute>
    <attribute>
        <id>ADC_CHANNEL_GNDS</id>
        <default> ";

    print join(',',@gnd_a);

    print " </default>
    </attribute>
    <attribute>
        <id>ADC_CHANNEL_GAINS</id>
        <default>\n            ";

    print join(",\n            ",@gain_a);

    print "\n        </default>
    </attribute>
    <attribute>
        <id>ADC_CHANNEL_OFFSETS</id>
        <default> ";

    print join(',',@offset_a);

    print " </default>
    </attribute>
    <attribute>
        <id>APSS_GPIO_PORT_MODES</id>
        <default> ";

    print join(',',@gpio_mode);

    print " </default>
    </attribute>
    <attribute>
        <id>APSS_GPIO_PORT_PINS</id>
        <default> ";

    print join(',',@gpio_pin);

    print " </default>
    </attribute>\n";
}

my $computeNodeInit = 0;
my %computeNodeList = ();
sub generate_compute_node_ipath
{
    my $location_codes_file = open_mrw_file($::mrwdir,
                                            "${sysname}-location-codes.xml");
    my $nodeTargets = parse_xml_file($location_codes_file);

    #get the node (compute) ipath details
    foreach my $Target (@{$nodeTargets->{'location-code-entry'}})
    {
        if($Target->{'assembly-type'} eq "compute")
        {
            my $ipath = $Target->{'instance-path'};
            my $assembly = $Target->{'assembly-type'};
            my $position = $Target->{position};

            $computeNodeList{$position} = {
                'position'     => $position,
                'assembly'     => $assembly,
                'instancePath' => $ipath,
            }
        }
    }
}

sub generate_system_node
{
    # Get the node ipath info
    if ($computeNodeInit == 0)
    {
        generate_compute_node_ipath;
        $computeNodeInit = 1;
    }

    # Brazos node4 is the fsp node and we'll let the fsp
    # MRW parser handle that.
    if( !( ($sysname =~ /brazos/) && ($node == $MAXNODE) ) )
    {
        my $fapi_name = "NA"; # node not FAPI target

        print "
<!-- $SYSNAME System node $node -->

<targetInstance>
    <id>sys${sys}node${node}</id>
    <type>enc-node-power9</type>
    <attribute><id>HUID</id><default>0x0${node}020000</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$node</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$computeNodeList{$node}->{'instancePath'}</default>
    </compileAttribute>";

    print "    <!-- Node Attributes from MRW -->\n";
    addNodeAttrs();

        # add fsp extensions
        do_plugin('fsp_node_add_extensions', $node);
        print "
</targetInstance>
";
    }
    else
    {
        # create fsp control node
        do_plugin('fsp_control_node', $node);
    }

    # call to do any fsp per-system_node targets
    do_plugin('fsp_system_node_targets', $node);
}

sub calcAndAddFapiPos
{
    my ($type,$affinityPath,
        $relativePos,$fapiPosHr,$parentFapiPosOverride) = @_;

    # Uncomment to emit debug trace to STDERR
    #print STDERR "$affinityPath,";

    state %typeToLimit;
    if(not %typeToLimit)
    {
        # FAPI types with FAPI_POS attribute
        # none: NA
        # system: NA
        $typeToLimit{"isdimm"} = ARCH_LIMIT_DIMM_PER_MCA;
        $typeToLimit{"cdimm"}  = ARCH_LIMIT_DIMM_PER_MBA;
        $typeToLimit{"proc"}   = ARCH_LIMIT_PROC_PER_FABRIC_GROUP;
        $typeToLimit{"membuf"} = ARCH_LIMIT_MEMBUF_PER_DMI;
        $typeToLimit{"ex"}     = ARCH_LIMIT_EX_PER_EQ;
        $typeToLimit{"mba"}    = ARCH_LIMIT_MBA_PER_MEMBUF;
        $typeToLimit{"mcbist"} = ARCH_LIMIT_MCBIST_PER_PROC;
        $typeToLimit{"mcs"}    = ARCH_LIMIT_MCS_PER_PROC;
        $typeToLimit{"xbus"}   = ARCH_LIMIT_XBUS_PER_PROC;
        $typeToLimit{"abus"}   = ARCH_LIMIT_ABUS_PER_PROC;
        $typeToLimit{"l4"}     = ARCH_LIMIT_L4_PER_MEMBUF;
        $typeToLimit{"core"}   = ARCH_LIMIT_CORE_PER_EX;
        $typeToLimit{"eq"}     = ARCH_LIMIT_EQ_PER_PROC;
        $typeToLimit{"mca"}    = ARCH_LIMIT_MCA_PER_MCS;
        $typeToLimit{"mi"}     = ARCH_LIMIT_MI_PER_PROC;
        $typeToLimit{"capp"}   = ARCH_LIMIT_CAPP_PER_PROC;
        $typeToLimit{"dmi"}    = ARCH_LIMIT_DMI_PER_MI;
        $typeToLimit{"obus"}   = ARCH_LIMIT_OBUS_PER_PROC;
        $typeToLimit{"nv"}     = ARCH_LIMIT_NV_PER_PROC;
        $typeToLimit{"sbe"}    = ARCH_LIMIT_SBE_PER_PROC;
        $typeToLimit{"ppe"}    = ARCH_LIMIT_PPE_PER_PROC;
        $typeToLimit{"perv"}   = ARCH_LIMIT_PERV_PER_PROC;
        $typeToLimit{"pec"}    = ARCH_LIMIT_PEC_PER_PROC;
        $typeToLimit{"phb"}    = ARCH_LIMIT_PHB_PER_PEC;

    }

    my $parentFapiPos = 0;
    if(defined $parentFapiPosOverride)
    {
        $parentFapiPos = $parentFapiPosOverride;
    }
    else
    {
        my $parentAffinityPath = $affinityPath;
        # Strip off the trailing affinity path component to get the
        # affinity path of the parent.  For example,
        # affinity:sys-0/proc-0/eq-0 becomes affinity:sys-0/proc-0
        $parentAffinityPath =~ s/\/[a-zA-Z]+-[0-9]+$//;

        if(!exists $fapiPosHr->{$parentAffinityPath} )
        {
            die "No record of affinity path $parentAffinityPath";
        }
        $parentFapiPos = $fapiPosHr->{$parentAffinityPath};
    }

    if(exists $typeToLimit{$type})
    {
        # Compute this target's FAPI_POS value.  We first take the parent's
        # FAPI_POS and multiply by the max number of targets of this type that
        # the parent's type can have. This yields the lower bound of this
        # target's FAPI_POS.  Then we add in the relative position of this
        # target with respect to the parent.  Typically this is done by passing
        # in the chip unit, in which case (such as for cores) it can be much
        # greater than the architecture limit ratio (there can be cores with
        # chip units of 0..23, but only 2 cores per ex), so to normalize we
        # have to take the value mod the architecture limit.  Note that this
        # scheme only holds up because every parent also had the same type of
        # calculation to compute its own FAPI_POS.
        my $fapiPos = ($parentFapiPos
            * $typeToLimit{$type}) + ($relativePos % $typeToLimit{$type});

        $fapiPosHr->{$affinityPath} = $fapiPos;

        # Uncomment to emit debug trace to STDERR
        # print STDERR "$fapiPos\n";

        # Indented oddly to get the output XML to line up in the final output
        print "
   <attribute>
       <id>FAPI_POS</id>
       <default>$fapiPos</default>
   </attribute>";

        #mcs MEMVPD_POS is the same as FAPI_POS on single node systems.
        if($type eq "mcs")
        {
            # Uncomment to emit debug trace to STDERR
            # print STDERR "MEMVPD_POS=$fapiPos\n";
        print "
   <attribute>
       <id>MEMVPD_POS</id>
       <default>$fapiPos</default>
   </attribute>";
        }
    }
    else
    {
        die "Invalid type of $type specified";
    }
}

sub generate_proc
{
    my ($proc, $is_master, $ipath, $lognode, $logid, $ordinalId,
        $fsiA, $altfsiA,
        $fruid, $hwTopology, $fapiPosHr) = @_;

    my @fsi = @{$fsiA};
    my @altfsi = @{$altfsiA};
    my $uidstr = sprintf("0x%02X05%04X",${node},${proc});
    my $vpdnum = ${proc};
    my $position = ${proc};
    my $scomFspApath = $devpath->{chip}->{$ipath}->{'scom-path-a'};
    my $scanFspApath = $devpath->{chip}->{$ipath}->{'scan-path-a'};
    my $scomFspAsize = length($scomFspApath) + 1;
    my $scanFspAsize = length($scanFspApath) + 1;
    my $scomFspBpath = "";
    if (ref($devpath->{chip}->{$ipath}->{'scom-path-b'}) ne "HASH")
    {
        $scomFspBpath = $devpath->{chip}->{$ipath}->{'scom-path-b'};
    }
    my $scanFspBpath = "";
    if (ref($devpath->{chip}->{$ipath}->{'scan-path-b'}) ne "HASH")
    {
        $scanFspBpath = $devpath->{chip}->{$ipath}->{'scan-path-b'};
    }
    my $scomFspBsize = length($scomFspBpath) + 1;
    my $scanFspBsize = length($scanFspBpath) + 1;
    my $mboxFspApath = "";
    my $mboxFspAsize = 0;
    my $mboxFspBpath = "";
    my $mboxFspBsize = 0;
    if (exists $devpath->{chip}->{$ipath}->{'mailbox-path-a'})
    {
        $mboxFspApath = $devpath->{chip}->{$ipath}->{'mailbox-path-a'};
        $mboxFspAsize = length($mboxFspApath) + 1;
    }
    if (exists $devpath->{chip}->{$ipath}->{'mailbox-path-b'})
    {
        $mboxFspBpath = $devpath->{chip}->{$ipath}->{'mailbox-path-b'};
        $mboxFspBsize = length($mboxFspBpath) + 1;
    }

    #sbeFifo paths
    my $sbefifoFspApath = "";
    my $sbefifoFspAsize = 0;
    my $sbefifoFspBpath = "";
    my $sbefifoFspBsize = 0;
    if (exists $devpath->{chip}->{$ipath}->{'sbefifo-path-a'})
    {
        $sbefifoFspApath = $devpath->{chip}->{$ipath}->{'sbefifo-path-a'};
        $sbefifoFspAsize = length($sbefifoFspApath) + 1;
    }
    if (exists $devpath->{chip}->{$ipath}->{'sbefifo-path-b'})
    {
        $sbefifoFspBpath = $devpath->{chip}->{$ipath}->{'sbefifo-path-b'};
        $sbefifoFspBsize = length($sbefifoFspBpath) + 1;
    }

    my $psichip = 0;
    my $psilink = 0;
    for my $psi ( 0 .. $#hbPSIs )
    {
        if(($node eq $hbPSIs[$psi][HB_PSI_PROC_NODE_FIELD]) &&
           ($proc eq $hbPSIs[$psi][HB_PSI_PROC_POS_FIELD] ))
        {
            $psichip = $hbPSIs[$psi][HB_PSI_MASTER_CHIP_POSITION_FIELD];
            $psilink = $hbPSIs[$psi][HB_PSI_MASTER_CHIP_UNIT_FIELD];
            last;
        }
    }

    #MURANO=DCM installed, VENICE=SCM
    my $dcm_installed = 0;
    if($CHIPNAME eq "murano")
    {
        $dcm_installed = 1;
    }

    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc";

    my $mruData = get_mruid($ipath);

    # default needed
    my $UseXscom   = $haveFSPs ? 0 : 1;
    my $UseFsiScom = $haveFSPs ? 0 : 1;
    my $UseSbeScom = $haveFSPs ? 1 : 0;

    my $fapi_name = sprintf("pu:k0:n%d:s0:p%02d", $node, $proc);
    print "
    <!-- $SYSNAME n${node}p${proc} processor chip -->

<targetInstance>
    <id>sys${sys}node${node}proc${proc}</id>
    <type>chip-processor-$CHIPNAME</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute><id>POSITION</id><default>${position}</default></attribute>
    <attribute><id>SCOM_SWITCHES</id>
        <default>
            <field><id>useSbeScom</id><value>$UseSbeScom</value></field>
            <field><id>useFsiScom</id><value>$UseFsiScom</value></field>
            <field><id>useXscom</id><value>$UseXscom</value></field>
            <field><id>useInbandScom</id><value>0</value></field>
            <field><id>reserved</id><value>0</value></field>
        </default>
    </attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>FABRIC_GROUP_ID</id>
        <default>$lognode</default>
    </attribute>
    <attribute>
        <id>FABRIC_CHIP_ID</id>
        <default>$logid</default>
    </attribute>
    <attribute>
        <id>FRU_ID</id>
        <default>$fruid</default>
    </attribute>
    <attribute><id>VPD_REC_NUM</id><default>$vpdnum</default></attribute>
    <attribute><id>PROC_DCM_INSTALLED</id>
        <default>$dcm_installed</default>
    </attribute>";

    calcAndAddFapiPos("proc",$affinityPath,$logid,$fapiPosHr,$lognode);

    #For FSP-based systems, the default will always get overridden by the
    # the FSP code before it is used, based on which FSP is being used as
    # the primary.  Therefore, the default is only relevant in the BMC
    # case where it is required since the value generated here will not
    # be updated before it is used by HB.
    ## Master value ##
    if( $is_master && ($proc == 0) )
    {
        print "
    <attribute>
        <id>PROC_MASTER_TYPE</id>
        <default>ACTING_MASTER</default>
    </attribute>";
    }
    elsif( $is_master )
    {
        print "
    <attribute>
        <id>PROC_MASTER_TYPE</id>
        <default>MASTER_CANDIDATE</default>
    </attribute>";
    }
    else
    {
        print "
    <attribute>
        <id>PROC_MASTER_TYPE</id>
        <default>NOT_MASTER</default>
    </attribute>";
    }

    ## Setup FSI Attributes ##
    if( ($#fsi <= 0) && ($#altfsi <= 0) )
    {
        print "
    <!-- No FSI connection -->
    <attribute>
        <id>FSI_MASTER_TYPE</id>
        <default>NO_MASTER</default>
    </attribute>";
    }
    else
    {
        print "
    <!-- FSI connections -->
    <attribute>
        <id>FSI_MASTER_TYPE</id>
        <default>MFSI</default>
    </attribute>";
    }

    # if a proc is sometimes the master then it
    #  will have flipped ports
    my $flipport = 0;
    if( $is_master )
    {
        $flipport = 1;
    }

    # these values are common for both fsi ports
    print "
    <attribute>
        <id>FSI_SLAVE_CASCADE</id>
        <default>0</default>
    </attribute>
    <attribute>
        <id>FSI_OPTION_FLAGS</id>
        <default>
        <field><id>flipPort</id><value>$flipport</value></field>
        <field><id>reserved</id><value>0</value></field>
        </default>
    </attribute>";

    if( $#fsi <= 0 )
    {
        print "
    <!-- FSI-A is not connected -->
    <attribute>
        <id>FSI_MASTER_CHIP</id>
        <default>physical:sys</default><!-- no A path -->
    </attribute>
    <attribute>
        <id>FSI_MASTER_PORT</id>
        <default>0xFF</default><!-- no A path -->
    </attribute>";
    }
    else
    {
        my $mNode = $fsi[FSI_MASTERNODE_FIELD];
        my $mPos = $fsi[FSI_MASTERPOS_FIELD];
        my $link = $fsi[FSI_LINK_FIELD];
        print "
    <!-- FSI-A is connected via node$mNode:proc$mPos:MFSI-$link -->
    <attribute>
        <id>FSI_MASTER_CHIP</id>
        <default>physical:sys-$sys/node-$mNode/proc-$mPos</default>
    </attribute>
    <attribute>
        <id>FSI_MASTER_PORT</id>
        <default>$link</default>
    </attribute>";
    }

    if( $#altfsi <= 0 )
    {
        print "
    <!-- FSI-B is not connected -->
    <attribute>
        <id>ALTFSI_MASTER_CHIP</id>
        <default>physical:sys</default><!-- no B path -->
    </attribute>
    <attribute>
        <id>ALTFSI_MASTER_PORT</id>
        <default>0xFF</default><!-- no B path -->
    </attribute>\n";
    }
    else
    {
        my $mNode = $altfsi[FSI_MASTERNODE_FIELD];
        my $mPos = $altfsi[FSI_MASTERPOS_FIELD];
        my $link = $altfsi[FSI_LINK_FIELD];
        print "
    <!-- FSI-B is connected via node$mNode:proc$mPos:MFSI-$link -->
    <attribute>
        <id>ALTFSI_MASTER_CHIP</id>
        <default>physical:sys-$sys/node-$mNode/proc-$mPos</default>
    </attribute>
    <attribute>
        <id>ALTFSI_MASTER_PORT</id>
        <default>$link</default>
    </attribute>\n";
    }
    print "    <!-- End FSI connections -->\n";
    ## End FSI ##

    # add EEPROM attributes
    addEepromsProc($sys, $node, $proc);

    #add Hot Plug attributes
    addHotPlug($sys,$node,$proc);

    # add I2C_BUS_SPEED_ARRAY attribute
    addI2cBusSpeedArray($sys, $node, $proc, "pu");

    # fsp-specific proc attributes
    do_plugin('fsp_proc',
            $scomFspApath, $scomFspAsize, $scanFspApath, $scanFspAsize,
            $scomFspBpath, $scomFspBsize, $scanFspBpath, $scanFspBsize,
            $node, $proc, $fruid, $ipath, $hwTopology, $mboxFspApath,
            $mboxFspAsize, $mboxFspBpath, $mboxFspBsize, $ordinalId,
            $sbefifoFspApath, $sbefifoFspAsize, $sbefifoFspBpath,
            $sbefifoFspBsize);

    # Data from PHYP Memory Map
    print "\n";
    print "    <!-- Data from PHYP Memory Map -->\n";

    my $nodeSize = 0x200000000000; # 32 TB
    my $chipSize = 0x40000000000;  #  4 TB

    # Calculate the FSP and PSI BRIGDE BASE ADDR
    my $fspBase = 0;
    my $psiBase = 0;
    foreach my $i (@{$psiBus->{'psi-bus'}})
    {
        if (($i->{'processor'}->{target}->{position} eq $proc) &&
            ($i->{'processor'}->{target}->{node} eq $node ))
        {
            #FSP MMIO address
            $fspBase = 0x0006030100000000 + $nodeSize*$lognode +
                         $chipSize*$logid;
            #PSI Link address
            $psiBase = 0x0006030203000000 + $nodeSize*$psichip +
                         $chipSize*$logid;
            last;
        }
    }

    # FSP MMIO address
    printf( "    <attribute><id>FSP_BASE_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n", $fspBase );
    printf( "    </attribute>\n" );

    # PSI Link address
    printf( "    <attribute><id>PSI_BRIDGE_BASE_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n", $psiBase );
    printf( "    </attribute>\n" );

    #PHB 64 bit MMIO address (PHB0-PHB5)
    printf( "    <attribute><id>PHB_MMIO_ADDRS_64</id>\n" );
    printf( "        <default>\n" );
    printf( "            0x%016X,0x%016X,\n",
       0x0006000000000000 + $nodeSize*$lognode + $chipSize*$logid,
       0x0006002000000000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "            0x%016X,0x%016X,\n",
       0x0006004000000000 + $nodeSize*$lognode + $chipSize*$logid,
       0x0006006000000000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "            0x%016X,0x%016X,\n",
       0x0006008000000000 + $nodeSize*$lognode + $chipSize*$logid,
       0x000600A000000000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "        </default>\n" );
    printf( "    </attribute>\n" );

    #PHB 32 Bit MMIO address (PHB0-PHB5)
    printf( "    <attribute><id>PHB_MMIO_ADDRS_32</id>\n" );
    printf( "        <default>\n" );
    printf( "            0x%016X,0x%016X,\n",
       0x000600C000000000 + $nodeSize*$lognode + $chipSize*$logid,
       0x000600C080000000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "            0x%016X,0x%016X,\n",
       0x000600C100000000 + $nodeSize*$lognode + $chipSize*$logid,
       0x000600C180000000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "            0x%016X,0x%016X,\n",
       0x000600C200000000 + $nodeSize*$lognode + $chipSize*$logid,
       0x000600C280000000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "        </default>\n" );
    printf( "    </attribute>\n" );

    #PHB XIVE ESB address (PHB0-PHB5)
    printf( "    <attribute><id>PHB_XIVE_ESB_ADDRS</id>\n" );
    printf( "        <default>\n" );
    printf( "            0x%016X,0x%016X,\n",
       0x000600C300000000 + $nodeSize*$lognode + $chipSize*$logid,
       0x000600C320000000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "            0x%016X,0x%016X,\n",
       0x000600C340000000 + $nodeSize*$lognode + $chipSize*$logid,
       0x000600C360000000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "            0x%016X,0x%016X,\n",
       0x000600C380000000 + $nodeSize*$lognode + $chipSize*$logid,
       0x000600C3A0000000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "        </default>\n" );
    printf( "    </attribute>\n" );

    #PHB Register Space address (PHB0-PHB5)
    printf( "    <attribute><id>PHB_REG_ADDRS</id>\n" );
    printf( "        <default>\n" );
    printf( "            0x%016X,0x%016X,\n",
       0x000600C3C0000000 + $nodeSize*$lognode + $chipSize*$logid,
       0x000600C3C0100000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "            0x%016X,0x%016X,\n",
       0x000600C3C0200000 + $nodeSize*$lognode + $chipSize*$logid,
       0x000600C3C0300000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "            0x%016X,0x%016X,\n",
       0x000600C3C0400000 + $nodeSize*$lognode + $chipSize*$logid,
       0x000600C3C0500000 + $nodeSize*$lognode + $chipSize*$logid);
    printf( "        </default>\n" );
    printf( "    </attribute>\n" );

    #XIVE Routing ESB address
    printf( "    <attribute><id>XIVE_ROUTING_ESB_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006010000000000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #XIVE Routing END address
    printf( "    <attribute><id>XIVE_ROUTING_END_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006011000000000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #XIVE Presentation NVT address
    printf( "    <attribute><id>XIVE_PRESENTATION_NVT_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006012000000000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #VAS Hypervisor Window Contexts address
    printf( "    <attribute><id>VAS_HYPERVISOR_WINDOW_CONTEXT_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006013000000000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #VAS User Window Contexts address
    printf( "    <attribute><id>VAS_USER_WINDOW_CONTEXT_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006013100000000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #LPC Bus address
    printf( "    <attribute><id>LPC_BUS_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006030000000000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #Nvidia Link - NPU Priviledged address
    printf( "    <attribute><id>NVIDIA_NPU_PRIVILEGED_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006030200000000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #Nvidia Link - NPU User Regs address
    printf( "    <attribute><id>NVIDIA_NPU_USER_REG_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006030201000000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #Nvidia Link - Phy 0 Regs address
    printf( "    <attribute><id>NVIDIA_PHY0_REG_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006030201200000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #Nvidia Link - Phy 1 Regs address
    printf( "    <attribute><id>NVIDIA_PHY1_REG_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006030201400000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #XIVE - Controller Bar address
    printf( "    <attribute><id>XIVE_CONTROLLER_BAR_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006030203100000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #XIVE - Presentation Bar address
    printf( "    <attribute><id>XIVE_PRESENTATION_BAR_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006030203180000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #XIVE - Thread Management Bar Address register 1
    printf( "    <attribute><id>XIVE_THREAD_MGMT1_BAR_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x0006020000000000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #PSI HB - ESP space address
    printf( "    <attribute><id>PSI_HB_ESB_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x00060302031C0000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #NX - RNG space address
    printf( "    <attribute><id>NX_RNG_ADDR</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x00060302031D0000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    #XSCOM address
    printf( "    <attribute><id>XSCOM_BASE_ADDRESS</id>\n" );
    printf( "        <default>0x%016X</default>\n",
       0x000603FC00000000 + $nodeSize*$lognode + $chipSize*$logid );
    printf( "    </attribute>\n" );

    print "    <!-- End PHYP Memory Map -->\n\n";
    # end PHYP Memory Map

    print "    <!-- PROC_PCIE_ attributes -->\n";
    addProcPcieAttrs( $proc, $node );

    print "    <!-- End PROC_PCIE_ attributes -->\n";

    if ((scalar @SortedPmChipAttr) == 0)
    {
        # Default the values.
        print "    <!-- PM_ attributes (default values) -->\n";
        print "    <attribute>\n";
        print "        <id>PM_UNDERVOLTING_FRQ_MINIMUM</id>\n";
        print "        <default>0</default>\n";
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_UNDERVOLTING_FREQ_MAXIMUM</id>\n";
        print "        <default>0</default>\n";
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_SPIVID_PORT_ENABLE</id>\n";
        if( $proc % 2 == 0 ) # proc0 of DCM
        {
            print "        <default>0x4</default><!-- PORT0NONRED -->\n";
        }
        else # proc1 of DCM
        {
            print "        <default>0x0</default><!-- NONE -->\n";
        }
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_APSS_CHIP_SELECT</id>\n";
        if( $proc % 2 == 0 ) # proc0 of DCM
        {
            print "        <default>0x00</default><!-- CS0 -->\n";
        }
        else # proc1 of DCM
        {
            print "        <default>0xFF</default><!-- NONE -->\n";
        }
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_PBAX_NODEID</id>\n";
        print "        <default>0</default>\n";
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_PBAX_CHIPID</id>\n";
        print "        <default>$logid</default>\n";
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_PBAX_BRDCST_ID_VECTOR</id>\n";
        print "        <default>$lognode</default>\n";
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_SLEEP_ENTRY</id>\n";
        print "        <default>0x0</default>\n";
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_SLEEP_EXIT</id>\n";
        print "        <default>0x0</default>\n";
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_SLEEP_TYPE</id>\n";
        print "        <default>0x0</default>\n";
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_WINKLE_ENTRY</id>\n";
        print "        <default>0x0</default>\n";
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_WINKLE_EXIT</id>\n";
        print "        <default>0x0</default>\n";
        print "    </attribute>\n";
        print "    <attribute>\n";
        print "        <id>PM_WINKLE_TYPE</id>\n";
        print "        <default>0x0</default>\n";
        print "    </attribute>\n";
        print "    <!-- End PM_ attributes (default values) -->\n";
    }
    else
    {
        print "    <!-- PM_ attributes -->\n";
        addProcPmAttrs( $proc, $node );
        print "    <!-- End PM_ attributes -->\n";
    }

    # Pull the value from the system policy we grabbed earlier
    print "    <attribute>\n";
    print "        <id>BOOT_FREQ_MHZ</id>\n";
    print "        <default>$reqPol->{'boot-frequency'}->{content}</default>\n";
    print "    </attribute>\n";


    my $nXpY = "n" . $node . "p" . $proc;
    foreach my $attr (keys %procLoadline)
    {
        my $val;
        if(defined $procLoadline{$attr}{ $nXpY })
        {
            $val = $procLoadline{$attr}{ $nXpY };
        }
        else
        {
            $val = $procLoadline{$attr}{sys};
        }
        print "    <attribute>\n";
        print "        <id>$attr</id>\n";
        print "        <default>$val</default>\n";
        print "    </attribute>\n";
    }

    print "</targetInstance>\n";

}

sub generate_ex
{
    my ($proc, $ex, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X06%04X",${node},$proc*MAX_EX_PER_PROC + $ex);
    my $eq = ($ex - ($ex%2))/2;
    my $ex_orig = $ex;
    $ex = $ex % 2;
    my $mruData = get_mruid($ipath);
    my $fapi_name = sprintf("pu.ex:k0:n%d:s0:p%02d:c%d", $node, $proc,$ex_orig);
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/eq-$eq/ex-$ex";
    #EX is a logical target, Chiplet ID is the chiplet id of their immediate
    #parent which is EQ. The range of EQ is 0x10 - 0x15
    my $chipletId = sprintf("0x%X",(($ex_orig/2) + 0x10));
    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}eq${eq}ex$ex</id>
    <type>unit-ex-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/eq-$eq/ex-$ex</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$ex_orig</default>
    </attribute>
    <attribute>
        <id>CHIPLET_ID</id>
        <default>$chipletId</default>
    </attribute>";

    calcAndAddFapiPos("ex",$affinityPath,$ex_orig,$fapiPosHr);

    # call to do any fsp per-ex attributes
    do_plugin('fsp_ex', $proc, $ex, $ordinalId );

    print "
</targetInstance>
";
}

sub getPervasiveForUnit
{
    # Input should be of the form <type><chip unit>, example: "core0"
    my ($unit) = @_;

    # The mapping is a static variable that is preserved across new calls to
    # the function to speed up the mapping performance
    state %unitToPervasive;

    if ( not %unitToPervasive )
    {
        for my $core (0..MAX_CORE_PER_PROC-1)
        {
            $unitToPervasive{"core$core"} = 32 + $core;
        }
        for my $eq (0..MAX_EQ_PER_PROC-1)
        {
            $unitToPervasive{"eq$eq"} = 16 + $eq;
        }
        for my $xbus (0..MAX_XBUS_PER_PROC-1)
        {
            $unitToPervasive{"xbus$xbus"} = 6;
        }
        for my $obus (0..MAX_OBUS_PER_PROC-1)
        {
            $unitToPervasive{"obus$obus"} = 9 + $obus;
        }
        for my $capp (0..MAX_CAPP_PER_PROC-1)
        {
            $unitToPervasive{"capp$capp"} = 2 * ($capp+1);
        }
        for my $mcbist (0..MAX_MCBIST_PER_PROC-1)
        {
            $unitToPervasive{"mcbist$mcbist"} = 7 + $mcbist;
        }
        for my $mcs (0..MAX_MCS_PER_PROC-1)
        {
            $unitToPervasive{"mcs$mcs"} = 7 + ($mcs > 1);
        }
        for my $mca (0..MAX_MCA_PER_PROC-1)
        {
            $unitToPervasive{"mca$mca"} = 7 + ($mca > 3);
        }
        for my $pec (0..MAX_PEC_PER_PROC-1)
        {
            $unitToPervasive{"pec$pec"} = 13 + $pec;
        }
        for my $phb (0..MAX_PHB_PER_PROC-1)
        {
            $unitToPervasive{"phb$phb"} = 13 + ($phb>0) + ($phb>2);
        }
        for my $nv (0..MAX_NV_PER_PROC-1)
        {
            $unitToPervasive{"nv$nv"} = 5;
        }
    }

    my $pervasive = "unknown";
    if(exists $unitToPervasive{$unit})
    {
        $pervasive = $unitToPervasive{$unit};
    }
    else
    {
        die "Cannot find pervasive for $unit";
    }

    return $pervasive
}

sub addPervasiveParentLink
{
    my ($sys,$node,$proc,$unit,$type) = @_;

    my $pervasive = getPervasiveForUnit("$type$unit");

    print "
    <attribute>
        <id>PARENT_PERVASIVE</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/perv-$pervasive</default>
    </attribute>";
}

sub generate_core
{
    my ($proc, $core, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X07%04X",${node},
                         $proc*MAX_CORE_PER_PROC + $core);
    my $mruData = get_mruid($ipath);
    my $core_orig = $core;
    my $ex = (($core - ($core % 2))/2) % 2;
    my $eq = ($core - ($core % 4))/4;
    $core = $core % 2;
    #Chiplet ID range for Cores start with 0x20
    my $chipletId = sprintf("0x%X",($core_orig + 0x20));
    my $fapi_name = sprintf("pu.core:k0:n%d:s0:p%02d:c%d",
                            $node, $proc, $core_orig);
    my $affinityPath =
        "affinity:sys-$sys/node-$node/proc-$proc/eq-$eq/ex-$ex/core-$core";
    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}eq${eq}ex${ex}core$core</id>
    <type>unit-core-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/eq-$eq/ex-$ex/core-$core</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$core_orig</default>
    </attribute>
    <attribute>
        <id>CHIPLET_ID</id>
        <default>$chipletId</default>
    </attribute>";

    addPervasiveParentLink($sys,$node,$proc,$core_orig,"core");

    calcAndAddFapiPos("core",$affinityPath,$core_orig,$fapiPosHr);

    # call to do any fsp per-ex_core attributes
    do_plugin('fsp_ex_core', $proc, $core, $ordinalId );

    my $snbase=62;

    my $tempsnbase= 137;
    my $freqsnbase= 149;
    # $TODO RTC:110399
    if( $haveFSPs == 0 )
    {

     my $procsn = $snbase+$ordinalId;
     my $tempsn = $tempsnbase+$ordinalId;
     my $freqsn = $freqsnbase+$ordinalId;


      print "\n<!-- IPMI Sensor numbers for Core status -->
    <attribute>
        <id>IPMI_SENSORS</id>
         <default>
             0x0100, $tempsn, <!-- Temperature sensor -->
             0x0500, $procsn, <!-- State sensor -->
             0xC100, $freqsn, <!-- Frequency sensor -->
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF,
             0xFFFF, 0xFF
         </default>
     </attribute>\n";
    }


    print "
</targetInstance>
";
}

sub generate_eq
{
    my ($proc, $eq, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X23%04X",${node},$proc*MAX_EQ_PER_PROC + $eq);
    my $mruData = get_mruid($ipath);
    my $fapi_name = sprintf("pu.eq:k0:n%d:s0:p%02d:c%d", $node, $proc, $eq);
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/eq-$eq";
    #Chiplet ID range for EQ start with 0x10
    my $chipletId = sprintf("0x%X",($eq + 0x10));

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}eq$eq</id>
    <type>unit-eq-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/eq-$eq</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$eq</default>
    </attribute>
    <attribute>
        <id>CHIPLET_ID</id>
        <default>$chipletId</default>
    </attribute>";

    addPervasiveParentLink($sys,$node,$proc,$eq,"eq");

    calcAndAddFapiPos("eq",$affinityPath,$eq,$fapiPosHr);

    # call to do any fsp per-eq attributes
    do_plugin('fsp_eq', $proc, $eq, $ordinalId );

    print "
</targetInstance>
";
}


sub generate_mcs
{
    my ($proc, $mcs, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X0B%04X",${node},$proc*MAX_MCS_PER_PROC + $mcs);
    my $mruData = get_mruid($ipath);
    my $mcs_orig = $mcs;
    $mcs = $mcs%2;
    my $mcbist = ($mcs_orig - ($mcs_orig%2))/2;

    #MCS is a logical target, Chiplet ID is the chiplet id of their immediate
    #parent which is MCBIST. The range of MCBIST is 0x07 - 0x08
    my $chipletId = sprintf("0x%X",($mcbist + 0x07));

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
            $lognode = $chipIDs[$j][CHIP_ID_NODE];
            $logid = $chipIDs[$j][CHIP_ID_POS];
            last;
        }
    }

    #TODO:RTC 139073
    #IBSCOM address range starts at 0x0003E00000000000 (992 TB)
    #128GB per MCS/Centaur
    #Addresses assigned by logical node, not physical node
    my $mscStr = sprintf("0x%016X", 0x0003E00000000000 +
                   0x40000000000*$lognode +
                   0x10000000000*$logid + 0x2000000000*$mcs);

    my $lane_swap = 0;
    my $msb_swap = 0;
    my $swizzle = 0;
    foreach my $dmi ( @dbus_mcs )
    {
        if (($dmi->[DBUS_MCS_NODE_INDEX] eq ${node} ) &&
            ( $dmi->[DBUS_MCS_PROC_INDEX] eq $proc  ) &&
            ($dmi->[DBUS_MCS_UNIT_INDEX] eq  $mcs_orig   ))
        {
            $lane_swap = $dmi->[DBUS_MCS_DOWNSTREAM_INDEX];
            $msb_swap = $dmi->[DBUS_MCS_TX_SWAP_INDEX];
            $swizzle = $dmi->[DBUS_MCS_SWIZZLE_INDEX];
            last;
        }
    }
    my $physicalPath = "physical:sys-$sys/node-$node/proc-$proc"
                       . "/mcbist-$mcbist/mcs-$mcs";
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc"
                       . "/mcbist-$mcbist/mcs-$mcs";

    my $fapi_name =
               sprintf("pu.mcs:k0:n%d:s0:p%02d:c%d", $node, $proc, $mcs_orig);
    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}mcbist${mcbist}mcs$mcs</id>
    <type>unit-mcs-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>$physicalPath</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$mcs_orig</default>
    </attribute>
    <attribute>
        <id>CHIPLET_ID</id>
        <default>$chipletId</default>
    </attribute>
    <attribute><id>IBSCOM_MCS_BASE_ADDR</id>
        <!-- baseAddr = 0x0003E00000000000, 128GB per MCS -->
        <default>$mscStr</default>
    </attribute>
    <attribute>
        <id>EI_BUS_TX_MSBSWAP</id>
        <default>$msb_swap</default>
    </attribute>
    <attribute><id>VPD_REC_NUM</id><default>0</default></attribute>";

    addPervasiveParentLink($sys,$node,$proc,$mcs_orig,"mcs");

    calcAndAddFapiPos("mcs",$affinityPath,$mcs_orig,$fapiPosHr);

    # call to do any fsp per-mcs attributes
    do_plugin('fsp_mcs', $proc, $mcs, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_mca
{
    my ($proc, $mca, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X24%04X",${node},$proc*MAX_MCA_PER_PROC + $mca);
    my $mruData = get_mruid($ipath);
    my $mcs = (($mca - ($mca%2))/2)%2;
    my $mcbist = ($mca - ($mca%4))/4;
    my $mca_orig = $mca;
    $mca = $mca % 2;
    #MCA is a logical target, Chiplet ID is the chiplet id of their immediate
    #parent which is MCS. since MCS is the also logical, therefore the
    # chiplet id of MCSIST will be returned. The range of MCBIST is 0x07 - 0x08
    my $chipletId = sprintf("0x%X",($mcbist + 0x07));

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
            $lognode = $chipIDs[$j][CHIP_ID_NODE];
            $logid = $chipIDs[$j][CHIP_ID_POS];
            last;
        }
    }
    my $fapi_name = sprintf("pu.mca:k0:n%d:s0:p%02d:c%d",
                            $node, $proc, $mca_orig);
    my $affinityPath =
        "affinity:sys-$sys/node-$node/proc-$proc"
        . "/mcbist-$mcbist/mcs-$mcs/mca-$mca";
    my $physicalPath =
        "physical:sys-$sys/node-$node/proc-$proc"
         . "/mcbist-$mcbist/mcs-$mcs/mca-$mca";

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}mcbist${mcbist}mcs${mcs}mca$mca</id>
    <type>unit-mca-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>$physicalPath</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$mca_orig</default>
    </attribute>
    <attribute>
        <id>CHIPLET_ID</id>
        <default>$chipletId</default>
    </attribute>";

    addPervasiveParentLink($sys,$node,$proc,$mca_orig,"mca");

    calcAndAddFapiPos("mca",$affinityPath,$mca_orig,$fapiPosHr);

    # call to do any fsp per-mca attributes
    do_plugin('fsp_mca', $proc, $mca_orig, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_mcbist
{
    my ($proc, $mcbist, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X25%04X",${node},$proc*MAX_MCBIST_PER_PROC + $mcbist);
    my $mruData = get_mruid($ipath);

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
            $lognode = $chipIDs[$j][CHIP_ID_NODE];
            $logid = $chipIDs[$j][CHIP_ID_POS];
            last;
        }
    }
    my $fapi_name = sprintf("pu.mcbist:k0:n%d:s0:p%02d:c%d",
                            $node, $proc, $mcbist);
    my $physicalPath="physical:sys-$sys/node-$node/proc-$proc/mcbist-$mcbist";
    my $affinityPath="affinity:sys-$sys/node-$node/proc-$proc/mcbist-$mcbist";

    #Chiplet ID range for 2 MCBIST start with 0x07
    my $chipletId = sprintf("0x%X",($mcbist + 0x07));

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}mcbist$mcbist</id>
    <type>unit-mcbist-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>$physicalPath</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$mcbist</default>
    </attribute>
    <attribute>
        <id>CHIPLET_ID</id>
        <default>$chipletId</default>
    </attribute>";

    addPervasiveParentLink($sys,$node,$proc,$mcbist,"mcbist");

    calcAndAddFapiPos("mcbist",$affinityPath,$mcbist,$fapiPosHr);

    # call to do any fsp per-mcbist attributes
    do_plugin('fsp_mcbist', $proc, $mcbist, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_pec
{
    my ($proc, $pec, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X2D%04X",${node},$proc*MAX_PEC_PER_PROC + $pec);
    my $mruData = get_mruid($ipath);

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
            $lognode = $chipIDs[$j][CHIP_ID_NODE];
            $logid = $chipIDs[$j][CHIP_ID_POS];
            last;
        }
    }
    my $fapi_name = sprintf("pu.pec:k0:n%d:s0:p%02d:c%d", $node, $proc, $pec);

    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/pec-$pec";

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}pec$pec</id>
    <type>unit-pec-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/pec-$pec</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$pec</default>
    </attribute>";

    addPervasiveParentLink($sys,$node,$proc,$pec,"pec");

    calcAndAddFapiPos("pec",$affinityPath,$pec,$fapiPosHr);

    # call to do any fsp per-pec attributes
    do_plugin('fsp_pec', $proc, $pec, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_phb_chiplet
{
    my ($proc, $phb, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $phb_orig = $phb;
    my $uidstr = sprintf("0x%02X2E%04X",${node},$proc*MAX_PHB_PER_PROC + $phb);
    my $mruData = get_mruid($ipath);
    my $pec = 0;
    my $phbChipUnit = $phb;
    if($phb > 0 && $phb < 3)
    {
        $pec = 1;
        $phb = $phb - 1;
    }
    elsif($phb >= 3)
    {
        $pec = 2;
        $phb = $phb - 3;
    }

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
           $lognode = $chipIDs[$j][CHIP_ID_NODE];
           $logid = $chipIDs[$j][CHIP_ID_POS];
           last;
        }
    }

    my $fapi_name = sprintf("pu.phb:k0:n%d:s0:p%02d:c%d",
                            $node, $proc, $phb_orig);
    my $affinityPath =
        "affinity:sys-$sys/node-$node/proc-$proc/pec-$pec/phb-$phb";

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}pec${pec}phb$phb</id>
    <type>unit-phb-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/pec-$pec/phb-$phb</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$phbChipUnit</default>
    </attribute>";

    addPervasiveParentLink($sys,$node,$proc,$phbChipUnit,"phb");

    calcAndAddFapiPos("phb",$affinityPath,$phb,$fapiPosHr);

    # call to do any fsp per-phb attributes
    do_plugin('fsp_phb', $proc, $phb, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_ppe
{
    my ($proc, $ppe, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X2B%04X",${node},$proc*MAX_PPE_PER_PROC + $ppe);
    my $mruData = get_mruid($ipath);

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
            $lognode = $chipIDs[$j][CHIP_ID_NODE];
            $logid = $chipIDs[$j][CHIP_ID_POS];
            last;
        }
    }
    my $fapi_name = sprintf("pu.ppe:k0:n%d:s0:p%02d:c%d", $node, $proc, $ppe);

    my $affinityPath="affinity:sys-$sys/node-$node/proc-$proc/ppe-$ppe";

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}ppe$ppe</id>
    <type>unit-ppe-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/ppe-$ppe</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$ppe</default>
    </attribute>";

    calcAndAddFapiPos("ppe",$affinityPath,$ppe,$fapiPosHr);

    # call to do any fsp per-ppe attributes
    do_plugin('fsp_ppe', $proc, $ppe, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_obus
{
    my ($proc, $obus, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X28%04X",${node},
                         $proc*MAX_OBUS_PER_PROC + $obus);
    my $mruData = get_mruid($ipath);

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
            $lognode = $chipIDs[$j][CHIP_ID_NODE];
            $logid = $chipIDs[$j][CHIP_ID_POS];
            last;
        }
    }

    #Chiplet ID range for OBUS start with 0x09
    my $chipletId = sprintf("0x%X",($obus + 0x09));

    my $fapi_name = sprintf("pu.obus:k0:n%d:s0:p%02d:c%d", $node, $proc, $obus);
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/obus-$obus";

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}obus$obus</id>
    <type>unit-obus-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/obus-$obus</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$obus</default>
    </attribute>
    <attribute>
        <id>CHIPLET_ID</id>
        <default>$chipletId</default>
    </attribute>";

    addPervasiveParentLink($sys,$node,$proc,$obus,"obus");

    calcAndAddFapiPos("obus",$affinityPath,$obus,$fapiPosHr);

    # call to do any fsp per-obus attributes
    do_plugin('fsp_obus', $proc, $obus, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_xbus
{
    my ($proc, $xbus, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $mruData = get_mruid($ipath);
    my $uidstr = sprintf("0x%02X0E%04X",${node},$proc*MAX_XBUS_PER_PROC + $xbus);

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
            $lognode = $chipIDs[$j][CHIP_ID_NODE];
            $logid = $chipIDs[$j][CHIP_ID_POS];
            last;
        }
    }

    my $fapi_name = sprintf("pu.xbus:k0:n%d:s0:p%02d:c%d", $node, $proc, $xbus);
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/xbus-$xbus";

    #Chiplet ID for XBUS is 0x06
    my $chipletId = sprintf("0x%X", 0x06);

    # Peer target variables
    my $peer;
    my $p_proc;
    my $p_port;
    my $p_node;

    # See if this bus is connected to anything
    foreach my $pbus ( @pbus )
    {
        if ($pbus->[PBUS_FIRST_END_POINT_INDEX] eq
            "n${node}:p${proc}:x${xbus}" )
        {
            if ($pbus->[PBUS_SECOND_END_POINT_INDEX] ne "invalid")
            {
                $peer = 1;
                $p_proc = $pbus->[PBUS_SECOND_END_POINT_INDEX];
                $p_port = $p_proc;
                $p_node = $pbus->[PBUS_SECOND_END_POINT_INDEX];
                $p_node =~ s/^n(.*):p.*:.*$/$1/;
                $p_proc =~ s/^.*:p(.*):.*$/$1/;
                $p_port =~ s/.*:p.*:.(.*)$/$1/;
                my $node_config = $pbus->[PBUS_NODE_CONFIG_FLAG];
                last;
            }
        }
    }

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}xbus$xbus</id>
    <type>unit-xbus-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/xbus-$xbus</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$xbus</default>
    </attribute>
    <attribute>
        <id>CHIPLET_ID</id>
        <default>$chipletId</default>
    </attribute>";

    if ($peer)
    {
        my $peerPhysPath = "physical:sys-${sys}/node-${p_node}/"
            ."proc-${p_proc}/xbus-${p_port}";
        my $peerHuid = sprintf("0x%02X0E%04X",${p_node},
            $p_proc*MAX_XBUS_PER_PROC + $p_port);

    print "
    <attribute>
        <id>PEER_TARGET</id>
        <default>$peerPhysPath</default>
    </attribute>
    <compileAttribute>
        <id>PEER_HUID</id>
        <default>${peerHuid}</default>
    </compileAttribute>";

    }

    addPervasiveParentLink($sys,$node,$proc,$xbus,"xbus");

    calcAndAddFapiPos("xbus",$affinityPath,$xbus,$fapiPosHr);

    # call to do any fsp per-obus attributes
    do_plugin('fsp_xbus', $proc, $xbus, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_perv
{
    my ($proc, $perv, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X2C%04X",${node},$proc*MAX_PERV_PER_PROC + $perv);
    my $mruData = get_mruid($ipath);

    #Chiplet ID for PERV is 0x01
    my $chipletId = sprintf("0x%X", $perv);

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
            $lognode = $chipIDs[$j][CHIP_ID_NODE];
            $logid = $chipIDs[$j][CHIP_ID_POS];
            last;
        }
    }
    my $fapi_name = sprintf("pu.perv:k0:n%d:s0:p%02d:c%d", $node, $proc,$perv);
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/perv-$perv";

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}perv$perv</id>
    <type>unit-perv-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/perv-$perv</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$perv</default>
    </attribute>
    <attribute>
        <id>CHIPLET_ID</id>
        <default>$chipletId</default>
    </attribute>";

    calcAndAddFapiPos("perv",$affinityPath,$perv,$fapiPosHr);

    # call to do any fsp per-perv attributes
    do_plugin('fsp_perv', $proc, $perv, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_capp
{
    my ($proc, $capp, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X21%04X",${node},$proc*MAX_CAPP_PER_PROC + $capp);
    my $mruData = get_mruid($ipath);

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
            $lognode = $chipIDs[$j][CHIP_ID_NODE];
            $logid = $chipIDs[$j][CHIP_ID_POS];
            last;
        }
    }

    my $fapi_name = sprintf("pu.capp:k0:n%d:s0:p%02d:c%d", $node, $proc,$capp);
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/capp-$capp";

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}capp$capp</id>
    <type>unit-capp-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/capp-$capp</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$capp</default>
    </attribute>";

    addPervasiveParentLink($sys,$node,$proc,$capp,"capp");

    calcAndAddFapiPos("capp",$affinityPath,$capp,$fapiPosHr);

    # call to do any fsp per-capp attributes
    do_plugin('fsp_capp', $proc, $capp, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_sbe
{
    my ($proc, $sbe, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $uidstr = sprintf("0x%02X2A%04X",${node},$proc*MAX_SBE_PER_PROC + $sbe);
    my $mruData = get_mruid($ipath);

    my $lognode;
    my $logid;
    for (my $j = 0; $j <= $#chipIDs; $j++)
    {
        if ($chipIDs[$j][CHIP_ID_NXPX] eq "n${node}:p${proc}")
        {
            $lognode = $chipIDs[$j][CHIP_ID_NODE];
            $logid = $chipIDs[$j][CHIP_ID_POS];
            last;
        }
    }
    my $fapi_name = sprintf("pu.sbe:k0:n%d:s0:p%02d:c%d", $node, $proc,$sbe);
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/sbe-$sbe";

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}sbe$sbe</id>
    <type>unit-sbe-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/sbe-$sbe</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$sbe</default>
    </attribute>";

    calcAndAddFapiPos("sbe",$affinityPath,$sbe,$fapiPosHr);

    # call to do any fsp per-sbe attributes
    do_plugin('fsp_sbe', $proc, $sbe, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_nv
{
    my ($proc,$ordinalId) = @_;
    my $proc_name = "n${node}:p${proc}";
    print "\n<!-- $SYSNAME n${node}p${proc} NV units -->\n";

    for my $i ( 0 .. MAX_NV_PER_PROC-1 )
    {
        generate_a_nv( $proc, $i, MAX_NV_PER_PROC,
            ($ordinalId*MAX_NV_PER_PROC)+$i );
    }
}

my $nvIpathInit = 0;
my %nvList = ();
sub generate_nv_ipath
{
    #get the nv ipath detail using previously computed $eTargets
    foreach my $Target (@{$eTargets->{target}})
    {
        #get the nv ipath detail
        #@TODO-RTC:156600
        if($Target->{'ecmd-common-name'} eq "nvbus")
        {
            my $node = $Target->{'node'};
            my $position = $Target->{'position'};
            my $chipUnit = $Target->{'chip-unit'};
            my $ipath = $Target->{'instance-path'};

            $nvList{$node}{$position}{$chipUnit} = {
                'node'         => $node,
                'position'     => $position,
                'nvChipUnit'   => $chipUnit,
                'nvIpath'      => $ipath,
            }
        }
    }
}

sub generate_a_nv
{
    my ($proc, $nv, $max_nv, $ordinalId) = @_;
    my $uidstr = sprintf("0x%02X29%04X",${node},$proc*$max_nv + $nv);

    # Get the NV info
    if ($nvIpathInit == 0)
    {
        generate_nv_ipath;
        $nvIpathInit = 1;
    }

    my $fapi_name = "NA"; # NV not FAPI target

    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}nv${nv}</id>
    <type>unit-nv-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/nv-$nv</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/nv-$nv</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$nvList{$node}{$proc}{$nv}->{'nvIpath'}</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$nv</default>
    </attribute>";

    addPervasiveParentLink($sys,$node,$proc,$nv,"nv");

    print "
</targetInstance>
";
}

my $nxInit = 0;
my %nxList = ();
sub generate_nx_ipath
{
    foreach my $Target (@{$eTargets->{target}})
    {
        #get the nx ipath detail
        if($Target->{'ecmd-common-name'} eq "nx")
        {
            my $ipath = $Target->{'instance-path'};
            my $node = $Target->{node};
            my $position = $Target->{position};

            $nxList{$node}{$position} = {
                'node'         => $node,
                'position'     => $position,
                'instancePath' => $ipath,
            }
        }
    }
}

sub generate_nx
{
    my ($proc, $ordinalId, $node) = @_;
    my $uidstr = sprintf("0x%02X1E%04X",${node},$proc);

    # Get the nx info
    if ($nxInit == 0)
    {
        generate_nx_ipath;
        $nxInit = 1;
    }

    my $ipath = $nxList{$node}{$proc}->{'instancePath'};
    my $mruData = get_mruid($ipath);
    my $fapi_name = "NA"; # nx not FAPI target

    print "\n<!-- $SYSNAME n${node}p$proc NX units -->\n";
    print "
<targetInstance>
    <id>sys${sys}node${node}proc${proc}nx0</id>
    <type>unit-nx-power9</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/nx-0</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/nx-0</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>0</default>
    </attribute>";

    # call to do any fsp per-nx attributes
    do_plugin('fsp_nx', $proc, $ordinalId );

    print "
</targetInstance>
";
}

my $logicalDimmInit = 0;
my %logicalDimmList = ();
sub generate_logicalDimms
{
    my $memory_busses_file = open_mrw_file($::mrwdir,
                                           "${sysname}-memory-busses.xml");
    my $dramTargets = parse_xml_file($memory_busses_file);

    #get the DRAM details
    foreach my $Target (@{$dramTargets->{drams}->{dram}})
    {
        my $node = $Target->{'assembly-position'};
        my $ipath = $Target->{'dram-instance-path'};
        my $dimmIpath = $Target->{'dimm-instance-path'};
        my $mbaIpath = $Target->{'mba-instance-path'};
        my $mbaPort = $Target->{'mba-port'};
        my $mbaSlot = $Target->{'mba-slot'};

        my $dimm = substr($dimmIpath, index($dimmIpath, 'dimm-')+5);
        my $mba = substr($mbaIpath, index($mbaIpath, 'mba')+3);

        $logicalDimmList{$node}{$dimm}{$mba}{$mbaPort}{$mbaSlot} = {
                'node'             => $node,
                'dimmIpath'        => $dimmIpath,
                'mbaIpath'         => $mbaIpath,
                'dimm'             => $dimm,
                'mba'              => $mba,
                'mbaPort'          => $mbaPort,
                'mbaSlot'          => $mbaSlot,
                'logicalDimmIpath' => $ipath,
        }
    }
}

sub generate_centaur
{
    my ($ctaur, $mcs, $fsiA, $altfsiA, $ipath, $ordinalId, $relativeCentaurRid,
        $ipath, $membufVrmUuidHash,$fapiPosHr) = @_;

    my @fsi = @{$fsiA};
    my @altfsi = @{$altfsiA};
    my $scomFspApath = $devpath->{chip}->{$ipath}->{'scom-path-a'};
    my $scanFspApath = $devpath->{chip}->{$ipath}->{'scan-path-a'};
    my $scomFspAsize = length($scomFspApath) + 1;
    my $scanFspAsize = length($scanFspApath) + 1;
    my $scomFspBpath = "";

    if (ref($devpath->{chip}->{$ipath}->{'scom-path-b'}) ne "HASH")
    {
        $scomFspBpath = $devpath->{chip}->{$ipath}->{'scom-path-b'};
    }
    my $scanFspBpath = "";
    if (ref($devpath->{chip}->{$ipath}->{'scan-path-b'}) ne "HASH")
    {
        $scanFspBpath = $devpath->{chip}->{$ipath}->{'scan-path-b'};
    }
    my $scomFspBsize = length($scomFspBpath) + 1;
    my $scanFspBsize = length($scanFspBpath) + 1;
    my $proc = $mcs;
    $proc =~ s/.*:p(.*):.*/$1/g;
    $mcs =~ s/.*:.*:mcs(.*)/$1/g;

    my $mruData = get_mruid($ipath);
    my $uidstr = sprintf("0x%02X04%04X",${node},$proc*MAX_MCS_PER_PROC + $mcs);

    my $lane_swap = 0;
    my $msb_swap = 0;
    foreach my $dmi ( @dbus_centaur )
    {
        if (($dmi->[DBUS_CENTAUR_NODE_INDEX] eq ${node} ) &&
            ($dmi->[DBUS_CENTAUR_MEMBUF_INDEX] eq $ctaur) )
        {
            $lane_swap = $dmi->[DBUS_CENTAUR_UPSTREAM_INDEX];
            # Note: We swap rx/tx when we fill in the array, so there's no
            # need to use rx here - we already accounted for direction
            $msb_swap = $dmi->[DBUS_CENTAUR_TX_SWAP_INDEX];
            last;
        }
    }

    # Get the logical DIMM info
    if ($logicalDimmInit == 0)
    {
        generate_logicalDimms;
        $logicalDimmInit = 1;
    }

    my $fapi_name = sprintf("pu.centaur:k0:n%d:s0:p%02d:c0",
                            $node, $ctaur);
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/mcs-$mcs/"
            . "membuf-$ctaur";
    print "
<!-- $SYSNAME Centaur n${node}p${ctaur} : start -->

<targetInstance>
    <id>sys${sys}node${node}membuf${ctaur}</id>
    <type>chip-membuf-centaur</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute><id>POSITION</id><default>$ctaur</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/membuf-$ctaur</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>EI_BUS_TX_MSBSWAP</id>
        <default>$msb_swap</default>
    </attribute>";

    calcAndAddFapiPos("membuf",$affinityPath,0,$fapiPosHr);

    # FSI Connections #
    if( $#fsi <= 0 )
    {
        die "\n*** No valid FSI link found for Centaur $ctaur ***\n";
    }

    print "\n
    <!-- FSI connections -->
    <attribute>
        <id>FSI_MASTER_TYPE</id>
        <default>CMFSI</default>
    </attribute>
    <attribute>
        <id>FSI_SLAVE_CASCADE</id>
        <default>0</default>
    </attribute>
    <attribute>
        <id>FSI_OPTION_FLAGS</id>
        <default>
        <field><id>flipPort</id><value>0</value></field>
        <field><id>reserved</id><value>0</value></field>
        </default>
    </attribute>";

    my $mNode = $fsi[FSI_MASTERNODE_FIELD];
    my $mPos = $fsi[FSI_MASTERPOS_FIELD];
    my $link = $fsi[FSI_LINK_FIELD];
    print "
    <!-- FSI-A is connected via node$mNode:proc$mPos:CMFSI-$link -->
    <attribute>
        <id>FSI_MASTER_CHIP</id>
        <default>physical:sys-$sys/node-$mNode/proc-$mPos</default>
    </attribute>
    <attribute>
        <id>FSI_MASTER_PORT</id>
        <default>$link</default>
    </attribute>";

    if( $#altfsi <= 0 )
    {
        print "
    <!-- FSI-B is not connected -->
    <attribute>
        <id>ALTFSI_MASTER_CHIP</id>
        <default>physical:sys</default><!-- no B path -->
    </attribute>
    <attribute>
        <id>ALTFSI_MASTER_PORT</id>
        <default>0xFF</default><!-- no B path -->
    </attribute>\n";
    }
    else
    {
        $mNode = $altfsi[FSI_MASTERNODE_FIELD];
        $mPos = $altfsi[FSI_MASTERPOS_FIELD];
        $link = $altfsi[FSI_LINK_FIELD];
        print "
    <!-- FSI-B is connected via node$mNode:proc$mPos:CMFSI-$link -->
    <attribute>
        <id>ALTFSI_MASTER_CHIP</id>
        <default>physical:sys-$sys/node-$mNode/proc-$mPos</default>
    </attribute>
    <attribute>
        <id>ALTFSI_MASTER_PORT</id>
        <default>$link</default>
    </attribute>\n";
    }
    print "    <!-- End FSI connections -->\n";
    # End FSI #

    print "
    <attribute><id>VPD_REC_NUM</id><default>$ctaur</default></attribute>
    <attribute>
        <id>EI_BUS_TX_LANE_INVERT</id>
        <default>$lane_swap</default>
    </attribute>";

    foreach my $vrmType ( keys %$membufVrmUuidHash )
    {
        my $key = $membufVrmUuidHash->{$vrmType}{VRM_UUID};
        print
              "\n"
            . "    <attribute>\n"
            . "        <id>$vrmType" . "_ID</id>\n"
            . "        <default>$vrmHash{$key}{VRM_DOMAIN_ID}</default>\n"
            . "    </attribute>";
    }

    # call to do any fsp per-centaur attributes
    do_plugin('fsp_centaur', $scomFspApath, $scomFspAsize, $scanFspApath,
       $scanFspAsize, $scomFspBpath, $scomFspBsize, $scanFspBpath,
       $scanFspBsize, $relativeCentaurRid, $ordinalId, $membufVrmUuidHash);


    # $TODO RTC:110399
    if( $haveFSPs == 0 )
    {

    my @CentaurSensors = (
                    [74,101],[75,102],[76,103],[77,104] );

    my $temp_sensor  = $CentaurSensors[$ordinalId][1];
    my $state_sensor = $CentaurSensors[$ordinalId][0];


      print "<!-- IPMI Sensor numbers for Centaur status -->
    <attribute>
        <id>IPMI_SENSORS</id>
        <default>
            0x0100, $temp_sensor,  <!-- Temperature sensor -->
            0x0500, $state_sensor, <!-- State sensor -->
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF
        </default>
    </attribute>\n";

    }

    # Centaur is only used as an I2C Master in openpower systems
    if ( $haveFSPs == 0 )
    {
        # add EEPROM attributes
        addEepromsCentaur($sys, $node, $ctaur);

        # add I2C_BUS_SPEED_ARRAY attribute
        addI2cBusSpeedArray($sys, $node, $ctaur, "memb");
    }

    if($useGpioToEnableVddr)
    {
        my $vddrKey = "n" . $node . "p" . $ctaur;
        if(!exists $vddrEnableHash{$vddrKey})
        {
            die   "FATAL! Cannot find required GPIO info for memory buffer "
                . "$vddrKey VDDR enable.\n"
        }
        elsif(!exists $vddrEnableHash{$vddrEnableHash{$vddrKey}{i2cMasterKey}})
        {
            die   "FATAL! Must reference real membuf as I2C master for VDDR "
                . "enable.  Membuf $vddrEnableHash{$vddrKey}{i2cMasterKey} "
                . "requested.\n";
        }
        else
        {
            print
"\n    <attribute>
        <id>GPIO_INFO</id>
        <default>
            <field>
                <id>i2cMasterPath</id>
                <value>$vddrEnableHash{$vddrKey}{i2cMasterEntityPath}</value>
            </field>
            <field>
                <id>port</id>
                <value>$vddrEnableHash{$vddrKey}{i2cMasterPort}</value>
            </field>
            <field>
                <id>devAddr</id>
                <value>$vddrEnableHash{$vddrKey}{i2cAddressHexStr}</value>
            </field>
            <field>
                <id>engine</id>
                <value>$vddrEnableHash{$vddrKey}{i2cMasterEngine}</value>
            </field>
            <field>
                <id>vddrPin</id>
                <value>$vddrEnableHash{$vddrKey}{vddrPin}</value>
            </field>
        </default>
    </attribute>\n";
        }
    }

    print "\n</targetInstance>\n";

}

sub generate_mba
{
    my ($ctaur, $mcs, $mba, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $proc = $mcs;
    $proc =~ s/.*:p(.*):.*/$1/g;
    $mcs =~ s/.*:.*:mcs(.*)/$1/g;

    my $uidstr = sprintf("0x%02X0D%04X",
                          ${node},($proc * MAX_MCS_PER_PROC + $mcs)*
                                   MAX_MBA_PER_MEMBUF + $mba);
    my $mruData = get_mruid($ipath);

    my $fapi_name = sprintf("pu.mba:k0:n%d:s0:p%02d:c%d", $node, $proc, $mba);
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/mcs-$mcs/"
            . "membuf-$ctaur/mba-$mba";

    print "
<targetInstance>
    <id>sys${sys}node${node}membuf${ctaur}mba$mba</id>
    <type>unit-mba-centaur</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/membuf-$ctaur/"
            . "mba-$mba</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$mba</default>
    </attribute>";

    calcAndAddFapiPos("mba",$affinityPath,$mba,$fapiPosHr);

    # call to do any fsp per-mba attributes
    do_plugin('fsp_mba', $ctaur, $mba, $ordinalId );

    print "
</targetInstance>
";
}

sub generate_l4
{
    my ($ctaur, $mcs, $l4, $ordinalId, $ipath,$fapiPosHr) = @_;
    my $proc = $mcs;
    $proc =~ s/.*:p(.*):.*/$1/g;
    $mcs =~ s/.*:.*:mcs(.*)/$1/g;

    my $uidstr = sprintf("0x%02X0A%04X",${node},$proc*MAX_MCS_PER_PROC + $mcs);
    my $mruData = get_mruid($ipath);
    my $fapi_name = sprintf("pu.l4:k0:n%d:s0:p%02d:c0", $node, $proc, $l4);

    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/mcs-$mcs/"
            . "membuf-$ctaur/l4-$l4";

    print "
<targetInstance>
    <id>sys${sys}node${node}membuf${ctaur}l4${l4}</id>
    <type>unit-l4-centaur</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/membuf-$ctaur/"
            . "l4-$l4</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$ipath</default>
    </compileAttribute>
    <attribute>
        <id>CHIP_UNIT</id>
        <default>$l4</default>
    </attribute>";

    calcAndAddFapiPos("l4",$affinityPath,$l4,$fapiPosHr);

    # call to do any fsp per-centaur_l4 attributes
    do_plugin('fsp_centaur_l4', $ctaur, $ordinalId );

    print "</targetInstance>";
}

sub generate_is_dimm
{
    my ($fapiPosHr) = @_;

    # From the i2c busses, grab the information for the DIMMs, if any.
    my @dimmI2C;
    my $i2c_file = open_mrw_file($mrwdir, "${sysname}-i2c-busses.xml");
    my $i2cSettings = XMLin($i2c_file);

    foreach my $i (@{$i2cSettings->{'i2c-device'}})
    {
        if ( $i->{'part-id'} eq 'DIMM_SPD' )
        {
            # Adjust instance path to match Membus DIMM instance path
            my $tmp_ip = $i->{'instance-path'};
            $tmp_ip =~ s/\/DIMM_SPD-0$//;
            $tmp_ip =~ s/ddr._dimm_generic/dimm/;

            push @dimmI2C, {
                'port'=>$i->{'i2c-master'}->{'i2c-port'},
                'devAddr'=>$i->{'address'},
            # @todo RTC 119793 - engine 6 is invalid for hostboot
            #     'engine'=>$i->{'i2c-master'}->{'i2c-engine'},
                'engine'=>0,
                'ipath'=>$tmp_ip  };
        }
    }

    print "\n<!-- $SYSNAME JEDEC DIMMs -->\n";
    for my $i ( 0 .. $#SMembuses )
    {
        if ($SMembuses[$i][BUS_NODE_FIELD] != $node)
        {
            next;
        }

        my $ipath = $SMembuses[$i][DIMM_PATH_FIELD];
        my $proc = $SMembuses[$i][MCS_TARGET_FIELD];
        my $mcs = $proc;
        my $mca = $SMembuses[$i][MCA_TARGET_FIELD];
        $proc =~ s/.*:p(.*):.*/$1/;
        $mcs =~ s/.*mcs(.*)/$1/;
        $mca =~ s/.*mca(.*)/$1/;
        my $pos = $SMembuses[$i][DIMM_TARGET_FIELD];
        $pos =~ s/.*:p(.*)/$1/;
        my $dimm = $SMembuses[$i][DIMM_PATH_FIELD];
        $dimm =~ s/.*dimm-(.*)/$1/;

        my $dimmPos = $SMembuses[$i][DIMM_POS_FIELD];
        $dimmPos =~ s/.*dimm-(.*)/$1/;

        my $uidstr = sprintf("0x%02X03%04X",${node},$dimm+${node}*512);
        my $fapi_name = sprintf("dimm:k0:n%d:s0:p%02d",
                                $node, $dimm);

        $mcs = (($mca - ($mca%2))/2)%2;
        my $mcbist = ($mca - ($mca%4))/4;
        $mca = $mca % 2;

        my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc"
            . "/mcbist-$mcbist/mcs-$mcs/mca-$mca/dimm-$dimm";

        print "\n<!-- DIMM n${node}:p${pos} -->\n";
        print "
<targetInstance>
    <id>sys${sys}node${node}dimm$dimm</id>
    <type>lcard-dimm-jedec</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute><id>POSITION</id><default>$pos</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/dimm-$dimm</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$dimm</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>$ipath</default>
    </compileAttribute>
    <attribute>
        <id>VPD_REC_NUM</id>
        <default>$pos</default>
    </attribute>";

        calcAndAddFapiPos("isdimm",$affinityPath,$dimm,$fapiPosHr);

        # call to do any fsp per-dimm attributes
        my $dimmHex = sprintf("0xD0%02X",$dimmPos);
        do_plugin('fsp_dimm', $proc, $dimm, $dimm, $dimmHex );

        # $TODO RTC:110399
        if( $haveFSPs == 0 )
        {

     my $status_base = 30+$dimm;
     my $temp_base = 105+$dimm;

     print "\n<!-- IPMI Sensor numbers for DIMM status -->
    <attribute>
        <id>IPMI_SENSORS</id>
        <default>
            0x0100, $temp_base, <!-- Temperature sensor -->
            0x0500, $status_base, <!-- State sensor -->
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF

        </default>
    </attribute>\n";
        }

        print "\n</targetInstance>\n";

    }
}

sub generate_centaur_dimm
{
    my ($fapiPosHr) = @_;

    print "\n<!-- $SYSNAME Centaur DIMMs -->\n";

    for my $i ( 0 .. $#SMembuses )
    {
        if ($SMembuses[$i][BUS_NODE_FIELD] != $node)
        {
            next;
        }

        my $ipath = $SMembuses[$i][DIMM_PATH_FIELD];
        my $proc = $SMembuses[$i][MCS_TARGET_FIELD];
        my $mcs = $proc;
        $proc =~ s/.*:p(.*):.*/$1/;
        $mcs =~ s/.*mcs(.*)/$1/;
        my $ctaur = $SMembuses[$i][CENTAUR_TARGET_FIELD];
        my $mba = $ctaur;
        $ctaur =~ s/.*:p(.*):mba.*$/$1/;
        $mba =~ s/.*:mba(.*)$/$1/;
        my $pos = $SMembuses[$i][DIMM_TARGET_FIELD];
        $pos =~ s/.*:p(.*)/$1/;
        my $dimm = $SMembuses[$i][DIMM_PATH_FIELD];
        $dimm =~ s/.*dimm-(.*)/$1/;
        my $relativeDimmRid = $dimm;
        my $dimmPos = $SMembuses[$i][DIMM_POS_FIELD];
        $dimmPos =~ s/.*dimm-(.*)/$1/;
        my $relativePos = $dimmPos;
        print "\n<!-- C-DIMM n${node}:p${pos} -->\n";
        for my $id ( 0 .. 7 )
        {
            my $dimmid = $dimm;
            $dimmid <<= 3;
            $dimmid |= $id;
            $dimmid = sprintf ("%d", $dimmid);
            generate_dimm( $proc, $mcs, $ctaur, $pos, $dimmid, $id,
                           ($SMembuses[$i][BUS_ORDINAL_FIELD]*8)+$id,
                           $relativeDimmRid, $relativePos, $ipath,
                           $fapiPosHr);
        }
    }
}

# Since each Centaur has only one dimm, it is assumed to be attached to port 0
# of the MBA0 chiplet.
sub generate_dimm
{
    my ($proc, $mcs, $ctaur, $pos, $dimm, $id, $ordinalId, $relativeDimmRid,
        $relativePos,$fapiPosHr)
        = @_;

    my $x = $id;
    $x = int ($x / 4);
    my $y = $id;
    $y = int(($y - 4 * $x) / 2);
    my $z = $id;
    $z = $z % 2;
    my $zz = $id;
    $zz = $zz % 4;
    #$x = sprintf ("%d", $x);
    #$y = sprintf ("%d", $y);
    #$z = sprintf ("%d", $z);
    #$zz = sprintf ("%d", $zz);
    my $uidstr = sprintf("0x%02X03%04X",${node},$dimm);

    # Calculate the VPD Record number value
    my $vpdRec = 0;

    # Set offsets based on mba and dimm values
    if( 1 == $x )
    {
        $vpdRec = $vpdRec + 4;
    }
    if( 1 == $y )
    {
        $vpdRec = $vpdRec + 2;
    }
    if( 1 == $z )
    {
        $vpdRec = $vpdRec + 1;
    }

    my $position = ($proc * 64) + 8 * $mcs + $vpdRec;

    # Adjust offset based on MCS value
    $vpdRec = ($mcs * 8) + $vpdRec;
    # Adjust offset basedon processor value
    $vpdRec = ($proc * 64) + $vpdRec;

    my $dimmHex = sprintf("0xD0%02X",$relativePos
        + (CDIMM_RID_NODE_MULTIPLIER * ${node}));

    #MBA numbers should be 01 and 23
    my $mbanum=0;
    if (1 ==$x )
    {
        $mbanum = '23';
    }
    else
    {
        $mbanum = '01';
    }

    my $logicalDimmInstancePath = "instance:"
        . $logicalDimmList{$node}{$relativePos}{$mbanum}{$y}{$z}->{'logicalDimmIpath'};

    my $fapi_name = sprintf("dimm:k0:n%d:s0:p%02d", $node, $dimm);
    my $affinityPath = "affinity:sys-$sys/node-$node/proc-$proc/mcs-$mcs/"
            . "membuf-$pos/mba-$x/dimm-$zz";

    print "
<targetInstance>
    <id>sys${sys}node${node}dimm$dimm</id>
    <type>lcard-dimm-cdimm</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>
    <attribute><id>POSITION</id><default>$position</default></attribute>
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/dimm-$dimm</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>$affinityPath</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>$logicalDimmInstancePath</default>
    </compileAttribute>
    <attribute>
        <id>MBA_DIMM</id>
        <default>$z</default>
    </attribute>
    <attribute>
        <id>MBA_PORT</id>
        <default>$y</default>
    </attribute>
    <attribute><id>VPD_REC_NUM</id><default>$vpdRec</default></attribute>";

    calcAndAddFapiPos("cdimm",$affinityPath,$y*$z,$fapiPosHr);

    # call to do any fsp per-dimm attributes
    do_plugin('fsp_dimm', $proc, $ctaur, $dimm, $ordinalId, $dimmHex );

    # $TODO RTC:110399
    if( $haveFSPs == 0 )
    {
        print "\n<!-- IPMI Sensor numbers for DIMM status -->
    <attribute>
        <id>IPMI_SENSORS</id>
        <default>
            0x0100, 0x13,  <!-- Temperature sensor -->
            0x0500, 0x01,  <!-- State sensor -->
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF
        </default>
    </attribute>\n";

    }

print "\n</targetInstance>\n";
}

################################################################################
# Compares two Apss instances based on the node and position #
################################################################################
sub byApssNodePos($$)
{
    my $retVal = -1;

    my $lhsInstance_node = $_[0][SPI_NODE_FIELD];
    my $rhsInstance_node = $_[1][SPI_NODE_FIELD];
    if(int($lhsInstance_node) eq int($rhsInstance_node))
    {
         my $lhsInstance_pos = $_[0][SPI_APSS_POS_FIELD];
         my $rhsInstance_pos = $_[1][SPI_APSS_POS_FIELD];
         if(int($lhsInstance_pos) eq int($rhsInstance_pos))
         {
                die "ERROR: Duplicate apss positions: 2 apss with same
                    node and position, \
                    NODE: $lhsInstance_node POSITION: $lhsInstance_pos\n";
         }
         elsif(int($lhsInstance_pos) > int($rhsInstance_pos))
         {
             $retVal = 1;
         }
    }
    elsif(int($lhsInstance_node) > int($rhsInstance_node))
    {
        $retVal = 1;
    }
    return $retVal;
}

our @SPIs;
our $apssInit = 0;

# This routine is common to FSP and HB
# TODO RTC 116460 Only FSP uses the RID and ordinal numbering.
# Refactor FSP only elements to genHwsvMrwXml_fsp.pm
my $getBaseRidApss = 0;
my $ridApssBase = 0;

sub init_apss
{
    my $proc_spi_busses =
                open_mrw_file($::mrwdir, "${sysname}-proc-spi-busses.xml");
    if($proc_spi_busses ne "")
    {
        my $spiBus = ::parse_xml_file($proc_spi_busses,
            forcearray=>['processor-spi-bus']);

        # Capture all SPI connections into the @SPIs array
        my @rawSPIs;
        foreach my $i (@{$spiBus->{'processor-spi-bus'}})
        {
            if($getBaseRidApss == 0)  # TODO RTC 116460 FSP only
            {
                if ($i->{endpoint}->{'instance-path'} =~ /.*APSS-[0-9]+$/i)
                {
                    my $locCode = $i->{endpoint}->{'location-code'};
                    my @locCodeComp = split( '-', $locCode );
                    $ridApssBase = (@locCodeComp > 2) ? 0x4900 : 0x800;
                    $getBaseRidApss = 1;
                }
            }

            if ($i->{endpoint}->{'instance-path'} =~ /.*APSS-[0-9]+$/i)
            {
                my $pos = $i->{endpoint}->{'instance-path'};
                while (chop($pos) ne '/') {};
                $pos = chop($pos);
                push @rawSPIs, [
                $i->{processor}->{'instance-path'},
                $i->{processor}->{target}->{node},
                $i->{processor}->{target}->{position},
                $i->{endpoint}->{'instance-path'},
                $pos, 0, 0
                ];
            }
        }

        @SPIs = sort byApssNodePos @rawSPIs;

        my $ordinalApss = 0;
        my $apssPos = 0;
        my $currNode = -1;
        for my $i (0 .. $#SPIs)
        {
            $SPIs[$i][SPI_APSS_ORD_FIELD] = $ordinalApss;
            $ordinalApss++;
            if($currNode != $SPIs[$i][SPI_NODE_FIELD])
            {
                $apssPos = 0;
                $currNode = $SPIs[$i][SPI_NODE_FIELD];
            }
            $SPIs[$i][SPI_APSS_RID_FIELD]
            = sprintf("0x%08X", $ridApssBase + (2*$currNode) + $apssPos++);
        }
    }
}


my $occInit = 0;
my %occList = ();
sub occ_init
{
    my $targets_file = open_mrw_file($::mrwdir, "${sysname}-targets.xml");
    my $occTargets = ::parse_xml_file($targets_file);

    #get the OCC details
    foreach my $Target (@{$occTargets->{target}})
    {
        if($Target->{'ecmd-common-name'} eq "occ")
        {
            my $ipath = $Target->{'instance-path'};
            my $node = $Target->{node};
            my $position = $Target->{position};

            $occList{$node}{$position} = {
                'node'         => $node,
                'position'     => $position,
                'instancePath' => $ipath,
            }
        }
    }
}

sub generate_occ
{
    # input parameters
    my ($proc, $ordinalId) = @_;

    if ($apssInit == 0)
    {
        init_apss;
        $apssInit = 1;
    }

    my $uidstr = sprintf("0x%02X13%04X",${node},$proc);
    my $mastercapable = 0;

    for my $spi ( 0 .. $#SPIs )
    {
        my $ipath = $SPIs[$spi][SPI_ENDPOINT_PATH_FIELD];
        if(($SPIs[$spi][SPI_ENDPOINT_PATH_FIELD] =~ /.*APSS-[0-9]+$/i) &&
           ($node eq $SPIs[$spi][SPI_NODE_FIELD]) &&
           ($proc eq $SPIs[$spi][SPI_POS_FIELD]))
        {
            $mastercapable = 1;
            last;
        }
    }

    # Get the OCC info
    if ($occInit == 0)
    {
        occ_init;
        $occInit = 1;
    }
    my $mruData = get_mruid($occList{$node}{$proc}->{'instancePath'});

    my $fapi_name = "NA"; # OCC not FAPI target

    print "
<!-- $SYSNAME n${node}p${proc} OCC units -->

<targetInstance>
    <id>sys${sys}node${node}proc${proc}occ0</id>
    <type>occ</type>
    <attribute><id>HUID</id><default>${uidstr}</default></attribute>
    <attribute><id>FAPI_NAME</id><default>$fapi_name</default></attribute>";

    do_plugin('fsp_occ', $ordinalId );

    print "
    <attribute>
        <id>PHYS_PATH</id>
        <default>physical:sys-$sys/node-$node/proc-$proc/occ-0</default>
    </attribute>
    <attribute>
        <id>MRU_ID</id>
        <default>$mruData</default>
    </attribute>
    <attribute>
        <id>AFFINITY_PATH</id>
        <default>affinity:sys-$sys/node-$node/proc-$proc/occ-0</default>
    </attribute>
    <attribute>
        <id>ORDINAL_ID</id>
        <default>$ordinalId</default>
    </attribute>
    <compileAttribute>
        <id>INSTANCE_PATH</id>
        <default>instance:$occList{$node}{$proc}->{'instancePath'}</default>
    </compileAttribute>
    <attribute>
        <id>OCC_MASTER_CAPABLE</id>
        <default>$mastercapable</default>
    </attribute>\n";

    # $TODO RTC:110399
    # hardcode for now both palmetto and habenaro are
    # currently the same - this will change though
    #
    if( $haveFSPs == 0 )
    {
       print "\n<!-- IPMI sensor numbers -->
    <attribute>
        <id>IPMI_SENSORS</id>
        <default>
            0x0a00, 0x08, <!-- Occ_active -->
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF,
            0xFFFF, 0xFF
       </default>
    </attribute>\n";
    }
print "</targetInstance>\n";

}

sub addSysAttrs
{
    for my $i (0 .. $#systemAttr)
    {
        my $j =0;
        my $sysAttrArraySize=$#{$systemAttr[$i]};
        while ($j<$sysAttrArraySize)
        {
            # systemAttr is an array of pairs
            #  even index is the attribute id
            #  odd index has its default value
            my $l_default = $systemAttr[$i][$j+1];
            if (substr($l_default,0,2) eq "0b") #convert bin to hex
            {
                $l_default = sprintf('0x%X', oct($l_default));
            }
            print "    <attribute>\n";
            print "        <id>$systemAttr[$i][$j]</id>\n";
            print "        <default>$l_default</default>\n";
            print "    </attribute>\n";
            $j+=2; # next attribute id and default pair
        }
    }
}

sub addNodeAttrs
{
    for my $i (0 .. $#nodeAttr)
    {
        my $j =0;
        my $nodeAttrArraySize=$#{$nodeAttr[$i]};
        while ($j<$nodeAttrArraySize)
        {
            # nodeAttr is an array of pairs
            #  even index is the attribute id
            #  odd index has its default value
            my $l_default = $nodeAttr[$i][$j+1];
            if (substr($l_default,0,2) eq "0b") #convert bin to hex
            {
                $l_default = sprintf('0x%X', oct($l_default));
            }
            print "    <attribute>\n";
            print "        <id>$nodeAttr[$i][$j]</id>\n";
            print "        <default>$l_default</default>\n";
            print "    </attribute>\n";
            $j+=2; # next attribute id and default pair
        }
    }
}



sub addProcPmAttrs
{
    my ($position,$nodeId) = @_;

    for my $i (0 .. $#SortedPmChipAttr)
    {
        if (($SortedPmChipAttr[$i][CHIP_POS_INDEX] == $position) &&
            ($SortedPmChipAttr[$i][CHIP_NODE_INDEX] == $nodeId) )
        {
            #found the corresponding proc and node
            my $j =0;
            my $arraySize=$#{$SortedPmChipAttr[$i]} - CHIP_ATTR_START_INDEX;
            while ($j<$arraySize)
            {
                print "    <attribute>\n";
                print "        <id>$SortedPmChipAttr[$i][CHIP_ATTR_START_INDEX+$j]</id>\n";
                $j++;
                print "        <default>$SortedPmChipAttr[$i][CHIP_ATTR_START_INDEX+$j]</default>\n";
                print "    </attribute>\n";
                $j++;
            }
        }
    }
}

sub addProcPcieAttrs
{
    my ($position,$nodeId) = @_;

    foreach my $pcie ( keys %procPcieTargetList )
    {
        if( $procPcieTargetList{$pcie}{nodePosition} eq $nodeId &&
            $procPcieTargetList{$pcie}{procPosition} eq $position)
        {
            my $procPcieRef = (\%procPcieTargetList)->{$pcie};
            print "    <attribute>\n";
            print "        <id>PROC_PCIE_LANE_EQUALIZATION</id>\n";
            print "        <default>$procPcieRef->{phbValue}\n";
            print "        </default>\n";
            print "    </attribute>\n";
            last;
        }
    }
}

sub addEepromsProc
{
    my ($sys, $node, $proc) = @_;

    my $id_name eq "";
    my $devAddr = 0x00;
    my $tmp_ct eq "";

    # Loop through all i2c devices
    for my $i ( 0 .. $#I2Cdevices )
    {
        # FSP/Power systems:
        if ( $haveFSPs == 1 )
        {

            # Skip I2C devices that we don't care about
            if( ( !($I2Cdevices[$i]{i2cm_uid} eq "I2CM_PROC_PROM")
                  &&
                  !($I2Cdevices[$i]{i2cm_uid} eq "I2CM_PROC_PROM1")
                ) ||
                !($I2Cdevices[$i]{i2cm_node} == $node) )
            {
                next;
            }

            # Position field must match $proc with one exception:
            # Murano's PRIMARY_MODULE_VPD has a position field one spot
            # behind $proc
            if ( ($CHIPNAME eq "murano") &&
                 ("$I2Cdevices[$i]{i2c_content_type}" eq
                  "PRIMARY_MODULE_VPD") )
            {
                if ( ($I2Cdevices[$i]{i2cm_pos}+1) != $proc )
                {
                    next;
                }
            }
            elsif ( $I2Cdevices[$i]{i2cm_pos} != $proc)
            {
                next;
            }
        }

        # Openpower
        else
        {
            if ( ($I2Cdevices[$i]{i2cm_pos} != $proc) ||
                 ($I2Cdevices[$i]{i2cm_node} != $node) )
            {
                next;
            }
        }

        # Convert Content Type
        $tmp_ct = $I2Cdevices[$i]{i2c_content_type};
        if ( $tmp_ct eq "PRIMARY_SBE_VPD")
        {
            $id_name = "EEPROM_SBE_PRIMARY_INFO";
        }
        elsif ($tmp_ct eq "REDUNDANT_SBE_VPD")
        {
            $id_name = "EEPROM_SBE_BACKUP_INFO";
        }
        elsif ( ($tmp_ct eq "PRIMARY_MODULE_VPD") ||
                ($tmp_ct eq "PRIMARY_FRU_AND_MODULE_VPD") )
        {
            $id_name = "EEPROM_VPD_PRIMARY_INFO";
        }
        elsif ($tmp_ct eq "REDUNDANT_FRU_AND_MODULE_VPD")
        {
            $id_name = "EEPROM_VPD_BACKUP_INFO";
        }

        # Skipping these on openpower systems
        # @todo RTC 119830 - some of these might eventually be supported
        elsif ( ( ($tmp_ct eq "PLANAR_VPD") ||
                  ($tmp_ct eq "PRIMARY_FRU_VPD") ||
                  ($tmp_ct eq "CENTAUR_VPD") ||
                  ($tmp_ct eq "ALL_CENTAUR_VPD") )
                &&
                ( $haveFSPs == 0 )
              )
        {
            next;
        }

        else
        {
            die "ERROR: addEepromsProc: unrecognized Content Type $tmp_ct\n";
        }

        print "    <attribute>\n";
        print "        <id>$id_name</id>\n";
        print "        <default>\n";
        print "            <field><id>i2cMasterPath</id><value>physical:",
                          "sys-$sys/node-$node/proc-$proc</value></field>\n";
        print "            <field><id>port</id><value>",
                          "$I2Cdevices[$i]{i2c_port}</value></field>\n";
        print "            <field><id>devAddr</id><value>0x",
                          "$I2Cdevices[$i]{i2c_devAddr}",
                          "</value></field>\n";
        print "            <field><id>engine</id><value>",
                          "$I2Cdevices[$i]{i2c_engine}",
                          "</value></field>\n";
        print "            <field><id>byteAddrOffset</id><value>",
                          "$I2Cdevices[$i]{i2c_byte_addr_offset}",
                          "</value></field>\n";
        print "            <field><id>maxMemorySizeKB</id><value>",
                          "$I2Cdevices[$i]{i2c_max_mem_size}",
                          "</value></field>\n";
        print "            <field><id>writePageSize</id><value>",
                          "$I2Cdevices[$i]{i2c_write_page_size}",
                          "</value></field>\n";
        print "            <field><id>writeCycleTime</id><value>",
                          "$I2Cdevices[$i]{i2c_write_cycle_time}",
                          "</value></field>\n";
        print "        </default>\n";
        print "    </attribute>\n";

    }
}

sub addHotPlug
{
    my ($sys,$node,$proc) = @_;

    #hot plug array is 8x8 array
    my @hot_plug_array = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                          0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                          0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
    my $row_count = 8;
    my $column_count = 8;

    my $hot_count = 0;
    my $tmp_speed = 0x0;

    for my $i ( 0 .. $#I2CHotPlug )
    {
        my $i2cmProcNode;
        my $i2cmProcPos;
        for my $x (0 .. $#I2CHotPlug_Host )
        {
            if( $I2CHotPlug_Host[$x]{i2c_slave_path} eq
                    $I2CHotPlug[$i]{i2c_instPath})
            {
                $i2cmProcNode = $I2CHotPlug_Host[$i]{i2c_proc_node};
                $i2cmProcPos = $I2CHotPlug_Host[$i]{i2c_proc_pos};
                last;
            }
        }


        if(!($I2CHotPlug[$i]{'i2cm_node'} == $node) ||
                !($I2CHotPlug[$i]{'i2cm_pos'} == $proc))
        {
            next;
        }
        if($hot_count < $row_count)
        {
            #enum for MAX5961 and PCA9551 defined in attribute_types.xml
            #as SUPPORTED_HOT_PLUG.
            my $part_id_enum = 0x00;
            if($I2CHotPlug[$i]{i2c_part_id} eq "MAX5961")
            {
                $part_id_enum = 0x01;
            }
            else
            {
                $part_id_enum = 0x02;
            }

            #update array
            $tmp_speed = $I2CHotPlug[$i]{i2c_speed};

            #update array 8 at a time (for up to 8 times)
            $hot_plug_array[($hot_count*$row_count)]     =
                $I2CHotPlug[$i]{i2c_engine};
            $hot_plug_array[($hot_count*$row_count) + 1] =
                $I2CHotPlug[$i]{i2c_port};
            $hot_plug_array[($hot_count*$row_count) + 2] =
                ($tmp_speed & 0xFF00) >> 8;
            $hot_plug_array[($hot_count*$row_count) + 3] =
                ($tmp_speed & 0x00FF);
            $hot_plug_array[($hot_count*$row_count) + 4] =
                sprintf("0x%x",(hex $I2CHotPlug[$i]{i2c_slaveAddr}) * 2);
            $hot_plug_array[($hot_count*$row_count) + 5] = $part_id_enum;
            $hot_plug_array[($hot_count*$row_count) + 6] = $i2cmProcNode;
            $hot_plug_array[($hot_count*$row_count) + 7] = $i2cmProcPos;

            $hot_count = $hot_count + 1;
        }
        else
        {
            #if we have found more than 8 controllers (not supported)
            die "ERROR: addHotPlug: too many hotPlug's: $hot_count\n";
        }
    }

    #and then print attribute here
    if($hot_count > 0)
    {
        print "    <attribute>\n";
        print "        <id>HOT_PLUG_POWER_CONTROLLER_INFO</id>\n";
        print "        <default>\n";
        for my $j (0 .. ($row_count - 1))
        {
            print "            ";
            for my $k (0 .. ($column_count - 1))
            {
                if($j == ($row_count -1) && $k == ($column_count - 1))
                {
                    #last entry does not have a comma
                    print "$hot_plug_array[($j*$row_count) + $k]";
                }else
                {
                    print "$hot_plug_array[($j*$row_count) + $k],";
                }
            }
            print "\n";
        }
        print "        </default>\n";
        print "    </attribute>\n";
    }
}

sub addEepromsCentaur
{
    my ($sys, $node, $ctaur) = @_;

    my $id_name eq "";
    my $devAddr = 0x00;
    my $tmp_ct eq "";

    # Loop through all i2c devices
    for my $i ( 0 .. $#I2Cdevices )
    {
        # Convert Content Type
        $tmp_ct = "$I2Cdevices[$i]{i2c_content_type}";
        if ( $tmp_ct eq "ALL_CENTAUR_VPD" )
        {
            $id_name = "EEPROM_VPD_PRIMARY_INFO";
        }
        elsif ( $tmp_ct eq "CENTAUR_VPD" )
        {
            if ( ($I2Cdevices[$i]{i2cm_pos} != $ctaur) ||
                 ($I2Cdevices[$i]{i2cm_node} != $node) )
            {
                next;
            }
            $id_name = "EEPROM_VPD_PRIMARY_INFO";
        }
        else
        {
            next;
        }

        # Since I2C Master might be different than centaur, need to do
        # some checks
        if ( $I2Cdevices[$i]{i2cm_name} == "pu" )
        {
            $I2Cdevices[$i]{i2cm_name} = "proc";
        }
        elsif ( $I2Cdevices[$i]{i2cm_name} == "memb" )
        {
            $I2Cdevices[$i]{i2cm_name} = "membuf";
        }

        print "    <attribute>\n";
        print "        <id>$id_name</id>\n";
        print "        <default>\n";
        print "            <field><id>i2cMasterPath</id><value>physical:",
                          "sys-$sys/node-$node/",
                          "$I2Cdevices[$i]{i2cm_name}",
                          "-$I2Cdevices[$i]{i2cm_pos}</value></field>\n";
        print "            <field><id>port</id><value>",
                          "$I2Cdevices[$i]{i2c_port}</value></field>\n";
        print "            <field><id>devAddr</id><value>0x",
                          "$I2Cdevices[$i]{i2c_devAddr}",
                          "</value></field>\n";
        print "            <field><id>engine</id><value>",
                          "$I2Cdevices[$i]{i2c_engine}",
                          "</value></field>\n";
        print "            <field><id>byteAddrOffset</id><value>",
                          "$I2Cdevices[$i]{i2c_byte_addr_offset}",
                          "</value></field>\n";
        print "            <field><id>maxMemorySizeKB</id><value>",
                          "$I2Cdevices[$i]{i2c_max_mem_size}",
                          "</value></field>\n";
        print "            <field><id>writePageSize</id><value>",
                          "$I2Cdevices[$i]{i2c_write_page_size}",
                          "</value></field>\n";
        print "            <field><id>writeCycleTime</id><value>",
                          "$I2Cdevices[$i]{i2c_write_cycle_time}",
                          "</value></field>\n";
        print "        </default>\n";
        print "    </attribute>\n";

    }
}


sub addI2cBusSpeedArray
{
    my ($sys, $node, $pos, $i2cm_name) = @_;

    my $tmp_speed  = 0x0;
    my $tmp_engine = 0x0;
    my $tmp_port   = 0x0;
    my $tmp_offset = 0x0;
    my $tmp_ct eq "";

    # bus_speed_arry[engine][port] is 4x3 array
    my @speed_array = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

    # Loop through all i2c devices
    for my $i ( 0 .. $#I2Cdevices )
    {

        # -----------------------
        # Processor is I2C Master
        if ( $i2cm_name eq "pu" )
        {
            # FSP/Power systems:
            if ( $haveFSPs == 1 )
            {
                # Skip I2C devices that we don't care about
                if( ( !($I2Cdevices[$i]{i2cm_uid}
                      eq "I2CM_PROC_PROM")
                      &&
                      !($I2Cdevices[$i]{i2cm_uid}
                        eq "I2CM_PROC_PROM1")
                      &&
                      !( ($I2Cdevices[$i]{i2cm_uid}
                         eq "I2CM_HOTPLUG") &&
                         ( ($I2Cdevices[$i]{i2c_part_id}
                           eq "MAX5961") ||
                           ($I2Cdevices[$i]{i2c_part_id}
                           eq "PCA9551") )
                       )
                    ) ||
                    ($I2Cdevices[$i]{i2cm_node} != $node) ||
                    ($I2Cdevices[$i]{i2cm_name} != $i2cm_name) )
                {
                    next;
                }

                # Processor position field must match $pos with one exception:
                # Murano's PRIMARY_MODULE_VPD has a position field one spot
                # behind $proc
                if ( ($CHIPNAME eq "murano") &&
                     ("$I2Cdevices[$i]{i2c_content_type}" eq
                     "PRIMARY_MODULE_VPD") )
                {
                    if ( ($I2Cdevices[$i]{i2cm_pos}+1) != $pos )
                    {
                        next;
                    }
                }
                elsif ( $I2Cdevices[$i]{i2cm_pos} != $pos)
                {
                    next;
                }

            }
            # No FSP
            else
            {
                if ( ($I2Cdevices[$i]{i2cm_pos} != $pos) ||
                     ($I2Cdevices[$i]{i2cm_node} != $node) ||
                     !($I2Cdevices[$i]{i2cm_name} eq $i2cm_name) )
                {
                    next;
                }
            }
        }

        # -----------------------
        # Memb is I2C Master
        elsif ( $i2cm_name eq "memb" )
        {
            if ( ($I2Cdevices[$i]{i2cm_pos} != $pos) ||
                 ($I2Cdevices[$i]{i2cm_node} != $node) ||
                 !($I2Cdevices[$i]{i2cm_name} eq $i2cm_name) )
            {
                next;
            }

            # @todo RTC 119793 - engine 6 is invalid for hostboot
            if ( $I2Cdevices[$i]{i2c_engine} == 6 )
            {
                $I2Cdevices[$i]{i2c_engine} = 0;
            }
        }
        else
        {
            die "ERROR: addI2cBusSpeedArray: unsupported input $i2cm_name\n";
        }


        # update array
        $tmp_speed  = $I2Cdevices[$i]{i2c_speed};
        $tmp_engine = $I2Cdevices[$i]{i2c_engine};
        $tmp_port   = $I2Cdevices[$i]{i2c_port};
        $tmp_offset = ($tmp_engine * 3) + $tmp_port;

        # @todo RTC 153696 - Default everything off except TPM until MRW is correct and simics model is complete
        if ($tmp_engine == 2 && $tmp_port == 0) {
            $tmp_speed  = 400;
        } else {
            $tmp_speed = 0;
        }

        # use the slower speed if there is a previous entry
        if ( ($speed_array[$tmp_offset] == 0) ||
             ($tmp_speed < $speed_array[$tmp_offset] ) )
        {
            $speed_array[$tmp_offset] = $tmp_speed;

        }

    }
    print "     <attribute>\n";
    print "        <id>I2C_BUS_SPEED_ARRAY</id>\n";
    print "        <default>\n";
    print "            $speed_array[0],\n";
    print "            $speed_array[1],\n";
    print "            $speed_array[2],\n";
    print "            $speed_array[3],\n";
    print "            $speed_array[4],\n";
    print "            $speed_array[5],\n";
    print "            $speed_array[6],\n";
    print "            $speed_array[7],\n";
    print "            $speed_array[8],\n";
    print "            $speed_array[9],\n";
    print "            $speed_array[10],\n";
    print "            $speed_array[11],\n";
    print "        </default>\n";
    print "    </attribute>\n";

}



sub get_mruid
{
    my($ipath) = @_;
    my $mruData = 0;
    foreach my $i (@{$mruAttr->{'mru-id'}})
    {
        if ($ipath eq $i->{'instance-path'})
        {
            $mruData = $i->{'mrid-value'};
            last;
        }
    }
    return $mruData;
}

sub open_mrw_file
{
    my ($paths, $filename) = @_;

    #Need to get list of paths to search
    my @paths_to_search = split /:/, $paths;
    my $file_found = "";

    #Check for file at each directory in list
    foreach my $path (@paths_to_search)
    {
        if ( open (FH, "<$path/$filename") )
        {
            $file_found = "$path/$filename";
            close(FH);
            last; #break out of loop
        }
    }

    if ($file_found eq "")
    {
        #If the file was not found, build up error message and exit
        my $err_msg = "Could not find $filename in following paths:\n";
        foreach my $path (@paths_to_search)
        {
            $err_msg = $err_msg."  $path\n";
        }
        die $err_msg;
    }
    else
    {
        #Return the full path to the file found
        return $file_found;
    }
}

my %g_xml_cache = ();
sub parse_xml_file
{
    my $parms = Dumper(\@_);
    if (not defined $g_xml_cache{$parms})
    {
        $g_xml_cache{$parms} = XMLin(@_);
    }
    return $g_xml_cache{$parms};
}

sub display_help
{
    use File::Basename;
    my $scriptname = basename($0);
    print STDERR "
Usage:

    $scriptname --help
    $scriptname --system=sysname --systemnodes=2 --mrwdir=pathname
                     [--build=hb] [--outfile=XmlFilename]
        --system=systemname
              Specify which system MRW XML to be generated
        --systemnodes=systemnodesinbrazos
              Specify number of nodes for brazos system, by default it is 4
        --mrwdir=pathname
              Specify the complete dir pathname of the MRW. Colon-delimited
              list accepted to specify multiple directories to search.
        --build=hb
              Specify HostBoot build (hb)
        --outfile=XmlFilename
              Specify the filename for the output XML. If omitted, the output
              is written to STDOUT which can be saved by redirection.
\n";
}
