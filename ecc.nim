import bitops
import std/strformat

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

# assuming left is most significant byte(highest power)
proc poly_div_rem_gf8(a:seq[uint8],b:seq[uint8]):seq[uint8] =
    # coefficients are within gf2^8, so can xor
    var top = a
    while top.len >= b.len:
        echo &"top:{top}"
        var to_align = b
        let top_zeros = countLeadingZeroBits(top[0])
        let b_zeros = countLeadingZeroBits(b[0])
        for i in 0..b.len-1:
            to_align[i] = to_align[i] shl (b_zeros - top_zeros)

        # echo &"top[0]{top[0]:b} to_align[0]{to_align[0]:b}"
        
        for i in 0..b.len-1:
            top[i] = top[i] xor to_align[i]
        # remove leading zero elements
        while top[0] == 0:
            top = top[1..^1]
    top

# 5 bits in, 15 bits out
# a (15,5) triple error-correcting code over GF(2^4) is used
# code has 5 data bits and 10 check sum bits
# generator polynomial is g(x) = x^10 + x^8 + x^5 + x^4 + x^2 + x + 1
proc bch_code(x:range[0..31]):int =
    let g = 0b10100110111

    # echo &"{x:b}"
    # the order may need to be double checked of the bits

    # process: 
    # convert 5 bit int into a polynomial
    # shift message polynomial by multiplying by x^10
    var shifted = x shl 10
    # echo &"{shifted:b}"
    # remainder is the parity bits
    let rem = poly_div_rem_gf2(shifted,g)
    # echo &"{rem:b}"

    # then, message || parity is the output codeword
    # aka shifted message + remainder
    let codeword = shifted + rem
    # echo &"{codeword:b}"

    let final_rem = poly_div_rem_gf2(codeword,g)
    # echo &"{final_rem:b}"
    assert final_rem == 0

    let mask = 0b101010000010010 # xord with to prevent all 0 string
    codeword xor mask

# using L error correction, (26,19,2) code to match wikipedia page
# generator g(x) = x^7 + 127x^6 + 122x^5 + 154x^4 + 164x^3 + 11x^2 + 68x + 117
proc reed_solomon_v1code(data:seq[uint8]):seq[uint8] = 
    # data gets rearranged and packed into blocks of 8 bits each
    let g:seq[uint8] = @[1,127,122,154,164,11,68,117]
    let final_rem = poly_div_rem_gf8(data,g)
    echo &"{final_rem}"
    # assert poly_div_rem_gf8( data & final_rem,g) == @[]
    final_rem

when isMainModule:
    let bch_codeword = bch_code(0b10101)
    echo &"{bch_codeword:b}"
    assert bch_codeword == (0b101011001000111 xor 0b101010000010010)

    # test example from wikipedia
    # [41 17 77 77 72 E7 76 96 B6 97 06 56 46 96 12 E6 F7 26 70]
    let test_input:seq[uint8] = @[0x41, 0x17, 0x77, 0x77, 0x72, 0xE7, 0x76, 0x96, 0xB6, 0x97, 0x06, 0x56, 0x46, 0x96, 0x12, 0xE6, 0xF7, 0x26, 0x70]

    let reed_solomon = reed_solomon_v1code(test_input)
    echo &"{reed_solomon}"
