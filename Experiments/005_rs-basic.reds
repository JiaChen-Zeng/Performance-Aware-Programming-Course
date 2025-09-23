Red/System []

; p:   declare pointer! [integer!]       ;-- declare a pointer on an integer
; bar: declare pointer! [integer!]       ;-- declare another pointer on an integer

; p: as [pointer! [integer!]] 40000000h  ;-- type cast an integer! to a pointer!
; p/value: 1234                          ;-- write 1234 at address 40000000h
; foo: p/value                           ;-- read pointed value back
; bar: p                                 ;-- assign pointer address to 'bar

; *** Runtime Error 1: access violation
; *** at: 004010A3h

abc!: alias struct! [
    not-value [integer!]
    value [integer!]
]
abc: declare abc! 

abc/not-value: 345
abc/value: 456

print-line abc
print-line abc/not-value
print-line abc/value

abc-ptr: as abc! 0

print-line abc-ptr
