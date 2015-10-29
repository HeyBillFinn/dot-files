#!/usr/bin/python
import subprocess
import re

proc = subprocess.Popen(['heroku', 'addons'], stdout=subprocess.PIPE)
addons_output = proc.stdout.read()
addon_data = [{"app": b[0],
                "addon": b[1],
                "plan": b[2],
                "price": b[3]}
                for b in [a.split() for a in map(str.strip, addons_output.split('\n'))
                        if a != '' and not re.search('^Owning App', a)
                        and not re.search(u'\xe2\x94\x80', a)]]
for addon in [addon for addon in addon_data if addon["price"] != 'free']:
    print((subprocess
                .Popen(['heroku', 'addons:info', addon["addon"]], stdout=subprocess.PIPE)
                .stdout
                .read()))
