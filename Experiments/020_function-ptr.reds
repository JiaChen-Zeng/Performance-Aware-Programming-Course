Red/System []

funcn!: alias function! []

func1: func [] [print-line "1"]
func2: func [] [print-line "2"]
func3: func [] [print-line "3"]

pfunc: as funcn! :func1
pfunc

funcs: [:func1 :func2 :func2]

; pfunc: as funcn! funcs/2 ; Compilation Error: attempt to redefine existing function name: pfunc 
; pfunc

pfunc2: as funcn! funcs/2
pfunc2
