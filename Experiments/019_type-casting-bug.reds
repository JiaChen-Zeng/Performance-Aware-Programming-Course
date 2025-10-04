Red/System []

castb: func [pos [integer!] return: [logic!]] [return as-logic (#"^(01)" << pos)]
; b: as-integer (as-logic (#"^(01)" << 3)) ; Compiler internal error

b2: castb 3
print-line b2 ; true
print-line as-integer b2 ; 4206600 - Wrong

b3: as-logic (#"^(01)" << 3)
print-line as-integer b3 ; 1
