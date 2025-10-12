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

    OPSTR_MOV: "mov "
    OPSTR_ADD: "add "
    OPSTR_SUB: "sub "
    OPSTR_CMP: "cmp "

    ; union
    #enum resource-type! [ RT_NONE RT_REG RT_MEM ]
    resource!: alias struct! [
        type [resource-type!]
        data [integer!]
        data [integer!]
    ]
    resource-reg!: alias struct! [
        type [resource-type!]
        index [integer!]
        wide [logic!]
    ]
    resource-mem!: alias struct! [
        type [resource-type!]
        addr [integer!]
    ]

    ; ===============================================================

    inst-reg: [
        "al" "cl" "dl" "bl" "ah" "ch" "dh" "bh"
        "ax" "cx" "dx" "bx" "sp" "bp" "si" "di"
    ]
    inst-row-length: (size? inst-reg) / 2

    inst-mem: [
        "bx + si" "bx + di" "bp + si" "bp + di" "si" "di" "bp" "bx"
    ]

    registers: allocate size? inst-reg
    reg-map: [ ; registers/(reg-map/index) <-> inst-reg/index
        0 4 6 2 1 5 7 3
        0 2 4 6 8 10 12 14
    ]
    regex: context [ip: 0]


    set-register: func [
        index [integer!] wide [logic!] value [integer!]
        /local i [integer!]
    ] [
        either wide [
            set-int16 registers + reg-map/index value
        ] [
            i: reg-map/index
            registers/i: as-byte value
        ]
    ]

    get-register: func [
        index [integer!] wide [logic!]
        return: [integer!]
        /local i [integer!]
    ] [
        return either wide [
            decode-int16 registers + reg-map/index
        ] [
            i: reg-map/index
            as-integer registers/i
        ]
    ]

    memory: allocate 10000h

    set-memory86: func [
        addr [integer!] ; 0-based
        wide [logic!] value [integer!]
        /local addr1 [integer!]
    ] [
        either wide [
            set-int16 memory + addr value
        ] [
            addr1: addr + 1
            memory/addr1: as-byte value
        ]
    ]

    get-memory86: func [
        addr [integer!] ; 0-based
        wide [logic!]
        return: [integer!]
        /local addr1 [integer!]
    ] [
        return either wide [
            decode-int16 memory + addr
        ] [
            addr1: addr + 1
            as-integer memory/addr1
        ]
    ]

    compute-address: func [
        "Register specified address"
        index [integer!] ; correspond to inst-mem
        return: [integer!]
    ] [
        return switch index [
            1 [(get-register 12 true) + (get-register 15 true)]
            2 [(get-register 12 true) + (get-register 16 true)]
            3 [(get-register 14 true) + (get-register 15 true)]
            4 [(get-register 14 true) + (get-register 16 true)]
            5 [get-register 15 true]
            6 [get-register 16 true]
            7 [get-register 14 true]
            8 [get-register 12 true]
        ]
    ]

    flags: context [fzero?: false sign?: false]

    update-flags: func [ret [integer!] wide [logic!]] [
        flags/fzero?: ret = 0
        flags/sign?: as-logic either wide [ret and 80h] [ret and 8000h]
    ]

    print-reg-order: [1 4 2 3 5 6 7 8]
    print-registers: func [
        /local i [integer!] reg-index [integer!] mapped-index [integer!]
        reg [c-string!] v [integer!] temp [int-ptr!]
    ] [
        probe "Final registers:"
        
        i: 1
        loop inst-row-length [
            mapped-index: print-reg-order/i + inst-row-length
            v: get-register mapped-index true 
            probe [as-c-string inst-reg/mapped-index ": " string/to-hex v true " (" v ")"]

            i: i + 1
        ]
        probe ["ip: " (string/to-hex regex/ip true) " (" regex/ip ")"]
    ]

    print-flags: func [] [
        print "flags: "
        if flags/fzero? [print #"Z"]
        if flags/sign? [print #"S"]
        print #"^/"
    ]

    ; ===============================================================

    decode-str: as-c-string allocate 20

    decode-funcs-size: 256 * size? int-ptr!
    decode-funcs: as ptr-ptr! allocate decode-funcs-size
    set-memory as byte-ptr! decode-funcs null-byte decode-funcs-size

    decode-fun!: alias function! [out-asm [red-string!] op [byte!] p [byte-ptr!] return: [integer!]]
    #define decode-fun-ptr! int-ptr!

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
        byte [byte!] opstr [c-string!] reg [c-string!] type [c-string!] inc [integer!]
        reg-index [integer!]
        res [resource!] rreg [resource-reg!] rmem [resource-mem!] ret [integer!]
    ] [
        opstr: switch op [
            #"^(88)" [OPSTR_MOV]
            #"^(00)" [OPSTR_ADD]
            #"^(28)" [OPSTR_SUB]
            #"^(38)" [OPSTR_CMP]
            default [return 0 null]
        ]

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
        reg-index: 0
        reg: decode-reg byte 3 wide :reg-index

        ; Decode r_m
        inc: 0
        res: declare resource!
        decode-r_m byte 0 wide mode p + 2 :inc decode-str res

        ; Output assembly
        string/concatenate-literal out-asm opstr
        ; Apply direction
        either direction [ ; swap
            string/concatenate-literal out-asm reg
            string/concatenate-literal out-asm ", "
            string/concatenate-literal out-asm decode-str
        ] [ ; normal
            string/concatenate-literal out-asm decode-str
            string/concatenate-literal out-asm ", "
            string/concatenate-literal out-asm reg
        ]
        string/append-char GET_BUFFER(out-asm) as-integer lf


        switch res/type [
            RT_REG [
                rreg: as resource-reg! res
                switch op [
                    #"^(88)" [ ; mov
                        either direction [
                            ret: get-register rreg/index wide
                            set-register reg-index wide ret
                        ] [
                            ret: get-register reg-index wide
                            set-register rreg/index wide ret
                        ]
                    ]
                    #"^(00)" [ ; add
                        ret: (get-register rreg/index wide) + (get-register reg-index wide)
                        set-register either direction [reg-index] [rreg/index] wide ret
                    ]
                    #"^(28)" [ ; sub
                        ret: (get-register rreg/index wide) - (get-register reg-index wide)
                        either direction [
                            ret: -1 * ret
                            set-register reg-index wide ret
                        ] [
                            set-register rreg/index wide ret
                        ]
                    ]
                    #"^(38)" [ ; cmp
                        ret: (get-register rreg/index wide) - (get-register reg-index wide)
                        if direction [ret: -1 * ret]
                    ]
                    default [return 0]
                ]
                if op <> #"^(88)" [update-flags ret wide]
            ]
            RT_MEM [
                rmem: as resource-mem! res
                if op = #"^(88)" [
                    either direction [
                        ret: get-memory86 rmem/addr wide
                        set-register reg-index wide ret
                    ] [
                        ret: get-register reg-index wide
                        set-memory86 rmem/addr wide ret
                    ]
                ]
            ]
        ]


        return inc + 2
    ]

    decode-im-to-r_m: func [
        "For mov add sub cmp"
        out-asm [red-string!] op [byte!] p [byte-ptr!]
        return: [integer!]
        /local wide [logic!] signed [logic!] mode [byte!] im [integer!]
        str [c-string!] type [c-string!] inc [integer!]
        res [resource!] rreg [resource-reg!] rmem [resource-mem!] sop [byte!] ret [integer!]
    ] [
        either op = #"^(C6)" [ ; mov
            str: "mov "
        ] [
            sop: extract-bits p/2 3 3
            str: switch sop [
                SOP_ADD ["add "]
                SOP_SUB ["sub "]
                SOP_CMP ["cmp "]
                default [print-line "Unrecognized (decode-im-to-r_m):" as-integer p/2 return 0 null]
            ]
        ]

        wide: extract-bit p/1 0
        signed: either op = #"^(C6)" [false] [extract-bit p/1 1] ; mov hack added
        mode: decode-mode p/2 6

        inc: 0
        res: declare resource!
        decode-r_m p/2 0 wide mode p + 2 :inc decode-str res

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


        switch res/type [
            RT_REG [
                rreg: as resource-reg! res
                either op = #"^(C6)" [ ; mov
                    set-register rreg/index wide im
                ] [
                    switch sop [
                        SOP_ADD [
                            ret: (get-register rreg/index wide) + im
                            set-register rreg/index wide ret
                        ]
                        SOP_SUB [
                            ret: (get-register rreg/index wide) - im
                            set-register rreg/index wide ret
                        ]
                        SOP_CMP [
                            ret: (get-register rreg/index wide) - im
                        ]
                        default [return 0]
                    ]
                    update-flags ret wide
                ]
            ]
            RT_MEM [
                rmem: as resource-mem! res
                either op = #"^(C6)" [ ; mov
                    set-memory86 rmem/addr wide im
                ] [
                    switch sop [
                        SOP_ADD [
                            ret: (get-memory86 rmem/addr wide) + im
                            set-memory86 rmem/addr wide ret
                        ]
                        SOP_SUB [
                            ret: (get-memory86 rmem/addr wide) - im
                            set-memory86 rmem/addr wide ret
                        ]
                        SOP_CMP [
                            ret: (get-memory86 rmem/addr wide) - im
                        ]
                        default [return 0]
                    ]
                    update-flags ret wide
                ]
            ]
        ]


        return inc
    ]

    decode-im-to-reg-mov: func [
        "For mov"
        out-asm [red-string!] op [byte!] p [byte-ptr!]
        return: [integer!]
        /local byte [byte!] wide [logic!] 
        reg [c-string!] reg-index [integer!] im [integer!]
        inc [integer!]
    ] [
        ; Extract byte
        byte: p/1
        wide: extract-bit byte 3
        reg-index: 0
        reg: decode-reg byte 0 wide :reg-index

        ; Decode immediate
        either wide [
            im: decode-int16 p + 1
            inc: 3
        ] [
            im: decode-int8 p + 1
            inc: 2
        ]

        ; Output assembly
        string/concatenate-literal out-asm "mov "
        string/concatenate-literal out-asm reg
        string/concatenate-literal out-asm ", "
        string/concatenate-literal out-asm integer/form-signed im
        string/append-char GET_BUFFER(out-asm) as-integer lf

        set-register reg-index wide im

        return inc
    ]

    decode-im-to-acc: func [
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
            default [print-line ["Unrecognized (decode-im-to-acc): " as-integer p/1] return 0 null]
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
        /local inst [c-string!] sop [byte!] v [integer!]
    ] [
        sop: extract-bits p/1 0 4
        inst: switch sop [
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

        v: decode-sint8 p + 1

        string/concatenate-literal out-asm inst
        string/concatenate-literal out-asm integer/form-signed v
        string/append-char GET_BUFFER(out-asm) as-integer lf

        ; Only sim for jnz
        if sop = #"^(05)" [
            unless flags/fzero? [
                return 2 + v
            ]
        ]

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
        out-res [resource!]
        /local r_m [byte!] r_m-len [integer!] index [integer!] str-len [integer!] str-len2 [integer!] str [c-string!] int [integer!]
        reg-index [integer!]
        out-rreg [resource-reg!] out-rmem [resource-mem!]
    ] [
        switch mode [
            ; Register
            #"^(03)" [
                reg-index: 0
                copy-memory as byte-ptr! out-r_m as byte-ptr! decode-reg byte pos-start wide :reg-index 2
                r_m-len: 2
                out-inc/value: 0

                out-rreg: as resource-reg! out-res
                out-rreg/type: RT_REG
                out-rreg/index: reg-index
                out-rreg/wide: wide
            ]
            ; Memory
            #"^(00)" [
                out-rmem: as resource-mem! out-res
                out-rmem/type: RT_MEM

                r_m: extract-bits byte pos-start 3
                out-r_m/1: #"["
                either r_m <> #"^(06)" [
                    index: as-integer r_m + 1
                    r_m-len: length? as-c-string inst-mem/index
                    copy-memory as byte-ptr! out-r_m + 1 as byte-ptr! inst-mem/index r_m-len
                    out-inc/value: 0
                    out-rmem/addr: compute-address index
                ] [ ; Direct address
                    out-rmem/addr: decode-int16 disp
                    str: integer/form-signed out-rmem/addr
                    r_m-len: length? str
                    copy-memory as byte-ptr! out-r_m + 1 as byte-ptr! str r_m-len
                    out-inc/value: 2
                ]
                r_m-len: r_m-len + 2
                out-r_m/r_m-len: #"]"
            ]
            ; Memory + Displacement
            #"^(01)" #"^(02)" [
                out-rmem: as resource-mem! out-res
                out-rmem/type: RT_MEM

                r_m: extract-bits byte pos-start 3
                out-r_m/1: #"["

                index: as-integer r_m + 1
                str: as-c-string inst-mem/index
                str-len: length? str
                copy-memory as byte-ptr! (out-r_m + 1) as byte-ptr! str str-len
                out-rmem/addr: compute-address index

                either mode = #"^(01)" [
                    int: decode-int8 disp
                    out-inc/value: 1
                ] [
                    int: decode-int16 disp
                    out-inc/value: 2
                ]

                either int <> 0 [
                    out-rmem/addr: out-rmem/addr + int
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

    register!: alias struct! [
        index [integer!]

    ]

    decode-reg: func [
        byte [byte!] pos-start [integer!] wide [logic!]
        out-reg-index [int-ptr!]
        return: [c-string!]
        /local index [integer!]
    ] [
        index: (as-integer wide) * inst-row-length + (extract-bits byte pos-start 3) + 1
        out-reg-index/value: index
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

    set-int16: func [
        p [byte-ptr!] ; p = lo, p + 1 = hi
        v [integer!]
    ] [
        p/1: as-byte v and FFh
        p/2: as-byte v >> 8 and FFh
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
        :decode-im-to-r_m #"^(C6)" ; mov
        :decode-im-to-r_m #"^(80)" ; add sub cmp
        :decode-im-to-reg-mov #"^(B0)"
        :decode-im-to-acc #"^(04)" ; add
        :decode-im-to-acc #"^(2C)" ; sub
        :decode-im-to-acc #"^(3C)" ; cmp
        :decode-jnz #"^(70)"
        :decode-lp #"^(E0)"
    ]
]

; ================================================================

decode-exe: routine [
    bin [binary!] out-asm [string!]

    /local ser [series!] ser-head [byte-ptr!] ser-tail [byte-ptr!]
    cur [byte-ptr!] inc [integer!]
    byte [byte!] mask [byte!] fp [decode-fun-ptr!] f [decode-fun!]
] [
    string/concatenate-literal out-asm "bits 16^/"

    ser: GET_BUFFER(bin)
    ser-head: as byte-ptr! ser/offset
    ser-tail: as byte-ptr! ser/tail
    cur: ser-head
    while [all [
        ser-head <= cur
        cur < ser-tail
    ]] [
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
        if zero? inc [probe ["INTERNAL ERROR (decode-exe): " as-integer byte] exit]

        cur: cur + inc
        regex/ip: as-integer cur - as byte-ptr! ser/offset
    ]
]

print-extra: routine [] [
    print-registers
    print-flags
]

get-memory-red: routine [
    addr [integer!] ; 0-based
    return: [integer!]
    /local addr1 [integer!]
] [
    addr1: addr + 1
    as-integer memory/addr1
]

view-image: func [
    addr [integer!] width [integer!] height [integer!]
    /local size [pair!] draw-content [block!]
    pos [pair!] color [tuple!] img [image!] i [integer!]
] [
    size: to-pair width height
    img: make image! size
    i: 1
    loop length? img [
        img/:i: make tuple! reduce [
            get-memory-red addr + (i - 1 * 4)
            get-memory-red addr + (i - 1 * 4 + 1)
            get-memory-red addr + (i - 1 * 4 + 2)
            255 - (get-memory-red addr + (i - 1 * 4 + 3))
        ]
        i: i + 1
    ]
    view [image size img]
]

; ====================================================

; bin: read/binary %../computer_enhance/perfaware/part1/listing_0049_conditional_jumps
; bin: read/binary %../computer_enhance/perfaware/part1/listing_0052_memory_add_loop
bin: read/binary %../computer_enhance/perfaware/part1/listing_0054_draw_rectangle

print-bin bin
if debug? [print "====================="]

asm: ""
decode-exe bin asm
if debug? [print "====================="]
; prin asm

print ""

print-extra

view-image 64 * 4 64 64
