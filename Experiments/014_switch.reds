Red/System []

i1: as-integer #"^(01)"
i2: as-integer #"^(02)"

; doesn't work. Only literal allowed. but macro is ok
switch #"^(01)" [
    i1 [print-line 1]
    i2 [print-line 2]
]

; doesn't work
; b1: #"^(01)"
; b2: #"^(02)"

; switch #"^(01)" [
;     b1 [print-line 1]
;     b2 [print-line 2]
; ]
