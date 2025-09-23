Red []

rs-func: routine [] [
    print-line "here is rs"
]

rs-func

my-string: "123"

append-my-string: func [str-to-append [string!]] [ append my-string str-to-append ]
; append-my-string " 234"
my-print: func [n [integer!]] [print n]
#system [
    c-string: " 345"
    new-string: string/load c-string length? c-string UTF-8
    #call [append-my-string new-string]
    ; #call [my-print 123123 my-print 234234] ; my-print 234234 doesn't get called
    ; #call [my-print 234234]
]

print my-string
