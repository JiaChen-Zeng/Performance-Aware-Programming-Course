Red/System []

; Compiler internal error
; Where: emit-argument Near:  [forall list [
; receive: func [arr [int-ptr!]] []
; receive [1]

; Compiler internal error
; Where: emit-argument Near:  [forall list [
receive-n: func [[typed] count [integer!] list [typed-value!]] []
; receive-n [[1]]

a: [1]
receive-n [a] ; ok

; Compiler internal error
; Where: get-type Near:  [case [
; a2: [1 [1]]
; receive-n a2

receive-n [:a] ; ok

; Compiler internal error
; Where: Where: store-global Near:  [append spec/4 index? tail data-buf]
; b: [:a]
; receive-n b
