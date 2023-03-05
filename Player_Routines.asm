;===============================================================================
; PLAYER SETUP
;===============================================================================
;2w The Player Sprite here can move around the screen on top of the tiles
; and when the edge is reached, the screen scrolls in that direction.
;===============================================================================

#region "Player Setup"
PlayerInit

;-----------------------------------------------------------------------
; PLAYER has a strange setup as it's ALWAYS going to be using 
; sprites 0 and 1
; As well as always being 'active' (used)
;-----------------------------------------------------------------------

        lda #COLOR_BLACK
        sta VIC_BACKGROUND_COLOR

        lda #%11111111                          ; Turn on multicolor for sprites 0 and 1
        sta VIC_SPRITE_MULTICOLOR               ; also turn all others to single color

        lda #COLOR_BLACK
        sta VIC_SPRITE_MULTICOLOR_1             ; Set sprite shared multicolor 1 to brown
        lda #COLOR_LTRED
        sta VIC_SPRITE_MULTICOLOR_2             ; set sprite shared multicolor 2 to 'pink'

        lda #COLOR_YELLOW
        sta VIC_SPRITE_COLOR                    ; set sprite 0 color to yellow
        lda #COLOR_BLUE
        sta VIC_SPRITE_COLOR + 1                ; set sprite 1 color to orange (bkground sprite)

;------------------------------------------------------------------------------
; We now use a system that tracks the sprite position in character coords on
; the screen, so to avoid costly calculations every frame, we set the sprite
; to a character border intially and track all movement from there. That way
; we need only do this set of calculations once in the lifetime of the Player.
;
; To initally place the sprite, we use 'SpriteToCharPos'
;------------------------------------------------------------------------------
; Sprite X position
        lda #22
        sta PARAM1                      ; Char X pos = 19

        ldx #0
        lda SPRITE_STACK,x              ; 10,12,10,12,0,0,0,0
        sta PARAM2                      ; Char Y pos = 10
        jsr SpriteToCharPos             ; Set sprite and store coords

        ldx #1                          ; Sprite number 1
        lda SPRITE_STACK,x              ; 10,12,10,12,0,0,0,0
        sta PARAM2  
        jsr SpriteToCharPos             ; Set sprite and store coords

; Sprite 2 and 3: Enemy
        lda #1
        sta PARAM1                      ; Char X pos = 19

        ldx #2
        lda SPRITE_STACK,x              ; 10,12,10,12,0,0,0,0
        sta PARAM2                      ; Char Y pos = 10
        jsr SpriteToCharPos             ; Set sprite and store coords

        ldx #3                          ; Sprite number 1
        lda SPRITE_STACK,x              ; 10,12,10,12,0,0,0,0
        sta PARAM2  
        jsr SpriteToCharPos             ; Set sprite and store coords

;        lda #1
;        sta PARAM1                      ; Char X pos = 19

;        ldx #5
;        lda SPRITE_STACK,x              ; 10,12,10,12,0,0,0,0
;        sta PARAM2                      ; Char Y pos = 10
;        jsr SpriteToCharPos             ; Set sprite and store coords       

;-------------------------------------------------------------------------------
; Set sprite images.  The sprites from the MLP Spelunker demo used 2 sprites
; overlapped so they could use an extra color.  So our main player sprite
; uses 2 sprites (0 and 1).  The first walking frame image 1, and it's
; background sprite is image 8.  We use the SetSpriteImage subroutine as it
; will update the pointers for both Screen1 and Screen2 for us.
;-------------------------------------------------------------------------------

        lda #PLAYER_STATE_IDLE          ; Set initial state (idle)
        jsr ChangePlayerState

        lda #1
        sta SPRITE_IS_ACTIVE            ; Set sprite 0 to active
        sta SPRITE_IS_ACTIVE + 1        ; Set sprite 1 to active

        jsr SavePlayerPosition          ; Save Player x/y coordinates
        rts

#endregion

;===============================================================================
; UPDATE PLAYER 
;-------------------------------------------------------------------------------
; Update the player. Joystick controls are updated via interrupt so we read the 
; values from JOY_X and JOY_Y
;-------------------------------------------------------------------------------

#region "Update Player"

PLAYER_RIGHT_CAP = $1c                   ; Sprite movement caps - at this point we don't
PLAYER_LEFT_CAP = $09                    ; Move the sprite, we scroll the screen
PLAYER_UP_CAP = $04                          
PLAYER_DOWN_CAP = 13


UpdatePlayer                             ; Only update the player if it's active
        lda SPRITE_IS_ACTIVE             ; check against sprite #0 - is it active?
        bne @update 
        rts
@update    
        ldx #0
        jsr AnimateSprite
        jsr UpdatePlayerState            ;jump (PLAYER_STATE_JUMPTABLE)
        rts

#endregion

;===============================================================================
; JOYSTICK TESTING
; MOVING: Direction the character is moving in
; SCROLL: Check if the screen has stopped scrolling

; JoystickReady = 0 - the screen has stopped scrolling
; JoystickReady = 1 - the screen is now scrolling
;===============================================================================

#region "JoystickReady"
JoystickReady
        lda SCROLL_MOVING             ; if moving is 'stopped' we can test joystick
        beq @joyready
 
; Screen is still scrolling           ; if it's moving but direction is stopped, we're 'fixing'
        lda SCROLL_DIRECTION          ; > 0 then stop the character direction movement
        bne @joyready

; The screen has stopped scrolling
        rts                             

; The screen is now scrolling
@joyready
        lda #SCROLL_STOP                ; reset scroll direction - if it needs to scroll
        sta SCROLL_DIRECTION            ; it will be updated

        lda #0                          ; send code for joystick ready
        rts

#endregion

;===============================================================================
; PLAYER WALKS TO THE RIGHT
;===============================================================================

#region "MovePlayerRight"
MovePlayerRight
        lda #0
        sta SCROLL_FIX_SKIP
        clc                             ; clear carry flag because I'm paranoid
;===============================================================================
; Sprite has not reached the right edge screen yet.
; So we can keep moving the Sprite player to the right.
;===============================================================================
        lda SPRITE_CHAR_POS_X,x         ; load the sprite char X position
        cmp #PLAYER_RIGHT_CAP           ; check against the right edge of the screen
        bcc @rightMove                  ; if X char pos < cap - move the sprite, else scroll

;===============================================================================
; Sprite is at the right edge and the screen is scrolling,
; so we check the
; MAP_Y_POS and MAP_Y_DELTA variables
;===============================================================================
        lda MAP_X_POS                   ; load the current MAP X Position          
        cmp #100                         ; map = 64 tiles wide, screen = 10 tiles wide
        bne @scrollRight
        lda MAP_X_DELTA                 ; each tile is 4 characters wide (0-3)
        cmp #0                          ; if we hit this limit we don't scroll (or move)
        bne @scrollRight
                                        ;at this point we will revert to move 
        lda #1
        sta SCROLL_FIX_SKIP
        jmp @rightMove

;===============================================================================
; Check if Sprite hit anything while moving to the right
;===============================================================================
@scrollRight
        ldx #0
        jsr CheckMoveRight              ; Collision check against characters
        beq @scroll                     ; TODO - return the collision code here
        rts

;===============================================================================
; Sprite didn't hit anything so we can scroll the screen to the right
;===============================================================================
@scroll
        lda #SCROLL_RIGHT               ; Set the direction for scroll and post 
        sta SCROLL_DIRECTION            ; and post scroll checks
        sta SCROLL_MOVING
        lda #0                          ; load 'clear code'
        rts                             ; TODO - ensure collision code is returned

;===============================================================================
; Sprite is not at the right screen edge yet.
; So we check for any collision while moving right. If no collision exists,
; we can then move the sprite to the right.
;===============================================================================
                            
@rightMove
        ldx #0
        jsr CheckMoveRight              ; Check ahead for character collision
        bne @rightDone

        ldx #0                                  ; Check at Sprite's feet                         
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_CASHPILE                         ; Does floor exist under us?
        beq @walkrightcashpile

;        jsr EnemyCollision
@moveRight
        ldx #0
        jsr MoveSpriteRight             ; Move sprites one pixel right
        ldx #1
        jsr MoveSpriteRight

        lda #0                          ; move code 'clear'
@rightDone
        rts

@walkrightcashpile
        lda #6
        sta 53280
        jsr PlayerCashPickup
        rts

#endregion

;===============================================================================
; PLAYER WALKS TO THE LEFT
;===============================================================================

#region "Move Player Left"
MovePlayerLeft
        lda #0                          ; Make sure scroll 'fix' is on
        sta SCROLL_FIX_SKIP

        lda SPRITE_CHAR_POS_X,x           ; Check for left side movement cap
        cmp #PLAYER_LEFT_CAP
        bcs @leftMove                   ; if below cap, we move the sprite
                                        ; Otherwise we prepare to scroll

;===============================================================================
; IS SPRITE AT THE LEFT EDGE OF THE MAP? (MAP_X_POS)

; Sprite is at the left screen edge and the screen is scrolling,
; so we check the
; MAP_Y_POS and MAP_Y_DELTA variables
;=============================================================================== 
                                        ; Check for edge of map for scrolling
        lda MAP_X_POS                   ; Check for map pos X = 0
        bne @scrollLeft                 
        lda MAP_X_DELTA                 ; check for map delta = 0
        bne @scrollLeft
                                        ; We're at the maps left edge
                                        ; So we revert to sprite movement once more
;===============================================================================
; Since SPRITE_POS_X,x > 0 we move the sprite and not the screen.
;===============================================================================

;        lda #1
;        sta SCROLL_FIX_SKIP
        lda SPRITE_POS_X,x              ; Check for sprite pos > 0 (not sprite char pos)
        bpl @leftMove                   ; so we could walk to the edge of screen
        rts

@scrollLeft
        ;--------------------------------------- SCROLL SCREEN FOR LEFT MOVE
        ldx #0
        jsr CheckMoveLeft               ; check for character collision to the left
        beq @scroll
        rts                             ; TODO - return collision code

;===============================================================================
; SCREEN IS SCROLLING TO THE LEFT
;===============================================================================

@scroll
        lda #SCROLL_LEFT
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        lda #0                          ; return 'clear code'
        rts
        ;---------------------------------------- MOVE THE PLAYER LEFT ONE PIXEL

;===============================================================================
; Before we can move the sprite, we need to check if he collided into a tile
;===============================================================================
@leftMove
        ldx #0                          ; check at the head of our sprite's body
        jsr CheckMoveLeft               ; check for collisions with characters
        bne @leftDone                   ; TODO return collision code

        ldx #0                                  ; Check at Sprite's feet                         
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_CASHPILE                         ; Does floor exist under us?
        beq @walkleftcashpile
;===============================================================================
; SPRITE IS MOVING TO THE LEFT (Screen has stopped scrolling here)
;===============================================================================   
@moveLeft 
;        jsr EnemyCollision
        ldx #0
        jsr MoveSpriteLeft
        ldx #1
        jsr MoveSpriteLeft

        lda #0                          ; move code 'clear'
@leftDone
        rts

@walkleftcashpile
        lda #6
        sta 53280
        jsr PlayerCashPickup
        rts

#endregion

;===============================================================================
; PLAYER MOVES DOWN THE SCREEN
;===============================================================================

#region "Move Player Down"
MovePlayerDown

;===============================================================================
; Sprite has not reached the screen bottom.
; So we can keep moving the Sprite player downward.
;===============================================================================
        clc
        lda SPRITE_CHAR_POS_Y,x
        cmp #PLAYER_DOWN_CAP
        bcc @downMove

;===============================================================================
; Sprite is now below the bottom edge so we check the
; MAP_Y_POS and MAP_Y_DELTA variables
;===============================================================================

        lda MAP_Y_POS
        cmp #49                         ; Check for bottom of map
        bne @downScroll
        lda MAP_Y_DELTA
        cmp #02
        bcc @downScroll
        rts

;===============================================================================
; Check if Sprite hit anything while moving down
;===============================================================================
@downScroll
        ldx #1                          ; Check Sprite #0
        jsr CheckMoveDown               ; returns: 0 = can move : 1 = blocked
        beq @scroll                     ; We are not blocked = 0
        rts                             ; return with contents of collison routine

;===============================================================================
; Sprite didn't hit anything so we can scroll the screen downward
;===============================================================================

@scroll
;        lda SCROLL_COUNT_Y
;        sta 53286

        lda #SCROLL_DOWN
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        lda #0                          ; return a clear collision code
        rts

; Setting ldx #1 will not allow the single one button pressed jump
; This is because the collision detection looks at the sprite's head
; and not his feet. So the sprite's head won't detect anything so he
; won't jump.

;===============================================================================
; Sprite is not at the screen bottom edge yet.
; So we check for any collision while moving down. If no collision exists,
; we can then move the sprite downward.
;===============================================================================
@downMove
        ldx #0                          ; Check Sprite's leg area
        jsr CheckMoveDown               ; returns: 0 = can move : 1 = blocked
        bne @downDone                   ; retun with contents of collision code

        ldx #0
        jsr MoveSpriteDown              ; = 0 so we can move the Sprite Down
        ldx #1
        jsr MoveSpriteDown
        lda #0                          ; return with clear code
@downDone
        rts

#endregion

;===============================================================================
; PLAYER MOVES UP THE SCREEN
;===============================================================================

#region "MovePlayerUp"
MovePlayerUp
        sec
        lda SPRITE_CHAR_POS_Y,x
        cmp #PLAYER_UP_CAP
        bcs @upMove

        lda MAP_Y_POS
        bne @upScroll
        clc
        lda MAP_Y_DELTA
        cmp #1
        bcs @upScroll
        rts

@upScroll
        ldx #0
        jsr CheckMoveUp
        beq @scroll
        rts

@scroll
        lda #SCROLL_UP
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        rts

@upMove
        ldx #0                                  ; Check Sprite 0 (head/body)
        jsr CheckMoveUp
        bne @upDone
                
        jsr MoveSpriteUp                        ; Move Sprite 0(head - top)
        ldx #1
        jsr MoveSpriteUp                        ; Move Sprite 1 (body - bottom)
        lda #0
        rts
@upDone
        lda #1
        rts

#endregion

;===============================================================================
; PLAYER STATES
;===============================================================================
; Player states are incremented by 2 as they are indexes to look up the address 
; of the state
; code on the PLAYER_STATE_JUMPTABLE.  An address is 2 bytes (1 word) egro the 
; index must increase
; by 2 bytes.
;-------------------------------------------------------------------------------
PLAYER_STATE_IDLE               = 0     ; standing still - awaiting input
PLAYER_STATE_WALK_RIGHT         = 2     ; Walking right
PLAYER_STATE_WALK_LEFT          = 4     ; Walking left
PLAYER_STATE_PUNCH_RIGHT        = 6    ; punch right
PLAYER_STATE_PUNCH_LEFT         = 8    ; punch left
PLAYER_STATE_SHOOT_RIGHT        = 10    ; punch right
PLAYER_STATE_SHOOT_LEFT         = 12   ; punch left
PLAYER_STATE_KICK_RIGHT         = 14    ; kick right
PLAYER_STATE_KICK_LEFT          = 16    ; kick left
PLAYER_STATE_POLE               = 18    ; Climbing pole
PLAYER_STATE_SWIM_R             = 20    ; swim right
PLAYER_STATE_SWIM_L             = 22    ; swim left
PLAYER_STATE_FLOATING           = 24    ; floating
PLAYER_STATE_JUMP               = 26    ; Jumping

PLAYER_SUBSTATE_ENTER   = 0     ; we have just entered this state
PLAYER_SUBSTATE_RUNNING = 1     ; This state is running normally

;===============================================================================
; PLAYER STATE JUMPTABLE
;===============================================================================
PLAYER_STATE_JUMPTABLE
        word PlayerStateIdle
        word PlayerStateWalkRight
        word PlayerStateWalkLeft
        word PlayerStatePunchRight
        word PlayerStatePunchLeft
        word PlayerStateShootRight
        word PlayerStateShootLeft
        word PlayerStateKickRight
        word PlayerStateKickLeft
        word PlayerStatePole
        word PlayerStateSwimR
        word PlayerStateSwimL
        word PlayerStateFloating
        word PlayerStateJump
;===============================================================================
; CHANGE PLAYER STATE
;===============================================================================
; Change a players state
;
; A = state to change to
;
; Modifies A,X,ZEROPAGE_POINTER_1

;C64 Brain Notes: Player states recorded (animation, idle, running, etc.). 
; Data is saved to PLAYER_SUBSTATE
;-------------------------------------------------------------------------------
#region "PlayerChangeState"
ChangePlayerState
        tax                                             ; transfer A to X
        stx PLAYER_STATE                                ; store the new player state                            
        lda #PLAYER_SUBSTATE_ENTER                      ; Set substate to ENTER
        sta PLAYER_SUBSTATE

;        lda #1
;        sta SPRITE_ANIM_PLAY

        lda PLAYER_STATE_JUMPTABLE,x                    ; lookup state to change to
        sta ZEROPAGE_POINTER_1                          ; and store it in ZEROPAGE_POINTER_1

        lda PLAYER_STATE_JUMPTABLE + 1,x
        sta ZEROPAGE_POINTER_1 + 1

        jmp (ZEROPAGE_POINTER_1)                        ; jump to state (to setup)
                                                        ; NOTE: This is NOT a jsr.
                                                        ; The state will act as an extension of
                                                        ; this routine then return.
#endregion
;===============================================================================
; UPDATE PLAYER STATE
;-------------------------------------------------------------------------------
; Update the player based on their state
;-------------------------------------------------------------------------------
#region "UpdatePlayerState"
UpdatePlayerState
        ldx PLAYER_STATE                        ; Load player state
        lda PLAYER_STATE_JUMPTABLE,x            ; fetch the state address from the jump table
        sta ZEROPAGE_POINTER_1                  ; store it in ZEROPAGE_POINTER_1
        lda PLAYER_STATE_JUMPTABLE +1,x
        sta ZEROPAGE_POINTER_1 + 1
        jmp (ZEROPAGE_POINTER_1)                ; jump to the right state (note - NOT a jsr)
        rts
#endregion

;===============================================================================
; APPLY GRAVITY
;===============================================================================
; Apply Gravity to the player - this system will be totally rewritten at some 
; point to apply a proper gravity to a player or any other sprite.. 
; but for now it's just super basic
;
; A returns 0 if we moved down and a collision code if we didn't
;-------------------------------------------------------------------------------

#region "Apply Gravity"
;===============================================================================
; CHECK IF FLOOR IS FOUND WHILE FALLING
;===============================================================================
ApplyGravity 
;===============================================================================
; CHECK IF FLOOR WAS FOUND WHILE FALLING
;===============================================================================
@spriteFallCheck
        ldx #1                                  ; Check at Sprite's feet                         
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_FLOOR                         ; Does floor exist under us?
        beq @playerNotFalling 

@chkForPole
        ldx #1                                  ; Check at Sprite's feet                         
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_POLE  
        beq @playerNotFalling

        ldx #1                                  ; Check at Sprite's feet                         
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_CASHPILE                         ; Does floor exist under us?
        beq @foundcashStash

;===============================================================================
; NO FLOOR EXISTS: CAN SCROLL FREELY
;===============================================================================
@falling
        ldx #0
        jsr MovePlayerDown
        ldx #1
        jsr MovePlayerDown
        clc
        lda PLAYER_DAMAGE
        adc #1
        sta PLAYER_DAMAGE
        cmp #68
        bcc @safeFall
        lda #1
        sta PLAYER_ISDEAD
        rts
@safeFall
        rts

@foundcashStash
        jsr PlayerCashPickup
        rts

;===============================================================================
; FLOOR WAS FOUND: STOP SCREEN FROM MOVING
;===============================================================================
@playerNotFalling;   

        jsr ResetEnemytoPlayerVertical
        lda #0
        sta PLAYER_JUMP_POS
        sta PLAYER_DAMAGE
        jsr PlayerStateDead
        rts

#endregion

;===============================================================================
; PLAYER STATE IDLE
;===============================================================================
#region "Player State Idle"
PlayerStateIdle
;===============================================================================
; SET IDLE SPRITE
;===============================================================================
        lda PLAYER_DIED
        beq @contIdle
        jsr PlayerStateDead

@contIdle

        lda #1
        sta SPRITE_ANIM_PLAY                    ; pause our animation

        lda PLAYER_SUBSTATE                     ; First run PLAYER_SUBSTATE=0
        bne @running                            ; set in ChangePlayerState

; This is executed every time since PLAYER_SUBSTATE starts at zero.
        ldx #0                                  ; load sprite number (0) in X
        lda #<ANIM_PLAYER_IDLE                  ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  ; byte %00000111
        lda #>ANIM_PLAYER_IDLE
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda PLAYER_SUBSTATE_RUNNING             ; PLAYER_SUBSTATE_RUNNING=1
        sta PLAYER_SUBSTATE                     ; Now PLAYER_STATE=1, so we can exit
        rts 
 
;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady                       ; lda SCROLL_MOVING, lda SCROLL_DIRECTION
;        jsr DisplayNewSprite
        jsr DetectSprite
                                                               
;===============================================================================
; CHECK IF SPRITE IS ON GROUND (COLL_FLOOR)
;=============================================================================== 
; Note: ldx #0 - checks the sprite Head area (Sprite 0)
;       ldx #1 = checks the sprite Legs area (Sprite 1)

; Screen has stopped scrolling


; The @chkWater skip is necessary to prevent the sprite from
; jumping while in the air.

;===============================================================================
; SPRITE IS CLIMBING A POLE OR STANDING ABOVE IT
;===============================================================================
@goLadder
        ldx #1                            
        jsr CheckBlockUnder 
        cmp #COLL_POLE                          ; Check for pole under player 
        bne @checkFloor

; Sprite is climbing a ladder/pole
        lda #PLAYER_STATE_POLE
        jmp ChangePlayerState 

@checkFloor
        ldx #1                                  ; Check at Sprite's feet
        jsr CheckBlockUnder
        cmp #COLL_FLOOR
        bne @checkWater                         ; Sprite is not on the floor 

;===============================================================================
; CHECK IF FLOOR IS IS BELOW PLAYER SPRITE
;-------------------------------------------------------------------------------
; When this is turned on, the Player can't jump straight
; up when the joystick is not moving left/right.
;===============================================================================
; If ceiling is above Player, can't jump up
        ldx #1                            
        jsr CheckBlockUnder 
        cmp #COLL_FLOOR                       ; Check for pole under player 
        bne @resetvertPos

        lda #0
        sta PLAYER_JUMP_POS

;        ldx #0
;        jsr CheckMoveUp                     ; Check tile under Top sprite (Sprite)
;        beq @resetvertPos 
        rts

; Sprite is on the floor, reset enemy to same Y position as Player
; but off the screen for now.

@resetvertPos
        jsr ResetEnemytoPlayerVertical

;===============================================================================
; SPRITE HAS NOT YET LANDED ON THE FLOOR: STILL FALLING
;===============================================================================
@goFloor
;        ldx #1                                  ; Check at Sprite's feet area                         
;        jsr CheckBlockUnder              
;        cmp #COLL_FLOOR                         ; Does floor exist under us?
;        bne @stillFalling                       ; No, player keeps falling

        lda #0
        sta PLAYER_JUMP_POS                        

;===============================================================================
; CHECK FOR SPRITE FLOATING IN THE WATER
;===============================================================================
@checkWater
        ldx #1                          ; Check at the sprite's feet
        jsr CheckBlockUnder             ; first check we are on a pole
        cmp #COLL_WATER
        bne @checkdiagonals 

; Player is on the water, reset enemy to same Y position as Player
; but keep enemy off the screen during this time.

        lda #0
        ldx #2
        sta SPRITE_POS_X,x
        ldx #3
        sta SPRITE_POS_X,x

        ldx #0
        lda SPRITE_POS_Y,x              ; Find Player sprite Y (head) pos
        ldx #2
        sta SPRITE_POS_Y,x              ; Set enemy Head(y) to Player Y
        ldx #1
        lda SPRITE_POS_Y,x              ; Find Player sprite Y (body) pos
        ldx #3
        sta SPRITE_POS_Y,x              ; Set enemy Body(y) to Player Y

;Sprite is floating in the river
        lda #PLAYER_STATE_FLOATING
        jmp ChangePlayerState

;===============================================================================
; CHECK IF SPRITE IS PUNCHING RIGHT
;===============================================================================
;===============================================================================
; FLOOR WAS FOUND! COLL_FLOOR = 10
; Sprite is standing on a floor here so we can test the fire button
;-------------------------------------------------------------------------------
; BUTTON HAS BEEN PRESSED SO SPRITE CAN JUMP
;===============================================================================
@checkdiagonals

; Prevents sprite from jumping up when a FLOOR is above him
        ldx #0                            
        jsr CheckBlockUnder 
        cmp #COLL_FLOOR                          ; Check for pole under player 
        bne @playerIsFalling

        ldx #0                                  ; Check at Sprite's feet                         
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_CASHPILE                         ; Does floor exist under us?
        beq @foundCash

;===============================================================================
; CHECK FOR XBOX CONTROLLER BUTTON PRESS
;===============================================================================
        lda #%00010000                          ; Mask for bit 0
        bit JOY_2                               ; jumping (button pressed)
        beq @butPress                           ; continue other check

        lda checkupright
        bit JOY_2                               ; punch right
        beq @pressUpRight

;===============================================================================
; CHECK IF SPRITE IS PUNCHING LEFT
;===============================================================================
        lda checkupleft                         ; Mask for bit 0
        bit JOY_2                               ; jumping (button pressed)
        beq @pressUpLeft                        ; punch left  

;===============================================================================
; CHECK IF SPRITE IS A LITTLE BELOW THE FLOOR
; NOTE: Makes sprite idle up/down when on solid surface
;===============================================================================
;        lda SPRITE_CHAR_POS_Y
;        cmp #PLAYER_DOWN_CAP - 1                ; = 13: - 1 = 12
;        bcc @moveSpriteUp
@playerIsFalling
        jmp @stillFalling
;===============================================================================
; CHECK FOR BUTTON PRESS AND PUSHING UP
;===============================================================================
@butPress
;        ldx #0
;        jsr CheckMoveUp                     ; Check tile under Top sprite (Sprite)
;        bne @end 


@playerCanJump
        lda #PLAYER_STATE_JUMP                ; go to jump state
        jmp ChangePlayerState

@foundCash
        lda #6
        sta 53280
        jsr PlayerCashPickup
        rts

;===============================================================================
; @horizCheck: SKIPS OVER GRAVITY CHECK SINCE SPRITE IS ON THE FLOOR
;===============================================================================
        jmp @horizCheck                       ; Player has landed on tile (can't fall)

;===============================================================================
; SPRITE HAS NOT LANDED ON A FLOOR, SO STILL FALLING
;=============================================================================== 
@stillFalling
        jsr ApplyGravity

;===============================================================================
; CHECK THE VERTICAL MOVEMENT
;===============================================================================
; Is Sprite moving to the Left or Right while in the air?
;===============================================================================
@horizCheck
        lda JOY_X                               ; horizontal movement
        beq @vertCheck                          ; check zero - ho horizontal input
        bmi @left                               ; negative = left
        
;===============================================================================
; SPRITE HAS MOVED TO THE RIGHT
;===============================================================================
@right
        lda #PLAYER_STATE_WALK_RIGHT            ; go to walk state right
        jmp ChangePlayerState

;===============================================================================
; SPRITE HAS MOVED TO THE LEFT
;=============================================================================== 
@left
        lda #PLAYER_STATE_WALK_LEFT             ; go to walk state left
        jmp ChangePlayerState

@vertCheck
;===============================================================================
; CHECK IF JOYSTICK IS MOVING UP OR DOWN
;===============================================================================
        lda JOY_Y                               ; check vertical joystick input
        beq @end                                ; zero means no input
        rts

;===============================================================================
; SUBROUTINE FOR: SPRITE PUNCHING RIGHT
;===============================================================================
@pressUpRight
;        lda #PLAYER_STATE_PUNCH_RIGHT            ; go to jump state
;        jmp ChangePlayerState

; When a weapon is found, the subroutine below can be used (later)

        lda #PLAYER_STATE_SHOOT_RIGHT            ; go to jump state
        jmp ChangePlayerState
;===============================================================================
; SUBROUTINE FOR: SPRITE PUNCHING LEFT
;===============================================================================
@pressUpLeft
;        lda #PLAYER_STATE_PUNCH_LEFT            ; go to jump state
;        jmp ChangePlayerState

; When a weapon is found, the subroutine below can be used (later)

        lda #PLAYER_STATE_SHOOT_LEFT            ; go to jump state
        jmp ChangePlayerState

@end
        lda #PLAYER_STATE_IDLE            ; go to walk state right
        jmp ChangePlayerState

IDLE_VAR
        byte $00
#endregion

;===============================================================================
; PLAYER TO ENEMY COLLIS
;-------------------------------------------------------------------------------
; Check if Player run into an Enemy
;===============================================================================
PlayertoEnemyCollis
        lda #0
        sta ENEMY_HIT
        ldx #3               
        ldy #1
        lda SPRITE_POS_X,x
        cmp SPRITE_POS_X,y
        bcs @noEnemyCollis
        clc
        adc ENEMY_DISTANCE
        cmp SPRITE_POS_X,y
        bne @noEnemyCollis

        lda #1
        sta ENEMY_HIT
        rts

@noEnemyCollis
        lda #0
        sta ENEMY_HIT
        rts

DisplayConsolePanel
        loadpointer ZEROPAGE_POINTER_1, CONSOLE_TEXT

        lda #0                          ; PARAM1 contains X screen coord (column)
        sta PARAM1
        lda #19                         ; PARAM2 contains Y screen coord (row)
        sta PARAM2
        lda #COLOR_WHITE                ; PARAM3 contains the color to use
        sta PARAM3
        jsr DisplayText                 ; Then we display the stats panel

; Display Score Panel
        loadpointer ZEROPAGE_POINTER_1, SCORE_PANEL_TEXT

        lda #0                          ; PARAM1 contains X screen coord (column)
        sta PARAM1
        lda #23                         ; PARAM2 contains Y screen coord (row)
        sta PARAM2
        lda #COLOR_RED               ; PARAM3 contains the color to use
        sta PARAM3
        jsr DisplayText                 ; Then we display the stats panel

; Reset cash, so it doesn't increase score when we lose a life
        lda #0  
        sta PLAYER_CASH

        lda #1
        sta GAMESCORE_ACTIVE

        lda gamescore
        ldx #23 
        ldy #6  
        jsr ScoreBoard
        rts

PlayerGameOver
        loadpointer ZEROPAGE_POINTER_1, GAMEOVER_PANEL

        lda #0                          ; PARAM1 contains X screen coord (column)
        sta PARAM1
        lda #19                         ; PARAM2 contains Y screen coord (row)
        sta PARAM2
        lda #COLOR_WHITE                ; PARAM3 contains the color to use
        sta PARAM3
        jsr DisplayText                 ; Then we display the stats panel

        lda #0
        sta 53250
        sta 53251
        sta 53252
        sta 53253
        sta 53254

        jsr ShowDeadSprite
@waitJoyMove
        jsr JoystickReady

; Wait for fire button to restart Game
        lda #%00010000                          ; Mask for bit 0
        bit JOY_2                               ; check zero = jumping (button pressed)
        bne @waitJoyMove                           ; continue other check

;        lda JOY_X
;;        bne @resetGame
;        beq @waitJoyMove

@resetGame
        lda #5
        sta PLAYER_LIVES
        lda #0
        sta gamescore
        sta gamescore + 1
        lda #1
        sta GAMESCORE_ACTIVE
        rts

; Increase cash pickup when found.
PlayerCashPickup
        lda #1
        sta GAMESCORE_ACTIVE

        lda PLAYER_CASH
        clc
        adc #25
        sta PLAYER_CASH

;        loadpointer ZEROPAGE_POINTER_1, CONSOLE_TEXT
;        loadPointer WPARAM1,SCORE_SCREEN

        ldx #16         ; Y pos
        ldy #23          ; X pos
;        lda SCORE_LINE_OFFSET_TABLE_LO,x
;        sta ZEROPAGE_POINTER_1
;        lda SCORE_LINE_OFFSET_TABLE_HI,x
;        sta ZEROPAGE_POINTER_1 + 1 
;       
;        lda COLOR_LINE_OFFSET_TABLE_LO,x                ; fetch line address for color
;        sta ZEROPAGE_POINTER_3
;        lda COLOR_LINE_OFFSET_TABLE_HI,x
;        sta ZEROPAGE_POINTER_3 + 1

;        ldx #16         ; Y pos
;        ldy #23          ; X pos
;        ldx #35         ; Y pos
;        ldy #28          ; X pos
        jsr CashCounter

@flashScreen
        inc $d020
        inc flashcashDelay
        lda flashcashDelay
        cmp #120
        bcc @flashScreen
        lda #0
        sta flashcashDelay
        rts

SavePlayerPosition
        ldx #0
        lda SPRITE_CHAR_POS_X,x              ; Find Player sprite Y (head) pos
        sta SPRITE_SAVE_POS_X,x
        ldx #1
        lda SPRITE_CHAR_POS_X,x              ; Find Player sprite Y (head) pos
        sta SPRITE_SAVE_POS_X,x

        ldx #0
        lda SPRITE_CHAR_POS_Y,x              ; Set enemy Head(y) to Player Y
        sta SPRITE_SAVE_POS_Y,x
        ldx #1
        lda SPRITE_CHAR_POS_Y,x              ; Set enemy Head(y) to Player Y
        sta SPRITE_SAVE_POS_Y,x
;        ldx #1
;        lda SPRITE_POS_Y,x              ; Find Player sprite Y (body) pos
;        ldx #3
;        sta SPRITE_POS_Y,x              ; Set enemy Body(y) to Player Y
        rts

RestorePlayerPosition
        ldx #0
        lda SPRITE_SAVE_POS_X,x          ; Find Player sprite Y (head) pos
        sta SPRITE_CHAR_POS_X,x
        ldx #1
        lda SPRITE_SAVE_POS_X,x          ; Set enemy Head(y) to Player Y
        sta SPRITE_CHAR_POS_X,x

        ldx #0
        lda SPRITE_SAVE_POS_Y,x          ; Find Player sprite Y (head) pos
        sec
        sbc #6
        sta SPRITE_CHAR_POS_Y,x
        ldx #1
        lda SPRITE_SAVE_POS_Y,x          ; Set enemy Head(y) to Player Y
        sec
        sbc #6
        sta SPRITE_CHAR_POS_Y,x
        rts

DisplayNewSprite
; Sprite 4 display
        ldx #4                                  ; Point to sprite 4
        lda #<ANIM_ENEMY_BULLET                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_BULLET
        sta ZEROPAGE_POINTER_1 + 1
        jsr InitSpriteAnim

@running2
        lda #110
        sta 53256                               ; position Sprite 4 (x)
        lda #120
        sta 53257                               ; position Sprite 4 (y)
        lda #COLOR_BROWN
        sta 53291

; Sprite 5 display
        ldx #5                                  ; Point to sprite 5
        lda #<ANIM_ENEMY_BULLET                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_BULLET
        sta ZEROPAGE_POINTER_1 + 1
        jsr InitSpriteAnim

        lda #110
        sta 53258
        lda #135
        sta 53259
        lda #COLOR_BLUE
        sta 53292
        rts

; Sprite 6 display
;        ldx #6                                  ; Point to sprite 6
;        lda #<ANIM_NPC3                ; load animation in ZEROPAGE_POINTER_1
;        sta ZEROPAGE_POINTER_1
;        lda #>ANIM_NPC3
;        sta ZEROPAGE_POINTER_1 + 1
;        jsr InitSpriteAnim

;        lda #100
;        sta 53260
;        lda #120
;        sta 53261
;        lda #COLOR_VIOLET
;        sta 53293
;        rts

; Sprite 6 display
;        ldx #7                                  ; Point to sprite 7
;        lda #<ANIM_NPC4                ; load animation in ZEROPAGE_POINTER_1
;        sta ZEROPAGE_POINTER_1
;        lda #>ANIM_NPC4
;        sta ZEROPAGE_POINTER_1 + 1
;        jsr InitSpriteAnim

;        lda #100
;        sta 53262
;        lda #135
;        sta 53263
;        lda #COLOR_BROWN
;        sta 53294
;        rts

DetectSprite
        lda $D01E ;Read hardware sprite/sprite collision
        lsr       ; (LSR A for TASM users) Collision for sprite 1
        lsr
        bcc @spriteHit
        rts       ;No collision
@spriteHit     
        inc $D020
        rts

ShowDeadSprite
; Sprite 0 display
        ldx #0                                  ; Point to sprite 4
        lda #<ANIM_PLAYER_DEAD1                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_DEAD1
        sta ZEROPAGE_POINTER_1 + 1
        jsr InitSpriteAnim

; Sprite 1 display
        ldx #1                                  ; Point to sprite 5
        lda #<ANIM_PLAYER_DEAD2                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_DEAD2
        sta ZEROPAGE_POINTER_1 + 1
        jsr InitSpriteAnim

@running2
        ldx #0
        lda SPRITE_POS_X,x
        sta 53248                               ; position Sprite 0 (x)        
        ldx #1
        lda SPRITE_POS_X,x
        clc
        adc #20
        sta 53250

        lda #155
        sta 53249                               ; position Sprite 1 (y)
        sta 53251
;        lda #COLOR_GREY1
;        sta 53288
;        lda #COLOR_GREY2
;        sta 53289
        rts

;===============================================================================
; PLAYER STATE WALK RIGHT
;===============================================================================

#region "Player State Walk Right"
PlayerStateWalkRight  
        lda PLAYER_SUBSTATE
        bne @running

        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_WALK_R                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_WALK_R
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                 

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady                       ; The screen is now scrolling

;===============================================================================
; CHECK IF SPRITE HAS LANDED ON THE FLOOR
;=============================================================================== 

; Screen has stopped scrolling
@input

;===============================================================================
; NO FLOOR EXISTS YET. SPRITE KEEPS FALLING
;===============================================================================
        jsr ApplyGravity                ; Apply Gravity - if we are not falling

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@joyCheck
        lda JOY_X
        beq @exitRightIdle                  ; screen scrolls to right

;===============================================================================
; SPRITE IS MOVING TO THE RIGHT
; So we test for a jump here (fire button)
; This allows the sprite to run and jump at the same time.
;===============================================================================
@right   
        lda PLAYER_JUMP_POS 
        cmp #14
        bcs @moveRight

;===============================================================================
; Sprite can jump while running to the right
;===============================================================================
        lda #%00010000                  ; Mask for bit 0
        bit JOY_2                       ; check zero = button pressed
        beq @jumping                    ; Player can jump left

@moveRight
        ldx #0
        jsr MovePlayerRight             ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerRight             ; Use twice for double speed    
        jsr DetectSprite 
        rts 
 
@skipRightGravity     
        rts

@butPress
        lda #1
        sta JOY_X
        lda #PLAYER_STATE_JUMP            ; go to walk state right
        jmp ChangePlayerState

;===============================================================================
; CHECK SCROLL SCREEN MOVE RIGHT
;===============================================================================
@exitRight
        lda #SCROLL_RIGHT
        sta SCROLL_MOVING
        sta SCROLL_DIRECTION

@exitRightIdle
        lda #PLAYER_STATE_IDLE              
        jmp ChangePlayerState

@jumping
        lda #PLAYER_STATE_JUMP
        jmp ChangePlayerState
@scrollRight
        rts

#endregion

;===============================================================================
; PLAYER STATE WALK LEFT
;===============================================================================
#region "Player State Walk Left"
PlayerStateWalkLeft
        lda PLAYER_SUBSTATE
        bne @running

        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_WALK_L                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_WALK_L
        sta ZEROPAGE_POINTER_1 + 1

;===============================================================================
; IDLE ANIMATION: SPRITE RUNNING IN POSITION
;===============================================================================
        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts 

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady                       ; Screen is now scrolling (reads UpdateScroll)

;===============================================================================
; CHECK IF SPRITE HAS LANDED ON THE FLOOR
;=============================================================================== 

; Screen has stopped scrolling

@input

;===============================================================================
; NO FLOOR EXISTS YET. SPRITE KEEPS FALLING
;===============================================================================
        jsr ApplyGravity                ; Apply Gravity - if we are not falling

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@joyCheck
        lda JOY_X
        beq @exitLeft                       ; screen scrolls to left

;===============================================================================
; SPRITE IS MOVING TO THE LEFT
;===============================================================================
        lda PLAYER_JUMP_POS 
        cmp #14
        bcs @moveLeft

        lda #%00010000                  ; Mask for bit 0
        bit JOY_2                       ; check zero = button pressed
        beq @jumping                    ; Player can jump left

@moveLeft
        ldx #0
        jsr MovePlayerLeft              ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerLeft              ; Use twice for double speed
        jsr DetectSprite
        rts 

@skipLeftGravity
        rts

@butPress
        lda #255
        sta JOY_X
        lda #PLAYER_STATE_JUMP            ; go to walk state right
        jmp ChangePlayerState

;===============================================================================
; CHECK SCROLL SCREEN MOVE LEFT
;===============================================================================
@exitLeft
        lda #SCROLL_LEFT
        sta SCROLL_MOVING
        sta SCROLL_DIRECTION

        lda #PLAYER_STATE_IDLE              
        jmp ChangePlayerState

@jumping
        lda #PLAYER_STATE_JUMP
        jmp ChangePlayerState
@scrollLeft
        rts

#endregion

;===============================================================================
; PLAYER STATE SHOOT RIGHT
;-------------------------------------------------------------------------------
#region "Player State Shoot Right"
PlayerStateDead

; If Floor is not found, skip over death scenario
        ldx #1                                  ; Check at Sprite's feet                         
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_FLOOR                         ; Does floor exist under us?
        bne @exitDeath

; Floor is found. Check if Player is dead
        lda PLAYER_ISDEAD
        beq @exitDeath                          ; Player is not dead
        lda #1
        sta PLAYER_DIED

@deathAnimation
        lda #1
        sta SPRITE_ANIM_PLAY                 ; pause our animation

        lda PLAYER_SUBSTATE                     ; Check for first entry to state
        bne @running

;===============================================================================
; BEGIN PUNNCHING RIGHT ANIMATION
;===============================================================================
@showDeathAnim
        jsr ShowDeadSprite
;        jmp @running

        ldx #0
        lda #<ANIM_PLAYER_DEAD          ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  
        lda #>ANIM_PLAYER_DEAD
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda PLAYER_SUBSTATE_RUNNING             ; set the substate to Running
        sta PLAYER_SUBSTATE
        rts                                     ; wait till next frame to start

@running   
        jsr @restartMap 

@exitDeath
        rts
;===============================================================================
; PLAYER IS DEAD: RESET MAP
;===============================================================================
@restartMap 

@deathCD

; Check if Player is dead yet
        lda PLAYER_LIVES
        cmp #1
        bne @contGame
        jsr PlayerGameOver

; Flip score back to '000000' if game is over

        lda #1
        sta GAMESCORE_ACTIVE
        lda gamescore
        ldx #23 
        ldy #6  
        jsr ScoreBoard
        rts

@contGame
        jsr JoystickReady
        lda JOY_X
        bne @restartLife
        beq @showDeathAnim 

; Restart a new map
@restartLife
        loadPointer CURRENT_SCREEN,SCREEN1_MEM
        loadPointer CURRENT_BUFFER,SCREEN2_MEM

        ldx #65                        ; (129,26=default), 70,20
        ldy #20

        jsr DrawMap                     ; Draw the level map (Screen1)
                                        ; And initialize it

;        jsr CopyToBuffer                ; Copy to the backbuffer(Screen2)

; Display Game score since "DisplayConsolePanel" clears it 

;        lda #1
;        sta GAMESCORE_ACTIVE

;        lda gamescore
;        ldx #23 
;        ldy #6  
;        jsr ScoreBoard

        jsr DisplayConsolePanel

        lda #COLOR_LTRED
        sta VIC_SPRITE_MULTICOLOR_2
        lda #0
        sta PLAYER_DIED
        sta PLAYER_ISDEAD
        sta PLAYER_DAMAGE

        lda PLAYER_LIVES
        sec
        sbc #1
        sta PLAYER_LIVES
        rts

;===============================================================================
; STATE PUNCH RIGHT
;-------------------------------------------------------------------------------

; IMPORTANT: Checks when the Player can Move LEFT or RIGHT. No other state or 
; subroutine does this.

; The player is standing still and waiting input.
; Possible optimizations we are doublechecking CheckBlockUnder and CheckDown, 
; we can check once and store those in a temp variable and look them up if needed.
;===============================================================================
#region "Player State Punch Right"
PlayerStatePunchRight
        lda PLAYER_SUBSTATE                     ; Check for first entry to state
        bne @running

;===============================================================================
; BEGIN PUNNCHING RIGHT ANIMATION
;===============================================================================
        ldx #0
        lda #<ANIM_PLAYER_PUNCH_R               ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  
        lda #>ANIM_PLAYER_PUNCH_R
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda PLAYER_SUBSTATE_RUNNING             ; set the substate to Running
        sta PLAYER_SUBSTATE
        rts                                     ; wait till next frame to start
@running   
        jsr JoystickReady
        beq @input                              ; not ready for input, we return
        rts

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@input
        jsr PlayertoEnemyCollis
        lda ENEMY_HIT
        beq @missedRightPunch
        jsr EnemyStateRightDead
        jsr ResetEnemytoPlayerVertical
;        lda #0
;        sta ENEMY_HIT

@missedRightPunch
        lda #13
        sta PLAYER_JUMP_POS

        lda JOY_X
        beq @idle                       ; if JOY_X is 0 we are idling and need to change states
        bmi @idle                       ; if negative we are idling
        rts

@idle
        lda #0
        sta SPRITE_ANIM_PLAY            ; pause our animation

        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

#endregion

;===============================================================================
; STATE PUNCH RIGHT
;===============================================================================
#region "Player State Punch Left"
PlayerStatePunchLeft
        lda PLAYER_SUBSTATE                     ; Check for first entry to state
        bne @running

        ldx #0
        lda #<ANIM_PLAYER_PUNCH_L               ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  
        lda #>ANIM_PLAYER_PUNCH_L
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda PLAYER_SUBSTATE_RUNNING             ; set the substate to Running
        sta PLAYER_SUBSTATE
        rts                                     ; wait till next frame to start

@running
        lda #1
        sta SPRITE_ANIM_PLAY

        jsr JoystickReady
        beq @input
        rts

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@input
        jsr PlayertoEnemyCollis
        lda ENEMY_HIT
        beq @missedLeftPunch

;        lda #ENEMY_STATE_LEFT_DEAD 
;        jsr ChangeEnemyState
;        jsr ChangeEnemyStage
        jsr EnemyStateLeftDead
        jsr ResetEnemytoPlayerVertical
;        lda #0
;        sta ENEMY_HIT

@missedLeftPunch
        lda JOY_X
        beq @idle                       ; if JOY_X is 0 we are idling and need to change states
        bmi @idle                       ; if negative we are idling
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState
        rts

@idle
        rts
;        lda #0
;        sta SPRITE_ANIM_PLAY
;        rts
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState
#endregion

;===============================================================================
; PLAYER STATE SHOOT RIGHT
;-------------------------------------------------------------------------------
#region "Player State Shoot Right"
PlayerStateShootRight
        lda PLAYER_SUBSTATE                     ; Check for first entry to state
        bne @running

;===============================================================================
; BEGIN PUNNCHING RIGHT ANIMATION
;===============================================================================
        ldx #0
        lda #<ANIM_PLAYER_SHOOT_RIGHT          ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  
        lda #>ANIM_PLAYER_SHOOT_RIGHT
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda PLAYER_SUBSTATE_RUNNING             ; set the substate to Running
        sta PLAYER_SUBSTATE
        rts                                     ; wait till next frame to start
@running   
        jsr JoystickReady
        beq @input                              ; not ready for input, we return
        rts

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@input
        jsr PlayertoEnemyCollis
        lda ENEMY_HIT
        beq @missedRightShot

        jsr EnemyStateRightDead
        jsr ResetEnemytoPlayerVertical

@missedRightShot
        lda #13
        sta PLAYER_JUMP_POS

        lda JOY_X
        beq @idle                       ; if JOY_X is 0 we are idling and need to change states
        bmi @idle                       ; if negative we are idling
        rts

@idle
        lda #0
        sta SPRITE_ANIM_PLAY            ; pause our animation

        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

#endregion

;===============================================================================
; PLAYER STATE SHOOT LEFT
;-------------------------------------------------------------------------------
#region "Player State Shoot Left"
PlayerStateShootLeft
        lda PLAYER_SUBSTATE                     ; Check for first entry to state
        bne @running

;===============================================================================
; BEGIN PUNNCHING RIGHT ANIMATION
;===============================================================================
        ldx #0
        lda #<ANIM_PLAYER_SHOOT_LEFT            ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  
        lda #>ANIM_PLAYER_SHOOT_LEFT
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda PLAYER_SUBSTATE_RUNNING             ; set the substate to Running
        sta PLAYER_SUBSTATE
        rts                                     ; wait till next frame to start
@running   
        jsr JoystickReady
        beq @input                              ; not ready for input, we return
        rts

;===============================================================================
; NO JOYSTICK MOVEMEMENT - SET TO IDLE
;===============================================================================
@input
        jsr PlayertoEnemyCollis
        lda ENEMY_HIT
        beq @missedLeftShot

        jsr EnemyStateRightDead
        jsr ResetEnemytoPlayerVertical

@missedLeftShot
        lda JOY_X
        beq @idle                       ; if JOY_X is 0 we are idling and need to change states
        bmi @idle                       ; if negative we are idling
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState
        rts

@idle
        rts

#endregion

;===============================================================================
;  STATE KICK RIGHT
;===============================================================================
#region "Player State Kick Right"
PlayerStateKickRight
        lda PLAYER_SUBSTATE                     ; test for first run
        bne @running

;===============================================================================
; BEGIN KICKING RIGHT ANIMATION
;===============================================================================
        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_KICK_R                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_KICK_R
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                     ; state change goes into effect next frame

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady
        beq @idle                              ; not ready for input
        rts

@idle
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState
        ;-----------------------------------------------------------------------
#endregion

;===============================================================================
;  STATE KICK LEFT
;-------------------------------------------------------------------------------
;  Player state for climbing stairs
;-------------------------------------------------------------------------------
#region "Player State Kick Left"
PlayerStateKickLeft
        lda PLAYER_SUBSTATE                     ; test for first run
        bne @running

;===============================================================================
; BEGIN KICKING LEFT ANIMATION
;===============================================================================
        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_KICK_L                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_KICK_L
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                     ; state change goes into effect next frame

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady
        beq @idle                              ; not ready for input
        rts

@idle
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

;===============================================================================
;  PLAYER STATE POLE
;  Subroutine is only called if "COLL_POLE" is found
;===============================================================================
#region "Player State Pole"
PlayerStatePole
        lda PLAYER_SUBSTATE                     ; test for first run
        bne @running

;===============================================================================
; SET CLIMBING SPRITE
;===============================================================================
        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_CLIMB_POLE                   ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_CLIMB_POLE
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                     ; change takes effect next frame

;===============================================================================
; GET JOYSTICK TEST
;===============================================================================
@running
        jsr JoystickReady

;===============================================================================
; CHECK IF SPRITE IS ON THE POLE
;=============================================================================== 
@input
        lda #0
        sta PLAYER_JUMP_POS

        lda #1
        sta SPRITE_ANIM_PLAY                    ; start our animation

        lda COLOR_YELLOW
        sta VIC_SPRITE_MULTICOLOR_2 

;===============================================================================
; SPRITE IS ON THE POLE
;===============================================================================
; Is Sprite moving to the Left or Right?
;*******************************************************************************
        ldx #0                            
        jsr CheckBlockUnder 
        cmp #COLL_POLE                          ; Check for pole under player 
        beq @joychkOnPole

        lda #%00010000                          ; Mask for bit 0
        bit JOY_2                               ; check zero = jumping (button pressed)
        beq @butPress                           ; continue other check

@joychkOnPole
        lda JOY_X
        beq @checkJoystick                      ; joystick not moving left/right
        bmi @left
        bpl @right  
        rts

;===============================================================================
; CHECK FOR TILE COLLISION GOING LEFT
;===============================================================================
@left
        ldx #1
        jsr CheckMoveLeft
        beq @goLeft                             ; Not blocked, left routine
        rts

;===============================================================================
; POLE WAS FOUND: MOVE SPRITE UP
;=============================================================================== 
@exitPoleClimb 
        ldx #0
        jsr MovePlayerUp
        ldx #1
        jsr MovePlayerUp

;===============================================================================
; SPRITE HAS FALLEN OFF THE POLE
;===============================================================================
@noPoleFound
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

;===============================================================================
; CHECK IF SPRITE CAN MOVE TO THE RIGHT
;===============================================================================
@right
        ldx #1
        jsr CheckMoveRight
        beq @goRight                            ; Not blocked, right routine
        rts

;===============================================================================
; CALL SPRITE WALKING RIGHT SUBROUTINE
;===============================================================================
@goRight
        lda #PLAYER_STATE_WALK_RIGHT
        jmp ChangePlayerState

;===============================================================================
; CALL SPRITE WALKING LEFT SUBROUTINE
;===============================================================================
@goLeft
        lda #PLAYER_STATE_WALK_LEFT
        jmp ChangePlayerState

@butPress
        lda #PLAYER_STATE_JUMP
        jmp ChangePlayerState

;===============================================================================
; IF DELTA=4 PLAYER HAS PASSED THROUGH A TILE
;=============================================================================== 
@vertCheck 
        ldx #1
        lda SPRITE_POS_X_DELTA,x
        cmp #4                                  ; they pass through if delta is 4
        beq @checkJoystick                      ; We have passed completely through the tile
        bcc @deltaFinished                      ; if less than 4, shift right one pixel

        jsr MovePlayerLeft                      ; not equal, not less, must be more - shift left one
        jmp @checkJoystick

;===============================================================================
; SPRITE IS MOVING TO THE RIGHT
;===============================================================================
@deltaFinished
        ldx #0
        jsr MovePlayerRight
        ldx #1
        jsr MovePlayerRight    
        rts

;===============================================================================
; CHECK IF JOYSTICK IS IDLE OR MOVing UP OR DOWN
;===============================================================================
@checkJoystick
        lda JOY_Y                               ; Joystick not moving up/down
        beq @end
        bmi @up
        bpl @down
        rts

;===============================================================================
; SPRITE IS MOVING UP
;===============================================================================
@up
        ldx #0                            
        jsr CheckBlockUnder 
        cmp #COLL_POLE                          ; Check for pole under player 
        bne @poleNotAbove

        ldx #0
        jsr MovePlayerUp
        ldx #1
        jsr MovePlayerUp
        lda #0

@poleNotAbove
        rts

;===============================================================================
; SPRITE IS MOVING DOWN
;===============================================================================
@down
        ldx #1                            
        jsr CheckBlockUnder 
        cmp #COLL_POLE                          ; Check for pole under player 
        bne @poleNotBelow

        ldx #0
        jsr MovePlayerDown
        ldx #1
        jsr MovePlayerDown

@poleNotBelow
        rts

;===============================================================================
; IF DELTA=4 PLAYER HAS PASSED THROUGH A TILE
;===============================================================================
@endClimb
        lda SPRITE_POS_X_DELTA          ; Check if Sprite is passing 
        cmp #4                          ; completely through the tile
        beq @end                        ; Yes, they passed through
        rts    

@end
        lda #0
        sta SPRITE_ANIM_PLAY            ; pause our animation
        rts
#endregion

;===============================================================================
; PLAYER STATE SWIM RIGHT
;-------------------------------------------------------------------------------
#region "Player State Swim Right"
PlayerStateSwimR
        lda PLAYER_SUBSTATE
        bne @running

        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_SWIM_R                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_SWIM_R
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                     ; wait till next frame to start
        ;-----------------------------------------------------------------------------
@running
        lda #1
        sta SPRITE_ANIM_PLAY                    ; begin our animation when set to one

        jsr JoystickReady

@input
        lda JOY_X
        beq @idle
        bpl @right
        jmp @idle

@right
        ldx #0
        jsr MovePlayerRight             ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerRight
        rts

        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

@idle
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

@doneJoy
        rts
#endregion

;===============================================================================
; PLAYER STATE SWIM LEFT
;===============================================================================
#region "Player State Swim Left"
PlayerStateSwimL
        lda PLAYER_SUBSTATE
        bne @running

        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_SWIM_L                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_SWIM_L
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #PLAYER_SUBSTATE_RUNNING            ; set substate to RUNNING
        sta PLAYER_SUBSTATE
        rts                                     ; wait till next frame to start
        ;-----------------------------------------------------------------------
@running
        lda #1
        sta SPRITE_ANIM_PLAY                    ; begin our animation when set to one

        jsr JoystickReady

@input
        lda JOY_X
        beq @idle
        bmi @left
        jmp @idle

@left
        ldx #0
        jsr MovePlayerLeft             ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerLeft
        rts

        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

@idle
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

@doneJoy
        rts
#endregion

;===============================================================================
;  PLAYER STATE FLOATING
;===============================================================================
#region "Player State Walking Right"
PlayerStateFloating
        lda #0
        sta PLAYER_DIED
        sta PLAYER_ISDEAD
        sta PLAYER_DAMAGE

        lda #1
        sta SPRITE_ANIM_PLAY            ; pause our animation
        lda #0
        sta PLAYER_DAMAGE

        jsr JoystickReady

;===============================================================================
; IN WATER: LEFT/RIGHT MOVEMENT
;===============================================================================
@input
        lda JOY_X
        bmi @leftWaterMove
        bne @rightWaterMove

;===============================================================================
; IN WATER: UP/DOWN MOVEMENT
;===============================================================================
        lda JOY_Y
        beq @checkWaterCollis           ; No input, go to Floating routine
        bmi @checkWaterUp               ; joystick going up
        bpl @down                       ; joystick going down
        jmp @changeSpriteColor

@leftWaterMove
        lda #PLAYER_STATE_SWIM_L
        jmp ChangePlayerState

@rightWaterMove
        lda #PLAYER_STATE_SWIM_R
        jmp ChangePlayerState

;===============================================================================
; IN WATER: SPRITE RISES TO SURFACE
;===============================================================================
@checkWaterCollis
        ldx #0                                  ; Check at sprite's head
        jsr CheckBlockUnder                     ; Check under the sprite's feet
        cmp #COLL_POLE                          ; Does pole exist here?
        beq @poleFound                            ; Pole/ladder was found

        ldx #0                                  ; Check at sprite's head
        jsr CheckBlockUnder                     ; Check under the sprite's feet
        cmp #COLL_WATER                         ; water tile was found
        bne @end                                ; Sprite no longer in water
        jmp @goingUp                            ; Otherwise move him up

;===============================================================================
; IN WATER: CAN ONLY MOVE DOWN WHEN IN WATER
;===============================================================================
@checkWaterUp
        ldx #1
        jsr CheckMoveUp                     ; Check feet of sprite
        cmp #0                              ; Is sprite out of the water?
        beq @changeSpriteColor  

        ldx #1
        jsr CheckMoveUp                     ; Check tile under Top sprite (Sprite)
        cmp #COLL_WATER                     ; Does pole exist here?
        beq @goingUp                        ; No pole found, exit routine

        ldx #1
        jsr CheckMoveUp                     ; Check feet of sprite
        cmp #0                              ; Is sprite out of the water?
        bne @goingUp 
        rts

; Sprite has left the water
@changeSpriteColor
        lda #COLOR_BLUE
        sta VIC_SPRITE_MULTICOLOR_2         ; turn sprite blue under water 

@exitFloating
        rts

@goingUp
        lda #COLOR_BLUE
        sta VIC_SPRITE_MULTICOLOR_2

        ldx #0
        jsr MovePlayerUp             ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerUp             ; Move player one pixel across - A = move? 0 or 1
        rts

@poleFound
        rts

;===============================================================================
; IN WATER: CAN ONLY MOVE DOWN WHEN IN WATER
;===============================================================================
@down
        ldx #1
        jsr CheckBlockUnder                     ; Check tile under Top sprite (Sprite)
        cmp #COLL_WATER                         ; Does pole exist here?
        beq @goingDown 
        jmp @end

@goingDown
        lda #6
        sta VIC_SPRITE_MULTICOLOR_2            ; turn sprite blue under water 

        ldx #0
        jsr MovePlayerDown             ; Move player one pixel across - A = move? 0 or 1
        ldx #1
        jsr MovePlayerDown
        rts
@end
        lda #COLOR_LTRED
        sta VIC_SPRITE_MULTICOLOR_2
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

#endregion

;===============================================================================
; PLAYER STATE JUMP
;===============================================================================
#region "Player State Jump"
PlayerStateJump

; If Player is not jumping (executing "PlayerStateJump"), then
; the ApplyGravity routine still works to bring the sprite back down.
;===============================================================================
; CHECK IF SPACE ABOVE SPRITE IS OPEN
;===============================================================================
@jumping 
;        clc
;        adc #200
;        sta gamescore

;        lda #20                          ; Set VIC to Screen 6, Charset 2
;        sta VIC_MEMORY_CONTROL

        ;jsr UpdateTimers
        clc
        lda gamescore                                   ; increase score
        adc #1                                          ; 01,00
        sta gamescore

        ldx #0
        jsr CheckMoveUp                 ; Check for tile above our Sprite
        beq @contJump                   ; Tile exists, exit subroutine


        lda #0
        sta PLAYER_JUMP_POS

        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

;===============================================================================
; CHECK IF POLE IS ABOVE SPRITE
;===============================================================================
@contJump
        jsr JoystickReady

;===============================================================================
; CHECK IF FLOOR IS IS BELOW PLAYER SPRITE
;-------------------------------------------------------------------------------
; This is used to prevent Player sprite from jumping up through
; walls when on ladder or the floor.
;===============================================================================
        ldx #0                            
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_FLOOR                 ; Does floor exist under us?
        bne @checkJoyJumping

        ldx #1                            
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_FLOOR                 ; Does floor exist under us?
        beq @checkJoyJumping

        lda #0
        sta PLAYER_JUMP_POS 
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

;===============================================================================
; NO FLOOR IS ABOVE PLAYER SPRITE: So he can jump
;===============================================================================
@checkJoyJumping
        lda JOY_X
        beq @moveUp
        bmi @leftJump                   ; Check for joystick to Left = 255
        bpl @rightJump                  ; Check for joystick to Right = 1
        jmp @moveUp

;===============================================================================
; CHECK FOR JUMP TO THE RIGHT
;===============================================================================
@rightJump
        ldx #0
        jsr MovePlayerRight
        ldx #1
        jsr MovePlayerRight
        jmp @moveUp

;===============================================================================
; CHECK FOR JUMP TO THE LEFT
;===============================================================================
@leftJump
        ldx #0
        jsr MovePlayerLeft
        ldx #1
        jsr MovePlayerLeft
        jmp @moveUp

;===============================================================================
; CAN JUMP UP IF NOTHING IS ABOVE THE SPRITE
;===============================================================================
;===============================================================================
; IF NO FLOOR IS FOUND, SPRITE WILL FALL AT START
;===============================================================================
@moveUp
        ldx #1                            
        jsr CheckBlockUnder              
        lda COLLIDER_ATTR
        cmp #COLL_FLOOR                 ; Does floor exist under us?
        bne @spriteFalls

;        ldx #0
;        jsr MovePlayerUp

;===============================================================================
; SPRITE JUMPS UP IF < 12
;===============================================================================
        ldx #1
        jsr CheckMoveUp                 ; Check tile under Top sprite (Sprite)
        bne @cantMoveUp                ; blocked, can't move player up                                  

        lda PLAYER_JUMP_POS             ; for PLAYER_JUMP_TABLE,x to read until
        cmp #12                         ; it finds a "0" value. 28 bytes
        bcs @spriteFalls                ; sprite is falling only
        jmp @moveSpriteUp 

;===============================================================================
; SPRITE FALLS DOWN IF < 22
;===============================================================================
@spriteFalls
        lda PLAYER_JUMP_POS             ; for PLAYER_JUMP_TABLE,x to read until
        cmp #30                         ; it finds a "0" value. 28 bytes
        bcc @moveSpriteUp               ; sprite is falling only

;===============================================================================
; FLOOR IS FOUND UNDER SPRITE: CLEAR PLAYER_JUMP_POS, APPLY GRAVITY
;===============================================================================
@resetJump
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

;===============================================================================
; SPRITE IS NOT BLOCKED AND CAN FREELY JUMP UP
;===============================================================================
@moveSpriteUp  
        clc
        adc #1
        sta PLAYER_JUMP_POS             ; Counter to track table loop   

        ldx #0
        jsr MovePlayerUp
        ldx #1
        jsr MovePlayerUp
        rts

@cantMoveUp
        rts

#endregion

checkupright
        byte %0001001

checkupleft
        byte %0000101

PLAYER_STATE
        byte 0
PLAYER_SUBSTATE
        byte 0 

PLAYER_JUMP_POS
        byte 0

PLAYER_JUMP_TABLE
        byte 8,7,5,3,2,1,1,1,0,0

PLAYER_TIMER byte 0
PLAYER_SPEED byte 0

waterSpeed byte 0

PLAYER_LIVES byte 3
PLAYER_ISDEAD byte 0
PLAYER_DIED byte 0
PLAYER_DAMAGE byte 0
playerdeathDelay byte 0
flashcashDelay byte 0

PLAYER_CASH byte 0

GAMESCORE_ACTIVE byte 1         ; Checks if SCORE will show