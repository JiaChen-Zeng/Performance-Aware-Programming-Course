Red []

#system [
    rs-var: 123
]

call-rs: routine [] [
    rs-var: rs-var + 432
]

get-rs: routine [return: [integer!]] [
    rs-var
]

print get-rs
call-rs
print get-rs
call-rs
print get-rs
