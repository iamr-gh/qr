import strutils
include ecc
# QR Code encoder supporting Version 1 and Version 2
# https://commons.wikimedia.org/wiki/File:QR_Character_Placement.svg#/media/File:QR_Character_Placement.svg

# Version configuration
type 
    QRVersion* = enum
        V1 = 1
        V2 = 2

# Module sizes: V1=21, V2=25 (formula: version * 4 + 17)
proc getModuleSize*(version: QRVersion): int =
    case version
    of V1: 21
    of V2: 25

# Data codeword counts (before ECC)
proc getDataCodewords*(version: QRVersion): int =
    case version
    of V1: 19  # 26 total - 7 ECC
    of V2: 34  # 44 total - 10 ECC

# ECC codeword counts
proc getEccCount*(version: QRVersion): int =
    case version
    of V1: 7
    of V2: 10

# Byte mode capacities (after overhead: 4-bit mode + 8-bit length + 4-bit terminator = 2 bytes)
proc getByteCapacity*(version: QRVersion): int =
    case version
    of V1: 17  # 19 - 2
    of V2: 32  # 34 - 2

# Alphanumeric mode capacities (more efficient packing)
proc getAlphanumCapacity*(version: QRVersion): int =
    case version
    of V1: 25
    of V2: 47

# Determine version needed for input
proc selectVersion*(inputLen: int, isAlphanum: bool): QRVersion =
    if isAlphanum:
        if inputLen <= 25: V1 else: V2
    else:
        if inputLen <= 17: V1 else: V2

# Validate input length for maximum supported version (V2)
proc validateInputLength*(inputLen: int, isAlphanum: bool): bool =
    if isAlphanum:
        inputLen <= 47
    else:
        inputLen <= 32

proc bit_index(n:int,i:int):bool = bool((n shr i) and 1)

# using a (255,248) Reed Solomon code (shortened to (26,19) code by using "padding") that can correct up to 2 byte-errors. A total of 26 code-words consist of 7 error-correction bytes, and 17 data bytes, in addition to the "Len" (8 bit field), "Enc" (4 bit field), and "End" (4 bit field). The symbol is capable of level L error correction. The EC level is 01(L), and mask pattern is 001. Hence the first 5 bits of the format information are 01001 (without the format mask). After masking, the 5 bits become 11100, as seen here.

type
    image* = seq[seq[bool]]
    point = tuple[x,y:int]

# Create a new QR image of given size
proc newQRImage*(size: int): image =
    result = newSeq[seq[bool]](size)
    for i in 0..<size:
        result[i] = newSeq[bool](size)

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

proc mask_image(pattern:int, img:var image, moduleSize: int) =
    for x_i in 0..moduleSize-1:
        for y_i in 0..moduleSize-1:
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

# repackage into 8 bit chunks
proc data_repack_byte(enc:int, data_len:int, data:seq[int], end_enc:int):seq[int] = 
    # enc: 4 bit
    # len: 8 bit
    # data: n x 8 bit
    # end: 4 bit

    var chunks_4b:seq[int] = @[]
    chunks_4b.add(enc)
    chunks_4b.add((data_len and 0xf0) shr 4)
    chunks_4b.add(data_len and 0x0f)

    for c in data:
        chunks_4b.add((c and 0xf0) shr 4)
        chunks_4b.add(c and 0x0f)

    chunks_4b.add(end_enc)

    var chunks_8b: seq[int] = @[]
    for i in countup(0,chunks_4b.len-1,2):
        assert chunks_4b[i] < 16
        assert chunks_4b[i+1] < 16
        chunks_8b.add((chunks_4b[i] shl 4) + chunks_4b[i+1])
    chunks_8b

proc alphanumeric_value(c: char): int =
    # Returns 0-44 value for valid alphanumeric chars
    # Note: Only UPPERCASE letters are valid in alphanumeric mode
    # Lowercase letters should use byte mode instead
    if c >= '0' and c <= '9':
        return ord(c) - ord('0')
    elif c >= 'A' and c <= 'Z':
        return ord(c) - ord('A') + 10
    elif c == ' ': return 36
    elif c == '$': return 37
    elif c == '%': return 38
    elif c == '*': return 39
    elif c == '+': return 40
    elif c == '-': return 41
    elif c == '.': return 42
    elif c == '/': return 43
    elif c == ':': return 44
    else: return -1  # Lowercase letters and other chars are invalid

proc pack_alphanum_data(data: seq[int]): seq[int] =
    # Pack pairs of chars into 11 bits
    var bits: seq[bool] = @[]
    
    # Pack pairs of chars into 11 bits
    for i in countup(0,data.len-2,2):
        let val = data[i]*45 + data[i+1] # 11 bits total
        for j in countdown(10,0):
            bits.add(bit_index(val,j))

    # Handle last char if odd length
    if data.len mod 2 == 1:
        let val = data[^1] # 6 bits
        for i in countdown(5,0):
            bits.add(bit_index(val,i))
            
    # Pack bits into bytes
    var chunks_8b: seq[int] = @[]
    for i in countup(0,bits.len-1,8):
        var byte_val = 0
        for j in 0..7:
            if i+j < bits.len and bits[i+j]:
                byte_val = byte_val or (1 shl (7-j))
        chunks_8b.add(byte_val)
    chunks_8b

# Check if a cell is reserved (not for data)
# Reserved areas: finder patterns, separators, timing patterns, format info, alignment pattern (V2+)
proc isReserved(x, y: int, version: QRVersion, moduleSize: int): bool =
    # Finder pattern + separator at top-left (9x9 region)
    if x <= 8 and y <= 8: return true
    # Finder pattern + separator at top-right (9x9 region) 
    if x >= moduleSize - 8 and y <= 8: return true
    # Finder pattern + separator at bottom-left (9x9 region)
    if x <= 8 and y >= moduleSize - 8: return true
    
    # Timing patterns (column 6 and row 6)
    if x == 6 or y == 6: return true
    
    # Alignment pattern for V2 (5x5 centered at 18,18)
    if version == V2:
        if x >= 16 and x <= 20 and y >= 16 and y <= 20: return true
    
    return false

# Place data bits using the standard QR code zigzag pattern
# Per QR spec: Start at bottom-right, move in 2-column stripes
# Within each row: right column first, then left column
# Direction alternates: first stripe goes UP, next goes DOWN, etc.
proc placeBits(img: var image, bits: seq[bool], version: QRVersion, moduleSize: int) =
    var bitIndex = 0
    var x = moduleSize - 1  # Start from rightmost column
    var upward = true  # First stripe goes upward
    
    while x >= 0 and bitIndex < bits.len:
        # Skip timing pattern column (column 6) - move to column 5
        if x == 6:
            x -= 1
        
        # Process 2-column stripe
        if upward:
            # Going up: y from moduleSize-1 to 0
            for y in countdown(moduleSize - 1, 0):
                # For each row, place right column then left column
                for dx in [0, 1]:  # 0 = right column (x), 1 = left column (x-1)
                    let col = x - dx
                    if col >= 0 and not isReserved(col, y, version, moduleSize):
                        if bitIndex < bits.len:
                            img[col][y] = bits[bitIndex]
                            bitIndex += 1
        else:
            # Going down: y from 0 to moduleSize-1
            for y in 0..<moduleSize:
                # For each row, place right column then left column
                for dx in [0, 1]:  # 0 = right column (x), 1 = left column (x-1)
                    let col = x - dx
                    if col >= 0 and not isReserved(col, y, version, moduleSize):
                        if bitIndex < bits.len:
                            img[col][y] = bits[bitIndex]
                            bitIndex += 1
        
        # Move to next 2-column stripe (2 columns to the left)
        x -= 2
        upward = not upward
    
    echo &"Placed {bitIndex} bits out of {bits.len}"

# Apply mask only to data area (not reserved areas)
proc maskDataArea(pattern: int, img: var image, version: QRVersion, moduleSize: int) =
    for x_i in 0..moduleSize-1:
        for y_i in 0..moduleSize-1:
            if not isReserved(x_i, y_i, version, moduleSize):
                img[x_i][y_i] = mask_point(pattern, (x:x_i, y:y_i), img[x_i][y_i])

# Write alignment pattern (5x5) centered at given point - V2+ only
proc writeAlignmentPattern(center: point, img: var image) =
    for dx in -2..2:
        for dy in -2..2:
            let x = center.x + dx
            let y = center.y + dy
            if abs(dx) == 2 or abs(dy) == 2:
                img[x][y] = true  # Outer black border
            elif abs(dx) == 1 or abs(dy) == 1:
                img[x][y] = false  # White ring
            else:
                img[x][y] = true  # Center black dot

# Convert codewords to bit sequence
# QR standard: data is placed MSB first (bit 7 placed first, then bit 6, etc.)
proc codewordsToBits(codewords: seq[int]): seq[bool] =
    result = @[]
    for cw in codewords:
        for i in countdown(7, 0):
            result.add(bit_index(cw, i))

# Alphanumeric mode data packing
# Per QR spec: mode (4 bits) + length (9 bits for V1-V9) + data (11 bits per pair, 6 bits for odd) + terminator (4 bits)
proc data_repack_alphanum(enc:int, data_len:int, data:seq[int], end_enc:int):seq[int] =
    # enc: 4 bit
    # len: 9 bit (for V1-V9 alphanumeric mode)
    # data: pairs of chars packed into 11 bits, odd char in 6 bits
    # end: 4 bit
    
    var bits: seq[bool] = @[]
    
    # Add encoding (4 bits)
    for i in countdown(3,0):
        bits.add(bit_index(enc,i))
        
    # Add length (9 bits for alphanumeric mode V1-V9)
    for i in countdown(8,0):
        bits.add(bit_index(data_len,i))

    # Pack pairs of chars into 11 bits
    for i in countup(0,data.len-2,2):
        let val = data[i]*45 + data[i+1] # 11 bits total
        for j in countdown(10,0):
            bits.add(bit_index(val,j))

    # Handle last char if odd length
    if data.len mod 2 == 1:
        let val = data[^1] # 6 bits
        for i in countdown(5,0):
            bits.add(bit_index(val,i))

    # Add end encoding (4 bits)
    for i in countdown(3,0):
        bits.add(bit_index(end_enc,i))

    # Pack bits into bytes
    var chunks_8b: seq[int] = @[]
    for i in countup(0,bits.len-1,8):
        var byte_val = 0
        for j in 0..7:
            if i+j < bits.len and bits[i+j]:
                byte_val = byte_val or (1 shl (7-j))
        chunks_8b.add(byte_val)
    chunks_8b

# Original V1 hardcoded placement (known working)
proc make_qr_code_v1(input: string, is_alphanum: bool): image =
    const module_size = 21
    var img = newQRImage(module_size)
    
    let byte_encoding = 0b0100
    let alphanum_encoding = 0b0010
    let encoding = if is_alphanum: alphanum_encoding else: byte_encoding
    let end_encoding = 0b0000
    
    # Pad with spaces
    let padded_str = input & repeat(' ', 17 - input.len)
    
    # Get raw data bytes
    var data_seq = newSeq[int](17)
    for i in 0..padded_str.len-1:
        data_seq[i] = int(padded_str[i])
    
    let packed_seq = data_repack_byte(encoding, input.len, data_seq, end_encoding)
    let ecc_code = reed_solomon_v1code(packed_seq)
    
    # Verify test case
    if input == "www.wikipedia.org":
        let correct_seq = @[0x41, 0x17, 0x77, 0x77, 0x72, 0xE7, 0x76, 0x96, 0xB6, 0x97, 0x06, 0x56, 0x46, 0x96, 0x12, 0xE6, 0xF7, 0x26, 0x70]
        assert correct_seq == packed_seq
        assert ecc_code == @[0xAE, 0xAD, 0xEF, 0x06, 0x97, 0x8F, 0x25]
    
    # enc takes up the 2x2
    write_2x2((x:module_size-2, y:module_size-2), encoding, img)
    
    write_2x4_up((x:module_size-2, y:module_size-6), input.len, img) #len
    write_2x4_up((x:module_size-2, y:module_size-10), int(data_seq[0]), img) #d1
    write_4x2_anti_clockwise((x:module_size-4, y:module_size-12), data_seq[1], img) #d2
    write_2x4_down((x:module_size-4, y:module_size-10), data_seq[2], img) #d3
    write_2x4_down((x:module_size-4, y:module_size-6), data_seq[3], img) #d4

    write_4x2_clockwise((x:module_size-6, y:module_size-2), data_seq[4], img) #d5
    write_2x4_up((x:module_size-6, y:module_size-6), int(data_seq[5]), img) #d6
    write_2x4_up((x:module_size-6, y:module_size-10), data_seq[6], img) #d7

    write_4x2_anti_clockwise((x:module_size-8, y:module_size-12), data_seq[7], img) #d8
    write_2x4_down((x:module_size-8, y:module_size-10), data_seq[8], img) #d9
    write_2x4_down((x:module_size-8, y:module_size-6), data_seq[9], img) #d10

    write_4x2_clockwise((x:module_size-10, y:module_size-2), data_seq[10], img) #d11
    write_2x4_up((x:module_size-10, y:module_size-6), data_seq[11], img) #d12
    write_2x4_up((x:module_size-10, y:module_size-10), data_seq[12], img) #d13
    write_2x4_up((x:module_size-10, y:module_size-14), data_seq[13], img) #d14

    # break one for the fixed dots
    write_2x4_up((x:module_size-10, y:2), data_seq[14], img) #d15
    write_4x2_anti_clockwise((x:module_size-12, y:0), data_seq[15], img) #d16
    write_2x4_down((x:module_size-12, y:2), data_seq[16], img) # d17

    # breaks for the end
    write_2x2((x:module_size-12, y:module_size-14), end_encoding, img) # end encoding
    write_2x4_down((x:module_size-12, y:module_size-12), ecc_code[0], img) #e1
    write_2x4_down((x:module_size-12, y:module_size-8), ecc_code[1], img) #e2
    write_2x4_down((x:module_size-12, y:module_size-4), ecc_code[2], img) #e3

    # lateral segments
    write_2x4_up((x:module_size-14, y:module_size-12), ecc_code[3], img) #e4
    # dots break
    write_2x4_down((x:4, y:module_size-12), ecc_code[4], img) #e5
    write_2x4_up((x:2, y:module_size-12), ecc_code[5], img) #e6
    write_2x4_up((x:0, y:module_size-12), ecc_code[6], img) #e7

    # Apply mask to entire image (original working behavior)
    let mask_pattern = 0b100
    mask_image(mask_pattern, img, module_size)
    
    # Fixed patterns drawn AFTER masking
    const corner_size = 7
    write_square((x:0, y:0), img, corner_size)
    write_square((x:module_size-corner_size, y:0), img, corner_size)
    write_square((x:0, y:module_size-corner_size), img, corner_size)

    write_flat((x:corner_size, y:0), (x:corner_size, y:corner_size), false, img)
    write_flat((x:0, y:corner_size), (x:corner_size, y:corner_size), false, img)

    write_flat((x:module_size-corner_size-1, y:0), (x:module_size-corner_size-1, y:corner_size), false, img)
    write_flat((x:module_size-corner_size, y:corner_size), (x:module_size, y:corner_size), false, img)

    write_flat((x:0, y:module_size-corner_size-1), (x:corner_size, y:module_size-corner_size-1), false, img)
    write_flat((x:corner_size, y:module_size-corner_size), (x:corner_size, y:module_size), false, img)

    write_dotted((x:6, y:8), (x:6, y:14), img)
    write_dotted((x:8, y:6), (x:14, y:6), img)

    img[8][13] = true  # Dark module

    # Format info (hardcoded for V1, EC level L, mask 4)
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
    img[2][8] = bit_index(mask_pattern, 2)
    img[3][8] = bit_index(mask_pattern, 1)
    img[4][8] = bit_index(mask_pattern, 0)
    img[5][8] = true

    img[13][8] = true
    img[14][8] = true
    img[15][8] = true
    img[16][8] = true
    img[17][8] = false
    img[18][8] = false
    img[19][8] = true
    img[20][8] = true

    img[8][14] = false
    img[8][15] = true
    img[8][16] = bit_index(mask_pattern, 0)
    img[8][17] = bit_index(mask_pattern, 1)
    img[8][18] = bit_index(mask_pattern, 2)
    img[8][19] = true
    img[8][20] = true

    img

# V2 implementation using zigzag placement (still being debugged)
proc make_qr_code_v2(input: string, is_alphanum: bool): image =
    const moduleSize = 25
    var img = newQRImage(moduleSize)
    
    let byte_encoding = 0b0100
    let alphanum_encoding = 0b0010
    let encoding = if is_alphanum: alphanum_encoding else: byte_encoding
    let end_encoding = 0b0000
    let dataCodewords = 34
    
    # Calculate target capacity
    let targetCapacity = if is_alphanum: 47 else: 32
    let padded_str = input & repeat(' ', targetCapacity - input.len)
    
    # Encode data
    var packed_seq: seq[int]
    if is_alphanum:
        var alphanum_values = newSeq[int](padded_str.len)
        for i in 0..padded_str.len-1:
            alphanum_values[i] = alphanumeric_value(padded_str[i])
        packed_seq = data_repack_alphanum(encoding, input.len, alphanum_values, end_encoding)
    else:
        var byte_values = newSeq[int](padded_str.len)
        for i in 0..padded_str.len-1:
            byte_values[i] = int(padded_str[i])
        packed_seq = data_repack_byte(encoding, input.len, byte_values, end_encoding)
    
    # Pad to required length
    var padByte = 0
    while packed_seq.len < dataCodewords:
        packed_seq.add(if padByte mod 2 == 0: 236 else: 17)
        padByte += 1
    if packed_seq.len > dataCodewords:
        packed_seq.setLen(dataCodewords)
    
    let ecc_code = reed_solomon_v2code(packed_seq)
    
    # Convert to bits and place
    let allCodewords = packed_seq & ecc_code
    let bits = codewordsToBits(allCodewords)
    placeBits(img, bits, V2, moduleSize)
    
    # Apply mask to entire image
    let mask_pattern = 0b100
    mask_image(mask_pattern, img, moduleSize)
    
    # Fixed patterns drawn AFTER masking
    const corner_size = 7
    write_square((x:0, y:0), img, corner_size)
    write_square((x:moduleSize-corner_size, y:0), img, corner_size)
    write_square((x:0, y:moduleSize-corner_size), img, corner_size)

    write_flat((x:corner_size, y:0), (x:corner_size, y:corner_size), false, img)
    write_flat((x:0, y:corner_size), (x:corner_size, y:corner_size), false, img)

    write_flat((x:moduleSize-corner_size-1, y:0), (x:moduleSize-corner_size-1, y:corner_size), false, img)
    write_flat((x:moduleSize-corner_size, y:corner_size), (x:moduleSize, y:corner_size), false, img)

    write_flat((x:0, y:moduleSize-corner_size-1), (x:corner_size, y:moduleSize-corner_size-1), false, img)
    write_flat((x:corner_size, y:moduleSize-corner_size), (x:corner_size, y:moduleSize), false, img)

    write_dotted((x:6, y:8), (x:6, y:moduleSize-8), img)
    write_dotted((x:8, y:6), (x:moduleSize-8, y:6), img)

    img[8][17] = true  # Dark module for V2 (4*2+9=17)

    # Alignment pattern at (18,18)
    writeAlignmentPattern((x: 18, y: 18), img)

    # Format info for EC level L, mask 4: 111011111000100
    img[0][8] = true
    img[1][8] = true
    img[2][8] = true
    img[3][8] = false
    img[4][8] = true
    img[5][8] = true
    img[7][8] = true
    img[8][8] = true

    img[8][0] = true
    img[8][1] = true
    img[8][2] = true
    img[8][3] = false
    img[8][4] = true
    img[8][5] = true
    img[8][7] = true

    img[moduleSize-8][8] = true
    img[moduleSize-7][8] = false
    img[moduleSize-6][8] = false
    img[moduleSize-5][8] = false
    img[moduleSize-4][8] = true
    img[moduleSize-3][8] = false
    img[moduleSize-2][8] = false
    img[moduleSize-1][8] = true

    img[8][moduleSize-7] = true
    img[8][moduleSize-6] = false
    img[8][moduleSize-5] = false
    img[8][moduleSize-4] = false
    img[8][moduleSize-3] = true
    img[8][moduleSize-2] = false
    img[8][moduleSize-1] = false

    img

proc make_qr_code*(input: string): image =
    # Check if input is alphanumeric
    var is_alphanum = true
    for c in input:
        if alphanumeric_value(c) == -1:
            is_alphanum = false
            break

    # Validate input length
    assert validateInputLength(input.len, is_alphanum), 
        "Input too long: max " & (if is_alphanum: "47" else: "32") & " characters"

    # Auto-select version based on input length
    let version = selectVersion(input.len, is_alphanum)
    
    echo &"Version: {version}, is_alphanum: {is_alphanum}"

    # Use appropriate implementation
    if version == V1:
        # Force byte mode for V1 (original working implementation)
        if not is_alphanum:
            return make_qr_code_v1(input, false)
        else:
            # Alphanumeric V1 not yet supported, fall through to byte mode if it fits
            if input.len <= 17:
                return make_qr_code_v1(input, false)
            else:
                echo "Alphanumeric V1 not yet fully supported"
                return make_qr_code_v1(input, false)
    else:
        return make_qr_code_v2(input, is_alphanum)

when isMainModule:
    let img = make_qr_code("Hello World")
    echo img
