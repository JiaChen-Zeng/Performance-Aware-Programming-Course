Red []

code: read/lines %../computer_enhance/perfaware/part1/listing_0037_single_register_mov.asm

; code: skip code 18
; print code

reg-index: charset "abcd"
reg-type:  charset "xlh"
register: [ reg-index reg-type ] 

foreach line code [
    if line/1 == #";" [ continue ]

    reg1: none
    reg2: none
    parse line [
        any space
        "mov"
        some space
        copy reg1 register
        any space "," any space
        copy reg2 register
        any space
    ]
    if all [reg1 reg2] [ print [reg1 reg2] ]
]
