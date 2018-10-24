#!/bin/bash

# If this script is not sourced, return before executing anything
if (( ${#BASH_SOURCE[*]} == 1 )) ; then
  echo "This script is only meant to be sourced."
  exit 0
fi

#
# Filename related functions
#

match_output_suffix ()
{
  local   allowed_input_suffix=(com in  inp  COM IN  INP  orcainp)
  local matching_output_suffix=(log out log  LOG OUT LOG  orcaout)
  local choices=${#allowed_input_suffix[*]} count
  local test_suffix="$1" return_suffix
  debug "test_suffix=$test_suffix; choices=$choices"
  
  # Assign matching outputfile
  for (( count=0 ; count < choices ; count++ )) ; do
    debug "count=$count"
    if [[ "$test_suffix" == "${matching_output_suffix[$count]}" ]]; then
      return_suffix="$extract_suffix"
      debug "Recognised output suffix: $return_suffix."
      break
    elif [[ "$test_suffix" == "${allowed_input_suffix[$count]}" ]]; then
      return_suffix="${matching_output_suffix[$count]}"
      debug "Matched output suffix: $return_suffix."
      break
    else
      debug "No match for $test_suffix; $count; ${allowed_input_suffix[$count]}; ${matching_output_suffix[$count]}"
    fi
  done

  [[ -z $return_suffix ]] && return 1

  echo "$return_suffix"
}

match_output_file ()
{
  # Check what was supplied and if it is read/writeable
  # Returns a filename
  local extract_suffix return_suffix basename
  local testfile="$1" return_file
  debug "Validating: $testfile"

  basename="${testfile%.*}"
  extract_suffix="${testfile##*.}"
  debug "basename=$basename; extract_suffix=$extract_suffix"

  if return_suffix=$(match_output_suffix "$extract_suffix") ; then
    return_file="$basename.$return_suffix"
  else
    return 1
  fi

  [[ -r $return_file ]] || return 1

  echo "$return_file"    
}

#
# Parsing functions
#

read_orca_input_file ()
{
  # Currently a dummy routine to allow further manipulation if necessary
  local testfile="$1"
  mapfile -t assembled_input < "$testfile"
  assembled_input+=("# Assembled with $softwarename")
}


# 
# Routines for parsing some input
#

read_xyz_structure_file ()
{
    # Imported routine from tools-for-g16
    debug "Reading input file."
    local parsefile="$1" line storeline
    debug "Working on: $parsefile"
    local pattern pattern_num pattern_element pattern_print
    local         pattern_coord skip_reading_coordinates="no" convert_coord2xyz="no"
    local -a      inputfile_coord2xyz
    local         pattern_charge pattern_mult pattern_uhf
    # These are remnants from tools for gaussian, but it might still work
    # A global variable called 'inputfile_body' should start with the geometry
    # Other content is stored in global variables 'title_section', 'molecule_charge', 'molecule_mult'
    local molecule_charge_local molecule_mult_local molecule_uhf_local
    local body_index=0
    pattern_coord="^[[:space:]]*\\\$coord[[:space:]]*$"
    pattern_num="[+-]?[0-9]+\\.[0-9]*"
    pattern_element="[A-Za-z]+[A-Za-z]*"
    pattern="^[[:space:]]*($pattern_element)[[:space:]]*($pattern_num)[[:space:]]*($pattern_num)[[:space:]]*($pattern_num)[[:space:]]*(.*)$"
    pattern_print="%-3s %15.8f %15.8f %15.8f"
    pattern_charge="[Cc][Hh][Rr][Gg][[:space:]]+([+-]?[0-9]+)"
    pattern_mult="[Mm][Uu][Ll][Tt][[:space:]]+([0-9]+)"
    pattern_uhf="[Uu][Hh][Ff][[:space:]]+([0-9]+)"
    while read -r line || [[ -n "$line" ]] ; do
      debug "Read line: $line"
      
      if [[ "$skip_reading_coordinates" =~ [Nn][Oo] ]] ; then
        if [[ "$line" =~ $pattern_coord ]] ; then
          message "This appears to be a file in Turbomole format."
          message "File will be converted using openbabel."
          skip_reading_coordinates="yes"
          convert_coord2xyz="yes"
        else
          debug "Not a coord file."
        fi

        if [[ "$line" =~ $pattern ]] ; then
          # shellcheck disable=SC2059
          storeline=$(printf "$pattern_print" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}")
          debug "Ignored end of line: '${BASH_REMATCH[5]}'."
          inputfile_body[$body_index]="$storeline" 
          debug "Read and stored: '${inputfile_body[$body_index]}'"
          (( body_index++ ))
          debug "Increase index to $body_index."
          continue
        else
          debug "Line doesn't match pattern of xyz."
        fi
      fi

      if [[ "$line" =~ $pattern_charge ]] ; then
        molecule_charge_local="${BASH_REMATCH[1]}"
        message "Found molecule's charge: $molecule_charge_local."
        [[ -z $molecule_charge ]] || warning "Overwriting previously set charge ($molecule_charge)."
        molecule_charge="$molecule_charge_local"
        debug "Use molecule's charge: $molecule_charge."
      elif [[ "$line" =~ $pattern_mult ]] ; then
        molecule_mult_local="${BASH_REMATCH[1]}"
        message "Found molecule's multiplicity: $molecule_mult_local."
        [[ -z $molecule_mult ]] || warning "Overwriting previously set multiplicity ($molecule_mult)."
        molecule_mult="$molecule_mult_local"
        message "Use molecule's multiplicity: $molecule_mult."
      elif [[ "$line" =~ $pattern_uhf ]] ; then
        molecule_uhf_local="${BASH_REMATCH[1]}"
        message "Found number of unpaired electrons for the molecule: $molecule_uhf_local."
        [[ -z $molecule_mult ]] || warning "Overwriting previously set multiplicity ($molecule_mult)."
        molecule_mult="$(( molecule_uhf_local + 1 ))"
        message "Use molecule's multiplicity: $molecule_mult."
      fi

    done < "$parsefile"

    if [[ "$convert_coord2xyz" =~ [Yy][Ee][Ss] ]] ; then
      local tmplog 
      tmplog=$(mktemp tmp.XXXXXXXX) 
      debug "$(ls -lh "$tmplog")"
      mapfile -t inputfile_coord2xyz < <("$obabel_cmd" -itmol "$parsefile" -oxyz 2> "$tmplog")
      debug "$(cat "$tmplog")"
      debug "$(rm -v "$tmplog")"

      # First line is the number of atoms.
      # Second line is a comment.
      unset 'inputfile_coord2xyz[0]' 'inputfile_coord2xyz[1]'
      debug "$(printf '%s\n' "${inputfile_coord2xyz[@]}")"
      if (( ${#inputfile_body[@]} > 0 )) ; then
        warning "Input file body has previously been written to."
        warning "The following content will be overwritten:"
        warning "$(printf '%s\n' "${inputfile_body[@]}")"
      fi
      inputfile_body=( "${inputfile_coord2xyz[@]}" )
    else
      debug "Inputfile doesn't need conversion from Turbomol to Xmol format."
    fi

    if (( ${#inputfile_body[@]} == 0 )) ; then
      warning "No molecular structure in '$parsefile'." 
      return 1
    fi
    debug "Finished reading input file."
}

#
# modified input files
#

extract_jobname_inoutnames ()
{
    # Assigns the global variables inputfile outputfile jobname
    # Checks is locations are read/writeable
    local testfile="$1"
    local input_suffix output_suffix
    debug "Validating: $testfile"

    # Check if supplied inputfile is readable, extract suffix and title
    if inputfile=$(is_readable_file_or_exit "$testfile") ; then
      jobname="${inputfile%.*}"
      input_suffix="${inputfile##*.}"
      debug "Jobname: $jobname; Input suffix: $input_suffix."
      # Assign matching outputfile
      if output_suffix=$(match_output_suffix "$input_suffix") ; then
        debug "Output suffix: $output_suffix."
      else
        # Abort when input-suffix cannot be identified
        fatal "Unrecognised suffix of inputfile '$testfile'."
      fi
    else
      # Assume that only jobname was given
      debug "Assuming that '$testfile' is the jobname."
      jobname="$testfile"
      unset testfile
      debug "Found possible inputfiles: ${test_possible_inputfiles[*]}"
      (( ${#test_possible_inputfiles[*]} == 0 )) &&  fatal "No input files belonging to '$jobname' found in this directory."
      for testfile in ./$jobname.* ; do
        debug "Validating: $testfile"
        input_suffix="${testfile##*.}"
        debug "Extracted input suffix '$input_suffix', and will test if allowed."
        if output_suffix=$(match_output_suffix "$input_suffix") ; then
          debug "Will use input suffix '$input_suffix'."
          debug "Will use output suffix '$output_suffix'."
          break
        fi
      done
      debug "Jobname: $jobname; Input suffix: $input_suffix; Output suffix: $output_suffix."
    fi
    outputfile="$jobname.$output_suffix"
}

validate_write_in_out_jobname ()
{
    # Assigns the global variables inputfile outputfile jobname
    # Checks is locations are read/writeable
    local testfile="$1"
    extract_jobname_inoutnames "$testfile"

    # Check special ending of input file which is hard coded in the main script
    debug "inputfile=$inputfile" 
    if [[ "${inputfile##*.}" == "inp" ]] ; then
      warning "The chosen inputfile will be overwritten."
      backup_if_exists "${inputfile}.bak"
      backup_file "$inputfile" "${inputfile}.bak"
      inputfile="${inputfile}.bak"
    fi

    # Check if an outputfile exists and prevent overwriting
    backup_if_exists "$outputfile"

    # Display short logging message
    message "Will process Inputfile '$inputfile'."
    message "Output will be written to '$outputfile'."
}

#
# Function relating to writing the modified output
#

write_orca_input_file ()
{
  printf '%s\n' "${assembled_input[@]}"
}
