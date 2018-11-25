#!/bin/bash
declare -r ScriptLastMod="2018-11-25"
declare -r ScriptVersion="0.1"
# check if root
if ((EUID != 0)); then
  echo "ERROR${DELIMITER}Must run as root user"
  exit 1
fi

PathToScript="${0}"
PathToPackage="${1}"
TargetLocation="${2}" # eg /Applications
TargetVolume="${3}" # eg /Volumes/Macintosh HD
TargetVolume="${TargetVolume:+${TargetVolume/%\//}}"
if [[ -z "${TargetVolume}" || "${TargetVolume: -1}" != "/" ]]; then
  TargetVolume="${TargetVolume}/"
fi

# yes/no success/error true/false found/missing
declare -ri YES=0
declare -ri SUCCESS=${YES}
declare -ri TRUE=${YES}
declare -ri FOUND=${YES}
declare -ri NO=1
declare -ri ERROR=${NO}
declare -ri FALSE=${NO}
declare -ri MISSING=${NO}
# delimiter
declare -r DELIMITER=$'|'
# debug script?
declare -r DEBUG=${TRUE}
if ((DEBUG == TRUE)); then
  # PS4
	PS4='+(${BASH_SOURCE:-}:${LINENO:-}): ${FUNCNAME[0]:+${FUNCNAME[0]:-}(): }'
	set -xv
else
  :
  #set +xv
fi
# return code
declare -i RC=0
# return value
RV=""
# exit code
declare -i EC=0
# enable aliases
shopt -s expand_aliases
# aliases
alias PlistBuddy="${TargetVolume}usr/libexec/PlistBuddy"
alias awk="${TargetVolume}usr/bin/awk"
alias chmod="${TargetVolume}bin/chmod"
alias chown="${TargetVolume}usr/sbin/chown"
alias date="${TargetVolume}bin/date"
alias defaults="${TargetVolume}usr/bin/defaults"
alias dscl="${TargetVolume}usr/bin/dscl"
alias egrep="${TargetVolume}usr/bin/egrep"
alias find="${TargetVolume}usr/bin/find"
alias id="${TargetVolume}usr/bin/id"
alias ioreg="${TargetVolume}usr/sbin/ioreg"
alias kickstart="${TargetVolume}System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"
alias launchctl="${TargetVolume}bin/launchctl"
alias mkdir="${TargetVolume}bin/mkdir"
alias networksetup="${TargetVolume}usr/sbin/networksetup"
alias ntpdate="${TargetVolume}usr/sbin/ntpdate"
alias pkill="${TargetVolume}usr/bin/pkill"
alias plutil="${TargetVolume}usr/bin/plutil"
alias pmset="${TargetVolume}usr/bin/pmset"
alias printf="${TargetVolume}usr/bin/printf"
alias scutil="${TargetVolume}usr/sbin/scutil"
alias security="${TargetVolume}usr/bin/security"
alias sed="${TargetVolume}usr/bin/sed"
alias sntp="${TargetVolume}usr/bin/sntp"
alias sort="${TargetVolume}usr/bin/sort"
alias spctl="${TargetVolume}usr/sbin/spctl"
alias sw_vers="${TargetVolume}usr/bin/sw_vers"
alias system_profiler="${TargetVolume}usr/sbin/system_profiler"
alias systemsetup="${TargetVolume}usr/sbin/systemsetup"
alias touch="${TargetVolume}usr/bin/touch"
alias touristd="${TargetVolume}System/Library/PrivateFrameworks/Tourist.framework/Versions/A/Resources/touristd"
alias tr="${TargetVolume}usr/bin/tr"
alias which="${TargetVolume}usr/bin/which"
alias xmllint="${TargetVolume}usr/bin/xmllint"

# script path name
ScriptPN="${0%/*}"
if [ "${ScriptPN}" = "." ]; then
	ScriptPN="${PWD}"
elif [ "${ScriptPN:0:1}" != "/" ]; then
	ScriptPN="$(which ${0})"
fi
# script filename
declare -r ScriptFN="${0##*/}"
# script name
ScriptName="${ScriptFN%.*}"
# script extension
ScriptExtension=${ScriptFN##*.}
if [ "${ScriptName}" = "" ]; then
	ScriptName=".${ScriptExtension}"
	ScriptExtension=""
fi
declare -r ScriptPN ScriptName ScriptExtension
# global preferences file
declare -r GlobalPreferencesFN=".GlobalPreferences.plist"
# preferences relative path name
declare -r PrefsRPN="Library/Preferences"
# application support relative path name
declare -r AppSuRPN="Library/Application Support"
# users dir
declare -r UsersFQPN="${TargetVolume}Users"
# temp directory
declare -r TempFQPN="${TargetVolume}private/var/tmp"
# user template
declare -r UserTemplateFQPN="${TargetVolume}System/Library/User Template"
# sysctl.conf
declare -r SysctlConfFQFN="${TargetVolume}etc/sysctl.conf"
# date in seconds
declare -ir StartDateInSeconds=$(date +'%s')
# computer name
declare -r ComputerName="$(scutil --get ComputerName)"
# model identifier
declare -r ModelIdentifier="$(ioreg \
                               -c IOPlatformExpertDevice \
                               -d 2 2>&1 |\
                             awk -F'"' '
                               /product-name/ {
                                 print $(NF-1)
                               }
                             ')"
# Hardware UUID
declare -r HwUUID="$(ioreg \
                     -c IOPlatformExpertDevice \
                     -d 2 2>&1 |\
                   awk -F'"' '
                     /IOPlatformUUID/ {
                       print $(NF-1)
                     }
                   ')"
# serial number
declare -r SerialNumber="$(ioreg \
                           -c IOPlatformExpertDevice \
                           -d 2 2>&1 |\
                         awk -F'"' '
                           /IOPlatformUUID/ {
                             print $(NF-1)
                           }
                         ')"
# os x product version
declare -r OsProductVersion="$(defaults read /System/Library/CoreServices/SystemVersion.plist ProductVersion 2>&1)"
declare -i OsSystemVersionStampAsNumber=0
for Number in $(echo "${OsProductVersion}.0.0.0.0" |\
             awk -F'.' 'BEGIN { OFS="\n" } { print $1,$2,$3,$4 }'); do
  OsSystemVersionStampAsNumber=$((OsSystemVersionStampAsNumber * 256 + Number))
done
declare -r OsSystemVersionStampAsNumber
# os x build version
declare OsBuildVersion="$(sw_vers -buildVersion)"
if [[ -z "${OsBuildVersion}" ]]; then
  OsBuildVersion="$(defaults read /System/Library/CoreServices/SystemVersion.plist ProductBuildVersion 2>&1)"
fi
declare -r OsBuildVersion
# Split build version (eg 14A379a) into parts (14,A,379,a)
declare -i BuildMajorNumber=$(echo ${OsBuildVersion} | sed 's/[a-zA-Z][0-9]*//;s/[a-zA-Z]*$//')
BuildMinorCharacter=$(echo ${OsBuildVersion} | sed 's/^[0-9]*//;s/[0-9]*[a-zA-Z]*$//')
BuildRevisionNumber=$(echo ${OsBuildVersion} | sed 's/^[0-9]*[a-zA-Z]//;s/[a-zA-Z]*$//')
BuildStageCharacter=$(echo ${OsBuildVersion} | sed 's/^[0-9]*[a-zA-Z][0-9]*//')

BuildMinorNumber=$(($(printf "%d" "'${BuildMinorCharacter}")-65))
if [[ -n "${BuildStageCharacter}" ]]; then
  BuildStageNumber=$(($(printf "%d" "'${BuildStageCharacter}")-96))
else
  BuildStageNumber=0
fi
declare -r OsBuildVersionStampAsNumber=$((((BuildMajorNumber * 32 + BuildMinorNumber) * 2048 + BuildRevisionNumber) * 32 + BuildStageNumber))

# os x version array major minor patch
IFS='.' read -ra OsVersion <<<"${OsProductVersion}"
# os x version as integer
declare -ir IntegerOsVersion=10#$(printf '%02d%02d%02d' "${OsVersion[0]:-0}" "${OsVersion[1]:-0}" "${OsVersion[2]:-0}")
# dscl prefix
DsclPrefix="dscl"
# local admin users
declare -a LocalAdminUsers
LocalAdminUsers+=( "ardadmin" )
LocalAdminUsers+=( "emadmin" )
declare -r LocalAdminUsers
# local users
declare -a LocalUsers
LocalUsers=( $(printf "%s\n%s\n" "$( (set +o noglob && \
                                   cd "${TargetVolume}Users" && \
                                   { find * \
                                       -type d \
                                       -maxdepth 0 \
                                       \( -iname guest* -o -iname shared -o -iname *.localized \) -prune -o \
                                       -print || \
                                     : ; } && \
                                   set -o noglob) )" "${LocalAdminUsers[@]}" |\
                                  sort -u) \
                                )
declare -r LocalUsers
# function for getting values from Directory Service via dscl
readDS() {
	local _Account _DSKey _DSValue
	local _FS=":"

	while :; do
		case ${1} in
			-a|--account)
				if [[ -n "${2}" && "${2:0:2}" != "--" && "${2:0:1}" != "-" ]]; then
					_Account="${2}"
					shift
				else
					printf 'ERROR: "%s" requires a non-empty option argument.\n' "${1}" >&2
					return ${ERROR}
				fi
				;;
			--account=?*)
				_Account=${1#*=} # Delete everything up to "=" and assign the remainder.
				;;
			--account=) # Handle the case of an empty --account=
				printf 'ERROR: "%s" requires a non-empty option argument.\n' "${1}" >&2
				return ${ERROR}
				;;
			-k|--key)
				if [[ -n "${2}" && "${2:0:2}" != "--" && "${2:0:1}" != "-" ]]; then
					_DSKey="${2}"
					shift
				else
					printf 'ERROR: "%s" requires a non-empty option argument.\n' "${1}" >&2
					return ${ERROR}
				fi
				;;
			--key=?*)
				_DSKey=${1#*=} # Delete everything up to "=" and assign the remainder.
				;;
			--key=) # Handle the case of an empty --key=
				printf 'ERROR: "%s" requires a non-empty option argument.\n' "${1}" >&2
				return ${ERROR}
				;;
			--) # End of all options.
				shift
				break
				;;
			-?*)
				printf 'WARN: Unknown option (ignored): %s\n' "${1}" >&2
				;;
			*) # Default case: If no more options then break out of the loop.
				break
		esac
		shift
	done

	if [ -n "${_Account}" ] && \
  [ -n "${_DSKey}" ] && \
  _DSValue="$(dscl . read /Users/"${_Account}" "${_DSKey}" |\
							awk -F"${_FS}" \
									-v DSKey="${_DSKey}" \
							  '
                BEGIN {
									DSValue=""
									DSKeyFound=0
								}
								function getValuesFromPosition(StartPosition) {
									for(FieldNr=StartPosition; FieldNr <= NF; FieldNr++) {
										DSValue = (DSValue == "" ? "" : DSValue FS) $FieldNr
									}
								}
								DSKeyFound == 1 {
									getValuesFromPosition(1)
									DSKeyFound=0
								}
								$1 == DSKey {
								  if (NF > 1) {
								  	getValuesFromPosition(2)
								  } else {
								  	DSKeyFound=1
									  next
								  }
								}
								END {
									# trim leading space
									gsub(/^[[:space:]]+/, "", DSValue)
									printf("%s", DSValue)
								}
                ')"; then
		echo "${_DSValue}"
		return ${SUCCESS}
	else
		return ${ERROR}
	fi
}
# user name
declare -r UserName="$(id -p | awk -F'	' '/^uid/ { print $2 }')"
# user id
declare -ir UserId="$(readDS --account="${UserName}" --key="UniqueID")"
# user primary group id
declare -ir UserPrimaryGroupId="$(readDS --account="${UserName}" --key="PrimaryGroupID")"
# user home
declare -r UserHome="$(readDS --account="${UserName}" --key="NFSHomeDirectory")"
# logged in user
LoggedInUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
# login name
LoginName="$(id -p | awk -F'	' '/^login/ { print $2 }')"
if [ -z "${LoginName}" ]; then
	LoginName="${UserName}"
	# login id
	declare -i LoginId="${UserId}"
	# login primary group id
	declare -i LoginPrimaryGroupId=${UserPrimaryGroupId}
	# login home
	LoginHome="${UserHome}"
	# launch as user
	LaunchAsUser=""
else
	declare -i LoginId="$(readDS --account="${LoginName}" --key="UniqueID")"
	declare -i LoginPrimaryGroupId="$(readDS --account="${LoginName}" --key="PrimaryGroupID")"
	LoginHome="$(readDS --account="${LoginName}" --key="NFSHomeDirectory")"
	if [[ ${IntegerOsVersion} -ge 101000 ]]; then
    LaunchAsUser="launchctl asuser ${LoginId}"
    LaunchAsUserWithChroot="${LaunchAsUser} chroot -u ${LoginId} -g ${LoginPrimaryGroupId} /"
	elif [[ ${IntegerOsVersion} -le 100900 ]]; then
    LaunchAsUser="launchctl bsexec ${LoginId}"
    LaunchAsUserWithChroot="${LaunchAsUser} chroot -u ${LoginId} -g ${LoginPrimaryGroupId} /"
	fi
fi
declare -r LoginName LoginId LoginPrimaryGroupId LoginHome LaunchAsUser
# case $(ps -o state= -p ${$}) in
if [ -t 0 ]; then
		# interactive shell (not started from launch daemon)
		declare -ri Background=${NO}
else
		# background shell
		declare -ri Background=${YES}
fi
# time zone
declare -r TimeZone="Europe/Vienna"
# internal timeserver
declare -a TimeServersInt
TimeServersInt+=( "ntp1.premedia.at" )
TimeServersInt+=( "ntp2.premedia.at" )
declare -r TimeServersInt
# external timeserver
declare -a TimeServersExt
TimeServersExt+=( "time.euro.apple.com" )
TimeServersExt+=( "time.apple.com" )
declare -r TimeServersExt
# network services to turn off (regex)
#declare -r ShutdownNetworkServices="(Firewire|Bluetooth (DUN|PAN)|Thunderbolt Bridge)"
declare -a ShutdownNetworkServices
ShutdownNetworkServices+=( "Firewire" )
ShutdownNetworkServices+=( "Bluetooth DUN" )
ShutdownNetworkServices+=( "Bluetooth PAN" )
ShutdownNetworkServices+=( "Thunderbolt Bridge" )
declare -r ShutdownNetworkServices
# hidden users (typically the same as LocalAdminUsers)
declare -a HiddenUsers
HiddenUsers=( "${LocalAdminUsers[@]}" )
declare -r HiddenUsers
# sysctl.conf options
declare -a SysCtlOptions
SysCtlOptions+=( "kern.ipc.somaxconn=2048" )
SysCtlOptions+=( "kern.ipc.maxsockbuf=16777216" )
SysCtlOptions+=( "net.inet.tcp.delayed_ack=2" )
SysCtlOptions+=( "net.inet.tcp.sendspace=1048576" )
SysCtlOptions+=( "net.inet.tcp.recvspace=1048576" )
SysCtlOptions+=( "net.inet.tcp.autorcvbufmax=33554432" )
SysCtlOptions+=( "net.inet.tcp.autosndbufmax=33554432" )
SysCtlOptions+=( "net.inet.tcp.win_scale_factor=8" )
SysCtlOptions+=( "net.inet.tcp.mssdflt=1448" )
SysCtlOptions+=( "net.inet.tcp.msl=15000" )
declare -r SysCtlOptions
# global user preferences
declare -a GlobalUserPreferencesSettings
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}AppleHighlightColor${DELIMITER}-string${DELIMITER}0.764700 0.976500 0.568600${DELIMITER}Set highlight color to green" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}NSTableViewDefaultSizeMode${DELIMITER}-int${DELIMITER}2${DELIMITER}Set sidebar icon size to medium" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}AppleShowScrollBars${DELIMITER}-string${DELIMITER}Always${DELIMITER}Always show scrollbars" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}NSNavPanelExpandedStateForSaveMode${DELIMITER}-bool${DELIMITER}true${DELIMITER}Expand save panel by default" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}NSNavPanelExpandedStateForSaveMode2${DELIMITER}-bool${DELIMITER}true${DELIMITER}Expand save panel by default 2" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}PMPrintingExpandedStateForPrint${DELIMITER}-bool${DELIMITER}true${DELIMITER}Expand save panel by default" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}PMPrintingExpandedStateForPrint2${DELIMITER}-bool${DELIMITER}true${DELIMITER}Expand save panel by default 2" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}NSDocumentSaveNewDocumentsToCloud${DELIMITER}-bool${DELIMITER}false${DELIMITER}Save to disk (not to iCloud) by default" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}NSAutomaticCapitalizationEnabled${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable automatic capitalization" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}NSAutomaticDashSubstitutionEnabled${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable smart dashes" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}NSAutomaticQuoteSubstitutionEnabled${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable smart quotes" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}NSAutomaticPeriodSubstitutionEnabled${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable automatic period substitution" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}NSAutomaticSpellingCorrectionEnabled${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable auto-correct" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}com.apple.swipescrolldirection${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable 'natural' (Lion-style) scrolling" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}AppleKeyboardUIMode${DELIMITER}-int${DELIMITER}3${DELIMITER}Enable full keyboard access for all controls" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}KeyRepeat${DELIMITER}-int${DELIMITER}1${DELIMITER}Set fast keyboard repeat rate" )
GlobalUserPreferencesSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}InitialKeyRepeat${DELIMITER}-int${DELIMITER}15${DELIMITER}Set fast initial keyboard repeat time" )
declare -r GlobalUserPreferencesSettings
# terminal settings, generated through
# plutil -convert binary1 -o - /Library/Preferences/com.apple.Terminal.plist |\
# base64
TerminalSettings="YnBsaXN0MDDfEA8AAQACAAMABAAFAAYABwAIAAkACgALAAwADQAOAA8AEAARABAAEwAWABUAFQAXABgAGQGaAZsBnAGdAZ5fEBNIYXNNaWdyYXRlZERlZmF1bHRzXxAbTlNXaW5kb3cgRnJhbWUgTlNDb2xvclBhbmVsXxATU2VjdXJlS2V5Ym9hcmRFbnRyeV8QLk5TVG9vbGJhciBDb25maWd1cmF0aW9uIGNvbS5hcHBsZS5OU0NvbG9yUGFuZWxfEBdEZWZhdWx0IFdpbmRvdyBTZXR0aW5nc18QHVRUQXBwUHJlZmVyZW5jZXMgU2VsZWN0ZWQgVGFiXxAWRGVmYXVsdFByb2ZpbGVzVmVyc2lvbl8QG05TV2luZG93IEZyYW1lIFRUV2luZG93IFByb18QH05TV2luZG93IEZyYW1lIFRUQXBwUHJlZmVyZW5jZXNfEA9XaW5kb3cgU2V0dGluZ3NfEBdOU1dpbmRvdyBGcmFtZSBUVFdpbmRvd18QGE1hbiBQYWdlIFdpbmRvdyBTZXR0aW5nc18QFVByb2ZpbGVDdXJyZW50VmVyc2lvbl8QF1N0YXJ0dXAgV2luZG93IFNldHRpbmdzXxAaTlNXaW5kb3cgRnJhbWUgTlNGb250UGFuZWwJXxAbMCA4OSAyNTUgMjI5IDAgMCAyMjI1IDEyNDQgCdEAFAAVW1RCIElzIFNob3duEAFTUHJvXxAeOTIwIDgxIDEzMDUgNzQ5IDAgMCAyMjI1IDEyNDQgXxAeNzc4IDY0MiA3MjkgNTM3IDAgMCAyMjI1IDEyNDQg2wAaABsAHAAdAB4AHwAgACEAIgAjACQAJQA8AFkAcgCKAKYAtwFQAWcBfQGKVUdyYXNzVVBybyAxWVJlZCBTYW5kc1hIb21lYnJld15TaWx2ZXIgQWVyb2dlbFxTb2xpZCBDb2xvcnNTUHJvVU5vdmVsVU9jZWFuVUJhc2ljWE1hbiBQYWdl2wAmACcAKAApACoAKwAsAC0ALgAvADAAMQAyADMAEAA1ADYANwA4ADkAOgA7XlNlbGVjdGlvbkNvbG9yVHR5cGVZVGV4dENvbG9yXUZvbnRBbnRpYWxpYXNaQ3Vyc29yVHlwZV1UZXh0Qm9sZENvbG9yW0N1cnNvckNvbG9yXxAPQmFja2dyb3VuZENvbG9yVEZvbnRfEBVQ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b3JfEB1TaG93V2luZG93U2V0dGluZ3NOYW1lSW5UaXRsZVlUZXh0Q29sb3JfEBBGb250V2lkdGhTcGFjaW5nW0N1cnNvckNvbG9yXxAVUHJvZmlsZUN1cnJlbnRWZXJzaW9uXkJhY2tncm91bmRCbHVyVG5hbWVPEPhicGxpc3QwMNQBAgMEBQYVFlgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagowcID1UkbnVsbNMJCgsMDQ5XTlNXaGl0ZVxOU0NvbG9yU3BhY2VWJGNsYXNzTTAgMC44NTAwMDAwMgAQA4AC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhQXWRydHZ7ho+XmqO1uL0AAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAvwhPEPZicGxpc3QwMNQBAgMEBQYVFlgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagowcID1UkbnVsbNMJCgsMDQ5XTlNXaGl0ZVxOU0NvbG9yU3BhY2VWJGNsYXNzSzAuMjU0MDMyMjUAEAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FIUF1kcHJ0eYSNlZihs7a7AAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAL1PEQEDYnBsaXN0MDDUAQIDBAUGGBlYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKQHCBESVSRudWxs1AkKCwwNDg8QVk5TU2l6ZVhOU2ZGbGFnc1ZOU05hbWVWJGNsYXNzI0AkAAAAAAAAEBCAAoADVk1vbmFjb9ITFBUWWiRjbGFzc25hbWVYJGNsYXNzZXNWTlNGb250ohUXWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RobVHJvb3SAAQgRGiMtMjc8QktSW2JpcnR2eH+Ej5ifoqu9wMUAAAAAAAABAQAAAAAAAAAcAAAAAAAAAAAAAAAAAAAAx18QD1dpbmRvdyBTZXR0aW5ncxACTxDtYnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OV05TV2hpdGVcTlNDb2xvclNwYWNlViRjbGFzc0IxABADgALSEBESE1okY2xhc3NuYW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSFBdZGdpa3B7hIyPmKqtsgAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC0CE8Q9mJwbGlzdDAw1AECAwQFBhUWWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCjBwgPVSRudWxs0wkKCwwNDldOU1doaXRlXE5TQ29sb3JTcGFjZVYkY2xhc3NLMC45NDc1ODA2NAAQA4AC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhQXWRwcnR5hI2VmKGztrsAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAvSM/7973ve97308Q9mJwbGlzdDAw1AECAwQFBhUWWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCjBwgPVSRudWxs0wkKCwwNDldOU1doaXRlXE5TQ29sb3JTcGFjZVYkY2xhc3NLMC4zMDI0MTkzNgAQA4AC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhQXWRwcnR5hI2VmKGztrsAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAvSNAAGZmZmZmZiMAAAAAAAAAAFVQcm8gMd0AWgBbAFwAXQBeAF8AYABhAGIAYwBkAGUAZgBnABUAEABpAGoAawBsAG0AbgBvAHAANQBxXxAPQmFja2dyb3VuZENvbG9yWkN1cnNvclR5cGVdRm9udEFudGlhbGlhc15TZWxlY3Rpb25Db2xvclRGb250VHR5cGVdVGV4dEJvbGRDb2xvcllUZXh0Q29sb3JfEBBGb250V2lkdGhTcGFjaW5nW0N1cnNvckNvbG9yXxAVUHJvZmlsZUN1cnJlbnRWZXJzaW9uXxAaZm9udEFsbG93c0Rpc2FibGVBbnRpYWxpYXNUbmFtZU8RARdicGxpc3QwMNQBAgMEBQYVFlgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagowcID1UkbnVsbNMJCgsMDQ5VTlNSR0JcTlNDb2xvclNwYWNlViRjbGFzc08QLDAuNDc4MjYwODcgMC4xNDUxMDQzNiAwLjExNjg4MTIxIDAuODUwMDAwMDIAEAGAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltikZOVmqWutrnC1NfcAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAN4JTxEBDmJwbGlzdDAw1AECAwQFBhUWWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCjBwgPVSRudWxs0wkKCwwNDlVOU1JHQlxOU0NvbG9yU3BhY2VWJGNsYXNzTxAjMC4yMzc5MDMyMSAwLjA5NzYwMTMzOSAwLjA4NzQzNDUyMwAQAoAC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KIioyRnKWtsLnLztMAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA1U8RAQticGxpc3QwMNQBAgMEBQYYGVgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagpAcIERJVJG51bGzUCQoLDA0ODxBWTlNTaXplWE5TZkZsYWdzVk5TTmFtZVYkY2xhc3MjQCYAAAAAAAAQEIACgANeU0ZNb25vLVJlZ3VsYXLSExQVFlokY2xhc3NuYW1lWCRjbGFzc2VzVk5TRm9udKIVF1hOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEaG1Ryb290gAEIERojLTI3PEJLUltiaXJ0dniHjJegp6qzxcjNAAAAAAAAAQEAAAAAAAAAHAAAAAAAAAAAAAAAAAAAAM9fEA9XaW5kb3cgU2V0dGluZ3NPEQEHYnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPEBwwLjg3NSAwLjc0MDM4ODQ1IDAuMTMyMTM4NzMAEAGAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltigYOFipWepqmyxMfMAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAAM5PEQEMYnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPECEwLjg0MzEzNzMyIDAuNzg4MjM1MzcgMC42NTQ5MDE5OAAQAoAC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2KGiIqPmqOrrrfJzNEAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAA0yM/8BCEIQhCEE8Q7WJwbGlzdDAw1AECAwQFBhUWWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCjBwgPVSRudWxs0wkKCwwNDldOU1doaXRlXE5TQ29sb3JTcGFjZVYkY2xhc3NCMQAQA4AC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhQXWRnaWtwe4SMj5iqrbIAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAtCNAAGZmZmZmZllSZWQgU2FuZHPcAHMAdAB1AHYAdwB4AHkAegB7AHwAfQB+AH8ANQBMAIEAggCDAIQAEACGAIcAiACJXxAPQmFja2dyb3VuZENvbG9yWkN1cnNvclR5cGVdRm9udEFudGlhbGlhc15TZWxlY3Rpb25Db2xvclRGb250VHR5cGVdVGV4dEJvbGRDb2xvcltDdXJzb3JCbGlua1lUZXh0Q29sb3JbQ3Vyc29yQ29sb3JfEBVQcm9maWxlQ3VycmVudFZlcnNpb25UbmFtZU8Q+GJwbGlzdDAw1AECAwQFBhUWWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCjBwgPVSRudWxs0wkKCwwNDldOU1doaXRlXE5TQ29sb3JTcGFjZVYkY2xhc3NNMCAwLjg5OTk5OTk4ABADgALSEBESE1okY2xhc3NuYW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSFBdZHJ0dnuGj5eao7W4vQAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC/CE8RAQlicGxpc3QwMNQBAgMEBQYVFlgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagowcID1UkbnVsbNMJCgsMDQ5VTlNSR0JcTlNDb2xvclNwYWNlViRjbGFzc08QHjAuMDM0NTc4Mzk1IDAgMC45MTMyNjUzMSAwLjY1ABABgALSEBESE1okY2xhc3NuYW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSE5bYoOFh4yXoKirtMbJzgAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAADQTxEBB2JwbGlzdDAw1AECAwQFBhgZWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCkBwgRElUkbnVsbNQJCgsMDQ4PEFZOU1NpemVYTlNmRmxhZ3NWTlNOYW1lViRjbGFzcyNAKAAAAAAAABAQgAKAA1pBbmRhbGVNb25v0hMUFRZaJGNsYXNzbmFtZVgkY2xhc3Nlc1ZOU0ZvbnSiFRdYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRGhtUcm9vdIABCBEaIy0yNzxCS1JbYmlydHZ4g4iTnKOmr8HEyQAAAAAAAAEBAAAAAAAAABwAAAAAAAAAAAAAAAAAAADLXxAPV2luZG93IFNldHRpbmdzTxDvYnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NGMCAxIDAAEAGAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltiaWttcn2GjpGarK+0AAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAALYJTxEBDWJwbGlzdDAw1AECAwQFBhUWWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCjBwgPVSRudWxs0wkKCwwNDlVOU1JHQlxOU0NvbG9yU3BhY2VWJGNsYXNzTxAiMC4xNTY4NjI3NSAwLjk5NjA3ODQ5IDAuMDc4NDMxMzc1ABACgALSEBESE1okY2xhc3NuYW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSE5bYoeJi5CbpKyvuMrN0gAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAADUTxEBDGJwbGlzdDAw1AECAwQFBhUWWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCjBwgPVSRudWxs0wkKCwwNDlVOU1JHQlxOU0NvbG9yU3BhY2VWJGNsYXNzTxAhMC4yMTk2MDc4NiAwLjk5NjA3ODQ5IDAuMTUyOTQxMTgAEAKAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltihoiKj5qjq663yczRAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAANMjQABmZmZmZmZYSG9tZWJyZXfeAIsAjACNAI4AjwCQAJEAkgCTAJQAlQCWAJcAmACZABAAEACcAJ0AngCfAKAAoQBXAKIAowCkAKVfEA9CYWNrZ3JvdW5kQ29sb3JfECRCYWNrZ3JvdW5kU2V0dGluZ3NGb3JJbmFjdGl2ZVdpbmRvd3NdRm9udEFudGlhbGlhc15TZWxlY3Rpb25Db2xvclRGb250XxAXQmFja2dyb3VuZEFscGhhSW5hY3RpdmVUdHlwZV1UZXh0Qm9sZENvbG9yXxAQRm9udFdpZHRoU3BhY2luZ18QFkJhY2tncm91bmRCbHVySW5hY3RpdmVbQ3Vyc29yQ29sb3JfEBVQcm9maWxlQ3VycmVudFZlcnNpb25eQmFja2dyb3VuZEJsdXJUbmFtZU8RAWticGxpc3QwMNQBAgMEBQYfIFgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagpQcIERUcVSRudWxs1AkKCwwNDg8QV05TV2hpdGVcTlNDb2xvclNwYWNlXxASTlNDdXN0b21Db2xvclNwYWNlViRjbGFzc0gwLjUgMC41ABADgAKABNISDBMUVE5TSUQQAoAD0hYXGBlaJGNsYXNzbmFtZVgkY2xhc3Nlc1xOU0NvbG9yU3BhY2WiGhtcTlNDb2xvclNwYWNlWE5TT2JqZWN00hYXHR5XTlNDb2xvcqIdG18QD05TS2V5ZWRBcmNoaXZlctEhIlRyb290gAEACAARABoAIwAtADIANwA9AEMATABUAGEAdgB9AIYAiACKAIwAkQCWAJgAmgCfAKoAswDAAMMA0ADZAN4A5gDpAPsA/gEDAAAAAAAAAgEAAAAAAAAAIwAAAAAAAAAAAAAAAAAAAQUJCU8RAQ9icGxpc3QwMNQBAgMEBQYVFlgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagowcID1UkbnVsbNMJCgsMDQ5VTlNSR0JcTlNDb2xvclNwYWNlViRjbGFzc08QJDAuMzk0NDMwMDcxMSAwLjM5OTY0NjY5OTQgMC41NDA0Mjg0ABABgALSEBESE1okY2xhc3NuYW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSE5bYomLjZKdpq6xuszP1AAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAADWTxEBC2JwbGlzdDAw1AECAwQFBhgZWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCkBwgRElUkbnVsbNQJCgsMDQ4PEFZOU1NpemVYTlNmRmxhZ3NWTlNOYW1lViRjbGFzcyNAJgAAAAAAABAQgAKAA15TRk1vbm8tUmVndWxhctITFBUWWiRjbGFzc25hbWVYJGNsYXNzZXNWTlNGb250ohUXWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RobVHJvb3SAAQgRGiMtMjc8QktSW2JpcnR2eIeMl6CnqrPFyM0AAAAAAAABAQAAAAAAAAAcAAAAAAAAAAAAAAAAAAAAzyM/4AAAAAAAAF8QD1dpbmRvdyBTZXR0aW5nc08RAUJicGxpc3QwMNQBAgMEBQYfIFgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagpQcIERUcVSRudWxs1AkKCwwNDg8QV05TV2hpdGVcTlNDb2xvclNwYWNlXxASTlNDdXN0b21Db2xvclNwYWNlViRjbGFzc0IxABADgAKABNISDBMUVE5TSUQQAoAD0hYXGBlaJGNsYXNzbmFtZVgkY2xhc3Nlc1xOU0NvbG9yU3BhY2WiGhtcTlNDb2xvclNwYWNlWE5TT2JqZWN00hYXHR5XTlNDb2xvcqIdG18QD05TS2V5ZWRBcmNoaXZlctEhIlRyb290gAEIERojLTI3PUNMVGF2fYCChIaLkJKUmaStur3K09jg4/X4/QAAAAAAAAEBAAAAAAAAACMAAAAAAAAAAAAAAAAAAAD/Iz/wEIQhCEIQTxDwYnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OV05TV2hpdGVcTlNDb2xvclNwYWNlViRjbGFzc0UwLjg1ABADgALSEBESE1okY2xhc3NuYW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSFBdZGpsbnN+h4+Sm62wtQAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC3I0AAZmZmZmZmIz/wAAAAAAAAXlNpbHZlciBBZXJvZ2Vs2ACnAKgAqQCqAKsArACtAK4ArwAQALEAsgCzALQAtQC2VHR5cGVdRm9udEFudGlhbGlhc18QEEZvbnRXaWR0aFNwYWNpbmdbQ3Vyc29yQ29sb3JURm9udF8QF0JhY2tncm91bmRJbWFnZUJvb2ttYXJrXxAVUHJvZmlsZUN1cnJlbnRWZXJzaW9uVG5hbWVfEA9XaW5kb3cgU2V0dGluZ3MJIz/wEIQhCEIQTxEBaGJwbGlzdDAw1AECAwQFBh8gWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqClBwgRFRxVJG51bGzUCQoLDA0ODxBXTlNXaGl0ZVxOU0NvbG9yU3BhY2VfEBJOU0N1c3RvbUNvbG9yU3BhY2VWJGNsYXNzRTAuNzUAEAOAAoAE0hIMExRUTlNJRBACgAPSFhcYGVokY2xhc3NuYW1lWCRjbGFzc2VzXE5TQ29sb3JTcGFjZaIaG1xOU0NvbG9yU3BhY2VYTlNPYmplY3TSFhcdHldOU0NvbG9yoh0bXxAPTlNLZXllZEFyY2hpdmVy0SEiVHJvb3SAAQAIABEAGgAjAC0AMgA3AD0AQwBMAFQAYQB2AH0AgwCFAIcAiQCOAJMAlQCXAJwApwCwAL0AwADNANYA2wDjAOYA+AD7AQAAAAAAAAACAQAAAAAAAAAjAAAAAAAAAAAAAAAAAAABAk8RAQticGxpc3QwMNQBAgMEBQYYGVgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagpAcIERJVJG51bGzUCQoLDA0ODxBWTlNTaXplWE5TZkZsYWdzVk5TTmFtZVYkY2xhc3MjQCYAAAAAAAAQEIACgANeU0ZNb25vLVJlZ3VsYXLSExQVFlokY2xhc3NuYW1lWCRjbGFzc2VzVk5TRm9udKIVF1hOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEaG1Ryb290gAEIERojLTI3PEJLUltiaXJ0dniHjJegp6qzxcjNAAAAAAAAAQEAAAAAAAAAHAAAAAAAAAAAAAAAAAAAAM9PEQLqYnBsaXN0MDDUAQIDBAUGFBVYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA1VJG51bGzSCQoLDFdOUy5kYXRhViRjbGFzc08RAehib29r6AEAAAAAARAQAAAATAEAAAcAAAABAQAATGlicmFyeQAQAAAAAQEAAERlc2t0b3AgUGljdHVyZXMMAAAAAQEAAFNvbGlkIENvbG9ycwwAAAABBgAABAAAABQAAAAsAAAACAAAAAQDAAAtgDYDAAAAAAgAAAAEAwAA2tM4AwAAAAAIAAAABAMAAJfUOAMAAAAADAAAAAEGAABUAAAAZAAAAHQAAAAYAAAAAQIAAAIAAAAAAAAADwAAAAAAAAAAAAAAAAAAAAwAAAABAQAATWFjaW50b3NoIEhECAAAAAQDAAAAAAAACgAAAAgAAAAABAAAQbAnRXIAAAAkAAAAAQEAADM1OTAxRjRELUQ1RTUtM0E5OC1CODAzLTc3MEM0NUE5RDA2QxgAAAABAgAAgQAAAAEACADvPwAAAQAIAAAAAAAAAAAAAQAAAAEBAAAvAAAAAAAAAAEFAACEAAAA/v///wEAAAAAAAAACgAAAAQQAABAAAAAAAAAAAUQAACEAAAAAAAAABAQAACYAAAAAAAAAAIgAAA4AQAAAAAAABAgAAC4AAAAAAAAABEgAADsAAAAAAAAABIgAADMAAAAAAAAABMgAADcAAAAAAAAACAgAAAYAQAAAAAAADAgAABEAQAAAAAAAIAC0g4PEBFaJGNsYXNzbmFtZVgkY2xhc3Nlc11OU011dGFibGVEYXRhoxASE1ZOU0RhdGFYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFhdUcm9vdIABAAgAEQAaACMALQAyADcAOwBBAEYATgBVAkECQwJIAlMCXAJqAm4CdQJ+ApACkwKYAAAAAAAAAgEAAAAAAAAAGAAAAAAAAAAAAAAAAAAAApojQABmZmZmZmZcU29saWQgQ29sb3Jz3xAVALgAuQC6ALsAvAC9AL4AvwDAAMEAwgDDAMQAxQDGAMcAyADJAMoAywDMAM0AzgDPANAATADSANMA1ADVAFAA1gDXANgATADaANsAVwDcAN0ATAFPXlNlbGVjdGlvbkNvbG9yWVRleHRDb2xvcltDdXJzb3JDb2xvcl1BTlNJQmx1ZUNvbG9yXUZvbnRBbnRpYWxpYXNdVGV4dEJvbGRDb2xvclhyb3dDb3VudF1Db21tYW5kU3RyaW5nXxAVUHJvZmlsZUN1cnJlbnRWZXJzaW9uXxAPc2hlbGxFeGl0QWN0aW9uVG5hbWVURm9udF8QE0FOU0lCcmlnaHRCbHVlQ29sb3JfEB1TaG93V2luZG93U2V0dGluZ3NOYW1lSW5UaXRsZVR0eXBlXxAQRm9udFdpZHRoU3BhY2luZ15CYWNrZ3JvdW5kQmx1cltjb2x1bW5Db3VudF8QD2tleU1hcEJvdW5kS2V5c18QEVJ1bkNvbW1hbmRBc1NoZWxsXxAPQmFja2dyb3VuZENvbG9yTxD2YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OV05TV2hpdGVcTlNDb2xvclNwYWNlViRjbGFzc0swLjI1NDAzMjI1ABADgALSEBESE1okY2xhc3NuYW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSFBdZHBydHmEjZWYobO2uwAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC9TxD2YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OV05TV2hpdGVcTlNDb2xvclNwYWNlViRjbGFzc0swLjk0NzU4MDY0ABADgALSEBESE1okY2xhc3NuYW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSFBdZHBydHmEjZWYobO2uwAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC9TxD2YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKMHCA9VJG51bGzTCQoLDA0OV05TV2hpdGVcTlNDb2xvclNwYWNlViRjbGFzc0swLjMwMjQxOTM2ABADgALSEBESE1okY2xhc3NuYW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSFBdZHBy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EBESE1okY2xhc3NuYW1lWCRjbGFzc2VzV05TQ29sb3KiEhRYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRFxhUcm9vdIABCBEaIy0yNztBSE5bYn+Bg4iTnKSnsMLFygAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAADMTxEBBGJwbGlzdDAw1AECAwQFBhgZWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCkBwgRElUkbnVsbNQJCgsMDQ4PEFZOU1NpemVYTlNmRmxhZ3NWTlNOYW1lViRjbGFzcyNAKAAAAAAAABAQgAKAA1dDb3VyaWVy0hMUFRZaJGNsYXNzbmFtZVgkY2xhc3Nlc1ZOU0ZvbnSiFRdYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRGhtUcm9vdIABCBEaIy0yNzxCS1JbYmlydHZ4gIWQmaCjrL7BxgAAAAAAAAEBAAAAAAAAABwAAAAAAAAAAAAAAAAAAADII0AAZmZmZmZmCNsBaAFpAWoBawFsAW0BbgFvAXABcQFyAXMBdAF1ABABdwF4AXkBegF7ADUBfF5TZWxlY3Rpb25Db2xvclR0eXBlWVRleHRDb2xvcl1Gb250QW50aWFsaWFzXxAQRm9udFdpZHRoU3BhY2luZ11UZXh0Qm9sZENvbG9yVEZvbnRfEA9CYWNrZ3JvdW5kQ29sb3JfEBVQcm9maWxlQ3VycmVudFZlcnNpb25fEBpmb250QWxsb3dzRGlzYWJsZUFudGlhbGlhc1RuYW1lTxEBAmJwbGlzdDAw1AECAwQFBhUWWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCjBwgPVSRudWxs0wkKCwwNDlVOU1JHQlxOU0NvbG9yU3BhY2VWJGNsYXNzTxAXMC4xMzA3MzkzIDAuNDI4NDU4MDYgMQAQAYAC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2J8foCFkJmhpK2/wscAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAyV8QD1dpbmRvdyBTZXR0aW5nc08Q7WJwbGlzdDAw1AECAwQFBhUWWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCjBwgPVSRudWxs0wkKCwwNDldOU1doaXRlXE5TQ29sb3JTcGFjZVYkY2xhc3NCMQAQA4AC0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIUWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhQXWRnaWtwe4SMj5iqrbIAAAAAAAABAQAAAAAAAAAZAAAAAAAAAAAAAAAAAAAAtAkjP+/e973ve99PEO1icGxpc3QwMNQBAgMEBQYVFlgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagowcID1UkbnVsbNMJCgsMDQ5XTlNXaGl0ZVxOU0NvbG9yU3BhY2VWJGNsYXNzQjEAEAOAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FIUF1kZ2lrcHuEjI+Yqq2yAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAALRPEQELYnBsaXN0MDDUAQIDBAUGGBlYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3ASAAGGoKQHCBESVSRudWxs1AkKCwwNDg8QVk5TU2l6ZVhOU2ZGbGFnc1ZOU05hbWVWJGNsYXNzI0AmAAAAAAAAEBCAAoADXlNGTW9uby1SZWd1bGFy0hMUFRZaJGNsYXNzbmFtZVgkY2xhc3Nlc1ZOU0ZvbnSiFRdYTlNPYmplY3RfEA9OU0tleWVkQXJjaGl2ZXLRGhtUcm9vdIABCBEaIy0yNzxCS1JbYmlydHZ4h4yXoKeqs8XIzQAAAAAAAAEBAAAAAAAAABwAAAAAAAAAAAAAAAAAAADPTxEBDGJwbGlzdDAw1AECAwQFBhUWWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCjBwgPVSRudWxs0wkKCwwNDlVOU1JHQlxOU0NvbG9yU3BhY2VWJGNsYXNzTxAhMC4xMzIwNTYyNCAwLjMwODQ3ODU2IDAuNzM5MTMwNDQAEAGAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltihoiKj5qjq663yczRAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAANMjQABmZmZmZmZVT2NlYW7WAX4BfwGAAYEBggGDABABhQGGAYcBiAGJXUZvbnRBbnRpYWxpYXNfEBBGb250V2lkdGhTcGFjaW5nVEZvbnRfEBVQcm9maWxlQ3VycmVudFZlcnNpb25UdHlwZVRuYW1lCSM/8BCEIQhCEE8RAQticGxpc3QwMNQBAgMEBQYYGVgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagpAcIERJVJG51bGzUCQoLDA0ODxBWTlNTaXplWE5TZkZsYWdzVk5TTmFtZVYkY2xhc3MjQCYAAAAAAAAQEIACgANeU0ZNb25vLVJlZ3VsYXLSExQVFlokY2xhc3NuYW1lWCRjbGFzc2VzVk5TRm9udKIVF1hOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEaG1Ryb290gAEIERojLTI3PEJLUltiaXJ0dniHjJegp6qzxcjNAAAAAAAAAQEAAAAAAAAAHAAAAAAAAAAAAAAAAAAAAM8jQABmZmZmZmZfEA9XaW5kb3cgU2V0dGluZ3NVQmFzaWPYAYsBjAGNAY4BjwGQAZEBkgGTABABlQGWAZcBmAGZANNUdHlwZV1Gb250QW50aWFsaWFzXxAQRm9udFdpZHRoU3BhY2luZ1RGb250XxAPQmFja2dyb3VuZENvbG9yXxAVUHJvZmlsZUN1cnJlbnRWZXJzaW9uVG5hbWVYcm93Q291bnRfEA9XaW5kb3cgU2V0dGluZ3MJIz/wEIQhCEIQTxEBC2JwbGlzdDAw1AECAwQFBhgZWCR2ZXJzaW9uWCRvYmplY3RzWSRhcmNoaXZlclQkdG9wEgABhqCkBwgRElUkbnVsbNQJCgsMDQ4PEFZOU1NpemVYTlNmRmxhZ3NWTlNOYW1lViRjbGFzcyNAJgAAAAAAABAQgAKAA15TRk1vbm8tUmVndWxhctITFBUWWiRjbGFzc25hbWVYJGNsYXNzZXNWTlNGb250ohUXWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RobVHJvb3SAAQgRGiMtMjc8QktSW2JpcnR2eIeMl6CnqrPFyM0AAAAAAAABAQAAAAAAAAAcAAAAAAAAAAAAAAAAAAAAz08RARFicGxpc3QwMNQBAgMEBQYVFlgkdmVyc2lvblgkb2JqZWN0c1kkYXJjaGl2ZXJUJHRvcBIAAYagowcID1UkbnVsbNMJCgsMDQ5VTlNSR0JcTlNDb2xvclNwYWNlViRjbGFzc08QJjAuOTk2MDc4NDkxMiAwLjk1Njg2MjgwNzMgMC42MTE3NjQ3MjkAEAKAAtIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltii42PlJ+osLO8ztHWAAAAAAAAAQEAAAAAAAAAGQAAAAAAAAAAAAAAAAAAANgjQABmZmZmZmZYTWFuIFBhZ2VfEB4xNjAgNzI1IDUyNCAzNDkgMCAwIDIyMjUgMTI0NCBYTWFuIFBhZ2UjQABmZmZmZmZTUHJvXxAfMTcyNCAxNzAgNDQ1IDMyOCAwIDAgMjIyNSAxMjQ0IAAIAEcAXQB7AJEAwgDcAPwBFQEzAVUBZwGBAZwBtAHOAesB7AIKAgsCEAIcAh4CIgJDAmQCkQKXAp0CpwKwAr8CzALQAtYC3ALiAusDGAMnAywDNgNEA08DXQNpA3sDgAOYA50ErQS/BcYFxwXJBs8H1gjlCe0J9gn8CjUKRwpVCmQKaQpuCoAKjgquCrgKywrXCu8K/gsDC/4L/wz4Df8OEQ4TDwMPBA/9EAYQ/xEIERERFxFMEV4RaRF3EYYRixGQEZ4RqBG7EccR3xH8EgETHBMdFC8VPhVQFlsXaxd0GGQYbRh3GKgYuhjFGNMY4hjnGOwY+hkGGRAZHBk0GTkaNBo1G0IcTRxfHVEdUh5jH3MffB+FH74f0B/3IAUgFCAZIDMgOCBGIFkgciB+IJYgpSCqIhkiGiIbIy4kPSRGJFglniWnJpomoyasJrsm3CbhJu8nAicOJxMnLSdFJ0onXCddJ2Yo0inhLM8s2CzlLTwtSy1VLWEtby19LYstlC2iLbotzC3RLdYt7C4MLhEuJC4zLj8uUS5lLncvcDBpMWI1iTWKNno2fDbuNvc2+zgKPBk8GjwsPDU8Nz0aPSA9JT0rPTE9Nj08PUI9ST1OPVM9WT1fPWU9az1xPXY9ez2BPYc9jD2SPZg9nj2kPak9rj20Pbk9vz3FPco9zz3UPdo94D3lPes98D32Pfs+AD4GPgw+Ej4XPhw+IT4nPi0+Mz45Pj4+Qz5IPk4+VD5aPmA+Zz5tPnM+eT5/Poc+jT6TPpo+oT6nPq0+sz65Pr0+xD7TPtk+3z7lPus+8T73Pv0/BD8IPws/ET8XPx0/IT8nPy0/Mj84Pzw/Pz9FP0s/UT9XP10/Xz9lP2s/cT93P34/hD+KP5A/kj+YP54/n0CaQMdA1kDbQOVA6kD4QQZBEkEkQSlBQUFhQnxCgkOSQ6RDpUSvRchG0UfZR+JH40gQSB9IJEguSDxIT0hdSGJIdEiMSKlIrkm0ScZKtkq3SsBLsEy/Tc9N2E3eTfdOBU4YTh1ONU46Tj9OQE5JT1hPYU9zT3lPmk+fT61PwE/FT9dP70/0T/1QD1AQUBlRKFI9UkZST1JwUnlSglKGAAAAAAAAAgIAAAAAAAABnwAAAAAAAAAAAAAAAAAAUqg="
# setup asssistant settings
declare -a SetupAssistantSettings
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeAppearanceSetup${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeApplePaySetup${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeAvatarSetup${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeCloudDiagnostics${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeCloudSetup${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeiCloudLoginForStorageServices${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeePrivacy${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeSiriSetup${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeSyncSetup${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeSyncSetup2${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeTouchIDSetup${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}DidSeeTrueTonePrivacy${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}GestureMovieSeen${DELIMITER}-string${DELIMITER}none${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}LastPreLoginTasksPerformedBuild${DELIMITER}-string${DELIMITER}${OsBuildVersion}${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}LastPreLoginTasksPerformedVersion${DELIMITER}-string${DELIMITER}${OsProductVersion}${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}LastPrivacyBundleVersion${DELIMITER}-string${DELIMITER}2${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}LastSeenBuddyBuildVersion${DELIMITER}-string${DELIMITER}${OsBuildVersion}${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}LastSeenCloudProductVersion${DELIMITER}-string${DELIMITER}${OsProductVersion}${DELIMITER}" )
SetupAssistantSettings+=( "~/${PrefsRPN}/com.apple.SetupAssistant.plist${DELIMITER}RunNonInteractive${DELIMITER}-bool${DELIMITER}true${DELIMITER}" )
declare -r SetupAssistantSettings
# login settings
declare -a AppleLoginWindowSettings
AppleLoginWindowSettings+=( "${TargetVolume}${PrefsRPN}/com.apple.loginwindow.plist${DELIMITER}EnableExternalAccounts${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable external accounts" )
AppleLoginWindowSettings+=( "${TargetVolume}${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}MultipleSessionEnabled${DELIMITER}-bool${DELIMITER}true${DELIMITER}Enable fast user switching" )
AppleLoginWindowSettings+=( "${TargetVolume}${PrefsRPN}/com.apple.loginwindow.plist${DELIMITER}AdminHostInfo${DELIMITER}-string${DELIMITER}IPAddress${DELIMITER}Show additional information on the loginscreen" )
AppleLoginWindowSettings+=( "${TargetVolume}${PrefsRPN}/com.apple.loginwindow.plist${DELIMITER}SHOWFULLNAME${DELIMITER}-bool${DELIMITER}true${DELIMITER}Show user and password on the loginscreen" )
AppleLoginWindowSettings+=( "${TargetVolume}${PrefsRPN}/com.apple.loginwindow.plist${DELIMITER}Hide500Users${DELIMITER}-bool${DELIMITER}true${DELIMITER}Hide accounts with id < 500" )
declare -r AppleLoginWindowSettings
# login window settings
declare -a LoginWindowSettings
LoginWindowSettings+=( "~/${PrefsRPN}/loginwindow.plist${DELIMITER}BuildVersionStampAsNumber${DELIMITER}-integer${DELIMITER}${OsBuildVersionStampAsNumber}${DELIMITER}" )
LoginWindowSettings+=( "~/${PrefsRPN}/loginwindow.plist${DELIMITER}BuildVersionStampAsString${DELIMITER}-string${DELIMITER}${OsBuildVersion}${DELIMITER}" )
LoginWindowSettings+=( "~/${PrefsRPN}/loginwindow.plist${DELIMITER}SystemVersionStampAsNumber${DELIMITER}-integer${DELIMITER}${OsSystemVersionStampAsNumber}${DELIMITER}" )
LoginWindowSettings+=( "~/${PrefsRPN}/loginwindow.plist${DELIMITER}SystemVersionStampAsString${DELIMITER}-string${DELIMITER}${OsProductVersion}${DELIMITER}" )
LoginWindowSettings+=( "${TargetVolume}${PrefsRPN}/com.apple.loginwindow.plist${DELIMITER}showInputMenu${DELIMITER}-bool${DELIMITER}true${DELIMITER}Show input menu in systemUI" )
declare -r LoginWindowSettings
# automatic updates settings
declare -a AutomaticUpdateSettings
AutomaticUpdateSettings+=( "${TargetVolume}${PrefsRPN}/com.apple.SoftwareUpdate.plist${DELIMITER}AutomaticCheckEnabled${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable automatic update check" )
AutomaticUpdateSettings+=( "${TargetVolume}${PrefsRPN}/com.apple.SoftwareUpdate.plist${DELIMITER}AutomaticDownload${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable automatic update download" )
AutomaticUpdateSettings+=( "${TargetVolume}${PrefsRPN}/com.apple.commerce.plist${DELIMITER}AutoUpdate${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable automatic app updates" )
AutomaticUpdateSettings+=( "${TargetVolume}${PrefsRPN}/com.apple.commerce.plist${DELIMITER}AutoUpdateRestartRequired${DELIMITER}-bool${DELIMITER}false${DELIMITER}Disable automatic os updates" )
declare -r AutomaticUpdateSettings
# authorizationdb settings
declare -a authorizationdbSettings
authorizationdbSettings+=( "system.preferences${DELIMITER}allow" )
authorizationdbSettings+=( "system.preferences.datetime${DELIMITER}allow" )
authorizationdbSettings+=( "system.preferences.energysaver${DELIMITER}allow" )
authorizationdbSettings+=( "system.preferences.network${DELIMITER}allow" )
authorizationdbSettings+=( "system.preferences.printing${DELIMITER}allow" )
authorizationdbSettings+=( "system.print.operator${DELIMITER}allow" )
authorizationdbSettings+=( "system.print.admin${DELIMITER}allow" )
authorizationdbSettings+=( "system.services.systemconfiguration.network${DELIMITER}allow" )
declare -r authorizationdbSettings
# screen settings
declare -a ScreenSettings
ScreenSettings+=( "~/${PrefsRPN}/com.apple.screensaver.plist${DELIMITER}askForPassword${DELIMITER}-int${DELIMITER}1${DELIMITER}Require password after sleep or screen saver begins" )
ScreenSettings+=( "~/${PrefsRPN}/com.apple.screensaver.plist${DELIMITER}askForPasswordDelay${DELIMITER}-int${DELIMITER}0${DELIMITER}Require the sleep or screen saver password immediately" )
ScreenSettings+=( "~/${PrefsRPN}/com.apple.screencapture.plist${DELIMITER}location${DELIMITER}-string${DELIMITER}\"${HOME}/Desktop\"${DELIMITER}Save screenshots to the desktop" )
ScreenSettings+=( "~/${PrefsRPN}/com.apple.screencapture.plist${DELIMITER}type${DELIMITER}-string${DELIMITER}png${DELIMITER}Save screenshots in PNG format" )
ScreenSettings+=( "~/${PrefsRPN}/com.apple.screencapture.plist${DELIMITER}disable-shadow${DELIMITER}-bool${DELIMITER}true${DELIMITER}Disable shadow in screenshots" )
ScreenSettings+=( "~/${PrefsRPN}/${GlobalPreferencesFN}${DELIMITER}AppleFontSmoothing${DELIMITER}-int${DELIMITER}1${DELIMITER}Enable subpixel font rendering on non-Apple LCDs" )
declare -r ScreenSettings
# whats new settings
# Var:0:2 = ~/ -> Var/#~/Var2
# funtions
setTCPSettings() {
  local SysctlOption=""
  local SysctlValue=""
  local -i Idx=0
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Set TCP settings ... "
  echo -n "Configure ${SysctlConfFQFN} ... "
  for ((Idx=0; Idx < ${#SysCtlOptions[@]}; Idx++)); do
    while IFS="=" read SysctlOption SysctlValue; do
      if ((Idx > 0)); then
        echo -n ", "
      fi
      echo -n "Write ${SysctlOption} ... "
      RV="$(sed -i '' -E '
            /^.*'"${SysctlOption}"'[[:space:]]*=[[:space:]]*.*$/ {
              h
              s/^(.*)('"${SysctlOption}"'[[:space:]]*=[[:space:]]*).*$/\2'"${SysctlValue}"'/
              }
            $ {
              x
              /^$/ {
                s//'"${SysctlOption}"'='"${SysctlValue}"'/
                H
              }
              x
              }
            ' "${SysctlConfFQFN}" 2>&1)"; RC=${?}
      if ((RC == SUCCESS)); then
        echo -n "ok"
      else
        echo -e "ERROR${DELIMITER}Writing of ${SysctlOption}=${SysctlValue} to /etc/sysctl.conf failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    done <<<"${SysCtlOptions[${Idx}]}"
  done

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

disableNetworkServices() {
  local NetworkService=""
  local -i DisabledNetworkServices=0
  local -i Idx=0
  local -i RC=0
  local -i EC=0
  local RV

  echo "INFO${DELIMITER}Shutdown network services ... "
#  while read NetworkService; do
  for ((Idx=0; Idx < ${#ShutdownNetworkServices[@]}; Idx++)); do
    while read NetworkService; do
      ((++Idx > 1)) && echo -n ", "
      echo -n "shutdown ${NetworkService} ... "
      RV="$(networksetup -setnetworkserviceenabled "${NetworkService}" off 2>&1)"; RC=${?}
      if ((RC == SUCCESS)); then
        ((DisabledNetworkServices++))
        echo -n "ok"
      else
        echo -e "ERROR${DELIMITER}networksetup -setnetworkserviceenabled '${NetworkService}' off failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    done < <(echo "${ShutdownNetworkServices[${Idx}]}" |\
             egrep -v "^\*")
  done
#  done <<<"${ShutdownNetworkServices[${Idx}]}"
#  done < <(networksetup -listallnetworkservices |\
#           egrep "^([^\*])?${ShutdownNetworkServices}")

  if ((DisabledNetworkServices == SUCCESS)); then
    echo -n "No unnecessary network service found"
    EC=${SUCCESS}
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

disableIPV6() {
  local NetworkService=""
  local -i Idx=0
  local -i RC=0
  local -i EC=0
  local RV

  echo "INFO${DELIMITER}Disable IPv6 ... "
  while IFS= read NetworkService; do
    ((++Idx > 1)) && echo -n ", "
    echo -n "disable IPv6 for '${NetworkService}' ... "
    RV="$(networksetup -setv6off "${NetworkService}" 2>&1)"; RC=${?}
    if ((RC == SUCCESS)); then
      echo -n "ok"
    else
      echo -e "ERROR${DELIMITER}networksetup -setv6off '${NetworkService}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
      EC=$((EC||RC))
    fi
  done < <(networksetup -listallnetworkservices |\
           awk 'NR > 1 && /^[^\*]/ { print $0 }')

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

setTimeServer() {
  # based on https://discussions.apple.com/thread/8440807
  local NtpConf=""
  local NtpConfFQFN="${TargetVolume}etc/ntp.conf"
  local NtpDriftFQFN="${TargetVolume}etc/ntp/drift"
  local NtpDriftFQPN="${NtpDriftFQFN%/*}"
  local NtpKodFQFN="${TargetVolume}var/db/ntp-kod"
  local NtpKodFQPN="${NtpKodFQFN%/*}"
  local -a TimeServers=()
  local -i TimeServerCnt
  local -i RC=0
  local -i EC=0
  local RV=""

  case "${ModelIdentifier}" in
    "MacBook"*)
      TimeServers=( "${TimeServersExt[@]}" )
      ;;
    *)
      TimeServers=( "${TimeServersInt[@]}" )
      ;;
  esac

  for ((TimeServerCnt=0; TimeServerCnt < ${#TimeServers[@]}; TimeServerCnt++)); do
    NtpConf+="server ${TimeServers[${TimeServerCnt}]} iburst $(((TimeServerCnt == 0)) && echo "prefer")\n"
  done
  NtpConf+="server 127.127.1.0\n"
  NtpConf+="fudge 127.127.1.0 stratum 10\n"
  NtpConf+="driftfile ${NtpDriftFQFN}\n"
  NtpConf+="restrict default noquery nomodify\n"
  NtpConf+="restrict 127.0.0.1\n"

  echo "INFO${DELIMITER}Setting time server"
  echo -n "Turn network time off ... "
  RV="$(systemsetup -setusingnetworktime off 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}systemsetup -setusingnetworktime off failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n ", create '${NtpDriftFQPN}' ... "
  RV="$(mkdir -p "${NtpDriftFQPN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}mkdir -p '${NtpDriftFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n ", create '${NtpConfFQFN}' ... "
  RV="$( { echo -e "${NtpConf}" > "${NtpConfFQFN}"; } 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}echo '${NtpConf}' > '${NtpConfFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n ", touch '${NtpConfFQFN}' ... "
  RV="$(touch "${NtpConfFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}touch '${NtpConfFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n ", set timezone to '${TimeZone}' ... "
  RV="$(systemsetup -settimezone "${TimeZone}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}systemsetup -settimezone '${TimeZone}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n ", set date from '${TimeServers[0]}' ... "

  case ${OsVersion[1]} in
    1[2-4])
      if [[ ! -d "${NtpKodFQPN}" ]]; then
        RV="$(mkdir -p "${NtpKodFQPN}" 2>&1)"; RC=${?}
        if ((RC == SUCCESS)); then
          echo -n "ok"
        else
          echo -e "ERROR${DELIMITER}mkdir -p '${NtpKodFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
          EC=$((EC||RC))
        fi
      fi
      if [[ ! -f "${NtpKodFQFN}" ]]; then
        RV="$(touch "${NtpKodFQFN}" 2>&1)"; RC=${?}
        if ((RC == SUCCESS)); then
          echo -n "ok"
        else
          echo -e "ERROR${DELIMITER}touch '${NtpKodFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
          EC=$((EC||RC))
        fi
        RV="$(chmod 666 "${NtpKodFQFN}" 2>&1)"; RC=${?}
        if ((RC == SUCCESS)); then
          echo -n "ok"
        else
          echo -e "ERROR${DELIMITER}chmod 666 '${NtpKodFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
          EC=$((EC||RC))
        fi
      fi
      RV="$(sntp -sS "${TimeServers[0]}" 2>&1)"; RC=${?}
      if ((RC == SUCCESS)); then
        echo -n "ok"
      else
        echo -e "ERROR${DELIMITER}sntp -sS '${TimeServers[0]}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
      ;;
    11)
      RV="$(sntp -s -- "${TimeServers[0]}" 2>&1)"; RC=${?}
      if ((RC == SUCCESS)); then
        echo -n "ok"
      else
        echo -e "ERROR${DELIMITER}sntp -s -- '${TimeServers[0]}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
      RV="$(sntp -j -- "${TimeServers[0]}" 2>&1)"; RC=${?}
      if ((RC == SUCCESS)); then
        echo -n "ok"
      else
        echo -e "ERROR${DELIMITER}sntp -j -- '${TimeServers[0]}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
      ;;
    *)
      RV="$(ntpdate "${TimeServers[0]}" 2>&1)"; RC=${?}
      if ((RC == SUCCESS)); then
        echo -n "ok"
      else
        echo -e "ERROR${DELIMITER}ntpdate '${TimeServers[0]}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
      ;;
  esac

  echo -n ", turn network time on ... "
  RV="$(systemsetup -setusingnetworktime off 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}systemsetup -setusingnetworktime on failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

setAllLocalNames() {
  # ComputerName .... is the user-friendly name of your Mac.
  #                   It will show up on the Mac itself and what will be visible to others when
  #                   connecting to it over a local network. This is also what is visibule under
  #                   the Sharing preference panel
  # Hostname ........ is the name assigned to the computer as visible from the command line and
  #                   it is also used by local and remote networks when connecting through
  #                   SSH and Remote Login
  # LocalHostName ... is the name identifier used by Bonjour and visible through file-sharing
  #                   services like Airdrop
  # sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$MY_NAME"
  local AdjustedComputerName="$(echo "${ComputerName}" |\
                                awk '{ gsub(/_/, "-"); printf("%s", tolower($0)) }')"
  local NetBIOSName="$(echo "${AdjustedComputerName}" |\
                       awk '{ printf("%s%d", toupper(substr($1, 1, 14)), 1) }')"
  local SmbServerPlistFQFN="${TargetVolume}${PrefsRPN}/SystemConfiguration/com.apple.smb.server.plist"
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Set all names"
  echo -n "Setting ComputerName ... "
  RV="$(scutil --set ComputerName "${AdjustedComputerName}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok, "
  else
    echo -e "ERROR${DELIMITER}scutil --set ComputerName '${AdjustedComputerName}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n "Setting HostName ... "
  RV="$(scutil --set HostName "${AdjustedComputerName}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok, "
  else
    echo -e "ERROR${DELIMITER}scutil --set HostName '${AdjustedComputerName}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n "Setting LocalHostName ... "
  RV="$(scutil --set LocalHostName "${AdjustedComputerName}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok, "
  else
    echo -e "ERROR${DELIMITER}scutil --set LocalHostName '${AdjustedComputerName}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n "Setting NetBIOSName ... "
  RV="$(defaults write "${SmbServerPlistFQFN}" NetBIOSName -string "${NetBIOSName}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}defaults write '${SmbServerPlistFQFN}' NetBIOSName -string '${NetBIOSName}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

setPowerSaveSettings() {
  local GlobalPreferencesFQFN="${TargetVolume}${PrefsRPN}/${GlobalPreferencesFN}"
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Set power save settings"
  echo -n "Disable sleep ... "
  RV="$(pmset -c sleep 0 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok, "
  else
    echo -e "ERROR${DELIMITER}pmset -c sleep 0 failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n "Disable App Nap completly ... "
  RV="$(defaults write ${GlobalPreferencesFQFN} NSAppSleepDisabled -bool true 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}defaults write ${GlobalPreferencesFQFN} NSAppSleepDisabled -bool true failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

setPrinterSettings() {
  local CupsdConfFQFN="${TargetVolume}etc/cups/cupsd.conf"
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Set printer settings"
  echo -n "Enabling Resume-Printer ... "
  RV="$(sed -i '' -E 's/Resume-Printer([[:space:]])?//g' "${CupsdConfFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok, "
  else
    echo -e "ERROR${DELIMITER}sed -i '' -E 's/Resume-Printer([[:space:]])?//g' '${CupsdConfFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n "Disable PreserveJobFiles ... "
  RV="$(sed -i '' -E '
        /^PreserveJobFiles[[:space:]]+.*$/ {
          h
          s/^(PreserveJobFiles[[:space:]]+).*$/\1No/
          }
        $ {
          x
          /^$/ {
            s//PreserveJobFiles No/
            H
            }
          x
          }
        ' "${CupsdConfFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}: failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

enableARD() {
  local AllowedARDUserString="$( IFS=","; echo "${LocalAdminUsers[*]}" )"
  local -i RC=0
  local -i EC=0
  local RV=""

  if ((OsVersion[1] < 14)); then
    echo "INFO${DELIMITER}Enable ARD ... "
    echo -n "Configure ARD ... "
    RV="$(kickstart \
            -configure \
              -users "${AllowedARDUserString}" \
            -activate \
            -access \
              -on \
            -privs \
              -all \
            -allowAccessFor \
              -specifiedUsers \
            -clientopts \
              -setmenuextra \
                -menuextra no \
            -restart \
              -agent \
              -console \
              -menu 2>&1)"; RC=${?}
    if ((RC == SUCCESS)); then
      echo -n "ok"
    else
      echo -e "ERROR${DELIMITER}kickstart -configure -users '${AllowedARDUserString}' -activate -access -on -privs -all -allowAccessFor -specifiedUsers -clientopts -setmenuextra -menuextra no -restart -agent -console -menu failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
      EC=$((EC||RC))
    fi

    if ((EC == SUCCESS)); then
      echo -e "\nSUCCESS"
    fi
  else
    echo "Unable to activate ARD on macOS Mojave, you have to do it by yourself through the GUI"
  fi

  return ${EC}
}

enableSSH() {
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Enable ssh .. "
  echo -n "Configure ssh ... "
  RV="$(systemsetup -setremotelogin on 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}systemsetup -setremotelogin on failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

setAppleLoginWindowSettings() {
  local LoginWindowPlistFQFN="${TargetVolume}${PrefsRPN}/com.apple.loginwindow.plist"
  local -i HiddenUsersIdx=0
  local HiddenUserPlistCounter=""
  local -i HiddenUserPlistCounterIdx=0
  local -i HiddenUserFound=0
  local HiddenUserPlistCounterText=""
  local -i Idx=0
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Setting login settings ... "
  for ((Idx=0; Idx < ${#AppleLoginWindowSettings[@]}; Idx++)); do
    while IFS="${DELIMITER}" read -r SettingFile SettingName SettingType SettingValue SettingsDescription; do
      ((Idx > 0)) && echo -n ", "
      echo -n "${SettingsDescription:-${SettingName}}: "
      RV="$(defaults write "${SettingFile}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
      if ((RCs[${Idx}] == SUCCESS)); then
        RV="$(${DEBUG} chown -R "${dsclUniqueID}:${dsclPrimaryGroupID}" "${SettingFile}" 2>&1)"; RCs[${Idx}]=${?}
        if ((RCs[${Idx}] == SUCCESS)); then
          echo -n "ok"
        else
          echo -e "ERROR${DELIMITER}chown -R '${dsclUniqueID}:${dsclPrimaryGroupID}' '${SettingFile}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
          RC=$((RC||RCs[${Idx}]))
        fi
      else
        echo -e "ERROR${DELIMITER}defaults write '${SettingFile}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
        RC=$((RC||RCs[${Idx}]))
      fi
    done <<<"${AppleLoginWindowSettings[${Idx}]}"
  done


  RV="$({ plutil -convert xml1 -o - "${LoginWindowPlistFQFN}" |\
          xmllint -xpath "(//dict/key[text() = 'HiddenUsersList']/following-sibling::array)[1]" -; } 2>&1)"; RC=${?}
  if [[ ${RC} -eq 10 && "${RV}" == "XPath set is empty" ]]; then
    RV="$(${DEBUG} defaults write "${LoginWindowPlistFQFN}" HiddenUsersList -array 2>&1)"; RC=${?}
    if ((RC != SUCCESS)); then
      echo -e "ERROR${DELIMITER}defaults write '${LoginWindowPlistFQFN}' HiddenUsersList -array failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
      EC=$((EC||RC))
    fi
  elif [[ ! (${RC} -eq 0 && ${RV} =~ "array") ]]; then
    echo -e "ERROR${DELIMITER}plutil -convert xml1 -o - '${LoginWindowPlistFQFN}' | xmllint -xpath '(//dict/key[text() = 'HiddenUsersList']/following-sibling::array)[1]' - failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi
  if ((RC == SUCCESS)); then
    for ((HiddenUsersIdx=0; HiddenUsersIdx < ${#HiddenUsers[@]}; HiddenUsersIdx++)); do
      HiddenUserPlistCounter=$({ plutil -convert xml1 -o - "${LoginWindowPlistFQFN}" |\
                                 xmllint -xpath "count((//dict/key[text() = 'HiddenUsersList']/following-sibling::array)[1]/string)" -; } 2>&1); RC=${?}
      if ((RC == SUCCESS)); then
        HiddenUserFound=0
        for ((HiddenUserPlistCounterIdx=1; HiddenUserPlistCounterIdx <= ${HiddenUserPlistCounter}; HiddenUserPlistCounterIdx++)); do
          HiddenUserPlistCounterText="$({ plutil -convert xml1 -o - "${LoginWindowPlistFQFN}" |\
                                          xmllint -xpath "(//dict/key[text() = 'HiddenUsersList']/following-sibling::array)[1]/string[${HiddenUserPlistCounterIdx}]/text()" -; } 2>&1)"; RC=${?}
          if [[ "${HiddenUsers[${HiddenUsersIdx}]}" == "${HiddenUserPlistCounterText}" ]]; then
            ((HiddenUserFound++))
          fi
        done
        if ((HiddenUserFound == 0)); then
          echo -n ", Hiding ${HiddenUsers[${HiddenUsersIdx}]} ... "
          RV="$(${DEBUG} defaults write "${LoginWindowPlistFQFN}" HiddenUsersList -array-add "${HiddenUsers[${HiddenUsersIdx}]}" 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}defaults write '${LoginWindowPlistFQFN}' HiddenUsersList -array-add '${HiddenUsers[${HiddenUsersIdx}]}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
        fi
      else
        echo -e "ERROR${DELIMITER}plutil -convert xml1 -o - '${LoginWindowPlistFQFN}' | xmllint -xpath 'count((//dict/key[text() = 'HiddenUsersList']/following-sibling::array)[1]/string)' - failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    done
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

disableBonjourAdvertisement() {
  local mDNSResponderPlist="${TargetVolume}${PrefsRPN}/com.apple.mDNSResponder.plist"
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Disable bonjour advertising ... "

  echo -n "Configure mDNSResponder ... "
  RV="$(defaults write "${TargetVolume}${PrefsRPN}/${mDNSResponderPlist}" NoMulticastAdvertisements -bool true 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}defaults write '/${PrefsRPN}/${mDNSResponderPlist}' NoMulticastAdvertisements -bool true failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

setTerminalSettings() {
  local TerminalPlistFQFN="${TargetVolume}${PrefsRPN}/com.apple.Terminal.plist"
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Set terminal settings ... "

  echo -n "Restore settings ... "
  RV="$(echo "${TerminalSettings}" |\
        base64 -D -o "${TerminalPlistFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok, "
  else
    echo -e "ERROR${DELIMITER}echo '${TerminalSettings}' | base64 -D -o '${TerminalPlistFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n "Restore permissions ... "
  RV="$(chmod 644 "${TerminalPlistFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}chmod 644 '${TerminalPlistFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

disableGateKeeper() {
  local SecurityPlistFQFN="${TargetVolume}${PrefsRPN}/com.apple.security.plist"
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Disable GateKeeper ... "
  echo -n "Disable GateKeeper ... "
  RV="$(spctl --master-disable 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok, "
  else
    echo -e "ERROR${DELIMITER}spctl --master-disable failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n "Disable rearm of GateKeeper ... "
  RV="$(defaults write "${SecurityPlistFQFN}" GKAutoRearm -bool false 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}defaults write '${SecurityPlistFQFN}' GKAutoRearm -bool false failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

disableLocationService() {
  local LocationdFQPN="${TargetVolume}var/db/locationd"
  local LocationdPlistFQFN=""
  local LaunchctlLocationdPlistFQFN="${TargetVolume}System/Library/LaunchDaemons/com.apple.locationd.plist"
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Disable location service ... "
  echo -n "Stop location daemon ... "
  RV="$(launchctl unload "${LaunchctlLocationdPlistFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok, "
  else
    echo -e "ERROR${DELIMITER}launchctl unload '${LaunchctlLocationdPlistFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi
  echo -n "Disable location daemon ... "
  case ${OsVersion[1]} in
    1[2-4])
      LocationdPlistFQFN="${LocationdFQPN}/${PrefsRPN}/ByHost/com.apple.locationd.plist"
      RV="$(defaults write "${LocationdPlistFQFN}" LocationServicesEnabled -int 0 2>&1)"; RC=${?}
      ;;
    11)
      LocationdPlistFQFN="${LocationdFQPN}/${PrefsRPN}/ByHost/com.apple.locationd.${HwUUID}.plist"
      RV="$(defaults write "${LocationdPlistFQFN}" LocationServicesEnabled -int 0 2>&1)"; RC=${?}
      ;;
  esac
  if ((RC == SUCCESS)); then
    echo -n "ok, "
  else
    echo -e "ERROR${DELIMITER}defaults write '${LocationdPlistFQFN}' LocationServicesEnabled -int 0 failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi
  echo -n "Set owner ... "
  RV="$(chown -R _locationd:_locationd "${LocationdFQPN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok, "
  else
    echo -e "ERROR${DELIMITER}chown -R _locationd:_locationd '${LocationdFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi
  echo -n "Start location daemon ... "
  RV="$(launchctl load "${LaunchctlLocationdPlistFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}launchctl load '${LocationdPlistFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

setSetupAssistantSettings() {
  local SettingFile=""
  local SettingName=""
  local SettingType=""
  local SettingValue=""
  local SettingsDescription=""
  local UserPreferencesFQPN=""
  local UserTemplate=""
  local User=""
  local -i Idx=0
  local -i RC=0
  local -ia RCs=()
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Set setup assistant settings for users"

  for User in "${LocalUsers[@]}"; do
    RV="$(dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID 2>&1)"; RC=${?}
    if ((RC == SUCCESS)); then
      eval $(echo "${RV}" |\
             awk -v PrefixOutput="${DsclPrefix}" '
               BEGIN {
                 NFSHomeDirectory=""
                 PrimaryGroupID=""
                 RealNameFound=0
                 RealName=""
                 UniqueID=""
                 }
               function getRealNameFromPos(Position) {
                 for(FieldNr=Position; FieldNr <= NF; FieldNr++) {
                   RealName = (RealName == "" ? "" : RealName " ") $FieldNr
                   }
                 }
               RealNameFound == 1 {
                 getRealNameFromPos(1)
                 RealNameFound=0
                 }
               $1 == "RealName:" {
                 if(NF > 1) {
                   getRealNameFromPos(2)
                   }
                 else {
                   RealNameFound=1
                   }
                 }
               $1 == "NFSHomeDirectory:" {
                 NFSHomeDirectory=$2
                 }
               $1 == "PrimaryGroupID:" {
                 PrimaryGroupID=$2
                 }
               $1 == "UniqueID:" {
                 UniqueID=$2
                 }
               END {
                 if (NFSHomeDirectory != "" && PrimaryGroupID != "" && RealName != "" && UniqueID != "") {
                   printf("declare -i %sPrimaryGroupID=%s; %sNFSHomeDirectory=%c%s%c; %sRealName=%c%s%c; declare -i %sUniqueID=%s", PrefixOutput, PrimaryGroupID, PrefixOutput, 34, NFSHomeDirectory, 34, PrefixOutput, 34, RealName, 34, PrefixOutput, UniqueID)
                   exit 0
                   }
                 else {
                   exit 1
                   }
                 }
           '); RC=${?}
      dsclNFSHomeDirectory="${dsclNFSHomeDirectory/%\//}"
      UserPreferencesFQPN="${dsclNFSHomeDirectory}/${PrefsRPN}"
      if ((RC == SUCCESS)) && [[ -n "${dsclUniqueID}" && -n "${dsclPrimaryGroupID}" ]]; then
        echo -n "Process ${User} ... "
        if [[ ! -d "${UserPreferencesFQPN}" ]]; then
          echo -n "Create '${UserPreferencesFQPN}' ... "
          RV="$(mkdir -p "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok, "
          else
            echo -e "ERROR${DELIMITER}mkdir -p '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
        fi

        RC=0
        for ((Idx=0; Idx < ${#SetupAssistantSettings[@]}; Idx++)); do
          while IFS="${DELIMITER}" read -r SettingFile SettingName SettingType SettingValue SettingsDescription; do
            SettingFile="${SettingFile/#~/${dsclNFSHomeDirectory}}"
            ((Idx > 0)) && echo -n ", "
            echo -n "${SettingsDescription:-${SettingName}}: "
            RV="$(defaults write "${SettingFile}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
            if ((RCs[${Idx}] == SUCCESS)); then
              RV="$(chown -R "${dsclUniqueID}:${dsclPrimaryGroupID}" "${SettingFile}" 2>&1)"; RCs[${Idx}]=${?}
              if ((RCs[${Idx}] == SUCCESS)); then
                echo -n "ok"
              else
                echo -e "ERROR${DELIMITER}chown -R '${dsclUniqueID}:${dsclPrimaryGroupID}' '${SettingFile}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
                RC=$((RC||RCs[${Idx}]))
              fi
            else
              echo -e "ERROR${DELIMITER}defaults write '${SettingFile}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
              RC=$((RC||RCs[${Idx}]))
            fi
          done <<<"${SetupAssistantSettings[${Idx}]}"
        done

        if [[ "${User}" == "${LoggedInUser}" ]]; then
          echo -n ", Kill preferences cache process ... "
          RV="$(pkill -0 -U ${dsclUniqueID} -f "^/usr/sbin/cfprefsd agent$" && \
                pkill -U ${dsclUniqueID} -f "^/usr/sbin/cfprefsd agent$" || \
                : 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}pkill -U ${dsclUniqueID} -f '^/usr/sbin/cfprefsd agent\$' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
        fi

        if ((RC == SUCCESS)); then
          echo -e "\nSUCCESS"
        fi
        EC=$((EC||RC))
      else
        echo -e "WARNING${DELIMITER}UniqueID (${dsclUniqueID}) and PrimaryGroupID (${dsclPrimaryGroupID}) from dscl are empty, maybe not a real user?"
      fi
    else
      if ((RC == 56)); then
        echo -e "WARNING${DELIMITER}${User} via dscl not found${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
      else
        echo -e "ERROR${DELIMITER}dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi
  done

  echo "INFO${DELIMITER}Set setup assistant settings for user templates"
  for UserTemplate in "${UserTemplateFQPN}"/*; do
    UserPreferencesFQPN="${UserTemplate}/${PrefsRPN}"
    echo -n "Process ${UserTemplate##*/} ... "
    if [[ ! -d "${UserPreferencesFQPN}" ]]; then
      echo -n "Create '${UserPreferencesFQPN}' ... "
      RV="$(mkdir -p "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
      if ((RC != SUCCESS)); then
        echo -e "ERROR${DELIMITER}mkdir -p '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi

    RC=0
    for ((Idx=0; Idx < ${#SetupAssistantSettings[@]}; Idx++)); do
      while IFS="${DELIMITER}" read -r SettingFile SettingName SettingType SettingValue SettingsDescription; do
        if [[ "${SettingFile:0:1}" == "~" ]]; then
          SettingFile="${SettingFile/#~/${UserTemplate}}"
          ((Idx > 0)) && echo -n ", "
          echo -n "${SettingsDescription:-${SettingName}}: "
          RV="$(defaults write "${UserPreferencesFQPN}/${SettingFile}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
          if ((RCs[${Idx}] == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}defaults write '${UserPreferencesFQPN}/${SettingFile}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
            RC=$((RC||RCs[${Idx}]))
          fi
        fi
      done <<<"${SetupAssistantSettings[${Idx}]}"
    done

    if ((RC == SUCCESS)); then
      echo -e "\nSUCCESS"
    fi
    EC=$((EC||RC))
  done

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi

  return ${EC}
}

setLoginWindowSettings() {
  local SettingFile=""
  local SettingName=""
  local SettingType=""
  local SettingValue=""
  local SettingsDescription=""
  local UserPreferencesFQPN=""
  local UserTemplate=""
  local User=""
  local -i Idx=0
  local -i RC=0
  local -ia RCs=()
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Set login window settings for users"

  for User in "${LocalUsers[@]}"; do
    RV="$(dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID 2>&1)"; RC=${?}
    if ((RC == SUCCESS)); then
      eval $(echo "${RV}" |\
             awk -v PrefixOutput="${DsclPrefix}" '
               BEGIN {
                 NFSHomeDirectory=""
                 PrimaryGroupID=""
                 RealNameFound=0
                 RealName=""
                 UniqueID=""
                 }
               function getRealNameFromPos(Position) {
                 for(FieldNr=Position; FieldNr <= NF; FieldNr++) {
                   RealName = (RealName == "" ? "" : RealName " ") $FieldNr
                   }
                 }
               RealNameFound == 1 {
                 getRealNameFromPos(1)
                 RealNameFound=0
                 }
               $1 == "RealName:" {
                 if(NF > 1) {
                   getRealNameFromPos(2)
                   }
                 else {
                   RealNameFound=1
                   }
                 }
               $1 == "NFSHomeDirectory:" {
                 NFSHomeDirectory=$2
                 }
               $1 == "PrimaryGroupID:" {
                 PrimaryGroupID=$2
                 }
               $1 == "UniqueID:" {
                 UniqueID=$2
                 }
               END {
                 if (NFSHomeDirectory != "" && PrimaryGroupID != "" && RealName != "" && UniqueID != "") {
                   printf("declare -i %sPrimaryGroupID=%s; %sNFSHomeDirectory=%c%s%c; %sRealName=%c%s%c; declare -i %sUniqueID=%s", PrefixOutput, PrimaryGroupID, PrefixOutput, 34, NFSHomeDirectory, 34, PrefixOutput, 34, RealName, 34, PrefixOutput, UniqueID)
                   exit 0
                   }
                 else {
                   exit 1
                   }
                 }
           '); RC=${?}
      dsclNFSHomeDirectory="${dsclNFSHomeDirectory/%\//}"
      UserPreferencesFQPN="${dsclNFSHomeDirectory}/${PrefsRPN}"
      if ((RC == SUCCESS)) && [[ -n "${dsclUniqueID}" && -n "${dsclPrimaryGroupID}" ]]; then
        echo -n "Process ${User} ... "
        if [[ ! -d "${UserPreferencesFQPN}" ]]; then
          echo -n "Create '${UserPreferencesFQPN}' ... "
          RV="$(mkdir -p "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok, "
          else
            echo -e "ERROR${DELIMITER}mkdir -p '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
        fi
        RC=0

        for ((Idx=0; Idx < ${#LoginWindowSettings[@]}; Idx++)); do
          while IFS="${DELIMITER}" read -r SettingFile SettingName SettingType SettingValue SettingsDescription; do
            SettingFile="${SettingFile/#~/${dsclNFSHomeDirectory}}"
            ((Idx > 0)) && echo -n ", "
            echo -n "${SettingsDescription:-${SettingName}}: "
            RV="$(defaults write "${SettingFile}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
            if ((RCs[${Idx}] == SUCCESS)); then
              RV="$(chown -R "${dsclUniqueID}:${dsclPrimaryGroupID}" "${SettingFile}" 2>&1)"; RCs[${Idx}]=${?}
              if ((RCs[${Idx}] == SUCCESS)); then
                echo -n "ok"
              else
                echo -e "ERROR${DELIMITER}chown -R '${dsclUniqueID}:${dsclPrimaryGroupID}' '${SettingFile}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
                RC=$((RC||RCs[${Idx}]))
              fi
            else
              echo -e "ERROR${DELIMITER}defaults write '${SettingFile}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
              RC=$((RC||RCs[${Idx}]))
            fi
          done <<<"${LoginWindowSettings[${Idx}]}"
        done

        if [[ "${User}" == "${LoggedInUser}" ]]; then
          echo -n ", Kill preferences cache process ... "
          RV="$(pkill -0 -U ${dsclUniqueID} -f "^/usr/sbin/cfprefsd agent$" && \
                pkill -U ${dsclUniqueID} -f "^/usr/sbin/cfprefsd agent$" || \
                : 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}pkill -U ${dsclUniqueID} -f '^/usr/sbin/cfprefsd agent\$' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
          echo -n ", Kill SystemUIServer process ... "
          RV="$(pkill -0 -f "^/System/Library/CoreServices/SystemUIServer.app/Contents/MacOS/SystemUIServer$" && \
                pkill -f "^/System/Library/CoreServices/SystemUIServer.app/Contents/MacOS/SystemUIServer$" || \
                : 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}pkill -f '^/System/Library/CoreServices/SystemUIServer.app/Contents/MacOS/SystemUIServer\$' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
        fi

        if ((RC == SUCCESS)); then
          echo -e "\nSUCCESS"
        fi
        EC=$((EC||RC))
      else
        echo -e "WARNING${DELIMITER}UniqueID (${dsclUniqueID}) and PrimaryGroupID (${dsclPrimaryGroupID}) from dscl are empty, maybe not a real user?"
      fi
    else
      if ((RC == 56)); then
        echo -e "WARNING${DELIMITER}${User} via dscl not found${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
      else
        echo -e "ERROR${DELIMITER}dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi
  done

  echo "INFO${DELIMITER}Set login window settings for user templates"
  for UserTemplate in "${UserTemplateFQPN}"/*; do
    UserPreferencesFQPN="${UserTemplate}/${PrefsRPN}"
    echo -n "Process ${UserTemplate##*/} ... "
    if [[ ! -d "${UserPreferencesFQPN}" ]]; then
      echo -n "Create '${UserPreferencesFQPN}' ... "
      RV="$(mkdir -p "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
      if ((RC != SUCCESS)); then
        echo -e "ERROR${DELIMITER}mkdir -p '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi

    RC=0
    for ((Idx=0; Idx < ${#LoginWindowSettings[@]}; Idx++)); do
      while IFS="${DELIMITER}" read -r SettingFile SettingName SettingType SettingValue SettingsDescription; do
        if [[ "${SettingFile:0:1}" == "~" ]]; then
          SettingFile="${SettingFile/#~/${UserTemplate}}"
          ((Idx > 0)) && echo -n ", "
          echo -n "${SettingsDescription:-${SettingName}}: "
          RV="$(defaults write "${UserPreferencesFQPN}/${SettingFile}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
          if ((RCs[${Idx}] == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}defaults write '${UserPreferencesFQPN}/${SettingFile}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
            RC=$((RC||RCs[${Idx}]))
          fi
        fi
      done <<<"${LoginWindowSettings[${Idx}]}"
    done

  done

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi

  return ${EC}
}

: <<'EOF'
setUserSettings() {
  local SettingName=""
  local SettingType=""
  local SettingValue=""
  local UserPreferencesFQPN=""
  local SetupAssistantFN="com.apple.SetupAssistant.plist"
  local SetupAssistantFQFN=""
  local loginwindowFN="loginwindow.plist"
  local loginwindowFQFN=""
  local UserTemplate=""
  local User=""
  local AppleSetupDoneFQFN="${TargetVolume}var/db/.AppleSetupDone"
  local -i Idx=0
  local -i RC=0
  local -ia RCs=()
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Setting local user settings"

  for User in "${LocalUsers[@]}"; do
    RV="$(dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID 2>&1)"; RC=${?}
    if ((RC == SUCCESS)); then
      eval $(echo "${RV}" |\
             awk -v PrefixOutput="${DsclPrefix}" '
               BEGIN {
                 NFSHomeDirectory=""
                 PrimaryGroupID=""
                 RealNameFound=0
                 RealName=""
                 UniqueID=""
                 }
               function getRealNameFromPos(Position) {
                 for(FieldNr=Position; FieldNr <= NF; FieldNr++) {
                   RealName = (RealName == "" ? "" : RealName " ") $FieldNr
                   }
                 }
               RealNameFound == 1 {
                 getRealNameFromPos(1)
                 RealNameFound=0
                 }
               $1 == "RealName:" {
                 if(NF > 1) {
                   getRealNameFromPos(2)
                   }
                 else {
                   RealNameFound=1
                   }
                 }
               $1 == "NFSHomeDirectory:" {
                 NFSHomeDirectory=$2
                 }
               $1 == "PrimaryGroupID:" {
                 PrimaryGroupID=$2
                 }
               $1 == "UniqueID:" {
                 UniqueID=$2
                 }
               END {
                 if (NFSHomeDirectory != "" && PrimaryGroupID != "" && RealName != "" && UniqueID != "") {
                   printf("declare -i %sPrimaryGroupID=%s; %sNFSHomeDirectory=%c%s%c; %sRealName=%c%s%c; declare -i %sUniqueID=%s", PrefixOutput, PrimaryGroupID, PrefixOutput, 34, NFSHomeDirectory, 34, PrefixOutput, 34, RealName, 34, PrefixOutput, UniqueID)
                   exit 0
                   }
                 else {
                   exit 1
                   }
                 }
           '); RC=${?}
      UserPreferencesFQPN="${dsclNFSHomeDirectory:+${dsclNFSHomeDirectory/%\//}/}${PrefsRPN}"
      SetupAssistantFQFN="${UserPreferencesFQPN}/${SetupAssistantFN}"
      loginwindowFQFN="${UserPreferencesFQPN}/${loginwindowFN}"
      if ((RC == SUCCESS)) && [[ -n "${dsclUniqueID}" && -n "${dsclPrimaryGroupID}" ]]; then
        echo -n "Process ${User} ... "
        if [[ ! -d "${UserPreferencesFQPN}" ]]; then
          echo -n "Create '${UserPreferencesFQPN}' ... "
          RV="$(mkdir -p "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok, "
          else
            echo -e "ERROR${DELIMITER}mkdir -p '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
        fi
        RC=0
        echo -en "\nConfigure ${SetupAssistantFQFN} ... "
        for ((Idx=0; Idx < ${#SetupAssistantSettings[@]}; Idx++)); do
          while IFS="${DELIMITER}" read SettingName SettingType SettingValue; do
            ((Idx > 0)) && echo -n ", "
            echo -n "Write ${SettingName} ... "
            RV="$(defaults write "${SetupAssistantFQFN}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
            if ((RCs[${Idx}] == SUCCESS)); then
              echo -n "ok"
            else
              echo -e "ERROR${DELIMITER}defaults write '${SetupAssistantFQFN}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
              RC=$((RC||RCs[${Idx}]))
            fi
          done <<<"${SetupAssistantSettings[${Idx}]}"
        done
        echo -en "\nConfigure ${loginwindowFQFN} ... "
        for ((Idx=0; Idx < ${#loginwindowSettings[@]}; Idx++)); do
          while IFS="${DELIMITER}" read SettingName SettingType SettingValue; do
            ((Idx > 0)) && echo -n ", "
            echo -n "Write ${SettingName} ... "
            RV="$(defaults write "${loginwindowFQFN}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
            if ((RCs[${Idx}] == SUCCESS)); then
              echo -n "ok"
            else
              echo -e "ERROR${DELIMITER}defaults write '${loginwindowFQFN}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
              RC=$((RC||RCs[${Idx}]))
            fi
          done <<<"${loginwindowSettings[${Idx}]}"
        done
        EC=$((EC||RC))
        echo -n "Set owner ... "
        RV="$(chown -R "${dsclUniqueID}:${dsclPrimaryGroupID}" "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
        if ((RC == SUCCESS)); then
          echo -n "ok, "
        else
          echo -e "ERROR${DELIMITER}chown -R '${dsclUniqueID}:${dsclPrimaryGroupID}' '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
          EC=$((EC||RC))
        fi
        if ((RC == SUCCESS)); then
          echo -e "\nSUCCESS"
        fi
        EC=$((EC||RC))
      else
        echo -e "WARNING${DELIMITER}UniqueID (${dsclUniqueID}) and PrimaryGroupID (${dsclPrimaryGroupID}) from dscl are empty, maybe not a real user?"
      fi
    else
      if ((RC == 56)); then
        echo -e "WARNING${DELIMITER}${User} via dscl not found${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
      else
        echo -e "ERROR${DELIMITER}dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi
  done

  echo "INFO${DELIMITER}Setting user template settings"
  for UserTemplate in "${UserTemplateFQPN}"/*; do
    UserPreferencesFQPN="${UserTemplate}/${PrefsRPN}"
    SetupAssistantFQFN="${UserPreferencesFQPN}/${SetupAssistantFN}"
    loginwindowFQFN="${UserPreferencesFQPN}/${loginwindowFN}"
    echo -n "Process ${UserTemplate##*/} ... "
    if [[ ! -d "${UserPreferencesFQPN}" ]]; then
      echo -n "Create '${UserPreferencesFQPN}' ... "
      RV="$(mkdir -p "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
      if ((RC != SUCCESS)); then
        echo -e "ERROR${DELIMITER}mkdir -p '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi
    RC=0
    echo -en "\nConfigure ${SetupAssistantFQFN} ... "
    for ((Idx=0; Idx < ${#SetupAssistantSettings[@]}; Idx++)); do
      while IFS="${DELIMITER}" read SettingName SettingType SettingValue; do
        ((Idx > 0)) && echo -n ", "
        echo -n "Write ${SettingName} ... "
        RV="$(defaults write "${SetupAssistantFQFN}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
        if ((RCs[${Idx}] == SUCCESS)); then
          echo -n "ok"
        else
          echo -e "ERROR${DELIMITER}defaults write '${SetupAssistantFQFN}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
          RC=$((RC||RCs[${Idx}]))
        fi
      done <<<"${SetupAssistantSettings[${Idx}]}"
    done
    echo -en "\nConfigure ${loginwindowFQFN} ... "
    for ((Idx=0; Idx < ${#loginwindowSettings[@]}; Idx++)); do
      while IFS="${DELIMITER}" read SettingName SettingType SettingValue; do
        ((Idx > 0)) && echo -n ", "
        echo -n "Write ${SettingName} ... "
        RV="$(defaults write "${loginwindowFQFN}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
        if ((RCs[${Idx}] == SUCCESS)); then
          echo -n "ok"
        else
          echo -e "ERROR${DELIMITER}defaults write '${loginwindowFQFN}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
          RC=$((RC||RCs[${Idx}]))
        fi
      done <<<"${loginwindowSettings[${Idx}]}"
    done
    if ((RC == SUCCESS)); then
      echo -e "\nSUCCESS"
    fi
    EC=$((EC||RC))
  done

  echo -n "Create '${AppleSetupDoneFQFN}' ... "
  RV="$(touch "${AppleSetupDoneFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}touch '${AppleSetupDoneFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi

  return ${EC}
}
EOF

disableAutomaticUpdates() {
  :
}

setMunkiSettings() {
  local ManagedInstallsPlistFQFN="${TargetVolume}${PrefsRPN}/ManagedInstalls.plist"
  local MunkiStartupFileFQFN="${TargetVolume}Users/Shared/.com.googlecode.munki.checkandinstallatstartup"
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Set munki settings ... "
  echo -n "Follow redirects ... "
  RV="$(defaults write FollowHTTPRedirects "${ManagedInstallsPlistFQFN}" -string "all" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}defaults write FollowHTTPRedirects '${ManagedInstallsPlistFQFN}' -string 'all' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n "Touch '${MunkiStartupFileFQFN}' ... "
  RV="$(touch "${MunkiStartupFileFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n ", ok"
  else
    echo -e "ERROR${DELIMITER}touch '${MunkiStartupFileFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

enableAssistiveDevices() {
  local AccessibilityAPIEnabledFQFN="${TargetVolume}private/var/db/.AccessibilityAPIEnabled"
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Enable assistive devices"
  echo -n "Create '${AccessibilityAPIEnabledFQFN}' ... "
  RV="$(touch "${AccessibilityAPIEnabledFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}touch '${AccessibilityAPIEnabledFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  echo -n "Set permissions ... "
  RV="$(chmod 444 "${AccessibilityAPIEnabledFQFN}" 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}chmod 444 '${AccessibilityAPIEnabledFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

setAuthorizationDBSettings() {
: <<'EORESET'
cat >/private/var/tmp/system.preferences.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>allow-root</key>
  <true/>
  <key>authenticate-user</key>
  <true/>
  <key>class</key>
  <string>user</string>
  <key>comment</key>
  <string>Checked by the Admin framework when making changes to certain System Preferences.</string>
  <key>created</key>
  <real>553605114.68980598</real>
  <key>group</key>
  <string>admin</string>
  <key>modified</key>
  <real>553605114.68980598</real>
  <key>session-owner</key>
  <false/>
  <key>shared</key>
  <true/>
  <key>timeout</key>
  <integer>2147483647</integer>
  <key>tries</key>
  <integer>10000</integer>
  <key>version</key>
  <integer>0</integer>
</dict>
</plist>
EOF

cat >/private/var/tmp/system.preferences.datetime.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>allow-root</key>
  <true/>
  <key>authenticate-user</key>
  <true/>
  <key>class</key>
  <string>user</string>
  <key>comment</key>
  <string>Checked by the Admin framework when making changes to the Date &amp; Time preference pane.</string>
  <key>created</key>
  <real>553605114.68980598</real>
  <key>group</key>
  <string>admin</string>
  <key>modified</key>
  <real>553605114.68980598</real>
  <key>session-owner</key>
  <false/>
  <key>shared</key>
  <false/>
  <key>timeout</key>
  <integer>2147483647</integer>
  <key>tries</key>
  <integer>10000</integer>
  <key>version</key>
  <integer>1</integer>
</dict>
</plist>
EOF

cat >/private/var/tmp/system.preferences.network.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>allow-root</key>
  <true/>
  <key>authenticate-user</key>
  <true/>
  <key>class</key>
  <string>user</string>
  <key>comment</key>
  <string>Checked by the Admin framework when making changes to the Network preference pane.</string>
  <key>created</key>
  <real>553605114.68980598</real>
  <key>group</key>
  <string>admin</string>
  <key>modified</key>
  <real>553605114.68980598</real>
  <key>session-owner</key>
  <false/>
  <key>shared</key>
  <true/>
  <key>timeout</key>
  <integer>2147483647</integer>
  <key>tries</key>
  <integer>10000</integer>
  <key>version</key>
  <integer>0</integer>
  </dict>
</plist>
EOF

cat >/private/var/tmp/system.preferences.printing.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>allow-root</key>
  <true/>
  <key>authenticate-user</key>
  <true/>
  <key>class</key>
  <string>user</string>
  <key>comment</key>
  <string>Checked by the Admin framework when making changes to the Printing preference pane.</string>
  <key>created</key>
  <real>553605114.68980598</real>
  <key>group</key>
  <string>admin</string>
  <key>modified</key>
  <real>553605114.68980598</real>
  <key>session-owner</key>
  <false/>
  <key>shared</key>
  <true/>
  <key>timeout</key>
  <integer>2147483647</integer>
  <key>tries</key>
  <integer>10000</integer>
  <key>version</key>
  <integer>0</integer>
</dict>
</plist>
EOF

cat >/private/var/tmp/system.print.operator.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>allow-root</key>
  <true/>
  <key>authenticate-user</key>
  <true/>
  <key>class</key>
  <string>user</string>
  <key>created</key>
  <real>553605114.68980598</real>
  <key>group</key>
  <string>_lpoperator</string>
  <key>modified</key>
  <real>553605114.68980598</real>
  <key>session-owner</key>
  <false/>
  <key>shared</key>
  <true/>
  <key>timeout</key>
  <integer>2147483647</integer>
  <key>tries</key>
  <integer>10000</integer>
  <key>version</key>
  <integer>0</integer>
</dict>
</plist>
EOF

cat >/private/var/tmp/system.print.admin.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>class</key>
  <string>rule</string>
  <key>created</key>
  <real>553605114.68980598</real>
  <key>modified</key>
  <real>553605114.68980598</real>
  <key>rule</key>
  <array>
    <string>root-or-lpadmin</string>
  </array>
  <key>version</key>
  <integer>0</integer>
</dict>
</plist>
EOF

cat >/private/var/tmp/system.services.systemconfiguration.network.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>allow-root</key>
  <true/>
  <key>authenticate-user</key>
  <true/>
  <key>class</key>
  <string>user</string>
  <key>comment</key>
  <string>For making change to network configuration via System Configuration.</string>
  <key>created</key>
  <real>553605114.68980598</real>
  <key>entitled-group</key>
  <true/>
  <key>group</key>
  <string>admin</string>
  <key>modified</key>
  <real>553605114.68980598</real>
  <key>session-owner</key>
  <false/>
  <key>shared</key>
  <false/>
  <key>timeout</key>
  <integer>2147483647</integer>
  <key>tries</key>
  <integer>10000</integer>
  <key>version</key>
  <integer>1</integer>
  <key>vpn-entitled-group</key>
  <true/>
</dict>
</plist>
EOF
EORESET

  local SettingName=""
  local SettingPermission=""
  local PreferenceText=""
  local -i Idx=0
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Set authorizationdb settings ... "

  IFS= read -d '' PreferenceText <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>allow-root</key>
  <true/>
  <key>authenticate-user</key>
  <true/>
  <key>class</key>
  <string>user</string>
  <key>group</key>
  <string>admin</string>
  <key>session-owner</key>
  <true/>
  <key>shared</key>
  <true/>
</dict>
</plist>
EOXML

  for ((Idx=0; Idx < ${#authorizationdbSettings[@]}; Idx++)); do
    while IFS="${DELIMITER}" read SettingName SettingPermission; do
      ((Idx > 0)) && echo -n ", "
      echo -n "Write ${SettingName} ... "
      #RV="$(security authorizationdb write "${SettingName}" "${SettingPermission}" 2>&1)"; RCs[${Idx}]=${?}
      RV="$(security authorizationdb write "${SettingName}" 2>&1 <<<"${PreferenceText}")"; RCs[${Idx}]=${?}
      if [[ ${RCs[${Idx}]} -eq ${SUCCESS} && "${RV}" == "YES (0)" ]]; then
        echo -n "ok"
      else
        echo -e "ERROR${DELIMITER}security authorizationdb write '${SettingName}' '${SettingPermission}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        RC=$((RC||RCs[${Idx}]))
      fi
    done <<<"${authorizationdbSettings[${Idx}]}"
  done
  EC=$((EC||RC))

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

setGlobalUserSettings() {
  local SettingFileFQPN=""
  local SettingFile=""
  local SettingName=""
  local SettingType=""
  local SettingValue=""
  local SettingsDescription=""
  local UserPreferencesFQPN=""
  local UserTemplate=""
  local User=""
  local -i Idx=0
  local -i RC=0
  local -ia RCs=()
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Set global settings for users"

  for User in "${LocalUsers[@]}"; do
    RV="$(dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID 2>&1)"; RC=${?}
    if ((RC == SUCCESS)); then
      eval $(echo "${RV}" |\
             awk -v PrefixOutput="${DsclPrefix}" '
               BEGIN {
                 NFSHomeDirectory=""
                 PrimaryGroupID=""
                 RealNameFound=0
                 RealName=""
                 UniqueID=""
                 }
               function getRealNameFromPos(Position) {
                 for(FieldNr=Position; FieldNr <= NF; FieldNr++) {
                   RealName = (RealName == "" ? "" : RealName " ") $FieldNr
                   }
                 }
               RealNameFound == 1 {
                 getRealNameFromPos(1)
                 RealNameFound=0
                 }
               $1 == "RealName:" {
                 if(NF > 1) {
                   getRealNameFromPos(2)
                   }
                 else {
                   RealNameFound=1
                   }
                 }
               $1 == "NFSHomeDirectory:" {
                 NFSHomeDirectory=$2
                 }
               $1 == "PrimaryGroupID:" {
                 PrimaryGroupID=$2
                 }
               $1 == "UniqueID:" {
                 UniqueID=$2
                 }
               END {
                 if (NFSHomeDirectory != "" && PrimaryGroupID != "" && RealName != "" && UniqueID != "") {
                   printf("declare -i %sPrimaryGroupID=%s; %sNFSHomeDirectory=%c%s%c; %sRealName=%c%s%c; declare -i %sUniqueID=%s", PrefixOutput, PrimaryGroupID, PrefixOutput, 34, NFSHomeDirectory, 34, PrefixOutput, 34, RealName, 34, PrefixOutput, UniqueID)
                   exit 0
                   }
                 else {
                   exit 1
                   }
                 }
           '); RC=${?}
      dsclNFSHomeDirectory="${dsclNFSHomeDirectory/%\//}"
      if ((RC == SUCCESS)) && [[ -n "${dsclUniqueID}" && -n "${dsclPrimaryGroupID}" ]]; then
        echo -n "Process ${User} ... "

        if [[ "${User}" == "${LoggedInUser}" ]]; then
          RC=0
          echo -n ", Kill system preferences app ... "
          RV="$(pkill -0 -U ${dsclUniqueID} -f "^/Applications/System Preferences.app/Contents/MacOS/System Preferences$" && \
                pkill -U ${dsclUniqueID} -f "^/Applications/System Preferences.app/Contents/MacOS/System Preferences$" || \
                : 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}pkill -U ${dsclUniqueID} -f '^/Applications/System Preferences.app/Contents/MacOS/System Preferences\$' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
          RC=0
          echo -n ", Kill preferences cache process ... "
          RV="$(pkill -0 -U ${dsclUniqueID} -f "^/usr/sbin/cfprefsd agent$" && \
                pkill -U ${dsclUniqueID} -f "^/usr/sbin/cfprefsd agent$" || \
                : 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}pkill -U ${dsclUniqueID} -f '^/usr/sbin/cfprefsd agent\$' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
        fi

        RC=0
        for ((Idx=0; Idx < ${#GlobalUserPreferencesSettings[@]}; Idx++)); do
          while IFS="${DELIMITER}" read -r SettingFile SettingName SettingType SettingValue SettingsDescription; do
            SettingFile="${SettingFile/#~/${dsclNFSHomeDirectory}}"
            SettingFileFQPN="${SettingFile%/*}"
            if [[ ! -d "${SettingFileFQPN}" ]]; then
              echo -n "Create '${SettingFileFQPN}' ... "
              RV="$(mkdir -p "${SettingFileFQPN}" 2>&1)"; RC=${?}
              if ((RC == SUCCESS)); then
                echo -n "ok, "
              else
                echo -e "ERROR${DELIMITER}mkdir -p '${SettingFileFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
                EC=$((EC||RC))
              fi
            fi
            # ((Idx > 0)) && echo -n ", "
            echo -n "${SettingsDescription:-${SettingName}}: "
            RV="$(defaults write "${SettingFile}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
            if ((RCs[Idx] == SUCCESS)); then
              RV="$(chown -R "${dsclUniqueID}:${dsclPrimaryGroupID}" "${SettingFile}" 2>&1)"; RCs[${Idx}]=${?}
              if ((RCs[Idx] == SUCCESS)); then
                echo -n "ok, "
              else
                echo -e "ERROR${DELIMITER}chown -R '${dsclUniqueID}:${dsclPrimaryGroupID}' '${SettingFile}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
                RC=$((RC||RCs[Idx]))
              fi
            else
              echo -e "ERROR${DELIMITER}defaults write '${SettingFile}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
              RC=$((RC||RCs[Idx]))
            fi
          done <<<"${GlobalUserPreferencesSettings[${Idx}]}"
        done

        if ((RC == SUCCESS)); then
          echo -e "\nSUCCESS"
        fi
        EC=$((EC||RC))
      else
        echo -e "WARNING${DELIMITER}UniqueID (${dsclUniqueID}) and PrimaryGroupID (${dsclPrimaryGroupID}) from dscl are empty, maybe not a real user?"
      fi
    else
      if ((RC == 56)); then
        echo -e "WARNING${DELIMITER}${User} via dscl not found${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
      else
        echo -e "ERROR${DELIMITER}dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi
  done

  echo "INFO${DELIMITER}Set global settings for user templates"
  for UserTemplate in "${UserTemplateFQPN}"/*; do
    UserPreferencesFQPN="${UserTemplate}/${PrefsRPN}"
    echo -n "Process ${UserTemplate##*/} ... "
    if [[ ! -d "${UserPreferencesFQPN}" ]]; then
      echo -n "Create '${UserPreferencesFQPN}' ... "
      RV="$(mkdir -p "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
      if ((RC != SUCCESS)); then
        echo -e "ERROR${DELIMITER}mkdir -p '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi

    RC=0
    for ((Idx=0; Idx < ${#GlobalUserPreferencesSettings[@]}; Idx++)); do
      while IFS="${DELIMITER}" read -r SettingFile SettingName SettingType SettingValue SettingsDescription; do
        ((Idx > 0)) && echo -n ", "
        echo -n "${SettingsDescription:-${SettingName}}: "
        RV="$(defaults write "${UserPreferencesFQPN}/${SettingFile}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
        if ((RCs[Idx] == SUCCESS)); then
          echo -n "ok"
        else
          echo -e "ERROR${DELIMITER}defaults write '${UserPreferencesFQPN}/${SettingFile}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
          RC=$((RC||RCs[Idx]))
        fi
      done <<<"${GlobalUserPreferencesSettings[${Idx}]}"
    done

    if ((RC == SUCCESS)); then
      echo -e "\nSUCCESS"
    fi
    EC=$((EC||RC))
  done

  return ${EC}
}

setScreenSettings() {
  local UserPreferencesFQPN=""
  local UserTemplate=""
  local User=""
  local -i Idx=0
  local -i RC=0
  local -ia RCs
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Configure screen settings for users"

  for User in "${LocalUsers[@]}"; do
    RV="$(dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID 2>&1)"; RC=${?}
    if ((RC == SUCCESS)); then
      eval $(echo "${RV}" |\
             awk -v PrefixOutput="${DsclPrefix}" '
               BEGIN {
                 NFSHomeDirectory=""
                 PrimaryGroupID=""
                 RealNameFound=0
                 RealName=""
                 UniqueID=""
                 }
               function getRealNameFromPos(Position) {
                 for(FieldNr=Position; FieldNr <= NF; FieldNr++) {
                   RealName = (RealName == "" ? "" : RealName " ") $FieldNr
                   }
                 }
               RealNameFound == 1 {
                 getRealNameFromPos(1)
                 RealNameFound=0
                 }
               $1 == "RealName:" {
                 if(NF > 1) {
                   getRealNameFromPos(2)
                   }
                 else {
                   RealNameFound=1
                   }
                 }
               $1 == "NFSHomeDirectory:" {
                 NFSHomeDirectory=$2
                 }
               $1 == "PrimaryGroupID:" {
                 PrimaryGroupID=$2
                 }
               $1 == "UniqueID:" {
                 UniqueID=$2
                 }
               END {
                 if (NFSHomeDirectory != "" && PrimaryGroupID != "" && RealName != "" && UniqueID != "") {
                   printf("declare -i %sPrimaryGroupID=%s; %sNFSHomeDirectory=%c%s%c; %sRealName=%c%s%c; declare -i %sUniqueID=%s", PrefixOutput, PrimaryGroupID, PrefixOutput, 34, NFSHomeDirectory, 34, PrefixOutput, 34, RealName, 34, PrefixOutput, UniqueID)
                   exit 0
                   }
                 else {
                   exit 1
                   }
                 }
           '); RC=${?}
      dsclNFSHomeDirectory="${dsclNFSHomeDirectory/%\//}"
      if ((RC == SUCCESS)) && [[ -n "${dsclUniqueID}" && -n "${dsclPrimaryGroupID}" ]]; then
        echo -n "Process ${User} ... "

        if [[ "${User}" == "${LoggedInUser}" ]]; then
          echo -n ", Kill preferences cache process ... "
          RV="$(pkill -0 -U ${dsclUniqueID} -f "^/usr/sbin/cfprefsd agent$" && \
                pkill -U ${dsclUniqueID} -f "^/usr/sbin/cfprefsd agent$" || \
                : 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}pkill -U ${dsclUniqueID} -f '^/usr/sbin/cfprefsd agent\$' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
          echo -n ", Kill SystemUIServer process ... "
          RV="$(pkill -0 -f "^/System/Library/CoreServices/SystemUIServer.app/Contents/MacOS/SystemUIServer$" && \
                pkill -f "^/System/Library/CoreServices/SystemUIServer.app/Contents/MacOS/SystemUIServer$" || \
                : 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}pkill -f '^/System/Library/CoreServices/SystemUIServer.app/Contents/MacOS/SystemUIServer\$' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi
        fi

        RC=0
        for ((Idx=0; Idx < ${#ScreenSettings[@]}; Idx++)); do
          while IFS="${DELIMITER}" read -r SettingFile SettingName SettingType SettingValue SettingsDescription; do
            SettingFile="${SettingFile/#~/${dsclNFSHomeDirectory}}"
            SettingFileFQPN="${SettingFile%/*}"
            if [[ ! -d "${SettingFileFQPN}" ]]; then
              echo -n "Create '${SettingFileFQPN}' ... "
              RV="$(mkdir -p "${SettingFileFQPN}" 2>&1)"; RC=${?}
              if ((RC == SUCCESS)); then
                echo -n "ok, "
              else
                echo -e "ERROR${DELIMITER}mkdir -p '${SettingFileFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
                EC=$((EC||RC))
              fi
            fi
            # ((Idx > 0)) && echo -n ", "
            echo -n "${SettingsDescription:-${SettingName}}: "
            RV="$(defaults write "${SettingFile}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
            if ((RCs[Idx] == SUCCESS)); then
              RV="$(chown -R "${dsclUniqueID}:${dsclPrimaryGroupID}" "${SettingFile}" 2>&1)"; RCs[${Idx}]=${?}
              if ((RCs[Idx] == SUCCESS)); then
                echo -n "ok, "
              else
                echo -e "ERROR${DELIMITER}chown -R '${dsclUniqueID}:${dsclPrimaryGroupID}' '${SettingFile}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
                RC=$((RC||RCs[Idx]))
              fi
            else
              echo -e "ERROR${DELIMITER}defaults write '${SettingFile}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RCs[${Idx}]}${DELIMITER}RV=${RV}"
              RC=$((RC||RCs[Idx]))
            fi
          done <<<"${ScreenSettings[${Idx}]}"
        done

        if ((RC == SUCCESS)); then
          echo -e "\nSUCCESS"
        fi
        EC=$((EC||RC))
      else
        echo -e "WARNING${DELIMITER}UniqueID (${dsclUniqueID}) and PrimaryGroupID (${dsclPrimaryGroupID}) from dscl are empty, maybe not a real user?"
      fi
    else
      if ((RC == 56)); then
        echo -e "WARNING${DELIMITER}${User} via dscl not found${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
      else
        echo -e "ERROR${DELIMITER}dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi
  done

  echo "INFO${DELIMITER}Configure screen settings for user templates"
  for UserTemplate in "${UserTemplateFQPN}"/*; do
    UserPreferencesFQPN="${UserTemplate}/${PrefsRPN}"
    echo -n "Process ${UserTemplate##*/} ... "
    if [[ ! -d "${UserPreferencesFQPN}" ]]; then
      echo -n "Create '${UserPreferencesFQPN}' ... "
      RV="$(mkdir -p "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
      if ((RC != SUCCESS)); then
        echo -e "ERROR${DELIMITER}mkdir -p '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi
    RC=0

    for ((Idx=0; Idx < ${#ScreenSettings[@]}; Idx++)); do
      while IFS="${DELIMITER}" read -r SettingFile SettingName SettingType SettingValue SettingsDescription; do
        ((Idx > 0)) && echo -n ", "
        echo -n "${SettingsDescription}: "
        RV="$(defaults write "${UserPreferencesFQPN}/${SettingFile}" "${SettingName}" "${SettingType}" "${SettingValue}" 2>&1)"; RCs[${Idx}]=${?}
        if ((RCs[${Idx}] == SUCCESS)); then
          echo -n "ok"
        else
          echo -e "ERROR${DELIMITER}defaults write '${UserPreferencesFQPN}/${SettingFile}' '${SettingName}' '${SettingType}' '${SettingValue}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
          RC=$((RC||RCs[${Idx}]))
        fi
      done <<<"${ScreenSettings[${Idx}]}"
    done

    if ((RC == SUCCESS)); then
      echo -e "\nSUCCESS"
    fi
    EC=$((EC||RC))
  done
  return ${EC}
}

disableWhatsNewNotification() {
  local Touristd="com.apple.touristd"
  local TouristdPlistFN="${Touristd}.plist"
  local ASTouristdPlistFQFN=""
  local PTouristdPlistFQFN=""
  local UserPreferencesFQPN=""
  local UserTemplate=""
  local User=""
  local -i Tours=0
  local SeedDate="$(date -j -r ${StartDateInSeconds} -v '-7d' +'%Y-%m-%dT%TZ')"
  local Id=""
  local TouristdCmd="${TargetVolume}System/Library/PrivateFrameworks/Tourist.framework/Versions/A/Resources/touristd"
  local -i WatchedPID=0
  local -i WatcherPID=0
  local -i Idx=0
  local -i RC=0
  local -ia RCs
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Disable What's New notification for users"

  if ((OsVersion[1] < 13)); then
    echo "Nothing to do since OS Version < 10.13"
    return ${EC}
  fi

  for User in "${LocalUsers[@]}"; do
    RV="$(dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID 2>&1)"; RC=${?}
    if ((RC == SUCCESS)); then
      eval $(echo "${RV}" |\
             awk -v PrefixOutput="${DsclPrefix}" '
               BEGIN {
                 NFSHomeDirectory=""
                 PrimaryGroupID=""
                 RealNameFound=0
                 RealName=""
                 UniqueID=""
                 }
               function getRealNameFromPos(Position) {
                 for(FieldNr=Position; FieldNr <= NF; FieldNr++) {
                   RealName = (RealName == "" ? "" : RealName " ") $FieldNr
                   }
                 }
               RealNameFound == 1 {
                 getRealNameFromPos(1)
                 RealNameFound=0
                 }
               $1 == "RealName:" {
                 if(NF > 1) {
                   getRealNameFromPos(2)
                   }
                 else {
                   RealNameFound=1
                   }
                 }
               $1 == "NFSHomeDirectory:" {
                 NFSHomeDirectory=$2
                 }
               $1 == "PrimaryGroupID:" {
                 PrimaryGroupID=$2
                 }
               $1 == "UniqueID:" {
                 UniqueID=$2
                 }
               END {
                 if (NFSHomeDirectory != "" && PrimaryGroupID != "" && RealName != "" && UniqueID != "") {
                   printf("declare -i %sPrimaryGroupID=%s; %sNFSHomeDirectory=%c%s%c; %sRealName=%c%s%c; declare -i %sUniqueID=%s", PrefixOutput, PrimaryGroupID, PrefixOutput, 34, NFSHomeDirectory, 34, PrefixOutput, 34, RealName, 34, PrefixOutput, UniqueID)
                   exit 0
                   }
                 else {
                   exit 1
                   }
                 }
           '); RC=${?}
      UserPreferencesFQPN="${dsclNFSHomeDirectory:+${dsclNFSHomeDirectory/%\//}/}${PrefsRPN}"
      ASTouristdPlistFQFN="${dsclNFSHomeDirectory:+${dsclNFSHomeDirectory/%\//}/}${AppSuRPN}/${Touristd}/${TouristdPlistFN}"
      PTouristdPlistFQFN="${UserPreferencesFQPN}/${TouristdPlistFN}"
      if ((RC == SUCCESS)) && [[ -n "${dsclUniqueID}" && -n "${dsclPrimaryGroupID}" ]]; then
        if [[ -f "${ASTouristdPlistFQFN}" ]]; then
          echo -n "Process ${User} ... "
          if [[ ! -d "${UserPreferencesFQPN}" ]]; then
            echo -n "Create '${UserPreferencesFQPN}' ... "
            RV="$(mkdir -p "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
            if ((RC == SUCCESS)); then
              echo -n "ok, "
            else
              echo -e "ERROR${DELIMITER}mkdir -p '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
              EC=$((EC||RC))
            fi
          fi

          declare -i Tours=10#$(xmllint -xpath "count(//string[preceding-sibling::*[1][self::key = 'hasBeenViewed']])" "${ASTouristdPlistFQFN}")
          if ((Tours > 0)); then
            echo -n "Kill preference caching process ... "
            pkill -U ${dsclUniqueID} -f "^/usr/sbin/cfprefsd agent$"
            # reset notifications
            echo -n "Reset notifications ... "
            ( su - ${User} -c "${TouristdCmd} --reset notify" ) >/dev/null 2>&1 & WatchedPID=${!}
            ( sleep 10 && pkill -HUP ${WatchedPID} && pkill -0 ${WatchedPID} && sleep 1 && pkill -KILL ${WatchedPID}) >/dev/null 2>&1 & WatcherPID=${!}
            if wait ${WatchedPID} >/dev/null 2>&1; then
              pkill -HUP -P ${WatcherPID}
              wait ${WatcherPID}
            fi
            echo -n "Dismiss actual notifications ... "
            # dismiss actual showing messages in a subshell
            (set +m
             for ((Idx=0; Idx < Tours; Idx++)); do
               su - ${User} -c "${TouristdCmd} --menu=${Idx} dismiss" >/dev/null 2>&1 &
             done
            )
            echo -n "Set '${ASTouristdPlistFQFN}' ... "
            # set hasBeenViewed to 1
            for ((Idx=1; Idx <= Tours; Idx++)); do
              RV="$(xmllint --shell "${ASTouristdPlistFQFN}" 2>&1 <<-EOXML
                setns plist=http://www.apple.com/DTDs/PropertyList-1.0.dtd
                cd (//string[preceding-sibling::*[1][self::key = 'hasBeenViewed']])[${Idx}]
                set 1
                save
                quit
              EOXML
              )"; RC=${?}
            done
            # Id = keys of string with value hasBeenViewed from Application Support/com.apple.touristd/com.apple.touristd.plist
            # set seed-notificationDueDate-${Id} and seed-viewed-${Id} to 7 days before
            echo -n "Kill preference caching process ... "
            pkill -U ${dsclUniqueID} -f "^/usr/sbin/cfprefsd agent$"
            echo -n "Set '${PTouristdPlistFQFN}' ... "
            while IFS= read -r Id; do
              RV="$(defaults write "${PTouristdPlistFQFN}" "seed-notificationDueDate-${Id}" -date "${SeedDate}" 2>&1)"; RC=${?}
              if ((RC != SUCCESS)); then
                echo -e "ERROR${DELIMITER}defaults write '${PTouristdPlistFQFN}' 'seed-notificationDueDate-${Id}' -date '${SeedDate}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
                EC=$((EC||RC))
              fi
              RV="$(defaults write "${PTouristdPlistFQFN}" "seed-numNotifications-${Id}" -string "1" 2>&1)"; RC=${?}
              if ((RC != SUCCESS)); then
                echo -e "ERROR${DELIMITER}defaults write '${PTouristdPlistFQFN}' 'seed-numNotifications-${Id}' -date '${SeedDate}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
                EC=$((EC||RC))
              fi
              RV="$(defaults write "${PTouristdPlistFQFN}" "seed-viewed-${Id}" -date "${SeedDate}" 2>&1)"; RC=${?}
              if ((RC != SUCCESS)); then
                echo -e "ERROR${DELIMITER}defaults write '${PTouristdPlistFQFN}' 'seed-viewed-${Id}' -date '${SeedDate}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
                EC=$((EC||RC))
              fi
            done < <(xmllint -xpath "//key[following-sibling::*[1][self::dict[key = 'hasBeenViewed']]]" "${ASTouristdPlistFQFN}" |\
                     sed -E $'s|</key>$||g;s|</key>|\\\n|g;s|<key>||g')
            if [[ ! -f "${TempFQPN}/${TouristdPlistFN}" ]]; then
              echo -n "Copy '${PTouristdPlistFQFN}' to '${TempFQPN}' ... "
              RV="$(cp "${PTouristdPlistFQFN}" "${TempFQPN}/${TouristdPlistFN}" 2>&1)"; RC=${?}
              if ((RC != SUCCESS)); then
                echo -e "ERROR${DELIMITER}cp '${PTouristdPlistFQFN}' '${TempFQPN}/${TouristdPlistFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
                EC=$((EC||RC))
              fi
            fi
          fi
          RV="$(chown -R "${dsclUniqueID}:${dsclPrimaryGroupID}" "${PTouristdPlistFQFN}" 2>&1)"; RC=${?}
          if ((RC == SUCCESS)); then
            echo -n "ok"
          else
            echo -e "ERROR${DELIMITER}chown -R '${dsclUniqueID}:${dsclPrimaryGroupID}' '${PTouristdPlistFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
            EC=$((EC||RC))
          fi

          if ((RC == SUCCESS)); then
            echo -e "\nSUCCESS"
          fi
          EC=$((EC||RC))
        else
          echo -e "WARNING${DELIMITER}'${ASTouristdPlistFQFN}' missing"
        fi
      else
        echo -e "WARNING${DELIMITER}UniqueID (${dsclUniqueID}) and PrimaryGroupID (${dsclPrimaryGroupID}) from dscl are empty, maybe not a real user?"
      fi
    else
      if ((RC == 56)); then
        echo -e "WARNING${DELIMITER}${User} via dscl not found${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
      else
        echo -e "ERROR${DELIMITER}dscl . read ${UsersFQPN}/${User} NFSHomeDirectory PrimaryGroupID RealName UniqueID failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
        EC=$((EC||RC))
      fi
    fi
  done

  if ((RC == SUCCESS)); then
    echo "INFO${DELIMITER}Disable What's New notification for user templates"
    for UserTemplate in "${UserTemplateFQPN}"/*; do
      UserPreferencesFQPN="${UserTemplate}/${PrefsRPN}"
      PTouristdPlistFQFN="${UserPreferencesFQPN}/${TouristdPlistFN}"
      echo -n "Process ${UserTemplate##*/} ... "
      if [[ ! -d "${UserPreferencesFQPN}" ]]; then
        echo -n "Create '${UserPreferencesFQPN}' ... "
        RV="$(mkdir -p "${UserPreferencesFQPN}" 2>&1)"; RC=${?}
        if ((RC != SUCCESS)); then
          echo -e "ERROR${DELIMITER}mkdir -p '${UserPreferencesFQPN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
          EC=$((EC||RC))
        fi
      fi
      RC=0

      if [[ -f "${TempFQPN}/${TouristdPlistFN}" && ! -f "${PTouristdPlistFQFN}" ]]; then
        RV="$(cp "${TempFQPN}/${TouristdPlistFN}" "${PTouristdPlistFQFN}" 2>&1)"; RC=${?}
        if ((RC != SUCCESS)); then
          echo -e "ERROR${DELIMITER}cp '${TempFQPN}/${TouristdPlistFN}' '${PTouristdPlistFQFN}' failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
          EC=$((EC||RC))
        fi
      fi
    done
  fi
  rm -f "${TempFQPN}/${TouristdPlistFN}" >/dev/null 2>&1

  if ((RC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  EC=$((EC||RC))

  return ${EC}
}

func() {
  local -i RC=0
  local -i EC=0
  local RV=""

  echo "INFO${DELIMITER}Describe function"
  echo -n "Do some action ... "
  RV="$(: 2>&1)"; RC=${?}
  if ((RC == SUCCESS)); then
    echo -n "ok"
  else
    echo -e "ERROR${DELIMITER}: failed${DELIMITER}RC=${RC}${DELIMITER}RV=${RV}"
    EC=$((EC||RC))
  fi

  if ((EC == SUCCESS)); then
    echo -e "\nSUCCESS"
  fi
  return ${EC}
}

# main
# kill system preferences app
pkill -0 -f "^/Applications/System Preferences.app/Contents/MacOS/System Preferences$" && \
pkill -f "^/Applications/System Preferences.app/Contents/MacOS/System Preferences$" && \
{ sleep 1 && \
pkill -0 -f "^/Applications/System Preferences.app/Contents/MacOS/System Preferences$" && \
pkill -KILL -f "^/Applications/System Preferences.app/Contents/MacOS/System Preferences$"; } ||\
pkill -KILL -f "^/Applications/System Preferences.app/Contents/MacOS/System Preferences$"

: <<EOF
disableIPV6 # ok

disableNetworkServices # ok

setTCPSettings

setTimeServer

setAllLocalNames

setPowerSaveSettings

setPrinterSettings

enableARD

enableSSH

disableBonjourAdvertisement

setTerminalSettings

disableGateKeeper

disableLocationService

setUserSettings

setAuthorizationDBSettings

enableAssistiveDevices

setGlobalUserSettings

setScreenSettings

setLoginWindowSettings

setSetupAssistantSettings

setMunkiSettings

disableWhatsNewNotification

setAppleLoginWindowSettings # ok
EOF

disableNetworkServices
