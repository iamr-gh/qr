import bitops
import std/strformat

proc bit_index(n:SomeInteger,i:int):bool = bool((n shr i) and 1)

# division is over gf(2^n) so xor is equivalent to subtraction
proc poly_div_rem_gf2(a:int,b:int):int =
    var top = a
    while top > b:
        var to_align = b
        let top_zeros = countLeadingZeroBits(top)
        let b_zeros = countLeadingZeroBits(b)

        to_align = to_align shl (b_zeros - top_zeros)
        assert top_zeros == countLeadingZeroBits(to_align)
        top = top xor to_align
    if top == b:
        0
    else:
        top

# from AI
# I think it's just wrong
proc gfMult(a: SomeInteger, b: SomeInteger): SomeInteger =
    if b == 1:
        a
    elif a == 1:
        b
    else:
        var 
            bb = b
            prod = 0

        # in binary field, mult is and, add/subtract is xor
        for i in 0..7:
            if bit_index(bb,i):
                prod = prod xor (a shl i)
        poly_div_rem_gf2(prod,0x11d)

# 5 bits in, 15 bits out
# a (15,5) triple error-correcting code over GF(2^4) is used
# code has 5 data bits and 10 check sum bits
# generator polynomial is g(x) = x^10 + x^8 + x^5 + x^4 + x^2 + x + 1
proc bch_code(x:range[0..31]):int =
    let g = 0b10100110111
    # the order may need to be double checked of the bits

    # shift message polynomial by multiplying by x^10
    var shifted = x shl 10
    let rem = poly_div_rem_gf2(shifted,g)
    let codeword = shifted + rem

    let final_rem = poly_div_rem_gf2(codeword,g)
    # echo &"{final_rem:b}"
    assert final_rem == 0

    let mask = 0b101010000010010 # xord with to prevent all 0 string
    codeword xor mask

# assuming left is most significant byte(highest power)
proc poly_div_rem_gf8(a:seq[int],b:seq[int]):seq[int] =
    # coefficients are within gf2^8, so can xor
    var top = a
    var to_align = b
    while top.len >= b.len:
        echo &"top:{top}"
        to_align = b

        # WRONG, needs to use inverse which will involve proper multiplication?
        # let top_zeros = countLeadingZeroBits(top[0])
        # let b_zeros = countLeadingZeroBits(b[0])

        # leading digit is a 1, multiply by front to align
        for i in 0..b.len-1:
            to_align[i] = gfMult(top[0],b[i])
        echo &"aligned:{to_align}"
        
        for i in 0..b.len-1:
            top[i] = top[i] xor to_align[i]

        # remove leading zero elements
        while top.len > 0 and top[0] == 0:
            top = top[1..^1]
    top

# using L error correction, (26,19,2) code to match wikipedia page
# generator g(x) = x^7 + 127x^6 + 122x^5 + 154x^4 + 164x^3 + 11x^2 + 68x + 117
proc reed_solomon_v1code(data:seq[int]):seq[int] = 
    # data gets rearranged and packed into blocks of 8 bits each
    let g:seq[int] = @[1,127,122,154,164,11,68,117]

    # need to pad the message 
    let final_rem = poly_div_rem_gf8(data & newSeq[int](g.len),g)
    echo &"{final_rem}"
    # assert poly_div_rem_gf8( data & final_rem,g) == @[]
    final_rem

when isMainModule:
    let bch_codeword = bch_code(0b10101)
    echo &"{bch_codeword:b}"
    assert bch_codeword == (0b101011001000111 xor 0b101010000010010)


    # unit testing gf8 calculations
    # assert gfMult(0x53,0xCA) == 0xC1
    let
        a = 0b10001001
        b = 0b00101010
        r = gfMult(a,b)
    # echo &"{r:b}"
    assert r == 0b11000011
    
    # # test example from wikipedia
    # # [41 17 77 77 72 E7 76 96 B6 97 06 56 46 96 12 E6 F7 26 70]
    let test_input:seq[int] = @[0x41, 0x17, 0x77, 0x77, 0x72, 0xE7, 0x76, 0x96, 0xB6, 0x97, 0x06, 0x56, 0x46, 0x96, 0x12, 0xE6, 0xF7, 0x26, 0x70]
    #
    let reed_solomon = reed_solomon_v1code(test_input)
    echo &"{reed_solomon}"
