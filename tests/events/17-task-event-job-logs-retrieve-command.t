#!/bin/bash
# THIS FILE IS PART OF THE CYLC SUITE ENGINE.
# Copyright (C) 2008-2017 NIWA
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#-------------------------------------------------------------------------------
# Test remote job logs retrieval custom command, requires compatible version of
# cylc on remote job host.
CYLC_TEST_IS_GENERIC=false
. "$(dirname "$0")/test_header"
HOST=$(cylc get-global-config -i '[test battery]remote host' 2>'/dev/null')
if [[ -z "${HOST}" ]]; then
    skip_all '"[test battery]remote host": not defined'
fi
set_test_number 3

create_test_globalrc "" "
[hosts]
    [[${HOST}]]
        retrieve job logs = True
        retrieve job logs command = my-rsync"
OPT_SET='-s GLOBALCFG=True'

install_suite "${TEST_NAME_BASE}" "${TEST_NAME_BASE}"

mkdir -p "${TEST_DIR}/${SUITE_NAME}/bin"
cat >"${TEST_DIR}/${SUITE_NAME}/bin/my-rsync" <<'__BASH__'
#!/bin/bash
set -eu
echo "$@" >>"${CYLC_SUITE_LOG_DIR}/my-rsync.log"
exec rsync -a "$@"
__BASH__
chmod +x "${TEST_DIR}/${SUITE_NAME}/bin/my-rsync"

run_ok "${TEST_NAME_BASE}-validate" \
    cylc validate ${OPT_SET} -s "HOST=${HOST}" "${SUITE_NAME}"
suite_run_ok "${TEST_NAME_BASE}-run" \
    cylc run --reference-test --debug --no-detach ${OPT_SET} -s "HOST=${HOST}" \
    "${SUITE_NAME}"

SUITE_LOG_D="$(cylc get-global-config --print-run-dir)/${SUITE_NAME}/log"
sed 's/^.* -v //' "${SUITE_LOG_D}/suite/my-rsync.log" >'my-rsync.log.edited'

OPT_HEAD='--include=/1 --include=/1/t1'
OPT_TAIL='--exclude=/**'
ARGS="${HOST}:\$HOME/cylc-run/${SUITE_NAME}/log/job/ ${SUITE_LOG_D}/job/"
cmp_ok 'my-rsync.log.edited' <<__LOG__
${OPT_HEAD} --include=/1/t1/01 --include=/1/t1/01/** ${OPT_TAIL} ${ARGS}
${OPT_HEAD} --include=/1/t1/02 --include=/1/t1/02/** ${OPT_TAIL} ${ARGS}
${OPT_HEAD} --include=/1/t1/03 --include=/1/t1/03/** ${OPT_TAIL} ${ARGS}
__LOG__

purge_suite_remote "${HOST}" "${SUITE_NAME}"
purge_suite "${SUITE_NAME}"
exit
