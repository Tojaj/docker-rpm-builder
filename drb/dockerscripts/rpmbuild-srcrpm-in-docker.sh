#!/bin/bash
set -e

EXIT_STATUS="FAIL"
CURRENT_SCRIPT="$(basename $0)"

. /dockerscripts/functions.sh

setup_cmd_log

log "Starting"

[ -z "${SRCRPM}" ] && { echo "Missing SRCRPM"; /bin/false; }
[ -z "${RPMBUILD_OPTIONS}" ] && { echo "No rpmbuild options were set"; }

verify_environment_prereq
set_variables_from_environment

trap finish EXIT

TOMAP_DIR="${SRPMS_DIR}"
map_uid_gid_to_existing_users

log "Now downloading build dependencies, could take a while..."
yum makecache
# we don't check the gpg signature at this time, we don't really care;
# if the signature check fails it will fail later.
yum-builddep -y --nogpgcheck "${SRPMS_DIR}/${SRCRPM}"
log "Download of build dependencies succeeded"

setup_user_macros

log "Now executing rpmbuild; this could take a while..."
exitcode=0
rpmbuild_out="$(rpmbuild --rebuild ${RPMBUILD_EXTRA_OPTIONS} ${RPMBUILD_OPTIONS} "${SRPMS_DIR}/${SRCRPM}" 2>&1)" || { exitcode="$?" ; /bin/true ; }
if [ "${exitcode}" -ne 0 ]; then
        if [ "bashonfail" == "${BASH_ON_FAIL}" ]; then
            # if the build is interactive, we can see what's printed in the current log, no need to reprint.
            log "Build failed, spawning a shell. The build will terminate after such shell is closed."
            /bin/bash
        else
            log "rpmbuild command failed:output is: -->\n${rpmbuild_out}\nrpmbuild command output end\n\n."
        fi
    exit ${exitcode}
fi
log "rpmbuild succeeded"

if [ -r "/private.key" ]
then
    log "RPM signature enabled"
    setup_rpm_signing_system
	sign_rpmbuild_output_files
	log "RPM signature succeeded"
else
    log "RPM signature was not requested, output RPMs won't be signed"
fi

EXIT_STATUS="SUCCESS"
