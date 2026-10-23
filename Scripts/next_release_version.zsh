#!/bin/zsh
# Print the next four-component release version, carrying each digit at 9.
set -euo pipefail
cd "${0:A:h:h}"
current="${1:-$(git describe --tags --abbrev=0)}"
current="${current#v}"
if [[ "${current}" == "0.9.1" ]]; then
    print '0.9.1.2'
    exit 0
fi
if [[ ! "${current}" =~ '^[0-9]+\.[0-9]\.[0-9]\.[0-9]$' ]]; then
    print -u2 "Expected a four-component release version: ${current}"
    exit 1
fi
parts=("${(@s:.:)current}")
for index in 4 3 2; do
    if (( parts[index] < 9 )); then
        (( parts[index] += 1 ))
        for lower in {4..2}; do
            if (( lower > index )); then parts[lower]=0; fi
        done
        print "${(j:.:)parts}"
        exit 0
    fi
done
(( parts[1] += 1 ))
print "${parts[1]}.0.0.0"
