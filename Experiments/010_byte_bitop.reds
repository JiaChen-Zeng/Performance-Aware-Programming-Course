Red/System []

a: 217
b: 192
print-line a and b >> 6

c: #"^(D9)" ; 217
d: #"^(C0)" ; 192
print as-integer c
print " and "
print-line as-integer d
; print-line as-integer c and d >> 6 ; byte need the biggest bit also to be shifted. basic cs mistake
print-line as-integer c and d >>> 6
