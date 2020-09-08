#!/bin/bash
set -eo pipefail
IFS=$'\n\t'
set -x

source /assets/bin/entrypoint.functions

if [[ "${GENERATE_TEMPLATES}" = "true" ]]; then
    process_templates
fi

## set correct php.ini
if [[ "${ENVIRONMENT}" =~ ^(dev|ci|)$ ]]; then
    cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini
else
    cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini
fi

if [ "${LOCALDOMAIN}" != ""  ]; then echo "search ${LOCALDOMAIN}" >> /etc/resolv.conf; fi

exec "$@"