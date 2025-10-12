Red []

rsf: routine [return: [integer!]] [100]

my-image: [
    pen off
    fill-pen red
    box 1x1 10x10
    box 100x100 110x110
]

i: 0
loop rsf [
    color: random white
    p: random 400x400
    repend my-image ['fill-pen color 'box p (p + 10x10)]
]

?? my-image

view [
    base 400x400 draw my-image
    image 400x400
]