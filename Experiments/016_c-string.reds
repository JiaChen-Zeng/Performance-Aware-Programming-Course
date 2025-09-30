Red/System []

str: as-c-string allocate 20
str/2: #"^(00)"
print-line str ; garbage data inside

set-memory as byte-ptr! str #"^(00)" 20
print-line str

str/1: #"a"
str/2: #"b"
str/3: #"c"
print-line str

copy-memory as byte-ptr! str as byte-ptr! "red copied" 10
print-line str
