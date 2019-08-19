#! /bin/bash
copyq clipboard | sed '${/^$/d;}' | sed 's/^/> /' | xargs -0 copyq copy > /dev/null
