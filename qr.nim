include encoder

# this will need a different binding in html outputs
import pixie

const cell_size:int = 10

proc writeCode(ctx: Context, img: image, moduleSize: int) =
    let wh = vec2(float(cell_size), float(cell_size))
    for cell_x in 0..moduleSize-1:
        for cell_y in 0..moduleSize-1:
            if img[cell_x][cell_y]:
                let pos = vec2(float(cell_x*cell_size), float(cell_y*cell_size))
                ctx.fillRect(rect(pos, wh))

when isMainModule: 
    import os
    
    # Get input from command line or use default
    let input = if paramCount() > 0: paramStr(1) else: "hello world"
    echo &"Generating QR code for: \"{input}\""
    
    let qr_code: image = make_qr_code(input)
    let moduleSize = qr_code.len
    let image_size = cell_size * moduleSize

    let screen = newImage(image_size, image_size)
    screen.fill(rgba(255,255,255,255))

    let ctx = newContext(screen)
    ctx.fillStyle = rgba(0, 0, 0, 255)

    writeCode(ctx, qr_code, moduleSize)

    screen.writeFile("output.png")
    echo &"QR code saved to output.png ({moduleSize}x{moduleSize} modules)"

# test all the different mask patterns
# for i in 0..8:
#     var blank:image
#     mask_image(i,blank)
#     screen.fill(rgba(255,255,255,255)) # clear screen
#     writeCode(ctx,blank)
#
#     screen.writeFile("mask_" & $i & ".png")
