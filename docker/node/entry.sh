#!/bin/bash

PATH="${PATH:-/bin}:/usr/bin"
export PATH

set -euo pipefail
IFS=$'\n\t'

network="$(cat /etc/btcb-network)"
case "${network}" in
        live|'')
                network='live'
                dirSuffix=''
                ;;
        beta)
                dirSuffix='Beta'
                ;;
        test)
                dirSuffix='Test'
                ;;
esac

btcbdir="${HOME}/Btcb${dirSuffix}"
dbFile="${btcbdir}/data.ldb"
mkdir -p "${btcbdir}"
if [ ! -f "${btcbdir}/config.json" ]; then
        echo "Config File not found, adding default."
        cp "/usr/share/btcb/config/${network}.json" "${btcbdir}/config.json"
fi

pid=''
firstTimeComplete=''
while true; do
	if [ -n "${firstTimeComplete}" ]; then
		sleep 10
	fi
	firstTimeComplete='true'

	if [ -f "${dbFile}" ]; then
		dbFileSize="$(stat -c %s "${dbFile}" 2>/dev/null)"
		if [ "${dbFileSize}" -gt $[1024 * 1024 * 1024 * 20] ]; then
			echo "ERROR: Database size grew above 20GB (size = ${dbFileSize})" >&2

			while [ -n "${pid}" ]; do
				kill "${pid}" >/dev/null 2>/dev/null || :
				if ! kill -0 "${pid}" >/dev/null 2>/dev/null; then
					pid=''
				fi
			done

			btcb_node --vacuum
		fi
	fi

	if [ -n "${pid}" ]; then
		if ! kill -0 "${pid}" >/dev/null 2>/dev/null; then
			pid=''
		fi
	fi

	if [ -z "${pid}" ]; then
		btcb_node --daemon &
		pid="$!"
	fi
done
