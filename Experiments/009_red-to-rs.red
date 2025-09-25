Red []

str: "from red"

get-str: has [] [str]

#system [
    #call [get-str]
    red-str: as red-string! stack/arguments
]

get-rs-str: routine [] [red-str]

print get-rs-str ; doesn't work
