Red []

#system [
    debug?: true
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
    ; Op header

    ; Op Register/memory to/from register
    #define OP_MOV_RM2R #"^(22)"
    #define OP_ADD_RM2R #"^(00)"
    #define OP_SUB_RM2R #"^(0A)"
    #define OP_CMP_RM2R #"^(0E)"

    #define OP_ADD_SUB_CMP_IR #"^(20)"
    #define OP_ADD_SUB_CMP_IR_ADD #"^(00)"
    #define OP_ADD_SUB_CMP_IR_SUB #"^(05)"
    #define OP_ADD_SUB_CMP_IR_CMP #"^(07)"


    ; Op Immediate to register
    op-mov-ir: #"^(0B)" ; mov


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

    extract-bit: func [
        byte [byte!]
        pos [integer!] ; Count from the lower bits. 0 based index.
        return: [logic!]
    ] [
        return as-logic (byte and (#"^(01)" << pos))
    ]

    extract-bits: func [
        byte [byte!]
        pos-start [integer!] ; Count from the lower bits. 0 based index.
        len [integer!]
        return: [byte!]
    ] [
        return byte and (#"^(FF)" >>> (8 - len) << pos-start) >>> pos-start
    ]

    decode-r_m: func [
        byte [byte!]
        pos-start [integer!] ; Count from the lower bits. 0 based index.
        disp [byte-ptr!] ; Pointer at the 1st byte address of the displacement
        in-out-cur [pointer! [byte-ptr!]]
        out-r_m [c-string!] ; Need enough size pre-allocated
        /local r_m-len [integer!]
    ] [
        r_m-len: 0
        ; TODO

        r_m-len: r_m-len + 1
        out-r_m/r_m-len: #"^(00)"
    ]

    decode-reg: func [
        byte [byte!] pos-start [integer!] width [logic!]
        return: [c-string!]
        /local index [integer!]
    ] [
        index: (as-integer width) * inst-row-length + (extract-bits byte pos-start 3) + 1
        return as-c-string inst-reg/index
    ]

    decode-mode: func [
        byte [byte!] pos-start [integer!]
        return: [byte!]
    ] [
        return extract-bits byte pos-start 2
    ]
    
    decode-str: as-c-string allocate 20
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
        ; Match 2 bits op
        byte1: cur/1 >>> 2
        ; Reg/Memory and register to either
        output-cstr: switch byte1 [
            OP_MOV_RM2R ["mov "]
            OP_ADD_RM2R ["add "]
            OP_SUB_RM2R ["sub "]
            OP_CMP_RM2R ["cmp "]
            default [null]
        ]
        if output-cstr <> null [
            string/concatenate-literal out-asm output-cstr

            output-str: string/rs-make-at stack/push* 20
            ; Extract byte1
            byte1: cur/1
            width: extract-bit byte1 0
            direction: extract-bit byte1 1
            if debug? [print-line ["direction " direction " width " width]]

            ; Extract byte2
            byte2: cur/2
            mode: decode-mode byte2 6
            ; mode: byte2 and b11'000'000 >>> 6
            reg: byte2 and b00'111'000 >>> 3
            r_m: byte2 and b00'000'111
            if debug? [print-line ["mode " as-integer mode " reg " as-integer reg " r_m " as-integer r_m]]
            ; print-line ["mode " string/to-hex as-integer mode true " reg " string/to-hex as-integer reg true " r_m " string/to-hex as-integer r_m true] ; hex doesn't work 
            cur: cur + 2

            ; Decode reg
            ; TODO: replace reg and refactor function for other data decode
            output-cstr: decode-reg byte2 3 width
            ; index: (as-integer width) * inst-row-length + reg + 1
            ; output-cstr: as-c-string inst-reg/index

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
            ; Decode direction
            either direction [ ; swap
                string/concatenate-literal out-asm output-cstr
                string/concatenate-literal out-asm ", "
                string/concatenate out-asm output-str -1 0 yes no
            ] [ ; normal
            
                ; Op Register/memory to/from register
                string/concatenate out-asm output-str -1 0 yes no
                string/concatenate-literal out-asm ", "
                string/concatenate-literal out-asm output-cstr
            ]
            string/append-char GET_BUFFER(out-asm) as-integer lf

            continue
        ]

        ; Immediate to register/memory 
        if byte1 = OP_ADD_SUB_CMP_IR [
            byte2: cur/2 and #"^(1C)" >>> 2
            output-cstr: switch byte2 [
                OP_ADD_SUB_CMP_IR_ADD ["add "]
                OP_ADD_SUB_CMP_IR_SUB ["sub "]
                OP_ADD_SUB_CMP_IR_CMP ["cmp "]
                default [null]
            ]
            either output-cstr <> null [

                continue
            ] [
                print-line "Unrecognized"
                exit
            ]
        ]


        ; Match 4 bits op
        byte1: cur/1 >>> 4
        ; Immediate with register/memory
        if byte1 = op-mov-ir [
            ; Extract byte1
            byte1: cur/1
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

            continue
        ]

        print-line ["Unrecognized: " as-integer byte1]
        exit
    ]
]

; ====================================================

bin: read/binary %../computer_enhance/perfaware/part1/listing_0039_more_movs
; bin: read/binary %../computer_enhance/perfaware/part1/listing_0041_add_sub_cmp_jnz
print-bin bin
if debug? [print "====================="]

asm: ""
decode-exe bin asm
if debug? [print "====================="]
prin asm
