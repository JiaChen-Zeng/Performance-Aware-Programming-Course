Red/System []

funcn!: alias function! []

func1: func [] [print-line "1"]
func2: func [] [print-line "2"]
func3: func [] [print-line "3"]

pfunc: as funcn! :func1
pfunc

funcs: [:func1 :func2 :func3]

; Compilation Error: attempt to redefine existing function name: pfunc 
; pfunc: as funcn! funcs/2 
; pfunc

pfunc2: as funcn! funcs/2
pfunc2

; Compilation Error: type mismatch on setting path: funcs2/1 
; *** expected: [integer!]
; ***    found: [function! []]
funcs2: [null null null]
funcs2/1: as integer! :func3
pfunc3: as funcn! funcs2/1
pfunc3
