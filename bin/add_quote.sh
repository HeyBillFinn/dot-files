#! /bin/bash
copyq clipboard | sed 's/^/> /' | xargs -0 copyq copy > /dev/null
