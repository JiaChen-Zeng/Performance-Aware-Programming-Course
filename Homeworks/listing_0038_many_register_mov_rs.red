Red []

#system [
    debug?: false
]

get-debug?: routine [return: [logic!]] [debug?]
debug?: get-debug?

; for debug
print-bin: func [
    bin [binary!] return: [unset!]
    /local cur [binary!]
] [
    if not debug? [exit]

    parse bin [some [copy cur skip (prin append enbase/base cur 2 space) copy cur skip (print enbase/base cur 2)]]
]

; debug-print: does [] ; doesn't work somehow
; if debug? [debug-print: :print]

; ==============================================

#system [
    b00'100010: #"^(22)"
    b00'111111: #"^(3F)"
    b000000'10: #"^(02)"
    b000000'01: #"^(01)"

    b11'000'000: #"^(C0)"
    b00'111'000: #"^(38)"
    b00'000'111: #"^(07)"

    inst-row-length: 8
    inst-reg: [
        "al" "cl" "dl" "bl" "ah" "ch" "dh" "bh"
        "ax" "cx" "dx" "bx" "sp" "bp" "si" "di"
    ]
]

decode-exe: routine [
    bin [binary!] out-asm [string!]

    /local ser [series!] cur [byte-ptr!]
    byte1 [byte!] byte2 [byte!]
    direction [logic!] width [logic!] mode [byte!] reg [byte!] r_m [byte!]
    inst-reg-start [integer!] inst-reg-index [integer!]
] [
    string/concatenate-literal out-asm "bits 16^/"

    ser: GET_BUFFER(bin)
    cur: as byte-ptr! ser/offset
    while [cur < as byte-ptr! ser/tail] [
        byte1: cur/1
        case [
            not (byte1 >> 2 xor b00'100010) = b00'111111 [
                direction: as-logic byte1 and b000000'10
                width: as-logic byte1 and b000000'01
                if debug? [print-line ["direction " direction " width " width]]

                byte2: cur/2
                mode: byte2 and b11'000'000 >> 6 ; now only b11
                reg: byte2 and b00'111'000 >> 3
                r_m: byte2 and b00'000'111
                ; print-line ["mode " string/to-hex as-integer mode true " reg " string/to-hex as-integer reg true " r_m " string/to-hex as-integer r_m true] ; hex doesn't work 
                if debug? [print-line ["mode " as-integer mode " reg " as-integer reg " r_m " as-integer r_m]]

                inst-reg-start: (as-integer width) * inst-row-length
                string/concatenate-literal out-asm "mov "
                inst-reg-index: inst-reg-start + r_m + 1
                string/concatenate-literal out-asm as-c-string inst-reg/inst-reg-index
                string/concatenate-literal out-asm ", "
                inst-reg-index: inst-reg-start + reg + 1
                string/concatenate-literal out-asm as-c-string inst-reg/inst-reg-index
                string/append-char GET_BUFFER(out-asm) as-integer lf
            ]
            true [print-line ["Unrecognized: " as-integer byte1] exit]
        ]
        cur: cur + 2
    ]
]

; ====================================================

bin: read/binary %../computer_enhance/perfaware/part1/listing_0038_many_register_mov
asm: ""
decode-exe bin asm
print asm

if debug? [print "====================="]
print-bin bin
