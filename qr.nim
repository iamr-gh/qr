# either model 1 or 2 i what is desired for specification here
# https://www.keyence.com/ss/products/auto_id/codereader/basic_2d/qr.jsp

# goes from 21 to 177, but 21 should be ok
# 7 top, 7 bot,  11 in between
const module_size:int = 21

# going to implement version 1 for now
# https://commons.wikimedia.org/wiki/File:QR_Character_Placement.svg#/media/File:QR_Character_Placement.svg


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

# magically infer direction
proc write_dotted(src: point,dst: point,img:var image) =
    let 
        dx = dst.x - src.x
        dy = dst.y - src.y
        dir_x = if dx > 0: 1 else: 0
        dir_y = if dy > 0: 1 else: 0

    var 
        color:bool = true
        pos:point = src

    while pos.x != dst.x or pos.y != dst.y:
        if color:
            img[pos.x][pos.y] = true
        
        pos.x += dir_x
        pos.y += dir_y
        color = not color

# remember dark is true
func mask_point(pattern:int, loc:point, color:bool):bool = 
    # let fmt = pattern[0] * 4 + pattern[1] * 2 + pattern[2]
    # var fmt:int = 0
    # for i in 0..2:
    #     fmt = fmt * 2 + (if pattern[i]: 1 else: 0)

    # x is j, y is i in the notion of the image
    case pattern
        of 0b111:
            color xor loc.x mod 3 == 0
        of 0b110:
            color xor (loc.x + loc.y) mod 3 == 0
        of 0b101:
            color xor (loc.x + loc.y) mod 2 == 0
        of 0b100:
            color xor loc.y mod 2 == 0
        of 0b011:
            color xor ((loc.x*loc.y) mod 3 + (loc.x*loc.y)) mod 2 == 0
        of 0b010:
            color xor ((loc.x*loc.y) mod 3 + loc.x + loc.y) mod 2 == 0
        of 0b001:
            color xor (loc.x div 3 + loc.y div 2) mod 2 == 0
        of 0b000:
            color xor (loc.x*loc.y mod 2) + (loc.x*loc.y mod 3) == 0
        else:
            color

proc mask_image(pattern:int, img:var image) =
    for x_i in 0..module_size-1:
        for y_i in 0..module_size-1:
            img[x_i][y_i] = mask_point(pattern,(x:x_i,y:y_i),img[x_i][y_i])

# all used in the v1 method
proc write_2x4_up(src:point,data:array[8,bool],img:var image) =
    echo "todo"

proc write_2x4_down(src:point,data:array[8,bool],img:var image) =
    echo "todo"

proc write_4x2_anti_clockwise(src:point,data:array[8,bool],img:var image) =
    echo "todo"

proc write_4x2_clockwise(src:point,data:array[8,bool],img:var image) =
    echo "todo"

proc encode(input: string): image =
    var img:image

    # all v1, under this format: https://en.wikipedia.org/wiki/QR_code#/media/File:QR_Character_Placement.svg

    const corner_size = 7
    write_square((x:0,y:0),img,corner_size)
    write_square((x:module_size-corner_size,y:0),img,corner_size)
    write_square((x:0,y:module_size-corner_size),img,corner_size)

    # fixed patterns
    write_dotted((x:6,y:8),(x:6,y:14),img)
    write_dotted((x:8,y:6),(x:14,y:6),img)

    img[8][13] = true

    # format info(hardcoded v1)

    # tl
    img[8][0] = true
    img[8][1] = true
    img[8][2] = false
    img[8][3] = false
    img[8][4] = true
    img[8][5] = true

    img[8][7] = true
    img[8][8] = true

    img[0][8] = true
    img[1][8] = true
    img[2][8] = true
    img[3][8] = false
    img[4][8] = false
    img[5][8] = true

    # tr
    img[13][8] = true
    img[14][8] = true
    img[15][8] = true
    img[16][8] = true
    img[17][8] = false
    img[18][8] = false
    img[19][8] = true
    img[20][8] = true

    # bl


    # set up aligning margins(squares etc)

    # figure out how to encode the characters

    # add ECC, etc.

    # write the data bits to the image

    img


# this will need a different binding in html outputs
import pixie

const cell_size:int = 10
const image_size:int = cell_size*module_size

proc writeCode(ctx:Context,img:image) =
    let
      wh = vec2(float(cell_size), float(cell_size))
    for cell_x in 0..module_size-1:
        for cell_y in 0..module_size-1:
            if img[cell_x][cell_y]:
                let pos = vec2(float(cell_x*cell_size),float(cell_y*cell_size))
                ctx.fillRect(rect(pos, wh))

let qr_code:image = encode("www.wikipedia.org")

let screen = newImage(image_size,image_size)
screen.fill(rgba(255,255,255,255))

let ctx = newContext(screen)
ctx.fillStyle = rgba(0, 0, 0, 255)

writeCode(ctx,qr_code)

screen.writeFile("output.png")

# test all the different mask patterns
for i in 0..8:
    var blank:image
    mask_image(i,blank)
    screen.fill(rgba(255,255,255,255)) # clear screen
    writeCode(ctx,blank)

    screen.writeFile("mask_" & $i & ".png")
    
