Red/System []

change-str: func [/local str [c-string!]] [str: "123"]
my-str: "asd"
change-str my-str
print-line my-str

return-str: func [return: [c-string!]] ["123"]
my-str: return-str
print-line my-str

my-str: "qwe"
print-line my-str
my-str: return-str
print-line my-str
