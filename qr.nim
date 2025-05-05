# either model 1 or 2 i what is desired for specification here
# https://www.keyence.com/ss/products/auto_id/codereader/basic_2d/qr.jsp

# goes from 21 to 177, but 21 should be ok
# 7 top, 7 bot,  11 in between
const module_size:int = 25

type
    image = array[module_size, array[module_size,bool]]
    point = tuple[x,y:int]

# outer border of black, one layer of white, then center of black
proc write_square(src: point,img:var image, square_len:int) =
    for x_i in src.x..src.x+square_len-1:
        for y_i in src.y..src.y+square_len-1:
            # in between border is white
            if x_i == src.x or x_i == src.x+square_len-1 or
            y_i == src.y or y_i == src.y+square_len-1:
                # outside is black
                img[x_i][y_i] = true
            elif x_i == src.x+1 or x_i == src.x+square_len-2 or 
            y_i == src.y+1 or y_i == src.y+square_len-2:
                # everything else is white
                img[x_i][y_i] = false
            else:
                # inside is black
                img[x_i][y_i] = true

proc encode(input: string): image =
    var img:image

    const corner_size = 7
    write_square((x:0,y:0),img,corner_size)
    write_square((x:module_size-corner_size,y:0),img,corner_size)
    write_square((x:0,y:module_size-corner_size),img,corner_size)


    # set up aligning margins(squares etc)

    # figure out how to encode the characters

    # add ECC, etc.

    # write the data bits to the image

    img


# this will need a different binding in html outputs
import pixie

const cell_size:int = 10
const image_size:int = cell_size*module_size

let qr_code:image = encode("hello")

let screen = newImage(image_size,image_size)
screen.fill(rgba(255,255,255,255))

let ctx = newContext(screen)
ctx.fillStyle = rgba(0, 0, 0, 255)

let
  # pos = vec2(50, 50)
  wh = vec2(float(cell_size), float(cell_size))

for cell_x in 0..module_size-1:
    for cell_y in 0..module_size-1:
        if qr_code[cell_x][cell_y]:
            # echo "cell:", cell_x, ",", cell_y
            # echo "cell_size:", cell_size
            # echo "cast output:", float(cell_x*cell_size)
            let pos = vec2(float(cell_x*cell_size),float(cell_y*cell_size))
            ctx.fillRect(rect(pos, wh))

screen.writeFile("output.png")
