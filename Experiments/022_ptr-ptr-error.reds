Red/System []

decode-funcs: as ptr-ptr! allocate 100

t: decode-funcs + 0
t/value: null ; ok

b: #"^(00)"
i: as-integer b
t: decode-funcs + i
t/value: null ; ok

t: decode-funcs + (as-integer #"^(00)") ; ok
t/value: null

t: decode-funcs + (as-integer b)
t/value: null ; Runtime Error 1: access violation

; decode-funcs/136/value: 1 ; Internal Error: Script Error : Expected one of: word! - not: integer! 
; decode-funcs/136/value: t: 1 ; Internal Error: Script Error : comp-call expected name argument of type: word 
