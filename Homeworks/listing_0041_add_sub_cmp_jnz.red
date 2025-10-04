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
    #define OP_MOV_IR #"^(0B)"


    inst-reg: [
        "al" "cl" "dl" "bl" "ah" "ch" "dh" "bh"
        "ax" "cx" "dx" "bx" "sp" "bp" "si" "di"
    ]
    inst-row-length: (size? inst-reg) / 2

    inst-mem: [
        "bx + si" "bx + di" "bp + si" "bp + di" "si" "di" "bp" "bx"
    ]

    decode-str: as-c-string allocate 20

    decode-r_m-t_f-register: func [
        "For mov add sub cmp"
        out-asm [red-string!] op [byte!] p [byte-ptr!]
        return: [integer!]
        /local direction [logic!] wide [logic!] mode [byte!]
        byte [byte!] str [c-string!] inc [integer!]
    ] [
        str: switch op [
            OP_MOV_RM2R ["mov "]
            OP_ADD_RM2R ["add "]
            OP_SUB_RM2R ["sub "]
            OP_CMP_RM2R ["cmp "]
            default [null]
        ]
        if str = null [return 0]
        string/concatenate-literal out-asm str

        ; Extract byte1
        byte: p/1
        wide: extract-bit byte 0
        direction: extract-bit byte 1
        if debug? [print-line ["direction " direction " wide " wide]]

        ; Extract byte2
        byte: p/2
        mode: decode-mode byte 6
        if debug? [
            print-line ["mode " as-integer mode " reg " as-integer extract-bits byte 3 3 " r_m " as-integer extract-bits byte 0 3]
        ]

        ; Decode reg
        str: decode-reg byte 3 wide

        ; Decode r_m
        inc: 0
        decode-r_m byte 0 wide mode p + 2 :inc decode-str

        ; Output assembly
        ; Apply direction
        either direction [ ; swap
            string/concatenate-literal out-asm str
            string/concatenate-literal out-asm ", "
            string/concatenate-literal out-asm decode-str
        ] [ ; normal
            ; Op Register/memory to/from register
            string/concatenate-literal out-asm decode-str
            string/concatenate-literal out-asm ", "
            string/concatenate-literal out-asm str
        ]
        string/append-char GET_BUFFER(out-asm) as-integer lf

        return inc + 2
    ]

    decode-im-to-r_m: func [
        "For add sub cmp"
        out-asm [red-string!] op [byte!] p [byte-ptr!]
        return: [integer!]
        /local wide [logic!] signed [logic!] mode [byte!] im [integer!]
        str [c-string!] inc [integer!] temp[integer!] temp2[integer!]
    ] [
        if op <> OP_ADD_SUB_CMP_IR [return 0]

        str: switch extract-bits p/2 3 3 [
            OP_ADD_SUB_CMP_IR_ADD ["add "]
            OP_ADD_SUB_CMP_IR_SUB ["sub "]
            OP_ADD_SUB_CMP_IR_CMP ["cmp "]
            default [print-line "Unrecognized (decode-im-to-r_m):" return 999999 null]
        ]

        wide: extract-bit p/1 0
        signed: extract-bit p/1 1
        mode: decode-mode p/2 6

        inc: 0
        decode-r_m p/2 0 wide mode p + 2 :inc decode-str

        inc: inc + 2
        temp: inc + 1
        print-line ["wide " wide " signed " signed " " p/inc " " p/temp]
        either wide and not signed [
            im: decode-int16 p + inc
            inc: inc + 2
        ] [
            im: decode-int8 p + inc
            inc: inc + 1
        ]

        string/concatenate-literal out-asm str
        string/concatenate-literal out-asm decode-str
        string/concatenate-literal out-asm ", "
        string/concatenate-literal out-asm integer/form-signed im
        string/append-char GET_BUFFER(out-asm) as-integer lf

        return inc
    ]

    decode-im-to-reg-mov: func [
        "For mov"
        out-asm [red-string!] op [byte!] p [byte-ptr!]
        return: [integer!]
        /local byte [byte!] wide [logic!] 
        str [c-string!] str2 [c-string!]
        inc [integer!]
    ] [
        if op <> OP_MOV_IR [return 0]

        ; Extract byte
        byte: p/1
        wide: extract-bit byte 3
        str: decode-reg byte 0 wide

        ; Decode immediate
        either wide [
            str2: integer/form-signed decode-int16 p + 1
            inc: 3
        ] [
            str2: integer/form-signed decode-int8 p + 1
            inc: 2
        ]

        ; Output assembly
        string/concatenate-literal out-asm "mov "
        string/concatenate-literal out-asm str
        string/concatenate-literal out-asm ", "
        string/concatenate-literal out-asm str2
        string/append-char GET_BUFFER(out-asm) as-integer lf

        return inc
    ]

    decode-r_m: func [
        byte [byte!]
        pos-start [integer!] ; Count from the lower bits. 0 based index.
        wide [logic!] mode [byte!]
        disp [byte-ptr!] ; Pointer at the 1st byte address of displacement
        out-inc [int-ptr!]
        out-r_m [c-string!] ; Need enough size pre-allocated
        /local r_m [byte!] r_m-len [integer!] index [integer!] str-len [integer!] str-len2 [integer!] str [c-string!] int [integer!]
    ] [
        switch mode [
            #"^(03)" [
                copy-memory as byte-ptr! out-r_m as byte-ptr! decode-reg byte pos-start wide 2
                r_m-len: 2
                out-inc/value: 0
            ]
            #"^(00)" [
                r_m: extract-bits byte pos-start 3
                either r_m <> #"^(06)" [
                    either r_m < #"^(04)" [ ; ex. [bx + si]
                        out-r_m/1: #"["
                        
                        index: as-integer r_m + 1
                        copy-memory as byte-ptr! (out-r_m + 1) as byte-ptr! inst-mem/index 7 ; len of "bx + si"

                        out-r_m/9: #"]" ; len(7) + 2
                        r_m-len: 9
                        out-inc/value: 0
                    ] [ ; ex. si
                        index: as-integer r_m + 1
                        copy-memory as byte-ptr! out-r_m as byte-ptr! inst-mem/index 2
                        r_m-len: 2
                        out-inc/value: 0
                    ]
                ] [ ; Direct address
                    str: integer/form-signed decode-int16 disp
                    r_m-len: length? str
                    copy-memory as byte-ptr! out-r_m as byte-ptr! str r_m-len
                    out-inc/value: 2
                ]
            ]
            #"^(01)" #"^(02)" [
                r_m: extract-bits byte pos-start 3
                out-r_m/1: #"["

                index: as-integer r_m + 1
                str: as-c-string inst-mem/index
                str-len: length? str
                copy-memory as byte-ptr! (out-r_m + 1) as byte-ptr! str str-len

                either mode = #"^(01)" [
                    int: decode-int8 disp
                    out-inc/value: 1
                ] [
                    int: decode-int16 disp
                    out-inc/value: 2
                ]

                either int <> 0 [
                    copy-memory as byte-ptr! (out-r_m + str-len + 1) as byte-ptr! " + " 3

                    str: integer/form-signed int
                    str-len2: length? str
                    copy-memory as byte-ptr! (out-r_m + str-len + 4) as byte-ptr! str str-len2
                    r_m-len: str-len + 5 + str-len2
                ] [
                    r_m-len: str-len + 2
                ]
                out-r_m/r_m-len: #"]"
            ]
        ]

        r_m-len: r_m-len + 1
        out-r_m/r_m-len: #"^(00)"
    ]

    decode-reg: func [
        byte [byte!] pos-start [integer!] wide [logic!]
        return: [c-string!]
        /local index [integer!]
    ] [
        index: (as-integer wide) * inst-row-length + (extract-bits byte pos-start 3) + 1
        return as-c-string inst-reg/index
    ]

    decode-mode: func [
        byte [byte!] pos-start [integer!]
        return: [byte!]
    ] [
        return extract-bits byte pos-start 2
    ]

    decode-int16: func [
        p [byte-ptr!] ; 1st byte = low byte, 2nd byte = high byte
        return: [integer!]
    ] [
        return (as-integer p/1) + ((as-integer p/2) << 8)
    ]

    decode-int8: func [
        p [byte-ptr!]
        return: [integer!]
    ] [
        return as-integer p/value
    ]

    decode-sint8: func [
        p [byte-ptr!]
        return: [integer!]
    ] [
        either #"^(00)" < (p/1 and #"^(01)") [
            return -1 * as-integer p/2
        ] [
            return as-integer p/2
        ]
    ]

    extract-bit: func [
        byte [byte!]
        pos [integer!] ; Count from the lower bits. 0 based index.
        return: [logic!]
    ] [
        as-logic (byte and (#"^(01)" << pos)) ; `return` causes compiler bug
    ]

    extract-bits: func [
        byte [byte!]
        pos-start [integer!] ; Count from the lower bits. 0 based index.
        len [integer!]
        return: [byte!]
    ] [
        return byte and (#"^(FF)" >>> (8 - len) << pos-start) >>> pos-start
    ]
]

; ================================================================

decode-exe: routine [
    bin [binary!] out-asm [string!]

    /local ser [series!] cur [byte-ptr!] inc [integer!]
    byte1 [byte!] byte2 [byte!]

    direction [logic!] wide [logic!] mode [byte!] reg [byte!]
    index [integer!]
    output-cstr [c-string!] output-cstr2 [c-string!]
] [
    string/concatenate-literal out-asm "bits 16^/"

    ser: GET_BUFFER(bin)
    cur: as byte-ptr! ser/offset
    while [cur < as byte-ptr! ser/tail] [
        ; Match 2 bits op
        byte1: cur/1 >>> 2

        inc: decode-r_m-t_f-register out-asm byte1 cur
        if 0 < inc [cur: cur + inc continue]
        inc: decode-im-to-r_m out-asm byte1 cur
        if 0 < inc [cur: cur + inc continue]


        ; Match 4 bits op
        byte1: cur/1 >>> 4

        inc: decode-im-to-reg-mov out-asm byte1 cur
        if 0 < inc [cur: cur + inc continue]


        print-line ["Unrecognized (decode-exe): " as-integer cur/value]
        exit
    ]
]

; ====================================================

; bin: read/binary %../computer_enhance/perfaware/part1/listing_0039_more_movs
bin: read/binary %../computer_enhance/perfaware/part1/listing_0041_add_sub_cmp_jnz
print-bin bin
if debug? [print "====================="]

asm: ""
decode-exe bin asm
if debug? [print "====================="]
prin asm
