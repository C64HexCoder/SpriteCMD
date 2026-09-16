SPR_ADDR        = $FB
WRITE_PTR       = $fd
TXTTAB          = $2B
VARTAB          = $2D
LINE_NUMBER     = $f9
NEXT_LINE       = $F7
BYTES_IN_LINE   = $09
NUM_OF_LINES = 63/BYTES_IN_LINE
CHAROUT         = $FFD2

        *=$8000
cruncher
        ldx $7a
        ldy #$00
readLoop
        lda spriteString,y
        beq spriteCMDFound
        cmp $0200,x
        bne notSprite
        inx
        iny
        jmp readLoop

spriteCMDFound 
        lda #$00
        sta SPR_ADDR
        sta SPR_ADDR+1
skipSpaces
        lda $0200,x
        cmp #$00
        beq endOfCMD
        cmp #$20
        beq skipSpace
        cmp #'?'
        bne chkTyp
        jsr printHelp
        jmp endOfCMD
chkTyp
        jsr checkType
endOfCMD
        jmp $a474

skipSpace
        inx
        bne skipSpaces

notSprite

        ldx $7a
        jmp $a57c

checkType
        lda $0200,x
        cmp #'$'
        bne itsNum
        jsr parseHex
        jmp decodeDigit
itsNum
        jsr parseDec
decodeDigit
        lda $fc
        bne convertToData
        jsr convertImgNumToAddress
convertToData
        jsr sprDataToBasic

finisheDecoding
numError
perseError
        rts
convertImgNumToAddress
        ldy #$00
        ;sty $fc
        clc
        ldx #$06
lsrLoop
        asl $fb
        rol $fc
        dex
        bne lsrLoop
        rts

sprDataToBasic
        lda TXTTAB
        sta origTexTab
        lda TXTTAB+1
        sta origTexTab+1

        jsr findEndOfBasic

       
newLine    
        ; save the placeholder for the next basic line
        lda TXTTAB
        sta NEXT_LINE
        lda TXTTAB+1
        sta NEXT_LINE+1
  

        ldy #$02
        ldx #$00

     
        lda LINE_NUMBER
        STA (TXTTAB),y
        iny
        lda LINE_NUMBER+1
        sta (TXTTAB),y
        iny

        jsr incLineNum

        lda #$83        ;DATA token
        sta (TXTTAB),y
        iny

        lda #$20
        sta (TXTTAB),y
        iny

copyDataloop
        lda (SPR_ADDR,X)
       
        jsr numToAscii
        jsr incSprData
        dec bytesInLine
        beq endOfLine
        lda #$2c
        sta (TXTTAB),y
        iny
        jmp copyDataloop

endOfLine
        lda #BYTES_IN_LINE
        sta bytesInLine

        ; put 00 at end of line
        lda #$00
        sta (TXTTAB),y
        iny
        
        tya
        ldy #$00
        clc
        adc TXTTAB
        sta TXTTAB
     
        lda TXTTAB+1
        adc #$00
        sta TXTTAB+1
        
        ldy #$00
        lda TXTTAB
        sta (NEXT_LINE),y
        iny
        lda TXTTAB+1
        sta (NEXT_LINE),y


        dec dataLines
        bne newLine
        
        ldy #$00
        lda #$00
        sta (TXTTAB),y
        iny
        sta (TXTTAB),y
        
 
        clc
        lda TXTTAB
        adc #$02
        sta $2d
        sta $2f
        sta $31
        lda TXTTAB+1
        adc #$00
        sta $2e
        sta $30
        sta $32
   
        lda origTexTab
        sta TXTTAB
        lda origTexTab+1
        sta TXTTAB+1
 
        lda #NUM_OF_LINES
        sta dataLines

        rts

incSprData
        clc
        lda SPR_ADDR
        adc #$01
        sta SPR_ADDR
        lda SPR_ADDR+1
        adc #00
        sta SPR_ADDR+1
        rts
        
incLineNum
        clc
        lda LINE_NUMBER
        adc #$0A
        sta LINE_NUMBER
        lda LINE_NUMBER+1
        adc #00
        sta LINE_NUMBER+1
        rts      
checkIfNum
        cmp #'0'
        bcc notANumber
        cmp #'9'+1
        bcs notANumber     
        rts
notANumber
        lda #$00                ;return 1 if it's not a number
        rts

checkIfAlpha
        cmp #'a'
        bcc notAlpha    
        cmp #'f'+1
        bcs notAlpha
        rts
notAlpha
        lda #$00    
        rts
checkIfHex
        jsr checkIfNum
        beq returnTrue
        jsr checkIfAlpha
        beq returnTrue
        lda #$00   
        rts
returnTrue
        rts

parseHex
        inx
        lda $0200,x
       ; beq endOfHex
        ;cmp #$20
        ;beq endOfHex

        cmp #'0'                ; compare to '0' char
        bcc paseHexError        ; if less then '0' then error

        cmp #$40                ;compare to 'A' if bigger then not a digit
        bcs hexNum

        pha
        ldy #$00
@shiftLeft        
        asl $fb
        rol $fc
        iny
        cpy #$04
        bne @shiftLeft

        pla
   
        sec
        sbc #'0'
        ora $fb
        sta $fb
              
        jmp parseHex
    
hexNum
        cmp #$41                        ; Is it smaller then 'A'
        bcc paseHexError                ; if so then error
        cmp #$46+1                      ; if its greater the
        bcs paseHexError

        pha
        ldy #$00
shiftLeft        
        asl $fb
        rol $fc
        iny
        cpy #$04
        bne shiftLeft
        pla

        sec
        sbc #$41-10
        ora $fb
        sta $fb

        jmp parseHex

endOfHex
paseHexError
       rts
parseDec
        lda #$00
        sta $fb
        sta $fc
readNumber
        lda $0200,x
        cmp #$00
        beq endOfNum
        cmp #$20
        beq readNumber

        cmp #'0'                ; compare to '0' char
        bcc notDigit        ; if less then '0' then error

        cmp #$40            ;compare to 'A' if bigger then not a digit
        bcs notDigit

        sec
        sbc #$30
        
        pha
        jsr MulBy10
        pla

        clc
        adc $fb
        sta $fb
        lda $fc
        adc #$00
        sta $fc
        inx
        bne readNumber

endOfNum        
notDigit
        rts

MulBy10
        ; 1. הכפלה ב-2 (N * 2)
        asl $fb
        rol $fc

        ; 2. שמירת (N * 2) בזיכרון זמני
        lda $fb
        sta tmpFB
        lda $fc
        sta tmpFB+1

        ; 3. שתי הזזות נוספות של הערך הקיים כדי להגיע ל-(N * 8)
        asl $fb
        rol $fc         ; כעת זה N * 4
        asl $fb
        rol $fc         ; כעת זה N * 8

        ; 4. חיבור: (N * 8) + (N * 2) = N * 10
        clc
        lda $fb
        adc tmpFB
        sta $fb
        lda $fc
        adc tmpFB+1
        sta $fc

        rts



        ; divide A by 10
        ; result in x reminder in A

devideBy10
        ldx #$00
divLoop
        cmp #$0a
        bcc endDiv
        inx
        sec
        sbc #$0a
        jmp divLoop
endDiv
        rts

; ================================================================
; Routine: devideBy10_Binary
; Divides an 8-bit unsigned integer by 10 using binary long division.
;
; Inputs:  A = Dividend (0 - 255)
; Outputs: X = Quotient (A / 10)
;          A = Remainder (A % 10)
; Preserves: Y register (Untouched, safe for outer loops)
; Requires: 1 byte of Zero Page or RAM memory (tmpFB)
; ================================================================

devideBy10_Binary
        sta tmpFB           ; Store the original dividend in a temporary buffer
        lda #$00            ; Clear accumulator (will accumulate the remainder)
        ldx #$08            ; Loop counter: 8 bits to process

@divLoop
        asl tmpFB           ; Shift the MSB of the dividend out into the Carry flag.
                            ; (This also forces bit 0 of tmpFB to become 0)
                            
        rol                 ; Rotate the Carry bit into the remainder accumulator (A)
                            
        cmp #10             ; Compare the accumulated remainder against the divisor (10)
        bcc @skipSub        ; If remainder < 10, branch and leave bit 0 of tmpFB as 0
        
        sbc #10             ; If remainder >= 10, subtract 10 from the remainder
        inc tmpFB           ; Increment tmpFB to set bit 0 to 1 (this is the quotient bit)

@skipSub
        dex                 ; Decrement the bit loop counter
        bne @divLoop        ; Repeat the loop until all 8 bits are processed

        ldx tmpFB           ; Move the final completed quotient from the buffer into X
        
        ; At this point, A already retains the correct remainder (A = A % 10)
        rts

numToAscii
        ; convert Int in A to ascii Number
        ; A = number to convertImgNumToAddress
        sty tmpY

        ldy #$00
convertLoop
        jsr devideBy10_Binary
        
        clc
        adc #$30
        
        pha
        iny

        txa
        cmp #$00
        bne convertLoop

        tya
        tax
        ldy tmpY
@printLoop
        pla
        sta (TXTTAB),y
        iny
        dex
        bne @printLoop
             
        rts



printHelp
        ldx #$00
printLoop
        lda helpText,x
        beq endString
        jsr CHAROUT
        inx
        bne printLoop
endString
        rts
findEndOfBasic
        lda TXTTAB
        sta WRITE_PTR
        lda TXTTAB+1
        sta WRITE_PTR+1

        ldy #$01
        lda (WRITE_PTR),y
        bne hasProgram
                                ;FOUND BASIC    
        lda #$e8
        sta LINE_NUMBER
        lda #$03
        sta LINE_NUMBER+1
        rts

hasProgram
        ldy #$01
        lda (WRITE_PTR),y
        sta NEXT_LINE+1
        dey
        lda (WRITE_PTR),y
        sta NEXT_LINE

        ldy #$01
        lda (NEXT_LINE),y
        beq endOfProgram

        LDA NEXT_LINE
        sta WRITE_PTR
    
        lda NEXT_LINE+1
        sta WRITE_PTR+1

        jmp hasProgram

endOfProgram

        ldy #$02
        clc
        lda (WRITE_PTR),y
        adc #$0a
        sta LINE_NUMBER
        iny
        lda (WRITE_PTR),y
        adc #$00
        sta LINE_NUMBER+1

        lda NEXT_LINE
        sta TXTTAB
        lda NEXT_LINE+1
        sta TXTTAB+1

        rts

spriteString
        byte "sprite",0
tmpY    byte 0
tmpX    byte 0
tmpFB   byte 0,0

bytesInLine byte BYTES_IN_LINE
dataLines byte NUM_OF_LINES

; Colors: 0=Black, 1=White, 2=Red, 3=Cyan, 4=Purple, 5=Green, 6=Blue, 7=Yellow, 8=Orange, 9=Brown, 10=Light Red, 11=Dark Gray, 12=Medium Gray, 13=Light Green, 14=Light Blue, 15=Light Gray

helpText
        byte $0D                ; Carriage Return (CR)
        
        ; Syntax line: title in yellow, description in white
        byte $9E, "syntax: ", $05, "sprite [frame/addr]", $0D
        
        ; Hex example: title in cyan, description in white
        byte $9F, "hex: ", $05, "$c0 or $3000", $0D
        
        ; Decimal example: title in green, description in white
        byte $1E, "dec: ", $05, "192 or 12288", $0D
        
        ; Reset text color to system default (light blue) and null-terminate string
        byte $9A, $00

origTexTab byte 01,08


        *=$c000
init
        lda #<cruncher
        sta $304
        lda #>cruncher
        sta $305

 
        rts