Red/System []

str: "im string"
str2: "im string"
probe str = str2
probe [as int-ptr! str " " as int-ptr! str2]

istr: func [return: [c-string!]] ["inner string"]
probe [as int-ptr! istr " " as int-ptr! istr]
