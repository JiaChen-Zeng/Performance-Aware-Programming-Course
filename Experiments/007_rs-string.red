Red []

#system [
    c-str: "asd"
    str: string/load c-str length? c-str UTF-8
    string/concatenate-literal str " qwe"
]

get-str: routine [return: [string!]] [print str str] ; doesn't work
; get-str: routine [] [as c-string! string/rs-head str] ; doesn't work
; get-str: routine [return: [string!]] [as red-string! stack/set-last as cell! str] ; doesn't work
; get-str: routine [return: [string!] /local s [red-string!]] [s: as red-string! stack/set-last as cell! str s] ; doesn't work
print get-str

; change-str: routine [str [string!]] [
;     string/concatenate-literal str " qwe"
; ]

; red-str: "123"
; print red-str

; change-str red-str
; print red-str
