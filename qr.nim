include encoder

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

when isMainModule: 
    let qr_code:image = make_qr_code("hello world")

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
