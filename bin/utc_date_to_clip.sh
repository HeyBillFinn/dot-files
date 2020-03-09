#! /bin/bash
date -u -I'date' | tr -d '\n' | xargs -0 copyq copy > /dev/null
