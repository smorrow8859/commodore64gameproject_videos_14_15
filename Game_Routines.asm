;===============================================================================
; GAME CORE ROUTINES
;===============================================================================
; Core routines for the framework - Peter 'Sig' Hewett
; 2016
;-------------------------------------------------------------------------------
; Wait for the raster to reach line $f8 - if it's aleady there, wait for
; the next screen blank. This prevents mistimings if the code runs too fast
#region "WaitFrame"
WaitFrame
        lda VIC_RASTER_LINE         ; fetch the current raster line
        cmp #$F8                    ; wait here till l        
        beq WaitFrame           
        
@WaitStep2
        lda VIC_RASTER_LINE
        cmp #$F8
        bne @WaitStep2
        rts
#endregion        
;-------------------------------------------------------------------------------
; UPDATE TIMERS
;-------------------------------------------------------------------------------
; 2 basic timers - a fast TIMER that is updated every frame,
; and a SLOW_TIMER updated every 16 frames
;-------------------------------------------------------------------------------
#region "UpdateTimers"
UpdateTimers
        inc TIMER                       ; increment TIMER by 1
        lda TIMER
        and #$0F                        ; check if it's equal to 16
        beq @updateSlowTimer            ; if so we update SLOW_TIMER        
        rts

@updateSlowTimer
        inc SLOW_TIMER                  ; increment slow timer
        rts

;===============================================================================
; ANIMATION TIMER
;===============================================================================
AnimScreenControl
        lda $CB
        cmp #60
        bne @exit
        clc
        adc #1
        lda animLevel
        sta animLevel 
        sta 53280
        rts

@exit
        rts

WhichKey
        lda $CB
        cmp #60
        bne @exitKey
        lda #2
        sta 53280

@exitKey
        rts

;===============================================================================
; TILE DISPLAY (Future)
;===============================================================================
PlotATile
        ldx #70                        ; (129,26=default), 61
        ldy #20                          ; , 27

        jsr TileMap                     ; Draw the level map (Screen1)
                                        ; And initialize it

        jsr CopyToBuffer                ; Copy to the backbuffer(Screen2)
        rts

;===============================================================================
; SCORE PANEL DISPLAY
;===============================================================================
ScoreBoard
        sta PARAM4                                      ; gamescore data
        jsr GetLineAddress

        lda COLOR_LINE_OFFSET_TABLE_LO,x                ; fetch line address for color
        sta ZEROPAGE_POINTER_3
        lda COLOR_LINE_OFFSET_TABLE_HI,x
        sta ZEROPAGE_POINTER_3 + 1
        

;===============================================================================
; Gamescore counter 0-9 + carry bit (into high nybble)
;===============================================================================
        lda GAMESCORE_ACTIVE
        bne @scorePoints
        rts

@scorePoints
        sed
        clc
        lda gamescore                                   ; increase score
        adc PLAYER_CASH                                          ; 01,00
        sta gamescore
        lda gamescore+1
        adc #0                                          ;00, 00
        sta gamescore+1
        lda gamescore+2
        adc #0
        sta gamescore+2
        cld
        jsr display
        rts

display
        ldy #12          ;screen offset
        ldx #0          ; score byte index
sloop
        lda gamescore,x
        pha
        and #$0f        ; count between 0-9
        jsr plotdigit

        pla
        lsr a
        lsr a
        lsr a
        lsr a
        jsr plotdigit
        inx
        cpx #3
        bne sloop

        lda #0
        sta GAMESCORE_ACTIVE
        rts

plotdigit
        clc
        adc #48                                      ; write '0' zero on screen
        sta (ZEROPAGE_POINTER_1),y                   ; write the character code
        lda #COLOR_CYAN                              ; set the color to blue
        sta (ZEROPAGE_POINTER_3),y                   ; write the color to color ram  
        dey
        rts

#endregion

CashCounter
        sed
        clc
        lda PLAYER_CASH                                 ; increase score
        adc #1                                          ; 01,00
        sta PLAYER_CASH
        lda PLAYER_CASH+1
        adc #0                                          ;00, 00
        sta PLAYER_CASH+1
        lda PLAYER_CASH+2
        adc #0
        sta PLAYER_CASH+2
        cld
        jsr cashdisplay
        rts

cashdisplay
        ldy #12          ;screen offset
        ldx #0          ; score byte index
cashloop
        lda PLAYER_CASH,x
        pha
        and #$0f        ; count between 0-9
        jsr placedigit

        pla
        lsr a
        lsr a
        lsr a
        lsr a
        jsr placedigit
        inx
        cpx #3
        bne cashloop
        rts

placedigit
        clc
        adc #48                                      ; write '0' zero on screen
        sta (ZEROPAGE_POINTER_1),y                   ; write the character code
        lda #COLOR_BLUE                              ; set the color to blue
        sta (ZEROPAGE_POINTER_3),y                   ; write the color to color ram  
        dey
        rts
;-------------------------------------------------------------------------------
;  READ JOY 2
;-------------------------------------------------------------------------------
; Trying this a different way this time.  Rather than hitting the joystick 
; registers then
; doing something every time - The results will be stored in JOY_X and JOY_Y 
; with values -1 to 1 , with 0 meaning 'no input' 
; - I should be able to just add this to a 
; sprite for a
; simple move, while still being able to do an easy check for more complicated 
; movement later on
;-------------------------------------------------------------------------------
#region "ReadJoystick"

ReadJoystick
        lda #$00                        ; Reset JOY X and Y variables
        sta JOY_X
        sta JOY_Y
        sta NE_DIR
@testUp                                 ; Test for Up pressed
        lda checkup                     ; Mask for bit 0
        bit JOY_2                       ; test bit 0 for press
        bne @testDown
        lda #$FF                        ; set JOY_Y to -1 ($FF)
        sta JOY_Y
        jmp @testLeft                   ; Can't be up AND down

@testDown                               ; Test for Down
        lda checkdown                   ; Mask for bit 1
        bit JOY_2
        bne @testLeft
        lda #$01                        ; set JOY_Y to 1 ($01)
        sta JOY_Y
        rts
@testLeft                               ; Test for Left
        lda checkleft                   ; Mask for bit 2
        bit JOY_2
        bne @testRight
        lda #$FF
        sta JOY_X
        rts                             ; Can't be left AND right - no more tests

@testRight                              ; Test for Right
        lda checkright                  ; Mask for bit 3
        bit JOY_2
        bne @checkUpLeft
        lda #$01
        sta JOY_X
        rts   

@checkUpLeft                            ; check zero = button pressed
        lda #%00010000
        bit JOY_2                       ; check zero = button pressed
        bne @testDownRight              ; continue other checks

@testUpLeft
        lda #1
        sta NE_DIR
        rts

@testDownRight                          ; Test for Right
        lda checkdownright              ; Mask for bit 3
        bit JOY_2
        bne @done
        lda #$02
        sta NE_DIR
        rts 

@done    
        rts

#endregion
;-------------------------------------------------------------------------------
; JOYSTICK BUTTON PRESSED
;-------------------------------------------------------------------------------
; Notifies the state of the fire button on JOYSTICK 2.
; BUTTON_ACTION is set to one on a single press 
; (that is when the button is released)
; BUTTON_PRESSED is set to 1 while the button is held down.
; So either a long press, or a single press can be accounted for.
; TODO I might put a 'press counter' in here to test how long the button is 
; down for..
;-------------------------------------------------------------------------------
#region "JoyButton"

JoyButton

        lda #1                                  ; checks for a previous button action
        cmp BUTTON_ACTION                       ; and clears it if set
        bne @buttonTest

        lda #0                                  
        sta BUTTON_ACTION

@buttonTest
        lda #$10                                ; test bit #4 in JOY_2 Register
        bit JOY_2
        bne @buttonNotPressed
        
        lda #1                                  ; if it's pressed - save the result
        sta BUTTON_PRESSED                      ; and return - we want a single press
        rts                                     ; so we need to wait for the release

@buttonNotPressed

        lda BUTTON_PRESSED                      ; and check to see if it was pressed first
        bne @buttonAction                       ; if it was we go and set BUTTON_ACTION
        rts

@buttonAction
        lda #0
        sta BUTTON_PRESSED
        lda #1
        sta BUTTON_ACTION

        rts

#endregion        

;-------------------------------------------------------------------------------
; COPY CHARACTER SET
;-------------------------------------------------------------------------------
; Copy the custom character set into the VIC Memory Bank (2048 bytes)
; ZEROPAGE_POINTER_1 = Source
; ZEROPAGE_POINTER_2 = Dest
;
; Returns A,X,Y and PARAM2 intact
;-------------------------------------------------------------------------------

#region "CopyChars"

CopyChars
        
        saveRegs

        ldx #$00                                ; clear X, Y, A and PARAM2
        ldy #$00
        lda #$00
        sta PARAM2
@NextLine

; CHAR_MEM = ZEROPAGE_POINTER_1
; LEVEL_1_CHARS = ZEROPAGE_POINTER_2

        lda (ZEROPAGE_POINTER_1),Y              ; copy from source to target
        sta (ZEROPAGE_POINTER_2),Y

        inx                                     ; increment x / y
        iny                                     
        cpx #$08                                ; test for next character block (8 bytes)
        bne @NextLine                           ; copy next line
        cpy #$00                                ; test for edge of page (256 wraps back to 0)
        bne @PageBoundryNotReached

        inc ZEROPAGE_POINTER_1 + 1              ; if reached 256 bytes, increment high byte
        inc ZEROPAGE_POINTER_2 + 1              ; of source and target

@PageBoundryNotReached
        inc PARAM2                              ; Only copy 254 characters (to keep irq vectors intact)
        lda PARAM2                              ; If copying to F000-FFFF block
        cmp #255
        beq @CopyCharactersDone
        ldx #$00
        jmp @NextLine

@CopyCharactersDone

        restoreRegs

        rts
#endregion

; y=210 - stone wall scrolls
; y=186 - bottom of water tile (top part)
; y=194 (current)

;===============================================================================
; WATER ANIMATION FRAMES
;===============================================================================
WaterAnimation
        lda RIVER_ANIM3_LO
        sta ZEROPAGE_POINTER_3
        lda RIVER_ANIM3_HI
        sta ZEROPAGE_POINTER_3 + 1

@contAnim
        ldy #0 
        ldx #0                

; Still looping the animation
@shiftPixelsRight
; Get all 8 bits (128,64,32,16,8,4,2,1)

@store2
        lda CHRADR3,y
        lsr a
        bcc @store5
        clc        
        adc #128                 ; shift pixels down
;;        
@store5
        sta (ZEROPAGE_POINTER_3),y
        iny

; This comparison checks for the tile width + (all 4 tiles)
; In a 4x4 matrix. Because 4 x 4 = 16
        cpy #48                         ;58                                         
        bcc @shiftPixelsRight
        rts

ReadCharsetAddress
@screen1
        lda MAPSCREEN1_CHSET_OFFSET_TABLE_LO,y  ; Use Y to lookup the address and save it in
        sta ZEROPAGE_POINTER_4                  ; ZEROPAGE_POINTER_1
        lda MAPSCREEN1_CHSET_OFFSET_TABLE_HI,y
        sta ZEROPAGE_POINTER_4 + 1
        rts

riverAnimation
        clc
        lda waterSpeed                           ; increase score
        adc #1                                   ; 01,00
        sta waterSpeed
        
        lda waterSpeed
        cmp #40
        bcc @exitLoop

        lda CURRENT_SCREEN + 1          ; Hi byte of the current screen
        cmp #>SCREEN2_MEM               ; compare to start of Screen2
        beq @screen2_scene1

        lda #102                  ; Set VIC to Screen0, Charset 1
        sta VIC_MEMORY_CONTROL
        lda #5
        sta 53280
        jmp @scrollwater1

@screen2_scene1          
        lda #2                  ; Set VIC to Screen1, Charset 1
        sta VIC_MEMORY_CONTROL
        lda #3
        sta 53280

@scrollwater1       
        lda waterSpeed
        cmp #80
        bcc @exitLoop

        lda CURRENT_SCREEN + 1          ; Hi byte of the current screen
        cmp #>SCREEN2_MEM               ; compare to start of Screen2
        beq @screen2_scene2

        lda #102
        sta VIC_MEMORY_CONTROL
        lda #2
        sta 53280
        jmp @scrollwater2

@screen2_scene2          
        lda #102                 ; Set VIC to Screen1, Charset 1
        sta VIC_MEMORY_CONTROL
        lda #7
        sta 53280

@scrollwater2
        lda waterSpeed
        cmp #120
        bcc @exitLoop

        lda #0
        sta waterSpeed

@exitLoop
        rts

riverAnimation2
        clc
        lda waterSpeed                 ; increase score
        adc #1                         ; 01,00
        sta waterSpeed
        
        lda waterSpeed
        cmp #30
        bcc @exitLoop

        lda #20                         ; 20 = $5000 - Parkour Redo ChsetNew1.bin"
        sta VIC_MEMORY_CONTROL  
      
        lda waterSpeed
        cmp #70
        bcc @exitLoop

        lda waterSpeed
        cmp #110
        bcc @exitLoop

        lda #0
        sta waterSpeed

@exitLoop
        rts


MAPSCREEN1_CHSET_OFFSET_TABLE_LO
        byte <MAP_CHAR_MEM
        byte <MAP_CHAR_MEM + 8
        byte <MAP_CHAR_MEM + 16
        byte <MAP_CHAR_MEM + 24
        byte <MAP_CHAR_MEM + 32
        byte <MAP_CHAR_MEM + 40
        byte <MAP_CHAR_MEM + 48
        byte <MAP_CHAR_MEM + 56
        byte <MAP_CHAR_MEM + 64
        byte <MAP_CHAR_MEM + 72
        byte <MAP_CHAR_MEM + 80
        byte <MAP_CHAR_MEM + 88
        byte <MAP_CHAR_MEM + 96
        byte <MAP_CHAR_MEM + 104
        byte <MAP_CHAR_MEM + 112
        byte <MAP_CHAR_MEM + 120
        byte <MAP_CHAR_MEM + 128
        byte <MAP_CHAR_MEM + 136
        byte <MAP_CHAR_MEM + 144
        byte <MAP_CHAR_MEM + 152
        byte <MAP_CHAR_MEM + 160
        byte <MAP_CHAR_MEM + 168
        byte <MAP_CHAR_MEM + 176
        byte <MAP_CHAR_MEM + 184
        byte <MAP_CHAR_MEM + 192
        byte <MAP_CHAR_MEM + 200
        byte <MAP_CHAR_MEM + 208
        byte <MAP_CHAR_MEM + 216
        byte <MAP_CHAR_MEM + 224
        byte <MAP_CHAR_MEM + 232
        byte <MAP_CHAR_MEM + 240
        byte <MAP_CHAR_MEM + 248
        byte <MAP_CHAR_MEM + 256
        byte <MAP_CHAR_MEM + 264
        byte <MAP_CHAR_MEM + 272        
        byte <MAP_CHAR_MEM + 280
        byte <MAP_CHAR_MEM + 288
        byte <MAP_CHAR_MEM + 296
        byte <MAP_CHAR_MEM + 304
        byte <MAP_CHAR_MEM + 312
        byte <MAP_CHAR_MEM + 320        ;40
        byte <MAP_CHAR_MEM + 328
        byte <MAP_CHAR_MEM + 336
        byte <MAP_CHAR_MEM + 344
        byte <MAP_CHAR_MEM + 352
        byte <MAP_CHAR_MEM + 360
        byte <MAP_CHAR_MEM + 368
        byte <MAP_CHAR_MEM + 376
        byte <MAP_CHAR_MEM + 384        
        byte <MAP_CHAR_MEM + 392
        byte <MAP_CHAR_MEM + 400        ;50
        byte <MAP_CHAR_MEM + 408
        byte <MAP_CHAR_MEM + 416
        byte <MAP_CHAR_MEM + 424
        byte <MAP_CHAR_MEM + 432
        byte <MAP_CHAR_MEM + 440
        byte <MAP_CHAR_MEM + 448
        byte <MAP_CHAR_MEM + 456        
        byte <MAP_CHAR_MEM + 464
        byte <MAP_CHAR_MEM + 472
        byte <MAP_CHAR_MEM + 480
        byte <MAP_CHAR_MEM + 488
        byte <MAP_CHAR_MEM + 496
        byte <MAP_CHAR_MEM + 504
        byte <MAP_CHAR_MEM + 512
        byte <MAP_CHAR_MEM + 520
        byte <MAP_CHAR_MEM + 528
        byte <MAP_CHAR_MEM + 536
        byte <MAP_CHAR_MEM + 544
        byte <MAP_CHAR_MEM + 552
        byte <MAP_CHAR_MEM + 560        ;70
        byte <MAP_CHAR_MEM + 568
        byte <MAP_CHAR_MEM + 576
        byte <MAP_CHAR_MEM + 584
        byte <MAP_CHAR_MEM + 592
        byte <MAP_CHAR_MEM + 600
        byte <MAP_CHAR_MEM + 608
        byte <MAP_CHAR_MEM + 616
        byte <MAP_CHAR_MEM + 624
        byte <MAP_CHAR_MEM + 632        
        byte <MAP_CHAR_MEM + 640
        byte <MAP_CHAR_MEM + 648
        byte <MAP_CHAR_MEM + 656
        byte <MAP_CHAR_MEM + 664        
        byte <MAP_CHAR_MEM + 672
        byte <MAP_CHAR_MEM + 680
        byte <MAP_CHAR_MEM + 688
        byte <MAP_CHAR_MEM + 696
        byte <MAP_CHAR_MEM + 704
        byte <MAP_CHAR_MEM + 712
        byte <MAP_CHAR_MEM + 720        ;90
        byte <MAP_CHAR_MEM + 728
        byte <MAP_CHAR_MEM + 736
        byte <MAP_CHAR_MEM + 744
        byte <MAP_CHAR_MEM + 752
        byte <MAP_CHAR_MEM + 760
        byte <MAP_CHAR_MEM + 768
        byte <MAP_CHAR_MEM + 776
        byte <MAP_CHAR_MEM + 784
        byte <MAP_CHAR_MEM + 792
        byte <MAP_CHAR_MEM + 800        ;100
        byte <MAP_CHAR_MEM + 808
        byte <MAP_CHAR_MEM + 816
        byte <MAP_CHAR_MEM + 824
        byte <MAP_CHAR_MEM + 832
        byte <MAP_CHAR_MEM + 840
        byte <MAP_CHAR_MEM + 848
        byte <MAP_CHAR_MEM + 856
        byte <MAP_CHAR_MEM + 864
        byte <MAP_CHAR_MEM + 872
        byte <MAP_CHAR_MEM + 880        ;110
        byte <MAP_CHAR_MEM + 888
        byte <MAP_CHAR_MEM + 896
        byte <MAP_CHAR_MEM + 904
        byte <MAP_CHAR_MEM + 912
        byte <MAP_CHAR_MEM + 920
        byte <MAP_CHAR_MEM + 928
        byte <MAP_CHAR_MEM + 936
        byte <MAP_CHAR_MEM + 944        
        byte <MAP_CHAR_MEM + 952
        byte <MAP_CHAR_MEM + 960        ;120
        byte <MAP_CHAR_MEM + 968
        byte <MAP_CHAR_MEM + 976
        byte <MAP_CHAR_MEM + 984
        byte <MAP_CHAR_MEM + 992
        byte <MAP_CHAR_MEM + 1000
        byte <MAP_CHAR_MEM + 1008
        byte <MAP_CHAR_MEM + 1016        
        byte <MAP_CHAR_MEM + 1024
        byte <MAP_CHAR_MEM + 1032
        byte <MAP_CHAR_MEM + 1040       ;130
        byte <MAP_CHAR_MEM + 1048
        byte <MAP_CHAR_MEM + 1056
        byte <MAP_CHAR_MEM + 1064
        byte <MAP_CHAR_MEM + 1072
        byte <MAP_CHAR_MEM + 1080
        byte <MAP_CHAR_MEM + 1088
        byte <MAP_CHAR_MEM + 1096
        byte <MAP_CHAR_MEM + 1104
        byte <MAP_CHAR_MEM + 1112
        byte <MAP_CHAR_MEM + 1120       ;140
        byte <MAP_CHAR_MEM + 1128
        byte <MAP_CHAR_MEM + 1136
        byte <MAP_CHAR_MEM + 1144
        byte <MAP_CHAR_MEM + 1152
        byte <MAP_CHAR_MEM + 1160    
        byte <MAP_CHAR_MEM + 1168
        byte <MAP_CHAR_MEM + 1176
        byte <MAP_CHAR_MEM + 1184
        byte <MAP_CHAR_MEM + 1192
        byte <MAP_CHAR_MEM + 1200       ;150
        byte <MAP_CHAR_MEM + 1208
        byte <MAP_CHAR_MEM + 1216
        byte <MAP_CHAR_MEM + 1224
        byte <MAP_CHAR_MEM + 1232
        byte <MAP_CHAR_MEM + 1240
        byte <MAP_CHAR_MEM + 1248
        byte <MAP_CHAR_MEM + 1256
        byte <MAP_CHAR_MEM + 1264
        byte <MAP_CHAR_MEM + 1272
        byte <MAP_CHAR_MEM + 1280       ;160
        byte <MAP_CHAR_MEM + 1288
        byte <MAP_CHAR_MEM + 1296
        byte <MAP_CHAR_MEM + 1304
        byte <MAP_CHAR_MEM + 1312
        byte <MAP_CHAR_MEM + 1320
        byte <MAP_CHAR_MEM + 1328
        byte <MAP_CHAR_MEM + 1336
        byte <MAP_CHAR_MEM + 1344
        byte <MAP_CHAR_MEM + 1352       
        byte <MAP_CHAR_MEM + 1360       ;170
        byte <MAP_CHAR_MEM + 1368
        byte <MAP_CHAR_MEM + 1376
        byte <MAP_CHAR_MEM + 1384
        byte <MAP_CHAR_MEM + 1392
        byte <MAP_CHAR_MEM + 1400
        byte <MAP_CHAR_MEM + 1408
        byte <MAP_CHAR_MEM + 1416
        byte <MAP_CHAR_MEM + 1424
        byte <MAP_CHAR_MEM + 1432
        byte <MAP_CHAR_MEM + 1440       ;180
        byte <MAP_CHAR_MEM + 1448
        byte <MAP_CHAR_MEM + 1456
        byte <MAP_CHAR_MEM + 1464
        byte <MAP_CHAR_MEM + 1472
        byte <MAP_CHAR_MEM + 1480
        byte <MAP_CHAR_MEM + 1488
        byte <MAP_CHAR_MEM + 1496
        byte <MAP_CHAR_MEM + 1504
        byte <MAP_CHAR_MEM + 1512
        byte <MAP_CHAR_MEM + 1520       ;190
        byte <MAP_CHAR_MEM + 1528
        byte <MAP_CHAR_MEM + 1536
        byte <MAP_CHAR_MEM + 1544
        byte <MAP_CHAR_MEM + 1552
        byte <MAP_CHAR_MEM + 1560       
        byte <MAP_CHAR_MEM + 1568
        byte <MAP_CHAR_MEM + 1576
        byte <MAP_CHAR_MEM + 1584
        byte <MAP_CHAR_MEM + 1592
        byte <MAP_CHAR_MEM + 1600       ;200
        byte <MAP_CHAR_MEM + 1608
        byte <MAP_CHAR_MEM + 1616
        byte <MAP_CHAR_MEM + 1624
        byte <MAP_CHAR_MEM + 1632
        byte <MAP_CHAR_MEM + 1640
        byte <MAP_CHAR_MEM + 1648
        byte <MAP_CHAR_MEM + 1656
        byte <MAP_CHAR_MEM + 1664
        byte <MAP_CHAR_MEM + 1672
        byte <MAP_CHAR_MEM + 1680       ;210
        byte <MAP_CHAR_MEM + 1688
        byte <MAP_CHAR_MEM + 1696
        byte <MAP_CHAR_MEM + 1704
        byte <MAP_CHAR_MEM + 1712
        byte <MAP_CHAR_MEM + 1720
        byte <MAP_CHAR_MEM + 1728
        byte <MAP_CHAR_MEM + 1736
        byte <MAP_CHAR_MEM + 1744
        byte <MAP_CHAR_MEM + 1752
        byte <MAP_CHAR_MEM + 1760       ;220
        byte <MAP_CHAR_MEM + 1768
        byte <MAP_CHAR_MEM + 1776
        byte <MAP_CHAR_MEM + 1784
        byte <MAP_CHAR_MEM + 1792
        byte <MAP_CHAR_MEM + 1800
        byte <MAP_CHAR_MEM + 1808       ;226
        byte <MAP_CHAR_MEM + 1816
        byte <MAP_CHAR_MEM + 1824
        byte <MAP_CHAR_MEM + 1832
        byte <MAP_CHAR_MEM + 1840       ;230, 20312
        byte <MAP_CHAR_MEM + 1848
        byte <MAP_CHAR_MEM + 1856
        byte <MAP_CHAR_MEM + 1864
        byte <MAP_CHAR_MEM + 1872
        byte <MAP_CHAR_MEM + 1880       ;235

MAPSCREEN1_CHSET_OFFSET_TABLE_HI
        byte >MAP_CHAR_MEM
        byte >MAP_CHAR_MEM + 8
        byte >MAP_CHAR_MEM + 16
        byte >MAP_CHAR_MEM + 24
        byte >MAP_CHAR_MEM + 32
        byte >MAP_CHAR_MEM + 40
        byte >MAP_CHAR_MEM + 48
        byte >MAP_CHAR_MEM + 56
        byte >MAP_CHAR_MEM + 64
        byte >MAP_CHAR_MEM + 72
        byte >MAP_CHAR_MEM + 80
        byte >MAP_CHAR_MEM + 88
        byte >MAP_CHAR_MEM + 96
        byte >MAP_CHAR_MEM + 104
        byte >MAP_CHAR_MEM + 112
        byte >MAP_CHAR_MEM + 120
        byte >MAP_CHAR_MEM + 128
        byte >MAP_CHAR_MEM + 136
        byte >MAP_CHAR_MEM + 144
        byte >MAP_CHAR_MEM + 152
        byte >MAP_CHAR_MEM + 160
        byte >MAP_CHAR_MEM + 168
        byte >MAP_CHAR_MEM + 176
        byte >MAP_CHAR_MEM + 184
        byte >MAP_CHAR_MEM + 192
        byte >MAP_CHAR_MEM + 200
        byte >MAP_CHAR_MEM + 208
        byte >MAP_CHAR_MEM + 216
        byte >MAP_CHAR_MEM + 224
        byte >MAP_CHAR_MEM + 232
        byte >MAP_CHAR_MEM + 240
        byte >MAP_CHAR_MEM + 248
        byte >MAP_CHAR_MEM + 256
        byte >MAP_CHAR_MEM + 264
        byte >MAP_CHAR_MEM + 272        
        byte >MAP_CHAR_MEM + 280
        byte >MAP_CHAR_MEM + 288
        byte >MAP_CHAR_MEM + 296
        byte >MAP_CHAR_MEM + 304
        byte >MAP_CHAR_MEM + 312
        byte >MAP_CHAR_MEM + 320
        byte >MAP_CHAR_MEM + 328
        byte >MAP_CHAR_MEM + 336
        byte >MAP_CHAR_MEM + 344
        byte >MAP_CHAR_MEM + 352
        byte >MAP_CHAR_MEM + 360
        byte >MAP_CHAR_MEM + 368
        byte >MAP_CHAR_MEM + 376
        byte >MAP_CHAR_MEM + 384        
        byte >MAP_CHAR_MEM + 392
        byte >MAP_CHAR_MEM + 400
        byte >MAP_CHAR_MEM + 408
        byte >MAP_CHAR_MEM + 416
        byte >MAP_CHAR_MEM + 424
        byte >MAP_CHAR_MEM + 432
        byte >MAP_CHAR_MEM + 440
        byte >MAP_CHAR_MEM + 448
        byte >MAP_CHAR_MEM + 456        
        byte >MAP_CHAR_MEM + 464
        byte >MAP_CHAR_MEM + 472
        byte >MAP_CHAR_MEM + 480
        byte >MAP_CHAR_MEM + 488
        byte >MAP_CHAR_MEM + 496
        byte >MAP_CHAR_MEM + 504
        byte >MAP_CHAR_MEM + 512
        byte >MAP_CHAR_MEM + 520
        byte >MAP_CHAR_MEM + 528
        byte >MAP_CHAR_MEM + 536
        byte >MAP_CHAR_MEM + 544
        byte >MAP_CHAR_MEM + 552
        byte >MAP_CHAR_MEM + 560
        byte >MAP_CHAR_MEM + 568
        byte >MAP_CHAR_MEM + 576
        byte >MAP_CHAR_MEM + 584
        byte >MAP_CHAR_MEM + 592
        byte >MAP_CHAR_MEM + 600
        byte >MAP_CHAR_MEM + 608
        byte >MAP_CHAR_MEM + 616
        byte >MAP_CHAR_MEM + 624
        byte >MAP_CHAR_MEM + 632        
        byte >MAP_CHAR_MEM + 640
        byte >MAP_CHAR_MEM + 648
        byte >MAP_CHAR_MEM + 656
        byte >MAP_CHAR_MEM + 664        
        byte >MAP_CHAR_MEM + 672
        byte >MAP_CHAR_MEM + 680
        byte >MAP_CHAR_MEM + 688
        byte >MAP_CHAR_MEM + 696
        byte >MAP_CHAR_MEM + 704
        byte >MAP_CHAR_MEM + 712
        byte >MAP_CHAR_MEM + 720
        byte >MAP_CHAR_MEM + 728
        byte >MAP_CHAR_MEM + 736
        byte >MAP_CHAR_MEM + 744
        byte >MAP_CHAR_MEM + 752
        byte >MAP_CHAR_MEM + 760
        byte >MAP_CHAR_MEM + 768
        byte >MAP_CHAR_MEM + 776
        byte >MAP_CHAR_MEM + 784
        byte >MAP_CHAR_MEM + 792
        byte >MAP_CHAR_MEM + 800
        byte >MAP_CHAR_MEM + 808
        byte >MAP_CHAR_MEM + 816
        byte >MAP_CHAR_MEM + 824
        byte >MAP_CHAR_MEM + 832
        byte >MAP_CHAR_MEM + 840
        byte >MAP_CHAR_MEM + 848
        byte >MAP_CHAR_MEM + 856
        byte >MAP_CHAR_MEM + 864
        byte >MAP_CHAR_MEM + 872
        byte >MAP_CHAR_MEM + 880
        byte >MAP_CHAR_MEM + 888
        byte >MAP_CHAR_MEM + 896
        byte >MAP_CHAR_MEM + 904
        byte >MAP_CHAR_MEM + 912
        byte >MAP_CHAR_MEM + 920
        byte >MAP_CHAR_MEM + 928
        byte >MAP_CHAR_MEM + 936
        byte >MAP_CHAR_MEM + 944        
        byte >MAP_CHAR_MEM + 952
        byte >MAP_CHAR_MEM + 960
        byte >MAP_CHAR_MEM + 968
        byte >MAP_CHAR_MEM + 976
        byte >MAP_CHAR_MEM + 984
        byte >MAP_CHAR_MEM + 992
        byte >MAP_CHAR_MEM + 1000
        byte >MAP_CHAR_MEM + 1008
        byte >MAP_CHAR_MEM + 1016        
        byte >MAP_CHAR_MEM + 1024
        byte >MAP_CHAR_MEM + 1032
        byte >MAP_CHAR_MEM + 1040
        byte >MAP_CHAR_MEM + 1048
        byte >MAP_CHAR_MEM + 1056
        byte >MAP_CHAR_MEM + 1064
        byte >MAP_CHAR_MEM + 1072
        byte >MAP_CHAR_MEM + 1080
        byte >MAP_CHAR_MEM + 1088
        byte >MAP_CHAR_MEM + 1096
        byte >MAP_CHAR_MEM + 1104
        byte >MAP_CHAR_MEM + 1112
        byte >MAP_CHAR_MEM + 1120
        byte >MAP_CHAR_MEM + 1128
        byte >MAP_CHAR_MEM + 1136
        byte >MAP_CHAR_MEM + 1144
        byte >MAP_CHAR_MEM + 1152
        byte >MAP_CHAR_MEM + 1160 
        byte >MAP_CHAR_MEM + 1168
        byte >MAP_CHAR_MEM + 1176
        byte >MAP_CHAR_MEM + 1184
        byte >MAP_CHAR_MEM + 1192
        byte >MAP_CHAR_MEM + 1200
        byte >MAP_CHAR_MEM + 1208
        byte >MAP_CHAR_MEM + 1216
        byte >MAP_CHAR_MEM + 1224
        byte >MAP_CHAR_MEM + 1232
        byte >MAP_CHAR_MEM + 1240
        byte >MAP_CHAR_MEM + 1248
        byte >MAP_CHAR_MEM + 1256
        byte >MAP_CHAR_MEM + 1264
        byte >MAP_CHAR_MEM + 1272
        byte >MAP_CHAR_MEM + 1280
        byte >MAP_CHAR_MEM + 1288
        byte >MAP_CHAR_MEM + 1296
        byte >MAP_CHAR_MEM + 1304
        byte >MAP_CHAR_MEM + 1312
        byte >MAP_CHAR_MEM + 1320
        byte >MAP_CHAR_MEM + 1328
        byte >MAP_CHAR_MEM + 1336
        byte >MAP_CHAR_MEM + 1344
        byte >MAP_CHAR_MEM + 1352       
        byte >MAP_CHAR_MEM + 1360
        byte >MAP_CHAR_MEM + 1368
        byte >MAP_CHAR_MEM + 1376
        byte >MAP_CHAR_MEM + 1384
        byte >MAP_CHAR_MEM + 1392
        byte >MAP_CHAR_MEM + 1400
        byte >MAP_CHAR_MEM + 1408
        byte >MAP_CHAR_MEM + 1416
        byte >MAP_CHAR_MEM + 1424
        byte >MAP_CHAR_MEM + 1432
        byte >MAP_CHAR_MEM + 1440
        byte >MAP_CHAR_MEM + 1448
        byte >MAP_CHAR_MEM + 1456
        byte >MAP_CHAR_MEM + 1464
        byte >MAP_CHAR_MEM + 1472
        byte >MAP_CHAR_MEM + 1480
        byte >MAP_CHAR_MEM + 1488
        byte >MAP_CHAR_MEM + 1496
        byte >MAP_CHAR_MEM + 1504
        byte >MAP_CHAR_MEM + 1512
        byte >MAP_CHAR_MEM + 1520
        byte >MAP_CHAR_MEM + 1528
        byte >MAP_CHAR_MEM + 1536
        byte >MAP_CHAR_MEM + 1544
        byte >MAP_CHAR_MEM + 1552
        byte >MAP_CHAR_MEM + 1560       
        byte >MAP_CHAR_MEM + 1568
        byte >MAP_CHAR_MEM + 1576
        byte >MAP_CHAR_MEM + 1584
        byte >MAP_CHAR_MEM + 1592
        byte >MAP_CHAR_MEM + 1600
        byte >MAP_CHAR_MEM + 1608
        byte >MAP_CHAR_MEM + 1616
        byte >MAP_CHAR_MEM + 1624
        byte >MAP_CHAR_MEM + 1632
        byte >MAP_CHAR_MEM + 1640
        byte >MAP_CHAR_MEM + 1648
        byte >MAP_CHAR_MEM + 1656
        byte >MAP_CHAR_MEM + 1664
        byte >MAP_CHAR_MEM + 1672
        byte >MAP_CHAR_MEM + 1680
        byte >MAP_CHAR_MEM + 1688
        byte >MAP_CHAR_MEM + 1696
        byte >MAP_CHAR_MEM + 1704
        byte >MAP_CHAR_MEM + 1712
        byte >MAP_CHAR_MEM + 1720
        byte >MAP_CHAR_MEM + 1728
        byte >MAP_CHAR_MEM + 1736
        byte >MAP_CHAR_MEM + 1744
        byte >MAP_CHAR_MEM + 1752
        byte >MAP_CHAR_MEM + 1760
        byte >MAP_CHAR_MEM + 1768
        byte >MAP_CHAR_MEM + 1776
        byte >MAP_CHAR_MEM + 1784
        byte >MAP_CHAR_MEM + 1792
        byte >MAP_CHAR_MEM + 1800
        byte >MAP_CHAR_MEM + 1808
        byte >MAP_CHAR_MEM + 1816
        byte >MAP_CHAR_MEM + 1824
        byte >MAP_CHAR_MEM + 1832
        byte >MAP_CHAR_MEM + 1840
        byte >MAP_CHAR_MEM + 1848
        byte >MAP_CHAR_MEM + 1856
        byte >MAP_CHAR_MEM + 1864
        byte >MAP_CHAR_MEM + 1872
        byte >MAP_CHAR_MEM + 1880       ;245

MAPSCREEN2_CHSET_OFFSET_TABLE_LO
        byte <MAP_CHAR_MEM
        byte <MAP_CHAR_MEM + 100
        byte <MAP_CHAR_MEM + 200
        byte <MAP_CHAR_MEM + 300
        byte <MAP_CHAR_MEM + 400
        byte <MAP_CHAR_MEM + 500
        byte <MAP_CHAR_MEM + 600
        byte <MAP_CHAR_MEM + 700
        byte <MAP_CHAR_MEM + 800
        byte <MAP_CHAR_MEM + 900
        byte <MAP_CHAR_MEM + 1000
        byte <MAP_CHAR_MEM + 1100
        byte <MAP_CHAR_MEM + 1200
        byte <MAP_CHAR_MEM + 1300
        byte <MAP_CHAR_MEM + 1400
        byte <MAP_CHAR_MEM + 1500
        byte <MAP_CHAR_MEM + 1600
        byte <MAP_CHAR_MEM + 1700
        byte <MAP_CHAR_MEM + 1800
        byte <MAP_CHAR_MEM + 1900
        byte <MAP_CHAR_MEM + 2000
        byte <MAP_CHAR_MEM + 2100
        byte <MAP_CHAR_MEM + 2200
        byte <MAP_CHAR_MEM + 2300
        byte <MAP_CHAR_MEM + 2400
        byte <MAP_CHAR_MEM + 2500
        byte <MAP_CHAR_MEM + 2600
        byte <MAP_CHAR_MEM + 2700
        byte <MAP_CHAR_MEM + 2800
        byte <MAP_CHAR_MEM + 2900
        byte <MAP_CHAR_MEM + 3000
        byte <MAP_CHAR_MEM + 3100
        byte <MAP_CHAR_MEM + 3200

MAPSCREEN2_CHSET_OFFSET_TABLE_HI
        byte >MAP_CHAR_MEM
        byte >MAP_CHAR_MEM + 100
        byte >MAP_CHAR_MEM + 200
        byte >MAP_CHAR_MEM + 300
        byte >MAP_CHAR_MEM + 400
        byte >MAP_CHAR_MEM + 500
        byte >MAP_CHAR_MEM + 600
        byte >MAP_CHAR_MEM + 700
        byte >MAP_CHAR_MEM + 800
        byte >MAP_CHAR_MEM + 900
        byte >MAP_CHAR_MEM + 1000
        byte >MAP_CHAR_MEM + 1100
        byte >MAP_CHAR_MEM + 1200
        byte >MAP_CHAR_MEM + 1300
        byte >MAP_CHAR_MEM + 1400
        byte >MAP_CHAR_MEM + 1500
        byte >MAP_CHAR_MEM + 1600
        byte >MAP_CHAR_MEM + 1700
        byte >MAP_CHAR_MEM + 1800
        byte >MAP_CHAR_MEM + 1900
        byte >MAP_CHAR_MEM + 2000
        byte >MAP_CHAR_MEM + 2100
        byte >MAP_CHAR_MEM + 2200
        byte >MAP_CHAR_MEM + 2300
        byte >MAP_CHAR_MEM + 2400
        byte >MAP_CHAR_MEM + 2500
        byte >MAP_CHAR_MEM + 2600
        byte >MAP_CHAR_MEM + 2700
        byte >MAP_CHAR_MEM + 2800
        byte >MAP_CHAR_MEM + 2900
        byte >MAP_CHAR_MEM + 3000
        byte >MAP_CHAR_MEM + 3100
    
ATTRIB_ADDRESS
        word ATTRIBUTE_MEM

checkup
        byte %0000001
checkdown
        byte %0000010

checkleft
        byte %0000100

checkright
        byte %0001000

checkdownright
        byte %0001010

RIVER_ANIM1_LO       
        byte <CHRADR1
RIVER_ANIM1_HI
        byte >CHRADR1

RIVER_ANIM2_LO       
        byte <CHRADR2
RIVER_ANIM2_HI
        byte >CHRADR2

RIVER_ANIM3_LO       
        byte <CHRADR3
RIVER_ANIM3_HI
        byte >CHRADR3

RIVER_ANIM4_LO       
        byte <CHRADR4
RIVER_ANIM4_HI
        byte >CHRADR4

ZP1 word CHRADR1
ZP2 word CHRADR2
ZP3 word CHRADR3
ZP4 word CHRADR4

gamescore
        byte 0,0,0,0,0

animLevel
        byte 0

waterSpeed byte 0