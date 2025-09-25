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

    parse bin [some [copy cur skip (print enbase/base cur 2)]]
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

    b0000'1011: #"^(0B)"

    inst-reg: [
        "al" "cl" "dl" "bl" "ah" "ch" "dh" "bh"
        "ax" "cx" "dx" "bx" "sp" "bp" "si" "di"
    ]
    inst-row-length: (size? inst-reg) / 2

    inst-mem: [
        "bx + si" "bx + di" "bp + si" "bp + di" "si" "di" "bp" "bx"
    ]
]

decode-exe: routine [
    bin [binary!] out-asm [string!]

    /local ser [series!] cur [byte-ptr!]
    byte1 [byte!] byte2 [byte!]
    direction [logic!] width [logic!] mode [byte!] reg [byte!] r_m [byte!]
    index [integer!] mem [integer!]
    output-str [red-string!] output-cstr [c-string!] output-cstr2 [c-string!]
] [
    string/concatenate-literal out-asm "bits 16^/"

    ser: GET_BUFFER(bin)
    cur: as byte-ptr! ser/offset
    while [cur < as byte-ptr! ser/tail] [
        byte1: cur/1
        case [
            byte1 >>> 2 xor b00'100010 = #"^(00)" [
                output-str: string/rs-make-at stack/push* 20

                ; Extract byte1
                direction: as-logic byte1 and b000000'10
                width: as-logic byte1 and b000000'01
                if debug? [print-line ["direction " direction " width " width]]

                ; Extract byte2
                byte2: cur/2
                mode: byte2 and b11'000'000 >>> 6
                reg: byte2 and b00'111'000 >>> 3
                r_m: byte2 and b00'000'111
                if debug? [print-line ["mode " as-integer mode " reg " as-integer reg " r_m " as-integer r_m]]
                ; print-line ["mode " string/to-hex as-integer mode true " reg " string/to-hex as-integer reg true " r_m " string/to-hex as-integer r_m true] ; hex doesn't work 
                cur: cur + 2

                ; Decode right
                index: (as-integer width) * inst-row-length + reg + 1
                output-cstr: as-c-string inst-reg/index

                ; Decode 
                switch mode [
                    #"^(03)" [
                        index: (as-integer width) * inst-row-length + r_m + 1
                        string/concatenate-literal output-str as-c-string inst-reg/index
                    ]
                    #"^(00)" [
                        either r_m <> #"^(06)" [
                            either r_m < #"^(04)" [
                                string/append-char GET_BUFFER(output-str) as-integer #"["
                                index: as-integer r_m + 1
                                string/concatenate-literal output-str as-c-string inst-mem/index
                                string/append-char GET_BUFFER(output-str) as-integer #"]"
                            ] [
                                index: as-integer r_m + 1
                                string/concatenate-literal output-str as-c-string inst-mem/index
                            ]
                        ] [ ; Direct address
                            string/concatenate-literal output-str integer/form-signed (as-integer cur/1) + ((as-integer cur/2) << 8)
                            cur: cur + 2
                        ]
                    ]
                    #"^(01)" [
                        string/append-char GET_BUFFER(output-str) as-integer #"["
                        index: as-integer r_m + 1
                        string/concatenate-literal output-str as-c-string inst-mem/index

                        mem: as-integer cur/1
                        if mem <> 0 [
                            string/concatenate-literal output-str " + "
                            string/concatenate-literal output-str integer/form-signed mem
                        ]
                        string/append-char GET_BUFFER(output-str) as-integer #"]"
                        cur: cur + 1
                    ]
                    #"^(02)" [
                        string/append-char GET_BUFFER(output-str) as-integer #"["
                        index: as-integer r_m + 1
                        string/concatenate-literal output-str as-c-string inst-mem/index

                        mem: (as-integer cur/1) + ((as-integer cur/2) << 8)
                        if mem <> 0 [
                            string/concatenate-literal output-str " + "
                            string/concatenate-literal output-str integer/form-signed mem
                        ]
                        string/append-char GET_BUFFER(output-str) as-integer #"]"
                        cur: cur + 2
                    ]
                ]

                ; Output assembly
                string/concatenate-literal out-asm "mov "
                ; Decode direction
                either direction [ ; swap
                    string/concatenate-literal out-asm output-cstr
                    string/concatenate-literal out-asm ", "
                    string/concatenate out-asm output-str -1 0 yes no
                ] [ ; normal
                    string/concatenate out-asm output-str -1 0 yes no
                    string/concatenate-literal out-asm ", "
                    string/concatenate-literal out-asm output-cstr
                ]
                string/append-char GET_BUFFER(out-asm) as-integer lf
            ]
            byte1 >>> 4 xor b0000'1011 = #"^(00)" [
                ; Extract byte1
                width: as-logic byte1 and #"^(08)"
                reg: byte1 and #"^(07)"
                cur: cur + 1

                index: (as-integer width) * inst-row-length + reg + 1
                output-cstr: as-c-string inst-reg/index

                ; Decode immediate
                either width [
                    output-cstr2: integer/form-signed (as-integer cur/1) + ((as-integer cur/2) << 8)
                    cur: cur + 2
                ] [
                    output-cstr2: integer/form-signed as-integer cur/1
                    cur: cur + 1
                ]

                ; Output assembly
                string/concatenate-literal out-asm "mov "
                string/concatenate-literal out-asm output-cstr
                string/concatenate-literal out-asm ", "
                string/concatenate-literal out-asm output-cstr2
                string/append-char GET_BUFFER(out-asm) as-integer lf
            ]
            true [print-line ["Unrecognized: " as-integer byte1] exit]
        ]
    ]
]

; ====================================================

; bin: read/binary %../computer_enhance/perfaware/part1/listing_0038_many_register_mov
bin: read/binary %../computer_enhance/perfaware/part1/listing_0039_more_movs
print-bin bin
if debug? [print "====================="]

asm: ""
decode-exe bin asm
if debug? [print "====================="]
prin asm
