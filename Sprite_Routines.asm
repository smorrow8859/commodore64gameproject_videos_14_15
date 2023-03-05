;===============================================================================
; SPRITE TO CHARACTER POSITION X/Y
; ------------------------------------------------------------------------------
; These align the sprites (ex: 0,1 - to the background positioning)
;===============================================================================
SpriteToCharPos
        lda BIT_TABLE,x                 ; Lookup the bit for this sprite number (0-7)
        eor #$ff                        ; flip all bits (invert the byte %0001 would become %1110)
        and SPRITE_POS_X_EXTEND         ; mask out the X extend bit for this sprite
        sta SPRITE_POS_X_EXTEND         ; store the result back - we've erased just this sprites bit
        sta VIC_SPRITE_X_EXTEND         ; store this in the VIC register for extended X bits

        lda PARAM1                      ; load the X pos in character coords (the column)
        sta SPRITE_CHAR_POS_X,x         ; store it in the character X position variable
        cmp #30                         ; if X is less than 30, no need set the extended bit
        bcc @noExtendedX
        
        lda BIT_TABLE,x                 ; look up the the bit for this sprite number
        ora SPRITE_POS_X_EXTEND         ; OR in the X extend values - we have set the correct bit
        sta SPRITE_POS_X_EXTEND         ; Store the results back in the X extend variable
        sta VIC_SPRITE_X_EXTEND         ; and the VIC X extend register

@noExtendedX
                                        ; Setup our Y register so we transfer X/Y values to the
                                        ; correct VIC register for this sprite
        txa                             ; first, transfer the sprite number to A
        asl                             ; multiply it by 2 (shift left)
        tay                             ; then store it in Y 
                                        ; (note : see how VIC sprite pos registers are ordered
                                        ;  to understand why I'm doing this)

        lda PARAM1                      ; load in the X Char position
        asl                             ; 3 x shift left = multiplication by 8
        asl
        asl
        clc                             
        adc #24 - SPRITE_DELTA_OFFSET_X ; add the edge of screen (24) minus the delta offset
                                        ; to the rough center 8 pixels (1 char) of the sprite

        sta SPRITE_POS_X,x              ; save in the correct sprite pos x variable
        sta VIC_SPRITE_X_POS,y          ; save in the correct VIC sprite pos register


        lda PARAM2                      ; load in the y char position (rows)  "9"
        sta SPRITE_CHAR_POS_Y,x         ; store it in the character y pos for this sprite
        asl                             ; 3 x shift left = multiplication by 8
        asl
        asl
        clc
        adc #50 - SPRITE_DELTA_OFFSET_Y ; add top edge of screen (50) minus the delta offset - 42
        sta SPRITE_POS_Y,x              ; store in the correct sprite pos y variable 
        sta VIC_SPRITE_Y_POS,y          ; and the correct VIC sprite pos register

        lda #0
        sta SPRITE_POS_X_DELTA,x        ;set both x and y delta values to 0 - we are aligned
        sta SPRITE_POS_Y_DELTA,x        ;on a character border (for the purposes of collisions)
        rts

#endregion

;===============================================================================
; Puts a sprite at the position of character X Y. Calculates the proper sprite 
; coords from the
; screen memory position then sets it there directly.
; The primary use of this is the inital positioning of any sprite as it will 
; align it with the proper delta set up.
;
; PARAM 1 = Character x pos (column)
; PARAM 2 = Character y pos (row)
; X = sprite number
;-------------------------------------------------------------------------------
#region "SpriteToCharPos"

EnemyToCharPos
        lda BIT_TABLE,x                 ; Lookup the bit for this sprite number (0-7)
        eor #$ff                        ; flip all bits (invert the byte %0001 would become %1110)
        and ENEMY_SPRITE_POS_X_EXTEND   ; mask out the X extend bit for this sprite
        sta ENEMY_SPRITE_POS_X_EXTEND   ; store the result back - we've erased just this sprites bit
        sta VIC_SPRITE_X_EXTEND         ; store this in the VIC register for extended X bits

        lda PARAM1                      ; load the X pos in character coords (the column)
        sta ENEMY_SPRITE_POS_X,x         ; store it in the character X position variable
        cmp #30                         ; if X is less than 30, no need set the extended bit
        bcc @noExtendedX
        
        lda BIT_TABLE,x                 ; look up the the bit for this sprite number
        ora ENEMY_SPRITE_POS_X_EXTEND   ; OR in the X extend values - we have set the correct bit
        sta ENEMY_SPRITE_POS_X_EXTEND   ; Store the results back in the X extend variable
        sta VIC_SPRITE_X_EXTEND         ; and the VIC X extend register

@noExtendedX
                                        ; Setup our Y register so we transfer X/Y values to the
                                        ; correct VIC register for this sprite
        txa                             ; first, transfer the sprite number to A
        asl                             ; multiply it by 2 (shift left)
        tay                             ; then store it in Y 
                                        ; (note : see how VIC sprite pos registers are ordered
                                        ;  to understand why I'm doing this)

        lda PARAM1                      ; load in the X Char position
        asl                             ; 3 x shift left = multiplication by 8
        asl
        asl
        clc                             
        adc #24 - ENEMY_SPRITE_DELTA_OFFSET_X ; add the edge of screen (24) minus the delta offset
                                        ; to the rough center 8 pixels (1 char) of the sprite

        sta ENEMY_SPRITE_POS_X,x        ; save in the correct sprite pos x variable
        sta VIC_SPRITE_X_POS,y          ; save in the correct VIC sprite pos register


        lda PARAM2                      ; load in the y char position (rows)
        sta ENEMY_SPRITE_CHAR_POS_Y,x   ; store it in the character y pos for this sprite
        asl                             ; 3 x shift left = multiplication by 8
        asl
        asl
        clc
        adc SPRITE_DEPTH
        sec
        sbc SPRITE_DELTA_OFFSET_Y
        adc #50 - ENEMY_SPRITE_DELTA_OFFSET_Y ; add top edge of screen (50) minus the delta offset
        sta ENEMY_SPRITE_POS_Y,x              ; store in the correct sprite pos y variable
        sta VIC_SPRITE_Y_POS,y                ; and the correct VIC sprite pos register

        lda #0
        sta ENEMY_SPRITE_POS_X_DELTA,x        ;set both x and y delta values to 0 - we are aligned
        sta ENEMY_SPRITE_POS_Y_DELTA,x        ;on a character border (for the purposes of collisions)
        rts

#endregion

FlipBits
        lda BIT_TABLE,x
        eor #$ff
        and SPRITE_POS_X_EXTEND
        sta SPRITE_POS_X_EXTEND         ; enemy Position x
        sta VIC_SPRITE_X_EXTEND         ; 53264
        txa
        asl
        tay

        lda SPRITE_POS_X,x
        sta VIC_SPRITE_X_POS,y          ; $d000,x

        lda BIT_TABLE,x
        eor SPRITE_POS_X_EXTEND         ; enemy Position x
        sta SPRITE_POS_X_EXTEND         ; enemy Position X
        sta VIC_SPRITE_X_EXTEND         ; 53264
        rts

RepositionSprite
        ldx #1
        lda SPRITE_CHAR_POS_X,x         ; Char x pos = SPRITE_CHAR_POS_X,x
        sta PARAM1                      ; Char X pos = 19

        ldx #0
        lda SPRITE_CHAR_POS_Y,x         ; 10,12,10,12,0,0,0,0
        sta PARAM2                      ; Char Y pos = 10
        jsr SpriteToCharPos             ; Set sprite and store coords

        ldx #1                          ; Sprite number 1
        lda SPRITE_CHAR_POS_Y,x         ; 10,12,10,12,0,0,0,0
        sta PARAM2  
        jsr SpriteToCharPos             ; Set sprite and store coords

; Sprite 2 and 3: Enemy
        ldx #2
        lda SPRITE_CHAR_POS_X,x
        sta PARAM1                      ; Char X pos = 19

        ldx #2
        lda SPRITE_CHAR_POS_Y,x         ; 10,12,10,12,0,0,0,0
        sta PARAM2                      ; Char Y pos = 10
        jsr SpriteToCharPos             ; Set sprite and store coords

        ldx #3                          ; Sprite number 1
        lda SPRITE_CHAR_POS_Y,x         ; 10,12,10,12,0,0,0,0
        sta PARAM2  
        jsr SpriteToCharPos             ; Set sprite and store coords
        rts

;===============================================================================
; SPRITES WALKS TO THE LEFT
;===============================================================================

#region "MoveSpriteLeft"

MoveSpriteLeft
        lda SPRITE_POS_X,x                      ; First check for 0 (NOT negative)
        bne @decNoChange                        ; branch if NOT 0

        dec SPRITE_POS_X,x                      ; Decrement Sprite X position by 1 (to $FF)

        lda BIT_TABLE,x                         ; fetch the bit needed to change for this sprite
        eor SPRITE_POS_X_EXTEND                 ; use it as a mask to flip the correct X extend bit 
        sta SPRITE_POS_X_EXTEND                 ; store teh data then save it in the VIC II register
        sta VIC_SPRITE_X_EXTEND                 ; $D011 - Sprite extended X bits (one bit per sprite)
        jmp @noChangeInExtendedFlag             ; Jump to saving the X position

@decNoChange                                    ; Not zero X so we decrement
        dec SPRITE_POS_X,x
@noChangeInExtendedFlag
        txa                                     ; copy X to the accumulator (sprite number)
        asl                                     ; shift it left (multiply by 2)
        tay                                     ; save it in Y (to calculate the register to save to)

        lda SPRITE_POS_X,x                      ; Load our variable saved X position
        sta VIC_SPRITE_X_POS,y                  ; save it in $D000 offset by Y to the correct VIC
                                                ; sprite register

                                                ; Here we decrement the Sprite delta - we moved
                                                ; a pixel so the delta goes down by one
        dec SPRITE_POS_X_DELTA,x
        bmi @resetDelta                         ; test for change to negative
        rts                                     ; if delta is still > 0 we're done

@resetDelta                                     
        lda #$07                                ; if delta falls below 0
        sta SPRITE_POS_X_DELTA,x                ; reset it to #$07 - one char
        dec SPRITE_CHAR_POS_X,x                 ; delta has reset - so decrement character position
        rts
     
#endregion

;===============================================================================
; SPRITES WALKS TO THE RIGHT
;===============================================================================

#region "MoveSpriteRight"
MoveSpriteRight
        inc SPRITE_POS_X,x                      ; increase Sprite X position by 1
        bne @noChangeInExtendedFlag             ; if not #$00 then no change in x flag
        
        lda BIT_TABLE,x                         ; get the correct bit to set for this sprite
        eor SPRITE_POS_X_EXTEND                 ; eor in the extended bit (toggle it on or off)
        sta SPRITE_POS_X_EXTEND                 ; store the new flags
        sta VIC_SPRITE_X_EXTEND                 ; set it in the VIC register

@noChangeInExtendedFlag                          
        txa                                     ; transfer the sprite # to A
        asl                                     ; multiply it by 2
        tay                                     ; transfer the result to Y

        lda SPRITE_POS_X,x                      ; copy the new position to our variable
        sta VIC_SPRITE_X_POS,y                  ; update the correct X position 
                                                ; register in the VIC

                                                ; Our X position is now incremented, 
                                                ; so delta also increases by 1
        inc SPRITE_POS_X_DELTA,x
        lda SPRITE_POS_X_DELTA,x
        and #%0111                              ; Mask it to 0-7
        beq @reset_delta
        rts                                     ; if it hasn't we're done
@reset_delta                                    
        sta SPRITE_POS_X_DELTA,x                ; reset delta to 0 - this means we've crossed a
        inc SPRITE_CHAR_POS_X,x                 ; a character boundry, so increase our CHAR position
        rts

#endregion

;===============================================================================
; SPRITES MOVES UP
;===============================================================================

MoveSpriteUp
        dec SPRITE_POS_Y,x                      ; decrement the sprite position variable        
        txa                                     ; copy the sprite number to A
        asl                                     ; multiply it by 2
        tay                                     ; transfer it to Y        
        lda SPRITE_POS_Y,x                      ; load the sprite position for this sprite
        sta VIC_SPRITE_Y_POS,y                  ; send it to the correct VIC register - $D001 + y

                                                ; Y position has decreased, so our delta decreases
        dec SPRITE_POS_Y_DELTA,x
        bmi @reset_delta                        ; test to see if it drops to negative
        rts                                     ; if not we're done
@reset_delta
        lda #$07                                ; reset the delta to 0
        sta SPRITE_POS_Y_DELTA,x
        dec SPRITE_CHAR_POS_Y,x                 ; if delta resets, we've crossed a character border
        rts

#endregion

;===============================================================================
; SPRITES MOVES DOWN
;===============================================================================

MoveSpriteDown
        inc SPRITE_POS_Y,x                      ; increment the y pos variable for this sprite
        txa
        asl
        tay

        lda SPRITE_POS_Y,x
        sta VIC_SPRITE_Y_POS,y        
        inc SPRITE_POS_Y_DELTA,x
        lda SPRITE_POS_Y_DELTA,x
        cmp #$08
        beq @reset_delta
        rts

;@checkEnemyHead
;        cpx #2
;        beq @deactivateSprite

;@checkEnemyBody
;        cpx #3
;        beq @deactivateSprite
;        rts

;@deactivateSprite
;        lda #2
;        sta 53280
;        jsr DisableEnemySprite
;        rts

@reset_delta
        lda #$00
        sta SPRITE_POS_Y_DELTA,x
        inc SPRITE_CHAR_POS_Y,x
        rts

#endregion

;===============================================================================
; SPRITE ANIMATION ROUTINES
;===============================================================================


;===============================================================================
; ANIMATE SPRITE
;-------------------------------------------------------------------------------
; Animate an individual sprite. Taking data from it's Anim List, updating 
; it's variables and updating it's animation frame
;
; It can currently handle loop, play once, and ping-pong animations
;
; X = sprite number to animate
;
; Modifies :  Y, ZEROPAGE_POINTER_1
;
;-------------------------------------------------------------------------------
#region "AnimateSprites"
AnimateSprite
        ;-----------------------------------------------------------------------
        ; First - do we need to animate this sprite at all? Check the TIMER

        lda SPRITE_ANIM_PLAY                    ; return if anim paused
        bne @start
        rts
@start

; Contains the first 2 bytes of ANIM_PLAYER_

; Within SPRITE_ANIM_TIMER,x
; byte  1: %0000111
; bytes 2-x: 18,20,22 "ANIM_PLAYER_R"
        lda SPRITE_ANIM_TIMER,x                 ; load the anim timer mask
        bne @timerCheck                         ; is our timer turned off? (set to 0)

        rts
@timerCheck
        and #%00001111                          ; mask out the upper half byte (extra info)
        and TIMER                               ; and the mask against the timer
        beq @update                             ; if the result isn't 0 - return 
        rts
@update
        ;-----------------------------------------------------------------------
        ; First we need to fetch this sprites anim list.
        
        txa                                     ; put the sprite number in A
        asl                                     ; multiply by 2 (to lookup a word)
        tay                                     ; store the result in Y

; Earlier in InitSpriteAnim we saved the sprite frame data in 
; SPRITE_ANIMATION,y. So an example for ANIM_ENEMY_WALK_L would show as bytes
; 68,70,72 or seen as SPRITE ANIMATION: word 74,76,78 - etc.
; Bytes 74,76,78 are the individual different sprites shapes placed here.
        
        lda SPRITE_ANIMATION,y                  ; fetch the address to the sprites Anim List
        sta ZEROPAGE_POINTER_1                  ; and store it in ZEROPAGE_POINTER_1
        lda SPRITE_ANIMATION + 1,y
        sta ZEROPAGE_POINTER_1 + 1

        ;-----------------------------------------------------------------------
        ; Next - increment (or decrement for PING PONG) the animation counter

; Reads the byte (example: %0000111) to see if the timer
; is counting up or down.

        lda SPRITE_ANIM_TIMER,x                 ; check for the MSB in the timer, if it's set
        bpl @incTimer                           ; we count down instead
        
        dec SPRITE_ANIM_COUNT,x                 ; decrement anim counter and continue as normal
        jmp @zerocheck

@incTimer
        inc SPRITE_ANIM_COUNT,x                 ; increment the counter
@zerocheck
        lda SPRITE_ANIM_COUNT,x                 ; fetch it so we can do an end test

        beq @resetPong                          ; it should NEVER be zero, unless it's a PING_PONG
                                                ; anim returning back to zero as the first bytes
                                                ; is the anim timer mask

; Example: cycle through 18, 20, 22 ("ANIM_PLAYER_WALK_R")
; Basic Example POKE 2040, bytes (68, 70, 72) 
        tay                                     ; use as an index to load the current frame from the
        lda (ZEROPAGE_POINTER_1),y              ; animlist

        bpl @setImage                           ; Test to make sure the frame is positive (0-128)
                                                ; if it isn't, and the MSB is set, then it's the
                                                ; end byte, which we use to tell us the type of
                                                ; anim (and what to do when we reach the end)

        cmp #TYPE_LOOP                          ; Check to see what type of anim this is
        beq @resetLoop

        cmp #TYPE_PING_PONG
        beq @resetPing
        ;----------------------------------------------------------PLAY_ONCE_ANIM
                                                ; PlayOnce Anim doesn't get reset
        lda #0                                  ; We set the anim timer to 0, so it never updates
        sta SPRITE_ANIM_TIMER,x
        lda #$FF                                ; We set the count to -1 ($FF) as something our
        sta SPRITE_ANIM_COUNT,x                 ; code can check to see if a once only is finished
        rts
        ;------------------------------------------------------PING_PONG_ANIM
                                                ; We've reached the end of the animlist
@resetPing
        lda SPRITE_ANIM_TIMER,x
        eor #%10000000                          ; flip bit 7 in the timer to start 0 check
                                                ; and turn on decrementing
        sta SPRITE_ANIM_TIMER,x                 ; save the new counter

        lda SPRITE_ANIM_COUNT,x
        sec
        sbc #2                                  ; subtract 2 from the anim counter
        sta SPRITE_ANIM_COUNT,x                 ; and save the result
        tay
        lda (ZEROPAGE_POINTER_1),y              ; lookup the new sprite frame
                                                ; A now has the sprite image
                                                ; X has the sprite number
                                                ; so we set the image(s)
        jmp @setImage

@resetPong                                      ; The reverse of the above
        lda SPRITE_ANIM_TIMER,x
        eor #%10000000                          ; flip bit 7 (MSB) to count forwards
        sta SPRITE_ANIM_TIMER,x                 ; save the new timer

        lda #2                                  ; skip to frame 2
        sta SPRITE_ANIM_COUNT,x                 ; save the new counter
        tay
        lda (ZEROPAGE_POINTER_1),y              ; load the new sprite image
        jmp @setImage
        ;-------------------------------------------------------------LOOP_ANIM
@resetLoop                                   
        lda #1                                  ; reset the counter to the first frame
        sta SPRITE_ANIM_COUNT,x
        tay                                     ; now fetch the first frame
        lda (ZEROPAGE_POINTER_1),y

@setImage
        ;-------------------------------------------------------------------
        ; Set the sprite to it's new image - A currently contains the count
        ; ZEROPAGE_POINTER_1 has the address of the sprites animlist

                                                ; A = correct sprite image, X = sprite number,
                                                ; so we're ready to set our new sprite image
        jsr SetSpriteImage                      ; placed in SPRITE_POINTER_BASE (register 2040+)
        
        cpx #0                                  ; if sprite is 0 , it's the player sprite
        beq @setHeadSprite0                    ; so we need to set a second sprite 

; This reads the Body sprite
        cpx #2                                  ; if sprite is 2 , it's the enemy sprite
        beq @setBodySprite0                    ; so we need to set a second sprite  
        rts

@setHeadSprite0
        clc
        adc #1                                  ; add one to the frame
        inx                                     ; add one to the sprite number               
        jsr SetSpriteImage
        dex
        rts

@setBodySprite0
        clc
        adc #1                                  ; add one to the frame
        inx                                     ; add one to the sprite number                
        jsr SetSpriteImage
        dex
        rts

#endregion

;===============================================================================
; SET SPRITE IMAGE
;===============================================================================
; Sets the sprite image for a hardware sprite, and sets up its pointers for 
; both screens
;-------------------------------------------------------------------------------
; A = Sprite image number
; X = Hardware sprite number
;
; Leaves registers intact
;-------------------------------------------------------------------------------
#region "SetSpriteImage"
SetSpriteImage
        pha                                     ; Sprite image number
        clc
        adc #SPRITE_BASE                        ; Sprite image = image num + base
        sta SPRITE_POINTER_BASE1,x
        sta SPRITE_POINTER_BASE2,x              
        pla
        rts

#endregion

;===============================================================================
; INIT SPRITE ANIM
;-------------------------------------------------------------------------------
;
; Setup and initialize a sprites animations
;
; X = Sprite number
; ZERO_PAGE_POINTER_1 = animation list address
;
; Modifies A,Y
;-------------------------------------------------------------------------------
#region "InitSpriteAnim"
InitSpriteAnim
        lda #1                          ; Reset Anim counter to first frame
        sta SPRITE_ANIM_COUNT,x

        txa                             ; copy sprite number to A
        asl                             ; multiply it by 2 (so we can index a word)
        tay                             ; transfer result to Y
                                        ; reads "ANIM_PLAYER_" or "ANIM_ENEMY_"
        lda ZEROPAGE_POINTER_1          ; Store the address for the animlist
        sta SPRITE_ANIMATION,y          ; in the correct 'slot' for this sprite
        lda ZEROPAGE_POINTER_1 + 1
        sta SPRITE_ANIMATION + 1,y      ; SPRITE_ANIMATION = "ANIM_PLAYER_" (example)

; Reads through animation bytes Example: "ANIM_ENEMY_WALK_L"
; Such as byte %00000011, byte 74,76,78, byte TYPE_LOOP

; On the first pass through of y=0 we read the timer data
; When y=0, the code below could currently be seen in memory as:

;       ldy #0
;       lda (ZEROPAGE_POINTER_1),y    > %000111 (ANIM_ENEMY_WALK_L) timer

        ldy #0                          ; First byte in the list is the timer
        lda (ZEROPAGE_POINTER_1),y      ; fetch it
        sta SPRITE_ANIM_TIMER,x         ; store it in this sprites timer slot

; Earlier in PlayerStateWalk (left/right) we stored data in ZEROPAGE_POINTER_1
; to point to our sprite animation frames.

; The above code could now be seen in memory as:
;       ldy #0
;       lda (ZEROPAGE_POINTER_1),y      ; 68,70,72 (ANIM_ENEMY_WALK_L)

        iny                             ; increment Y to 1 - the first anim frame 
        lda (ZEROPAGE_POINTER_1),y      ; load it
                                        ; right now we have the sprite image in A
                                        ; and the sprite number in X, which is exactly what
                                        ; what we need to use SetSpriteImage
        jsr SetSpriteImage              ; Set (Head) sprite (POKE 2040, sprite frame)

        cpx #0                          ; if the sprite = 0, then we are setting the player sprite
        beq @bodySprite0               ; the player uses 2 sprites  
        rts

; Set the Body of the sprite (POKE 2041, sprite frame)

@bodySprite0                           ; We don't need to set all the info for this sprite
        inx                             ; increment X to the next hardware sprite
        clc                             ; add one to the current anim frame number
        adc #1                          ; because our background sprite is the next frame.        
        jsr SetSpriteImage              ; Now set the sprite image        
        rts

#endRegion

;===============================================================================
; INIT SPRITE ANIM
;-------------------------------------------------------------------------------
;
; Setup and initialize a sprites animations
;
; X = Sprite number
; ZERO_PAGE_POINTER_1 = animation list address
;
; Modifies A,Y
;-------------------------------------------------------------------------------
#region "InitSpriteAnim"
InitEnemyAnim
        lda #1                          ; Reset Anim counter to first frame
        sta SPRITE_ANIM_COUNT,x

        txa                             ; copy sprite number to A
        asl                             ; multiply it by 2 (so we can index a word)
        tay                             ; transfer result to Y
                                        ; reads "ANIM_PLAYER_" or "ANIM_ENEMY_"
        lda ZEROPAGE_POINTER_1          ; Store the address for the animlist
        sta SPRITE_ANIMATION,y          ; in the correct 'slot' for this sprite
        lda ZEROPAGE_POINTER_1 + 1
        sta SPRITE_ANIMATION + 1,y

; Reads through animation bytes Example: "ANIM_ENEMY_WALK_L"
; Such as byte %00000011, byte 74,76,78, byte TYPE_LOOP

; On the first pass through of y=0 we read the timer data
; When y=0, the code below could currently be seen in memory as:

;       ldy #0
;       lda (ZEROPAGE_POINTER_1),y    > %000111 (ANIM_ENEMY_WALK_L) timer

        ldy #0                          ; First byte in the list is the timer
        lda (ZEROPAGE_POINTER_1),y      ; fetch it
        sta SPRITE_ANIM_TIMER,x         ; store it in this sprites timer slot

; Earlier in PlayerStateWalk (left/right) we stored data in ZEROPAGE_POINTER_1
; to point to our sprite animation frames.

; The above code could now be seen in memory as:
;       ldy #0
;       lda (ZEROPAGE_POINTER_1),y      ; 68,70,72 (ANIM_ENEMY_WALK_L)

        iny                             ; increment Y to 1 - the first anim frame 
        lda (ZEROPAGE_POINTER_1),y      ; load it
 
                                        ; right now we have the sprite image in A
                                        ; and the sprite number in X, which is exactly what
                                        ; what we need to use SetSpriteImage
        jsr SetSpriteImage

        cpx #2                          ; if the sprite = 0, then we are setting the player sprite
        beq @secondSprite               ; the player uses 2 sprites  
        rts
@secondSprite
                                        ; We don't need to set all the info for this sprite
        inx                             ; increment X to the next hardware sprite
        clc                             ; add one to the current anim frame number
        adc #1                          ; because our background sprite is the next frame.        
        jsr SetSpriteImage              ; Now set the sprite image        
        rts

#endRegion
;-------------------------------------------------------------------------------
;===============================================================================
; DATA AND TABLES
;===============================================================================
;-------------------------------------------------------------------------------
; SPRITE POINTER TABLES
;-------------------------------------------------------------------------------

; Lookup tables for setting Sprite Pointers for the
; correct screens

SPRITE_POINTER_BASE1 = SCREEN1_MEM + $3f8
SPRITE_POINTER_BASE2 = SCREEN2_MEM + $3f8
SPRITE_POINTER_BASE3 = SCREEN2_MEM + $3f8

;-------------------------------------------------------------------------------
;===============================================================================
; SPRITE HANDLING DATA
;===============================================================================

RSP_GAME_SWITCH byte 0
LSP_GAME_SWITCH byte 0                                  ; But with 2 different Y positions, it had to 

; 0,1 = Sprite 0 (Player)
; 2,3 = Sprite 1 (Enemy)
SPRITE_STACK
        byte 10,12,10,12,10,0,0,0                       ; Handles the upper/lower sprite Y positions
                                                        ; NOTE: This was originally managed by PARAM2
                                                        ; But with 2 different Y positions, it had to
                                                        ; be altered.
SPRITE_DEPTH byte 36                                         

SPRITE_IS_ACTIVE
        byte $00,$00,$00,$00,$00,$00,$00,$00
                                                        ; Hardware sprite X position
SPRITE_POS_X
        byte $00,$00,$00,$00,$00,$00,$00,$00
                                                        ; Delta X position (0-7) - within a char
SPRITE_POS_X_DELTA
        byte $00,$00,$00,$00,$00,$00,$00,$00

SPRITE_CHAR_POS_X                                       ; Char pos X - sprite position in character
        byte $00,$00,$00,$00,$00,$00,$00,$00            ; coords (0-40)
SPRITE_DELTA_TRIM_X
        byte $00,$00,$00,$00,$00,$00,$00,$00            ; Trim delta for better collisions

SPRITE_POS_X_EXTEND                                     ; extended flag for X positon > 255
        byte $00                                        ; bits 0-7 correspond to sprite numbers


SPRITE_POS_Y                                            ; Hardware sprite Y position
        byte $00,$00,$00,$00,$00,$00,$00,$00
SPRITE_POS_Y_DELTA
        byte $00,$00,$00,$00,$00,$00,$00,$00
SPRITE_CHAR_POS_Y
        byte $00,$00,$00,$00,$00,$00,$00,$00

SPRITE_DIRECTION_X                                                
        byte $00,$00,$00,$00,$00,$00,$00,$00    ; Direction of the sprite (-1 0 1)
SPRITE_DIRECTION_Y
        byte $00,$00,$00,$00,$00,$00,$00,$00

SPRITE_ANIM_TIMER
        byte $00,$00,$00,$00,$00,$00,$00,$00    ; Timing and playback direction for current anim 
SPRITE_ANIM_COUNT
        byte $00,$00,$00,$00,$00,$00,$00,$00    ; Position in the anim list
SPRITE_ANIM_PLAY
        byte $00,$00,$00,$00,$00,$00,$00,$00    ; Currently animated or paused?

                                                ; Pointer to current animation table
SPRITE_ANIMATION
        word $0000,$0000,$0000,$0000
        word $0000,$0000,$0000,$0000  

SPRITE_SAVE_POS_X 
        byte $00,$00,$00,$00,$00,$00,$00,$00
SPRITE_SAVE_POS_Y 
        byte $00,$00,$00,$00,$00,$00,$00,$00

; Enemy Data  

ActiveTimer byte 1 
EnemyTimer byte 1
EnemyCountDown byte 0
EnemyFireCD byte 0

ENEMY_DISTANCE
        byte 22

ENEMY_HIT byte 0
                                   
ENEMY_SPRITE_POS_X
        byte $00,$00,$00,$00,$00,$00,$00,$00
                                                        ; Delta X position (0-7) - within a char
ENEMY_SPRITE_POS_X_DELTA
        byte $00,$00,$00,$00,$00,$00,$00,$00

ENEMY_SPRITE_CHAR_POS_X                                 ; Char pos X - sprite position in character
        byte $00,$00,$00,$00,$00,$00,$00,$00            ; coords (0-40)
ENEMY_SPRITE_DELTA_TRIM_X
        byte $00,$00,$00,$00,$00,$00,$00,$00            ; Trim delta for better collisions

ENEMY_SPRITE_POS_X_EXTEND                               ; extended flag for X positon > 255
        byte $00                                        ; bits 0-7 correspond to sprite numbers


ENEMY_SPRITE_POS_Y                                      ; Hardware sprite Y position
        byte $00,$00,$00,$00,$00,$00,$00,$00
ENEMY_SPRITE_POS_Y_DELTA
        byte $00,$00,$00,$00,$00,$00,$00,$00
ENEMY_SPRITE_CHAR_POS_Y
        byte $00,$00,$00,$00,$00,$00,$00,$00  
                 
;===============================================================================
; SPRITE ANIMATION TABLES
;===============================================================================
; Anims are held in a block of data containing info and a list of anim frames.
; byte 0 = Timing mask:
;          The lower 4 bits contain a mask we will and with the master timer, 
; if the result is
; is 0 we will go to the next frame
; valid values are those that use all bits (1,3,5,7,15)
.
; Bit 7 is used for the direction of the animation (in ping pong anims). if we 
; set it
; we can then use bmi (Branch MInus) to see if we count backwards instead of 
; forwards
;
; byte 1 to end = sprite numbers for the animation frames
; 
; The last byte both terminates the animation, and also shows what should be 
; done at the end
; of it.  On a loop we would reset to 0, on a play once anim we would end, on 
; a ping pong type it will start counting backwards
;-------------------------------------------------------------------------------
; ANIMATION TYPES
TYPE_LOOP = $FF
TYPE_PLAY_ONCE = $FE
TYPE_PING_PONG = $FD
;-------------------------------------------------------------------------------
ANIM_PLAYER_IDLE                                ; Player idle animation
        byte %0001111
        byte 4,2
        byte TYPE_PING_PONG

ANIM_PLAYER_WALK_R
        byte %0000111
        byte 18,20,22
        byte TYPE_LOOP

ANIM_PLAYER_WALK_L
        byte %0000111
        byte 12,14,16    
        byte TYPE_LOOP

ANIM_PLAYER_FALL
        byte %0001111
        byte 34
        byte TYPE_PLAY_ONCE

ANIM_CLIMB_POLE
        byte %0000011
        byte 8,10,12
        byte TYPE_LOOP

ANIM_PLAYER_JUMP                                ; Player jump animation
        byte %00000111
        byte 2,4,6
        byte TYPE_PING_PONG

ANIM_PLAYER_PUNCH_R
        byte %0000011
        byte 24,26
        byte TYPE_LOOP   

ANIM_PLAYER_PUNCH_L
        byte %0000011
        byte 30,32
        byte TYPE_LOOP  

ANIM_PLAYER_SHOOT_RIGHT
        byte %0001111
        byte 50,50                              ; Start at 50
        byte TYPE_LOOP 

ANIM_PLAYER_SHOOT_LEFT
        byte %0001111
        byte 52,52
        byte TYPE_LOOP 

ANIM_PLAYER_KICK_R
        byte %0001111
        byte 26,28
        byte TYPE_LOOP

ANIM_PLAYER_KICK_L
        byte %0001111
        byte 38,40
        byte TYPE_LOOP 

PLAYER_JUMPCOUNT
        byte 0

ANIM_PLAYER_SWIM_R
        byte %0000011
        byte 43,45
        byte TYPE_LOOP

ANIM_PLAYER_SWIM_L
        byte %0000011
        byte 46,48
        byte TYPE_LOOP

ANIM_PLAYER_DEAD
        byte %0000011
        byte 57,59
        byte TYPE_LOOP

ANIM_PLAYER_DEAD1
        byte %0000011
        byte 57,57
        byte TYPE_LOOP

ANIM_PLAYER_DEAD2
        byte %0000011
        byte 59,59
        byte TYPE_LOOP

ANIM_PLAYER_CASHPILE
        byte %0000011
        byte 61,61
        byte TYPE_LOOP

; ENEMY ANIMATION: Always go back 1 frame before the one that
; shows in the Sprite Editor.

ANIM_ENEMY_IDLE
        byte %0001111
        byte 98,102                           ; sprites 99-104
        byte TYPE_PING_PONG

ANIM_ENEMY_WALK_R
        byte %0000111
        byte 74,78                            ; sprites 77-80 running right
        byte TYPE_LOOP

ANIM_ENEMY_WALK_L
        byte %0000111
        byte 68,72                            ; sprites 69-74 running left   
        byte TYPE_LOOP

ANIM_ENEMY_WALK_D
        byte %0000111
        byte 58,60,62                         ; sprites 69-74 running left   
        byte TYPE_LOOP

ANIM_ENEMY_FIRING_RIGHT
        byte %0000111
        byte 74,80                            ; sprites 81, 82, (85,87)
        byte TYPE_LOOP

ANIM_ENEMY_FIRING_LEFT
        byte %0001111
        byte 66,72                            ; sprites 67, 68
        byte TYPE_LOOP

ANIM_ENEMY_ATTACK_RIGHT
        byte %0000111
        byte 86,88                            ;sprites 69-74 running left   
        byte TYPE_LOOP

ANIM_ENEMY_ATTACK_LEFT
        byte %0000111
        byte 90,92                            ;sprites 69-74 running left   
        byte TYPE_LOOP

ANIM_ENEMY_RIGHT_DEAD
        byte %0000111
        byte 82,84,86
        byte TYPE_LOOP

ANIM_ENEMY_LEFT_DEAD
        byte %0000111
        byte 82,84,86
        byte TYPE_LOOP

ANIM_ENEMY_CLIMB_ROPE
        byte %0000011
        byte 85,86
        byte TYPE_LOOP

ANIM_ENEMY_BULLET
        byte %0000011
        byte 54,54
        byte TYPE_LOOP

; Below are our current stationary sprites (don't move)
ANIM_NPC1                                       ; numbers 0 to 9
        byte %0000011
        byte 80,80                              ; was 74,68,82
        byte TYPE_PING_PONG

ANIM_NPC2                                       ; numbers 0 to 9
        byte %0000011
        byte 81,81                              ; was 75,69,83
        byte TYPE_PING_PONG

ANIM_NPC3                                       ; numbers 0 to 9
        byte %0000011
        byte 95,95                              ; was 99,99
        byte TYPE_PING_PONG

ANIM_NPC4                                       ; numbers 0 to 9
        byte %0000011
        byte 96,96                              ; was 99,99
        byte TYPE_PING_PONG