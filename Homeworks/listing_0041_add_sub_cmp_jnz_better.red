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

; ==============================================

#system [
    #define SOP_ADD #"^(00)"
    #define SOP_SUB #"^(05)"
    #define SOP_CMP #"^(07)"


    inst-reg: [
        "al" "cl" "dl" "bl" "ah" "ch" "dh" "bh"
        "ax" "cx" "dx" "bx" "sp" "bp" "si" "di"
    ]
    inst-row-length: (size? inst-reg) / 2

    inst-mem: [
        "bx + si" "bx + di" "bp + si" "bp + di" "si" "di" "bp" "bx"
    ]

    decode-str: as-c-string allocate 20

    decode-funcs-size: 256 * size? int-ptr!
    decode-funcs: as ptr-ptr! allocate decode-funcs-size
    set-memory as byte-ptr! decode-funcs null-byte decode-funcs-size

    decode-fun!: alias function! [out-asm [red-string!] op [byte!] p [byte-ptr!] return: [integer!]]
    #define decode-fun-ptr! int-ptr!

    ; Compiler internal error
    ; register-decode-func: func [
    ;     [typed] count [integer!] list [typed-value!]
    ;     /local f [decode-fun-ptr!] p [int-ptr!] size [integer!]
    ; ] [
    ;     loop count >> 1 [
    ;         f: as decode-fun-ptr! list/value
    ;         list: list + 1
    ;         either list/type = type-byte! [
    ;             set-decode-func as-byte list/value f
    ;         ] [
    ;             p: :list/value
    ;             probe ["size? list/value " size? list/value]
    ;             loop size? list/value [
    ;                 set-decode-func as-byte p/value f
    ;                 p: p + 1
    ;             ]
    ;         ]
    ;         list: list + 1
    ;     ]
    ; ]

    register-decode-func: func [
        [variadic] count [integer!] list [int-ptr!]
        /local f [decode-fun-ptr!] p [int-ptr!] size [integer!]
    ] [
        loop count >> 1 [
            f: as decode-fun-ptr! list/value
            list: list + 1
            set-decode-func as-byte list/value f
            list: list + 1
        ]
    ]

    set-decode-func: func [op [byte!] f [decode-fun-ptr!] /local p [ptr-ptr!] i [integer!]] [
        i: as-integer op ; Compiler bug
        p: decode-funcs + i
        p/value: f
    ]

    get-decode-func: func [op [byte!] return: [decode-fun-ptr!] /local p [ptr-ptr!] i [integer!]] [
        i: as-integer op ; Compiler bug
        p: decode-funcs + i
        return p/value
    ]

    decode-r_m-t_f-register: func [
        "For mov add sub cmp"
        out-asm [red-string!] op [byte!] p [byte-ptr!]
        return: [integer!]
        /local direction [logic!] wide [logic!] mode [byte!]
        byte [byte!] str [c-string!] type [c-string!] inc [integer!]
    ] [
        str: switch op [
            #"^(88)" ["mov "]
            #"^(00)" ["add "]
            #"^(28)" ["sub "]
            #"^(38)" ["cmp "]
            default [return 0 null]
        ]
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
        str [c-string!] type [c-string!] inc [integer!]
    ] [
        str: switch extract-bits p/2 3 3 [
            SOP_ADD ["add "]
            SOP_SUB ["sub "]
            SOP_CMP ["cmp "]
            default [print-line "Unrecognized (decode-im-to-r_m):" as-integer p/2 return 0 null]
        ]

        wide: extract-bit p/1 0
        signed: extract-bit p/1 1
        mode: decode-mode p/2 6

        inc: 0
        decode-r_m p/2 0 wide mode p + 2 :inc decode-str

        type: decode-type decode-str wide

        inc: inc + 2
        either wide and not signed [
            im: decode-int16 p + inc
            inc: inc + 2
        ] [
            im: decode-int8 p + inc
            inc: inc + 1
        ]

        string/concatenate-literal out-asm str
        if type <> null [string/concatenate-literal out-asm type]
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
        reg [c-string!] im [c-string!]
        inc [integer!]
    ] [
        ; Extract byte
        byte: p/1
        wide: extract-bit byte 3
        reg: decode-reg byte 0 wide

        ; Decode immediate
        either wide [
            im: integer/form-signed decode-int16 p + 1
            inc: 3
        ] [
            im: integer/form-signed decode-int8 p + 1
            inc: 2
        ]

        ; Output assembly
        string/concatenate-literal out-asm "mov "
        string/concatenate-literal out-asm reg
        string/concatenate-literal out-asm ", "
        string/concatenate-literal out-asm im
        string/append-char GET_BUFFER(out-asm) as-integer lf

        return inc
    ]

    decode-mem-to-acc: func [
        "For add sub cmp"
        out-asm [red-string!] op [byte!] p [byte-ptr!]
        return: [integer!]
        /local wide [logic!] index [integer!] im [integer!]
        str [c-string!] str2 [c-string!] inc [integer!]
    ] [
        str: switch extract-bits p/1 3 3 [
            SOP_ADD ["add "]
            SOP_SUB ["sub "]
            SOP_CMP ["cmp "]
            default [print-line ["Unrecognized (decode-mem-to-acc): " as-integer p/1] return 0 null]
        ]

        wide: extract-bit p/1 0

        inc: 1
        either wide [
            str2: as-c-string inst-reg/9
            im: decode-int16 p + 1
            inc: inc + 2
        ] [
            str2: as-c-string inst-reg/1
            im: decode-int8 p + 1
            inc: inc + 1
        ]

        string/concatenate-literal out-asm str
        string/concatenate-literal out-asm str2
        string/concatenate-literal out-asm ", "
        string/concatenate-literal out-asm integer/form-signed im
        string/append-char GET_BUFFER(out-asm) as-integer lf

        return inc
    ]

    decode-jnz: func [
        out-asm [red-string!] op [byte!] p [byte-ptr!]
        return: [integer!]
        /local inst [c-string!]
    ] [
        inst: switch extract-bits p/1 0 4 [
            #"^(04)" ["je "]
            #"^(0C)" ["jl "]
            #"^(0E)" ["jle "]
            #"^(02)" ["jb "]
            #"^(06)" ["jbe "]
            #"^(0A)" ["jp "]
            #"^(00)" ["jo "]
            #"^(08)" ["js "]
            #"^(05)" ["jnz "]
            #"^(0D)" ["jnl "]
            #"^(0F)" ["jg "]
            #"^(03)" ["jnb "]
            #"^(07)" ["ja "]
            #"^(0B)" ["jnp "]
            #"^(01)" ["jno "]
            #"^(09)" ["jns "]
            default [probe ["Unrecognized (decode-jnz): " p/1] return 0 null]
        ]

        string/concatenate-literal out-asm inst
        string/concatenate-literal out-asm integer/form-signed decode-sint8 p + 1
        string/append-char GET_BUFFER(out-asm) as-integer lf

        return 2
    ]

    decode-lp: func [
        out-asm [red-string!] op [byte!] p [byte-ptr!]
        return: [integer!]
        /local inst [c-string!]
    ] [
        inst: switch extract-bits p/1 0 2 [
            #"^(02)" ["loop "]
            #"^(01)" ["loopz "]
            #"^(00)" ["loopnz "]
            #"^(03)" ["jcxz "]
        ]

        string/concatenate-literal out-asm inst
        string/concatenate-literal out-asm integer/form-signed decode-sint8 p + 1
        string/append-char GET_BUFFER(out-asm) as-integer lf

        return 2
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
                out-r_m/1: #"["
                either r_m <> #"^(06)" [
                    index: as-integer r_m + 1
                    r_m-len: length? as-c-string inst-mem/index
                    copy-memory as byte-ptr! out-r_m + 1 as byte-ptr! inst-mem/index r_m-len
                    out-inc/value: 0
                ] [ ; Direct address
                    str: integer/form-signed decode-int16 disp
                    r_m-len: length? str
                    copy-memory as byte-ptr! out-r_m + 1 as byte-ptr! str r_m-len
                    out-inc/value: 2
                ]
                r_m-len: r_m-len + 2
                out-r_m/r_m-len: #"]"
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

    decode-type: func [
        r_m [c-string!] wide [logic!]
        return: [c-string!]
    ] [
        if r_m/1 = #"[" [ ; is memory
            either wide [return "word "] [return "byte "]
        ]
        return null
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
        /local i [integer!]
    ] [
        i: as-integer p/value
        if p/value >>> 7 = #"^(01)" [i: (not i) and FFh + 1 * -1]
        return i
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

    register-decode-func [
        :decode-r_m-t_f-register #"^(88)" ; mov
        :decode-r_m-t_f-register #"^(00)" ; add
        :decode-r_m-t_f-register #"^(28)" ; sub
        :decode-r_m-t_f-register #"^(38)" ; cmp
        :decode-im-to-r_m #"^(80)" ; add sub cmp
        :decode-im-to-reg-mov #"^(B0)"
        :decode-mem-to-acc #"^(04)" ; add
        :decode-mem-to-acc #"^(2C)" ; sub
        :decode-mem-to-acc #"^(3C)" ; cmp
        :decode-jnz #"^(70)"
        :decode-lp #"^(E0)"
    ]
]

; ================================================================

decode-exe: routine [
    bin [binary!] out-asm [string!]

    /local ser [series!] cur [byte-ptr!] inc [integer!]
    byte [byte!] mask [byte!] fp [decode-fun-ptr!] f [decode-fun!]
] [
    string/concatenate-literal out-asm "bits 16^/"

    ser: GET_BUFFER(bin)
    cur: as byte-ptr! ser/offset
    while [cur < as byte-ptr! ser/tail] [
        byte: cur/value
        mask: #"^(FF)"
        while [
            fp: get-decode-func byte and mask
            all [null? fp mask <> #"^(01)"]
        ] [
            mask: mask << 1
        ]

        if null? fp [probe ["Unrecognized (decode-exe): " as-integer byte] exit]

        f: as decode-fun! fp
        inc: f out-asm byte and mask cur
        if inc <= 0 [probe ["INTERNAL ERROR (decode-exe): " as-integer byte] exit]

        cur: cur + inc
    ]
]

; ====================================================

bin: read/binary %../computer_enhance/perfaware/part1/listing_0041_add_sub_cmp_jnz
print-bin bin
if debug? [print "====================="]

asm: ""
decode-exe bin asm
if debug? [print "====================="]
prin asm
