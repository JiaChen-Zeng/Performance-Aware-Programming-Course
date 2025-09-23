Red []

; #system [
;     c-str: "asd"
;     str: string/load c-str length? c-str UTF-8
;     string/concatenate-literal str " qwe"
; ]

; get-str: routine [return: [string!]] [str] ; doesn't work
; print get-str

change-str: routine [str [string!]] [
    string/concatenate-literal str " qwe"
]

red-str: "123"
print red-str

change-str red-str
print red-str
