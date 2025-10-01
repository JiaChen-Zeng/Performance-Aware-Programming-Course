Red/System []

str: "abcdefg"
p: as byte-ptr! str
print-line p/3

print-line p
pp: as ptr-ptr! :p  ; address of p
; pp/1: pp/1 + 1 ; move pointer p forward 1 unit
pp/value: as int-ptr! (as byte-ptr! pp/value) + 1
print-line p

print-line p
sptr!: alias struct! [value [c-string!]]
pp2: as sptr! :p
pp2/value: pp2/value + 1
print-line p
