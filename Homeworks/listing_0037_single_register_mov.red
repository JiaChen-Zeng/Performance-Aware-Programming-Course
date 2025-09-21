Red []

debug?: false

; for debug
print-bin: func [
    bin [binary!] return: [unset!]
    /local cur [binary!]
] [
    if not debug? [exit]

    parse bin [some [copy cur skip (prin append enbase/base cur 2 space) copy cur skip (print enbase/base cur 2)]]
    #(unset)
]

dprint: does []
if debug? [dprint: :print]

bin: read/binary %../computer_enhance/perfaware/part1/listing_0037_single_register_mov

b00'100010: to-integer 2#{00 100010}
b00'111111: to-integer 2#{00 111111}
b000000'10: to-integer 2#{000000 10}
b000000'01: to-integer 2#{000000 01}

b11'000'000: to-integer 2#{11 000 000}
b00'111'000: to-integer 2#{00 111 000}
b00'000'111: to-integer 2#{00 000 111}

inst-row-length: 8
inst-reg: [
    "al" "cl" "dl" "bl" "ah" "ch" "dh" "bh"
    "ax" "cx" "dx" "bx" "sp" "bp" "si" "di"
]

decode-exe: does [
    cur: bin
    print "bits 16" ; not detecting wrong format
    while [not tail? cur] [
        byte1: cur/1
        case [
            complement (byte1 >> 2 xor b00'100010) = b00'111111 [
                direction: make logic! byte1 and b000000'10
                width: make logic! byte1 and b000000'01
                dprint ['direction direction 'width width]

                byte2: cur/2
                mode: byte2 and b11'000'000 >> 6 ; now only b11
                reg: byte2 and b00'111'000 >> 3
                r_m: byte2 and b00'000'111
                dprint ['mode mode 'reg reg 'r_m r_m]

                inst-reg-start: (make integer! width) * inst-row-length
                print rejoin ["mov " inst-reg/(inst-reg-start + r_m + 1) ", " inst-reg/(inst-reg-start + reg + 1)]
            ]
            true [dprint ["Unrecognized: " enbase/base to-binary byte1 2]]
        ]
        cur: skip cur 2
    ]
]

decode-exe
dprint "====================="
print-bin bin
