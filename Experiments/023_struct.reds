Red/System []

a!: alias struct! [
    i1 [integer!]
    i2 [integer!]
]

a: declare a!
a/i1: 123
a2: declare a!
a2/i2: a/i1 + 234

probe a2/i2

; ==================================

funca: func [return: [a!] /local r] [
    r: declare a!
    r/i1: 111
    r/i2: 222
    return r
]

a3: funca
probe a3/i1 + a3/i2

; ==================================

d1!: alias struct! [
    i1 [integer!]
    i2 [integer!]
    i3 [integer!]
]

d2!: alias struct! [
    i1 [integer!]
    s [c-string!]
]

d: declare d1!
d2: as d2! d
probe d2/i1
; probe d2/s ; access violation
; d2: as d1! as int-pointer! d2 ; Compilation Error: attempt to change type of variable: d2 

; d2: as d1! as pointer! d2 ; Red/System Compiler Internal Error: Script Error : find-aliased expected type argument of type: word 
