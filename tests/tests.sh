#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

source /home/wodby/.shrc
expected_prompt='\u@'"$(hostname)"':\w $ '
if [[ "${PS1}" != "${expected_prompt}" ]]; then
    echo "Unexpected shell prompt: ${PS1}"
    exit 1
fi

dotnet --list-runtimes | grep -q "Microsoft.AspNetCore.App ${DOTNET_VERSION} "

ssh sshd cat /home/wodby/.ssh/authorized_keys | grep -q admin@example.com

curl -s nginx | grep -q ".NET test app"
curl -s localhost:8080 | grep -q ".NET test app"
test "$(curl -s localhost:8080/version)" = "${DOTNET_VERSION}"
test "$(curl -s localhost:8080/culture)" = ","
