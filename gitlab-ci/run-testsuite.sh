#!/bin/bash
#
# This script uses piglit to run a whole test suite (Vulkan/OpenGL) against the
# currently installed driver.
#
# Run:
#
# $ ./run-testsuite.sh {--opengl | --vulkan} --driver <driver> --commit <mesa-commit-id>

export LC_ALL=C

PATH=${HOME}/.local/bin$(echo :$PATH | sed -e s@:${HOME}/.local/bin@@g)

DISPLAY="${DISPLAY:-:0.0}"
export -p DISPLAY

# Unless specified, don't sync. It speeds up the tests execution ...
vblank_mode="${vblank_mode:-0}"
export -p vblank_mode


#------------------------------------------------------------------------------
#			Function: backup_redirection
#------------------------------------------------------------------------------
#
# backups current stout and sterr file handlers
function backup_redirection() {
        exec 7>&1            # Backup stout.
        exec 8>&2            # Backup sterr.
        exec 9>&1            # New handler for stout when we actually want it.
}


#------------------------------------------------------------------------------
#			Function: restore_redirection
#------------------------------------------------------------------------------
#
# restores previously backed up stout and sterr file handlers
function restore_redirection() {
        exec 1>&7 7>&-       # Restore stout.
        exec 2>&8 8>&-       # Restore sterr.
        exec 9>&-            # Closing open handler.
}


#------------------------------------------------------------------------------
#			Function: check_verbosity
#------------------------------------------------------------------------------
#
# perform sanity check on the passed verbosity level:
#   $1 - the verbosity to use
# returns:
#   0 is success, an error code otherwise
function check_verbosity() {
    case "x$1" in
	"xfull" | "xnormal" | "xquiet" )
	    ;;
	*)
	    printf "%s\n" "Error: Only verbosity levels among [full|normal|quiet] are allowed." >&2
	    usage
	    return 1
	    ;;
    esac

    return 0
}


#------------------------------------------------------------------------------
#			Function: apply_verbosity
#------------------------------------------------------------------------------
#
# applies the passed verbosity level to the output:
#   $1 - the verbosity to use
function apply_verbosity() {

    backup_redirection

    if [ "x$1" != "xfull" ]; then
	exec 1>/dev/null
    fi

    if [ "x$1" == "xquiet" ]; then
	exec 2>/dev/null
	exec 9>/dev/null
    fi
}


#------------------------------------------------------------------------------
#			Function: check_driver
#------------------------------------------------------------------------------
#
# perform sanity check on the passed GL driver to run:
#   $1 - the intended GL driver to run
# returns:
#   0 is success, an error code otherwise
function check_driver() {
    case "x$1" in
	"xi965" | "xnouveau" | "xnvidia" | "xradeon" | "xamd"  | "xllvmpipe" | "xswr" | "xsoftpipe" | "xanv" | "xradv" )
	    ;;
	*)
	    printf "%s\n" "Error: A driver among [i965|nouveau|nvidia|radeon|amd|llvmpipe|swr|softpipe|anv|radv] has to be provided." >&2
	    usage
	    return 1
	    ;;
    esac

    return 0
}

#------------------------------------------------------------------------------
#			Function: check_option_args
#------------------------------------------------------------------------------
#
# perform sanity checks on cmdline args which require arguments
# arguments:
#   $1 - the option being examined
#   $2 - the argument to the option
# returns:
#   if it returns, everything is good
#   otherwise it exit's
function check_option_args() {
    option=$1
    arg=$2

    # check for an argument
    if [ x"$arg" = x ]; then
	printf "%s\n" "Error: the '$option' option is missing its required argument." >&2
	usage
	exit 2
    fi

    # does the argument look like an option?
    echo $arg | $FPR_GREP "^-" > /dev/null
    if [ $? -eq 0 ]; then
	printf "%s\n" "Error: the argument '$arg' of option '$option' looks like an option itself." >&2
	usage
	exit 3
    fi
}

#------------------------------------------------------------------------------
#			Function: generate_pattern
#------------------------------------------------------------------------------
#
# generates exclusion/inclusion patterns
#   $1 - the testsuite for which the pattern is generated
# outputs:
#   the generated exclusion/inclusion pattern
# returns:
#   0 is success, an error code otherwise
function generate_pattern {
    # Ugly, but we will like to break long lines ...
    FPR_NEW_LINE="
"

    if [ ! -f "$FPR_PATTERNS_FILE" ]; then
	printf "%s\n" "Error: the patterns file: \"$FPR_PATTERNS_FILE\" doesn't exist." >&2
	usage
	return 12
    fi
    for i in $($FPR_GREP $FPR_GL_DRIVER "$FPR_PATTERNS_FILE" | $FPR_GREP $1 | $FPR_GREP "include" | cut -d : -f 2); do
	FPR_PATTERNS_PARAMETERS="-t $i "$FPR_NEW_LINE"$FPR_PATTERNS_PARAMETERS"
    done
    for i in $($FPR_GREP $FPR_GL_DRIVER "$FPR_PATTERNS_FILE" | $FPR_GREP $1 | $FPR_GREP "exclude" | cut -d : -f 2); do
	FPR_PATTERNS_PARAMETERS="-x $i "$FPR_NEW_LINE"$FPR_PATTERNS_PARAMETERS"
    done
    echo "$FPR_PATTERNS_PARAMETERS"

    return 0
}

#------------------------------------------------------------------------------
#			Function: inner_run_tests
#------------------------------------------------------------------------------
#
# performs the actual execution of the piglit tests
# returns:
#   0 is success, an error code otherwise
function inner_run_tests {
    printf "%s\n" ""
    test "x$FPR_INNER_RUN_MESSAGE" = "x" || printf "$FPR_INNER_RUN_MESSAGE " >&9
    printf "%s\n" "$FPR_PIGLIT_PATH/piglit run $FPR_INNER_RUN_SET $FPR_INNER_RUN_PARAMETERS -n $FPR_INNER_RUN_NAME $FPR_INNER_RUN_RESULTS" >&9
    $FPR_DRY_RUN && return 0
    "$FPR_PIGLIT_PATH"/piglit run $FPR_INNER_RUN_SET $FPR_INNER_RUN_PARAMETERS -n "$FPR_INNER_RUN_NAME" "$FPR_INNER_RUN_RESULTS"
    if [ $? -ne 0 ]; then
	return 9
    fi
    if $FPR_CREATE_REPORT; then
        if [ "x$FPR_INNER_RUN_REFERENCE" == "x" ]; then
	    printf "%s\n" \
	           "" \
	           "${FPR_PIGLIT_PATH}/piglit summary html -o -e pass $FPR_INNER_RUN_SUMMARY $FPR_INNER_RUN_RESULTS" \
	           ""
	    "${FPR_PIGLIT_PATH}"/piglit summary html -o -e pass "$FPR_INNER_RUN_SUMMARY" "$FPR_INNER_RUN_RESULTS"
        else
	    printf "%s\n" \
	           "" \
	           "${FPR_PIGLIT_PATH}/piglit summary html -o -e pass $FPR_INNER_RUN_SUMMARY $FPR_INNER_RUN_REFERENCE $FPR_INNER_RUN_RESULTS" \
	           ""
	    "${FPR_PIGLIT_PATH}"/piglit summary html -o -e pass "$FPR_INNER_RUN_SUMMARY" "$FPR_INNER_RUN_REFERENCE" "$FPR_INNER_RUN_RESULTS"
        fi
        if [ $? -ne 0 ]; then
	    return 11
	fi

    fi

    return 0
}

#------------------------------------------------------------------------------
#			Function: run_tests
#------------------------------------------------------------------------------
#
# performs the execution of the piglit tests
# returns:
#   0 is success, an error code otherwise
function run_tests {
    if [ "${FPR_MESA_COMMIT:-x}" == "x" ]; then
	printf "%s\n" "Error: a commit id has to be provided." >&2
	usage
	return 4
    fi

    check_driver $FPR_GL_DRIVER
    if [ $? -ne 0 ]; then
	return 5
    fi

    case "x${FPR_GL_DRIVER}" in
	"xllvmpipe" | "xswr" | "xsoftpipe" )
	    LIBGL_ALWAYS_SOFTWARE=1
	    GALLIUM_DRIVER=${FPR_GL_DRIVER}
	    export -p LIBGL_ALWAYS_SOFTWARE GALLIUM_DRIVER
	    ;;
	*)
	    ;;
    esac

    cd "${FPR_VK_GL_CTS_PATH}"
    VK_GL_CTS_COMMIT=$(git show --pretty=format:"%h" --no-patch)
    cd - > /dev/null
    if [ "x${VK_GL_CTS_COMMIT}" = "x" ]; then
	printf "%s\n" "Error: Couldn\'t get vk-gl-cts\'s commit ID" >&2
	return 6
    fi

    TIMESTAMP=`date +%Y%m%d%H%M%S`

    VK_CTS_NAME="VK-CTS-${FPR_GL_DRIVER}-${TIMESTAMP}-${VK_GL_CTS_COMMIT}-mesa-${FPR_MESA_COMMIT}"
    GL_CTS_NAME="GL-CTS-${FPR_GL_DRIVER}-${TIMESTAMP}-${VK_GL_CTS_COMMIT}-mesa-${FPR_MESA_COMMIT}"

    VK_CTS_RESULTS="${FPR_RESULTS_PATH}/results/${VK_CTS_NAME}"
    GL_CTS_RESULTS="${FPR_RESULTS_PATH}/results/${GL_CTS_NAME}"

    VK_CTS_SUMMARY="${FPR_RESULTS_PATH}/html/${VK_CTS_NAME}"
    GL_CTS_SUMMARY="${FPR_RESULTS_PATH}/html/${GL_CTS_NAME}"

    if $FPR_RUN_VK_CTS; then
	export -p PIGLIT_DEQP_VK_BIN="$FPR_VK_GL_CTS_PATH"/external/vulkancts/modules/vulkan/deqp-vk
	export -p PIGLIT_DEQP_VK_EXTRA_ARGS="--deqp-log-images=disable --deqp-log-shader-sources=disable"
	FPR_INNER_RUN_SET=deqp_vk
	FPR_INNER_RUN_PARAMETERS="$(generate_pattern vulkan)"
	if [ $? -ne 0 ]; then
	    return $?
	fi
	$FPR_RUN_VK_CTS_ALL_CONCURRENT && FPR_INNER_RUN_PARAMETERS="-c --deqp-mode=group $FPR_INNER_RUN_PARAMETERS"
	FPR_INNER_RUN_NAME=$VK_CTS_NAME
	FPR_INNER_RUN_RESULTS=$VK_CTS_RESULTS
	FPR_INNER_RUN_REFERENCE=$FPR_VK_CTS_REFERENCE
	FPR_INNER_RUN_SUMMARY=$VK_CTS_SUMMARY
	FPR_INNER_RUN_MESSAGE=" \
			      PIGLIT_DEQP_VK_BIN=\"$PIGLIT_DEQP_VK_BIN\" \
			      PIGLIT_DEQP_VK_EXTRA_ARGS=\"$PIGLIT_DEQP_VK_EXTRA_ARGS\""
	inner_run_tests
	if [ $? -ne 0 ]; then
	    return $?
	fi
        unset PIGLIT_DEQP_VK_BIN
        unset PIGLIT_DEQP_VK_EXTRA_ARGS
    fi

    if $FPR_RUN_GL_CTS; then
	FPR_RUN_GL_CTS_DIR="${FPR_VK_GL_CTS_PATH}"/external/openglcts/modules
	FPR_RUN_GL_CTS_BIN=glcts
	export -p MESA_GLES_VERSION_OVERRIDE=3.2
	export -p MESA_GL_VERSION_OVERRIDE=4.6
	export -p MESA_GLSL_VERSION_OVERRIDE=460
	cd "$FPR_RUN_GL_CTS_DIR"
	./"$FPR_RUN_GL_CTS_BIN" --deqp-runmode=txt-caselist --deqp-case=KHR-GL30 | $FPR_GREP KHR-GL30 > /dev/null
	if [ $? -eq 0 ] && [ -f "$FPR_PIGLIT_PATH/tests/khr_gl45.py" ]; then
	    FPR_INNER_RUN_SET=khr_gl45
	    export -p PIGLIT_KHR_GL_BIN="$FPR_RUN_GL_CTS_DIR"/"$FPR_RUN_GL_CTS_BIN"
	    FPR_INNER_RUN_MESSAGE=" \
			      PIGLIT_KHR_GL_BIN=\"$PIGLIT_KHR_GL_BIN\" \
			      PIGLIT_KHR_GL_EXTRA_ARGS=\"$PIGLIT_KHR_GL_EXTRA_ARGS\""
	else
	    FPR_INNER_RUN_SET=cts_gl45
	    export -p PIGLIT_CTS_GL_BIN="$FPR_RUN_GL_CTS_DIR"/"$FPR_RUN_GL_CTS_BIN"
	    FPR_INNER_RUN_MESSAGE=" \
			      PIGLIT_CTS_GL_BIN=\"$PIGLIT_CTS_GL_BIN\" \
			      PIGLIT_CTS_GL_EXTRA_ARGS=\"$PIGLIT_CTS_GL_EXTRA_ARGS\""
	fi
	cd -
	FPR_INNER_RUN_PARAMETERS="$(generate_pattern opengl)"
	if [ $? -ne 0 ]; then
	    return $?
	fi
	FPR_INNER_RUN_NAME=$GL_CTS_NAME
	FPR_INNER_RUN_RESULTS=$GL_CTS_RESULTS
	FPR_INNER_RUN_REFERENCE=$FPR_GL_CTS_REFERENCE
	FPR_INNER_RUN_SUMMARY=$GL_CTS_SUMMARY
	FPR_INNER_RUN_MESSAGE=" \
			      $FPR_INNER_RUN_MESSAGE \
			      MESA_GLES_VERSION_OVERRIDE=\"$MESA_GLES_VERSION_OVERRIDE\" \
			      MESA_GL_VERSION_OVERRIDE=\"$MESA_GL_VERSION_OVERRIDE\" \
			      MESA_GLSL_VERSION_OVERRIDE=\"$MESA_GLSL_VERSION_OVERRIDE\""
	inner_run_tests
	if [ $? -ne 0 ]; then
	    return $?
	fi
        unset FPR_RUN_GL_CTS_DIR
        unset FPR_RUN_GL_CTS_BIN
        unset PIGLIT_KHR_GL_BIN
        unset PIGLIT_CTS_GL_BIN
        unset MESA_GLES_VERSION_OVERRIDE
        unset MESA_GLSL_VERSION_OVERRIDE
        unset MESA_GLSL_VERSION_OVERRIDE
    fi
}

#------------------------------------------------------------------------------
#			Function: usage
#------------------------------------------------------------------------------
# Displays the script usage and exits successfully
#
function usage() {
    basename="`expr "//$0" : '.*/\([^/]*\)'`"
    cat <<HELP

Usage: $basename [options] --driver [i965|nouveau|nvidia|radeon|amd|llvmpipe|swr|softpipe|anv|radv] --commit <mesa-commit-id>

Options:
  --dry-run                        Does everything except running the tests
  --verbosity [full|normal|quite]  Which verbosity level to use
                                   [full|normal|quite]. Default, normal.
  --help                           Display this help and exit successfully
  --driver [i965|nouveau|nvidia|radeon|amd|llvmpipe|swr|softpipe|anv|radv]
                                   Which driver with which to run the tests
                                   [i965|nouveau|nvidia|radeon|amd|llvmpipe|swr
                                    |softpipe|anv|radv]
  --commit <commit>                Mesa commit to output
  --base-path <path>               <path> from which to create the rest of the
                                   relative paths
  --piglit-path <path>             <path> to the built piglit binaries
  --vk-gl-cts-path <path>          <path> to the built vk-gl-cts binaries
  --piglit-path <path>             <path> to the piglit results
  --run-vulkan                     Run Vulkan CTS
  --run-opengl                     Run OpenGL CTS
  --create-report                  If HTML result report should be create
  --vulkan-test-reference <path>   <path> to vk-cts test results reference
  --opengl-test-reference <path>   <path> to gl-cts test results reference
  --patterns-file <path>           <path> to the patterns file
  --vulkan-all-concurrent          Run all the vk-cts tests concurrently

HELP
}

#------------------------------------------------------------------------------
#			Script main line
#------------------------------------------------------------------------------
#

# Choose which grep program to use (on Solaris, must be gnu grep)
if [ "x$FPR_GREP" = "x" ] ; then
    if [ -x /usr/gnu/bin/grep ] ; then
	FPR_GREP=/usr/gnu/bin/grep
    else
	FPR_GREP=grep
    fi
fi

# Process command line args
while [ $# != 0 ]
do
    case $1 in
    # Does everything except running the tests
    --dry-run)
	FPR_DRY_RUN=true
	;;
    # Which verbosity level to use [full|normal|quite]. Default, normal.
    --verbosity)
	check_option_args $1 $2
	shift
	FPR_VERBOSITY=$1
	;;
    # Display this help and exit successfully
    --help)
	usage
	exit 0
	;;
    # Which driver with which to run the tests [i965|nouveau|nvidia|radeon|amd|llvmpipe|swr|softpipe|anv|radv]
    --driver)
	check_option_args $1 $2
	shift
	FPR_GL_DRIVER=$1
	;;
    # Mesa commit to output
    --commit)
	check_option_args $1 $2
	shift
	FPR_MESA_COMMIT=$1
	;;
    # PATH from which to create the rest of the relative paths
    --base-path)
	check_option_args $1 $2
	shift
	FPR_BASE_PATH=$1
	;;
    # PATH to the built piglit binaries
    --piglit-path)
	check_option_args $1 $2
	shift
	FPR_PIGLIT_PATH=$1
	;;
    # PATH to the output results
    --results-path)
	check_option_args $1 $2
	shift
	FPR_RESULTS_PATH=$1
	;;
    # PATH to the built vk-gl-cts binaries
    --vk-gl-cts-path)
	check_option_args $1 $2
	shift
	FPR_VK_GL_CTS_PATH=$1
	;;
    # Run vk-cts
    --run-vulkan)
	FPR_RUN_VK_CTS=true
	;;
    # Run gl-cts
    --run-opengl)
	FPR_RUN_GL_CTS=true
	;;
    # If HTML results report should be created.
    --create-report)
	FPR_CREATE_REPORT=true
	;;
    # vk-cts test reference results
    --vulkan-test-reference)
        check_option_args $1 $2
        shift
	FPR_VK_CTS_REFERENCE=$1
	;;
    # gl-cts test reference results
    --opengl-test-reference)
        check_option_args $1 $2
        shift
	FPR_GL_CTS_REFERENCE=$1
	;;
    # PATH to the patterns file
    --patterns-file)
	check_option_args $1 $2
	shift
	FPR_PATTERNS_FILE=$1
	;;
    # Run all the vk-cts tests concurrently
    --vk-cts-all-concurrent)
	FPR_RUN_VK_CTS_ALL_CONCURRENT=true
	;;
    --*)
	printf "%s\n" "Error: unknown option: $1" >&2
	usage
	exit 1
	;;
    -*)
	printf "%s\n" "Error: unknown option: $1" >&2
	usage
	exit 1
	;;
    *)
	printf "%s\n" "Error: unknown extra parameter: $1" >&2
	usage
	exit 1
	;;
    esac

    shift
done

# Paths ...
# ---------

FPR_BASE_PATH="${FPR_BASE_PATH:-/home/local}"
FPR_PIGLIT_PATH="${FPR_PIGLIT_PATH:-${FPR_BASE_PATH}/igalia-piglit}"
FPR_RESULTS_PATH="${FPR_RESULTS_PATH:-${FPR_BASE_PATH}/results}"
FPR_VK_GL_CTS_PATH="${FPR_VK_GL_CTS_PATH:-${FPR_BASE_PATH}/vk-gl-cts/build}"

# What tests to run?
# ------------------

FPR_RUN_VK_CTS="${FPR_RUN_VK_CTS:-false}"
FPR_RUN_GL_CTS="${FPR_RUN_GL_CTS:-false}"

# Run the tests concurrently?
# ---------------------------

FPR_RUN_VK_CTS_ALL_CONCURRENT="${FPR_RUN_VK_CTS_ALL_CONCURRENT:-false}"

# Verbose?
# --------

FPR_VERBOSITY="${FPR_VERBOSITY:-normal}"

check_verbosity "$FPR_VERBOSITY"
if [ $? -ne 0 ]; then
    return 13
fi

apply_verbosity "$FPR_VERBOSITY"

# dry run?
# --------

FPR_DRY_RUN="${FPR_DRY_RUN:-false}"

# Create an HTML report?
# ----------------------

FPR_CREATE_REPORT="${FPR_CREATE_REPORT:-false}"

# Patterns ...
# ------------

FPR_PATTERNS_FILE="${FPR_PATTERNS_FILE:-${FPR_BASE_PATH}/f-p-r-patterns.txt}"

run_tests

exit $?
