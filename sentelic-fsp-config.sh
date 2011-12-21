#!/bin/bash
#
# Sentelic FingerSensingPad (FSP) configuration script
#
# This provides an alternative to the fspc program:
# http://sourceforge.net/projects/fsp-lnxdrv/
#
# Use the -h option to show usage instructions, e.g.,
#    ./sentelic-fsp-config.sh -h
#
# Examples below assume this script is at /usr/local/bin/sentelic-fsp-config.sh
#
# Add a call to this script from /etc/rc.local to configure at boot.
# E.g., just add this line to /etc/rc.local:
#    /usr/local/bin/sentelic-fsp-config.sh
#
# The fspc program did not allow settings to be retained upon resume/thaw.
# You might create a script at /etc/pm/sleep.d/00_sentelic-fsp-config.sh
# E.g., something like this will do:
#	case $1 in
#		resume|thaw) /usr/local/bin/sentelic-fsp-config.sh ;;
#		*)           exit 0 ;;
#	esac
#
# TODO: Consider using a properties file, rather than default variables here.
#	This would allow current config to be written to disk by suspend hook and 
#		read at resume.
#	Note that the -l option to list current config echos a format matching that
#		of the fspc program mentioned above.
#

set -e


# Set defaults here:
FSP_CLICK="c"	# Tap to click (c=off, C=on)
FSP_HSCROLL="0"	# Horizontal scroll tap (0=off, 1=on)
FSP_VSCROLL="0"	# Vertical scroll tap (0=off, 1=on)
FSP_ACCEL="3"	# Accelaration value (1 to 10)


# Determine FSP device directory
for i in 0 1 2 3 4 5 6 7 8 9
do
	test_dir="/sys/devices/platform/i8042/serio$i"

	if [[ -d "$test_dir" && -f "$test_dir/flags" && -f "$test_dir/hscroll" && -f "$test_dir/vscroll" ]]; then
		FSP_DEV_DIR=$test_dir
		break
	fi
done
if [ -z "$FSP_DEV_DIR" ]; then
	echo "ERROR: Unable to find i8042/serio[n] directory for Sentelic FSP." >&2
	exit 1
fi


# Check for Sentelic device before proceeding
#TODO: somehow check whether connected to X server before calling xinput;
#      or, ignore xinput error when this is run from resume hook ("Unable to connect to X server")
#if [ -z "$(xinput --list | grep Sentelic)" ]; then
#	echo "ERROR: You do not appear to have a Sentelic FingerSensingPad." >&2
#	exit 1
#fi


# Acceleration index/value array
FSP_ACCEL_ARRAY=(
	[1]="1 4 1"
	[2]="1 2 1"
	[3]="1 1 1"
	[4]="3 2 3"
	[5]="2 1 3"
	[6]="5 2 3"
	[7]="3 1 4"
	[8]="7 2 4"
	[9]="4 1 4"
	[10]="9 2 4"
)


print_usage()
{
cat <<EOF

`basename $0` is a command line script for configuring the Sentelic FingerSensingPad (FSP).

Usage: $0 [-u] [-l] [-C|-c] [-V|-v] [-H|-h] [-a <val>]
	-u        :  Usage instructions
	-l        :  List current settings
	-C or -c  :  Tap to click, on or off
	-H or -h  :  Horizontal scroll, on or off
	-V or -v  :  Vertical scroll, on or off
	-a <num>  :  Set acceleration to <val> (integer, 1 to 10)

If no option is passed all defaults will be set.
Default values are set at the top of this script ($0)

EOF
}


exit_usage()
{
	print_usage
	echo "ERROR: $1" >&2
	exit 1
}


get_fsp_accel_index()
{
	fsp_accel_value=$1
	for i in {1..10}
	do
		if [ "${FSP_ACCEL_ARRAY[$i]}" = "$fsp_accel_value" ]; then
			echo -n "$i"
			break
		fi
	done
}


get_fsp_accel_value()
{
	fsp_accel_index=$1
	echo -n ${FSP_ACCEL_ARRAY[$fsp_accel_index]}
}


list_current_settings()
{
	if [ -f "${FSP_DEV_DIR}/flags" ]; then
		flags_cat=$(cat "${FSP_DEV_DIR}/flags")
		if [ "$flags_cat" = "c" ]; then
			click_val=0
		else
			click_val=1
		fi
		echo "EnableOnPadClick=$click_val"
	fi

	if [ -f "${FSP_DEV_DIR}/hscroll" ]; then
		echo "EnableHScr=$(cat "${FSP_DEV_DIR}/hscroll")"
	fi

	if [ -f "${FSP_DEV_DIR}/vscroll" ]; then
		echo "EnableVScr=$(cat "${FSP_DEV_DIR}/vscroll")"
	fi

	if [ -f "${FSP_DEV_DIR}/accel" ]; then
		echo "Acceleration=$(get_fsp_accel_index "$(cat "${FSP_DEV_DIR}/accel")")"
	fi
}


set_fsp_click()
{
	if [ -f "${FSP_DEV_DIR}/flags" ]; then
		echo -n "$1" > "${FSP_DEV_DIR}/flags"
	else
		echo "Warning: file not found: ${FSP_DEV_DIR}/flags" >&2
	fi
}


set_fsp_hscroll()
{
	if [ -f "${FSP_DEV_DIR}/hscroll" ]; then
		echo -n "$1" > "${FSP_DEV_DIR}/hscroll"
	else
		echo "Warning: file not found: ${FSP_DEV_DIR}/hscroll" >&2
	fi
}


set_fsp_vscroll()
{
	if [ -f "${FSP_DEV_DIR}/vscroll" ]; then
		echo -n "$1" > "${FSP_DEV_DIR}/vscroll"
	else
		echo "Warning: file not found: ${FSP_DEV_DIR}/vscroll" >&2
	fi
}


set_fsp_accel()
{
	case $1 in
		1|2|3|4|5|6|7|8|9|10)
			FSP_ACCEL_VAL=$(get_fsp_accel_value $1) ;;
		*)
			exit_usage "Invalid acceleration (-a) argument ($1) - must be between 1 and 10." ;;
	esac

	if [ -f "${FSP_DEV_DIR}/accel" ]; then
		echo -n "$FSP_ACCEL_VAL" > "${FSP_DEV_DIR}/accel"
	else
		echo "Warning: file not found: ${FSP_DEV_DIR}/accel"
	fi
}


set_fsp_defaults()
{
	set_fsp_click "$FSP_CLICK"
	set_fsp_hscroll "$FSP_HSCROLL"
	set_fsp_vscroll "$FSP_VSCROLL"
	set_fsp_accel "$FSP_ACCEL"
}

# Set defaults when no options are passed:
if [ -z "$*" ]; then
	set_fsp_defaults
	exit 0
fi


# Handle command options:
while getopts ":ulcChHvVa:" opt
do
	case "$opt" in
		u)		print_usage; exit 0 ;;
		l)		list_current_settings; exit 0 ;;
		c|C)	set_fsp_click "$opt" ;;
		H)		set_fsp_hscroll 1 ;;
		h)		set_fsp_hscroll 0 ;;
		V)		set_fsp_vscroll 1 ;;
		v)		set_fsp_vscroll 0 ;;
		a)		set_fsp_accel "$OPTARG" ;;
		\?)		exit_usage "Unknown option (-$OPTARG)" ;;
		\:)		exit_usage "Argument missing for -$OPTARG" ;;
	esac
done

exit 0
