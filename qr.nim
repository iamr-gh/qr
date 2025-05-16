# either model 1 or 2 i what is desired for specification here
# https://www.keyence.com/ss/products/auto_id/codereader/basic_2d/qr.jsp

# goes from 21 to 177, but 21 should be ok
# 7 top, 7 bot,  11 in between
const module_size:int = 21

# going to implement version 1 for now
# https://commons.wikimedia.org/wiki/File:QR_Character_Placement.svg#/media/File:QR_Character_Placement.svg

proc bit_index(n:int,i:int):bool = bool((n shr i) and 1)

# using a (255,248) Reed Solomon code (shortened to (26,19) code by using "padding") that can correct up to 2 byte-errors. A total of 26 code-words consist of 7 error-correction bytes, and 17 data bytes, in addition to the "Len" (8 bit field), "Enc" (4 bit field), and "End" (4 bit field). The symbol is capable of level L error correction. The EC level is 01(L), and mask pattern is 001. Hence the first 5 bits of the format information are 01001 (without the format mask). After masking, the 5 bits become 11100, as seen here.


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
        img[pos.x][pos.y] = color
        
        pos.x += dir_x
        pos.y += dir_y
        color = not color

proc write_flat(src: point,dst: point,color:bool,img:var image) =
    let 
        dx = dst.x - src.x
        dy = dst.y - src.y
        dir_x = if dx > 0: 1 else: 0
        dir_y = if dy > 0: 1 else: 0

    var 
        pos:point = src

    while pos.x != dst.x or pos.y != dst.y:
        img[pos.x][pos.y] = color
        
        pos.x += dir_x
        pos.y += dir_y

func mask_point(pattern:int, loc:point, color:bool):bool = 
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

# NOT UNIT TESTED

# all used in the v1 method, and 1 is MSB
# thus, 0 is the index of 8
# src is top left in all conventions
proc write_2x4_up(src:point,data:int,img:var image) =
    # 8 7
    # 6 5
    # 4 3 
    # 2 1 

    # code can be condensed with smart indexing
    img[src.x][src.y] = bit_index(data,0)
    img[src.x+1][src.y] = bit_index(data,1)
    img[src.x][src.y+1] = bit_index(data,2)
    img[src.x+1][src.y+1] = bit_index(data,3)
    img[src.x][src.y+2] = bit_index(data,4)
    img[src.x+1][src.y+2] = bit_index(data,5)
    img[src.x][src.y+3] = bit_index(data,6)
    img[src.x+1][src.y+3] = bit_index(data,7)

proc write_2x4_down(src:point,data:int,img:var image) =
    # 2 1
    # 4 3
    # 6 5 
    # 8 7
    img[src.x][src.y+3] = bit_index(data,0)
    img[src.x+1][src.y+3] = bit_index(data,1)
    img[src.x][src.y+2] = bit_index(data,2)
    img[src.x+1][src.y+2] = bit_index(data,3)
    img[src.x][src.y+1] = bit_index(data,4)
    img[src.x+1][src.y+1] = bit_index(data,5)
    img[src.x][src.y] = bit_index(data,6)
    img[src.x+1][src.y] = bit_index(data,7)

proc write_4x2_anti_clockwise(src:point,data:int,img:var image) =
    # 6 5 4 3 
    # 8 7 2 1
    img[src.x][src.y+1] = bit_index(data,0)
    img[src.x+1][src.y+1] = bit_index(data,1)
    img[src.x][src.y] = bit_index(data,2)
    img[src.x+1][src.y] = bit_index(data,3)
    img[src.x+2][src.y] = bit_index(data,4)
    img[src.x+3][src.y] = bit_index(data,5)
    img[src.x+2][src.y+1] = bit_index(data,6)
    img[src.x+3][src.y+1] = bit_index(data,7)

proc write_4x2_clockwise(src:point,data:int,img:var image) =
    # 8 7 2 1 
    # 6 5 4 3
    img[src.x][src.y] = bit_index(data,0)
    img[src.x+1][src.y] = bit_index(data,1)
    img[src.x][src.y+1] = bit_index(data,2)
    img[src.x+1][src.y+1] = bit_index(data,3)
    img[src.x+2][src.y+1] = bit_index(data,4)
    img[src.x+3][src.y+1] = bit_index(data,5)
    img[src.x+2][src.y] = bit_index(data,6)
    img[src.x+3][src.y] = bit_index(data,7)

# inferring from image, doing a zigzag
proc write_2x2(src:point,data:int,img:var image) =
    img[src.x+1][src.y+1] = bit_index(data,0)
    img[src.x+1][src.y] = bit_index(data,1)
    img[src.x][src.y+1] = bit_index(data,2)
    img[src.x][src.y] = bit_index(data,3)

proc encode(input: string): image =
    var img:image

    # all v1, under this format: https://en.wikipedia.org/wiki/QR_code#/media/File:QR_Character_Placement.svg

    let byte_encoding = 0b0100
    # 1 ends up in lower right corner of segment
    write_2x2((x:module_size-2,y:module_size-2),byte_encoding,img)


    let end_encoding = 0b0000

    # enc takes up the 2x2
    write_2x4_up((x:module_size-2,y:module_size-6),input.len,img) #len
    write_2x4_up((x:module_size-2,y:module_size-10),int(input[0]),img) #d1
    write_4x2_anti_clockwise((x:module_size-4,y:module_size-12),int(input[1]),img) #d2
    write_2x4_down((x:module_size-4,y:module_size-10),int(input[2]),img) #d3
    write_2x4_down((x:module_size-4,y:module_size-6),int(input[3]),img) #d4

    write_4x2_clockwise((x:module_size-6,y:module_size-2),int(input[4]),img) #d5
    write_2x4_up((x:module_size-6,y:module_size-6),int(input[5]) ,img) #d6
    write_2x4_up((x:module_size-6,y:module_size-10),int(input[6]),img) #d7

    write_4x2_anti_clockwise((x:module_size-8,y:module_size-12),int(input[7]),img) #d8
    # WRONG here currently
    write_2x4_down((x:module_size-8,y:module_size-10),int(input[8]),img) #d9
    write_2x4_down((x:module_size-8,y:module_size-6),int(input[9]),img) #d10

    write_4x2_clockwise((x:module_size-10,y:module_size-2),int(input[10]),img) #d11
    write_2x4_up((x:module_size-10,y:module_size-6),int(input[11]),img) #d12
    write_2x4_up((x:module_size-10,y:module_size-10),int(input[12]),img) #d13
    write_2x4_up((x:module_size-10,y:module_size-14),int(input[13]),img) #d14

    # break one for the fixed dots
    write_2x4_up((x:module_size-10,y:2),int(input[14]),img) #d15
    write_4x2_anti_clockwise((x:module_size-12,y:0),int(input[15]),img) #d16
    write_2x4_down((x:module_size-12,y:2),int(input[16]),img) # d17

    # in future, we will need to do this variably I think, and then ecc after

    # breaks for the end
    write_2x2((x:module_size-12,y:module_size-14),end_encoding,img) # end encoding
    write_2x4_down((x:module_size-12,y:module_size-12),0b0,img) #e1
    write_2x4_down((x:module_size-12,y:module_size-8),0b0,img) #e2
    write_2x4_down((x:module_size-12,y:module_size-4),0b0,img) #e3

    # lateral segments
    write_2x4_up((x:module_size-14,y:module_size-12),0b0,img) #e4
    # dots break
    write_2x4_down((x:4,y:module_size-12),0b0,img) #e5
    write_2x4_up((x:2,y:module_size-12),0b0,img) #e6
    write_2x4_up((x:0,y:module_size-12),0b0,img) #e7

    # for the larger ones(e.g. ver 3), need to automate this patterning mor

    # all data afterwards will hard rewrite over masking pattern

    # format info(hardcoded v1)
    let mask_pattern = 0b100
    
    mask_image(mask_pattern,img)
    

    const corner_size = 7
    write_square((x:0,y:0),img,corner_size)
    write_square((x:module_size-corner_size,y:0),img,corner_size)
    write_square((x:0,y:module_size-corner_size),img,corner_size)

    # write white borders under this constraint
    write_flat((x:corner_size,y:0),(x:corner_size,y:corner_size),false,img)
    write_flat((x:0,y:corner_size),(x:corner_size,y:corner_size),false,img)

    write_flat((x:module_size-corner_size-1,y:0),(x:module_size-corner_size-1,y:corner_size),false,img)
    write_flat((x:module_size-corner_size,y:corner_size),
                (x:module_size,y:corner_size),false,img)

    write_flat((x:0,y:module_size-corner_size-1),(x:corner_size,y:module_size-corner_size-1),false,img)
    write_flat((x:corner_size,y:module_size-corner_size),(x:corner_size,y:module_size),false,img)

    # fixed patterns
    write_dotted((x:6,y:8),(x:6,y:14),img)
    write_dotted((x:8,y:6),(x:14,y:6),img)

    img[8][13] = true


    assert bit_index(mask_pattern,2) == true
    assert bit_index(mask_pattern,1) == false
    assert bit_index(mask_pattern,0) == false

    # tl

    # ec level
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
    img[2][8] = bit_index(mask_pattern,2)
    img[3][8] = bit_index(mask_pattern,1)
    img[4][8] = bit_index(mask_pattern,0)
    img[5][8] = true
    # img[7][8] = true, post forced point format error correction


    # tr
    # is it reflected?
    # no just seems to be same but different rotation
    img[13][8] = true
    img[14][8] = true
    img[15][8] = true
    img[16][8] = true
    img[17][8] = false
    img[18][8] = false
    img[19][8] = true
    img[20][8] = true

    # bl
    # fmt ecc
    img[8][14] = false 
    img[8][15] = true 
    img[8][16] = bit_index(mask_pattern,0)
    img[8][17] = bit_index(mask_pattern,1)
    img[8][18] = bit_index(mask_pattern,2)
    # ecc level
    img[8][19] = true
    img[8][20] = true

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
# for i in 0..8:
#     var blank:image
#     mask_image(i,blank)
#     screen.fill(rgba(255,255,255,255)) # clear screen
#     writeCode(ctx,blank)
#
#     screen.writeFile("mask_" & $i & ".png")
    
