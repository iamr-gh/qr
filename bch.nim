import bitops
import std/strformat

# division is over gf(2^n) so xor is equivalent to subtraction
proc poly_div_rem(a:int,b:int):int =
    var top = a
    while top > b:
        var to_align = b

        let top_zeros = countLeadingZeroBits(top)
        let b_zeros = countLeadingZeroBits(b)
        # if needed multiplier, would extract here
        to_align = to_align shl (b_zeros - top_zeros)

        assert top_zeros == countLeadingZeroBits(to_align)
        top = top xor to_align
    if top == b:
        0
    else:
        top

# 5 bits in, 15 bits out
proc bch_code(x:range[0..31]):int =
    # a (15,5) triple error-correcting code over GF(2^4) is used
    # code has 5 data bits and 10 check sum bits
    # generator polynomial is g(x) = x^10 + x^8 + x^5 + x^4 + x^2 + x + 1
    let g = 0b10100110111

    # echo &"{x:b}"

    # the order may need to be double checked of the bits

    # process: 
    # convert 5 bit int into a polynomial
    # shift message polynomial by multiplying by x^10
    var shifted = x shl 10
    # echo &"{shifted:b}"
    # remainder is the parity bits
    let rem = poly_div_rem(shifted,g)
    # echo &"{rem:b}"

    # then, message || parity is the output codeword
    let codeword = shifted + rem
    # echo &"{codeword:b}"

    let final_rem = poly_div_rem(codeword,g)
    # echo &"{final_rem:b}"
    assert final_rem == 0

    # aka shifted message + remainder
    let mask = 0b101010000010010 # xord with to prevent all 0 string
    codeword xor mask

let code = bch_code(0b10101)
# echo &"{code:b}"
