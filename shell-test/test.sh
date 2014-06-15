#!/bin/bash

source ~/.bashrc
./easy-update.sh # ensures the latest lib/ is used

# usage of shunit2 : 

# write a function whose name start with 'test'.
# then it is recognized as a test.

# To run all tests, simply run this test script.

testExit(){

    cl <<EOF
(exit)
EOF
}

testPrint(){
    # use ${_ASSERT_EQUALS_} instead of assertEquals
    ${_ASSERT_EQUALS_} ':A' $(cl -e "(print :a) (exit)")
    ${_ASSERT_EQUALS_} '1' $(cl -e "(print 1) (exit)")
    ${_ASSERT_EQUALS_} '"hi"' $(cl -e '(prin1 "hi") (exit)')
}

testLoad(){
    cl -f "scripts/load.lisp" -e "(exit)" # dummy script
}

testReturnCode(){
    cl -e "(cim:exit)"
    ${_ASSERT_EQUALS_} 0 $?
    cl -e "(cim:exit 1)"
    ${_ASSERT_EQUALS_} 1 $?
}

testCIMASDF(){
    cl -C $(readlink -f ../)/ -e '(print *default-pathname-defaults*)'
    cl -C $(readlink -f ../)/ shell-test/cim-asdf-test.lisp
}

# loading shunit2.
. loader