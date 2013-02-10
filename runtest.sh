#!/bin/bash

if [ -n "$1" ]; then
    input="$1"
else
    input="hello.spk"
fi
spkDir=$( dirname "$input" )
spkFile=$( basename "$input" )
class=${spkFile%.spk}
inFile=$class.in
output=$class.java
compare=$class.expected
testNum=${class#test_}

echo -n "$testNum: "
./spc "$input" >/dev/null
if [ $? = 0 ]; then
    cd "$spkDir"
	if [ -f "$inFile" ]; then
	    e=$( java $class < "$inFile" )
	else
    	e=$( java $class )
	fi
    if echo "$e" | cmp -s "$compare" -; then
	    echo "OK"
	else
	    echo "FAIL"
		echo "Expected:"
		cat "$compare"
		echo "Got:"
		echo "$e"
	fi
else
	echo "FAIL"
fi
