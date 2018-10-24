#!/bin/bash

# The following script gives default values to any of the scripts within the package.
# They can (or should) be set in the rc file, too.

# If this script is not sourced, return before executing anything
if (( ${#BASH_SOURCE[*]} == 1 )) ; then
  echo "This script is only meant to be sourced."
  exit 0
fi

#
# Generic details about these tools 
#
softwarename="tools-for-orca.bash"
version="0.0.1.dev"
versiondate="2018-10-XX"

#
# Standard commands for external software:
#
# ORCA related options
#
# General path to the ORCA directory (this should work on every system)
orca_installpath="/path/is/not/set"
# Define where scratch files shall be written to
orca_scratch="$TEMP"
# Define the overhead you'd like to give ORCA in MB 
orca_overhead=2000
#? The 2000 might be a very conservative guess, but additionally
#? the memory will be scaled by (CPU + 1)/CPU (at least in the submit script).
#?
# If a modular software management is available, use it?
load_modules="true"
# By default it takes the available path (at runtime) as this might include local directories
load_modules_from_path="$MODULEPATH"
# For example: On the RWTH cluster ORCA can be loaded via a module system,
# an example file is included,
# the names (in correct order) of the modules:
orca_modules[0]="orca"
# (Include OpenMPI if an orca module does not take care of it.)

# Options related to using OpenMPI (if not set via modules)
openmpi_installpath="/path/is/not/set"

# Options related to use open babel
obabel_cmd="obabel"

#
# Default files, suffixes, options for ORCA 
#
orca_input_suffix="inp"
orca_output_suffix="log"

#
# Default options for printing (Not in use)
#
values_separator=" " # (space separated values)
output_verbosity=0

#
# Default values for queueing system submission
#
# Select a queueing system (only bsub-gen) # TODO: bsub-rwth, pbs-gen, etc
request_qsys="bsub-gen"
# Walltime for remote execution, header line for the queueing system
requested_walltime="24:00:00"
# Specify a default value for the memory (MB)
requested_memory=512
# This corresponds to nthreads/NProcShared (etc)
requested_numCPU=4
# TODO: Limits disk space, not usre if avail for ORCA
requested_maxdisk=10000
# Account to project (currently only for bsub-rwth)
bsub_project=default
# E-Mail address to send notifications to
bsub_email=default
# Calculations will be submitted to run (hold/keep)
requested_submit_status="run"

