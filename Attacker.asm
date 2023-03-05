;===============================================================================
; PLAYER.ASM  - PLAYER LOGIC
; Peter 'Sig' Hewett - Retroromicon 2017; PLAYER.ASM  - PLAYER LOGIC
;===============================================================================
;
; Handling player and player control logic
;-------------------------------------------------------------------------------
; SET SPRITE COLORS/MULITCOLORS 
;-------------------------------------------------------------------------------
#region "Enemy Setup"
EnemySetup
        lda #%11111111                          ; Turn on multicolor for sprites 0 and 1
        sta VIC_SPRITE_MULTICOLOR               ; also turn all others to single color

        lda #COLOR_BLACK
        sta VIC_SPRITE_MULTICOLOR_1             ; Set sprite shared multicolor 1 to brown
        lda #COLOR_LTRED
        sta VIC_SPRITE_MULTICOLOR_2             ; set sprite shared multicolor 2 to 'pink'

        lda #COLOR_GREEN
        sta VIC_SPRITE_COLOR + 2                ; set sprite 0 color to yellow
        lda #COLOR_BLUE
        sta VIC_SPRITE_COLOR + 3                ; set sprite 1 orange (bkground sprite)


        lda #1
        sta SPRITE_IS_ACTIVE,x
        inx
        sta SPRITE_IS_ACTIVE,x

;------------------------------------------------------------------------------
; We now use a system that tracks the sprite position in character coords on
; the screen, so to avoid costly calculations every frame, we set the sprite
; to a character border intially and track all movement from there. That way
; we need only do this set of calculations once in the lifetime of the Player.
;
; To initally place the sprite, we use 'SpriteToCharPos'
;------------------------------------------------------------------------------
; Set sprite images.  The sprites from the MLP Spelunker demo used 2 sprites
; overlapped so they could use an extra color.  So our main player sprite
; uses 2 sprites (0 and 1).  The first walking frame image 1, and it's
; background sprite is image 8.  We use the SetSpriteImage subroutine as it
; will update the pointers for both Screen1 and Screen2 for us.
;---------------------------------------------------------------------------
        lda #0
        sta SPRITE_DELTA_TRIM_X
        rts

#endregion

;===============================================================================
; UPDATE PLAYER 
;-------------------------------------------------------------------------------
; Update the player. Joystick controls are updated via interrupt so we read the 
; values from JOY_X and JOY_Y
;-------------------------------------------------------------------------------
#region "Update Enemy"

ENEMY_RIGHT_CAP = 50                      ; Sprite movement caps - at this point we don't
ENEMY_LEFT_CAP = $03                      ; Move the sprite, we scroll the screen
ENEMY_UP_CAP = $04                          
ENEMY_DOWN_CAP = $0F

UpdateEnemy
                                          ; Only update the player if it's active
        lda SPRITE_IS_ACTIVE              ; check against sprite #0 - is it active?
        bne @update 
        rts
@update
        ldx #2
        jsr AnimateSprite                 ; Display animation to screen
        jsr UpdateEnemyState              ; Update player by state
        rts

#endregion

;===============================================================================
; JOYSTICK / PLAYER MOVE
;===============================================================================
; The old system of joystick movement was going to become very unweildy very fast 
; and not be very
; good for expanding what the player can do. I'm trying a new system where the 
; routines are broken
; down and input is checked in individual states for what the player can do at 
; any given time.
; The movement routines will then be broken down and called as needed by the 
; states.
; Since the old system didn't actually read the joystick or scroll the screen 
; (it read / set
; variables by routines that do) - this SHOULD be fairly workable.
;-------------------------------------------------------------------------------

;===============================================================================
; JOYSTICK READY
;-------------------------------------------------------------------------------
; There are times atm when we have to ignore joystick input so the scrolling can 
; 'catch up' after
; movement stops. Usually for a couple of frames.
;
; Returns A :  0 = ready   1 = not ready
;
; Modifies A
;-------------------------------------------------------------------------------
;===============================================================================
; MOVE ENEMY RIGHT
;===============================================================================
; Move the player one pixel to the right if possible, taking into account 
; scrolling, map limits
; and collision detection against the screen
;
; Returns A: any blocking or special character to the right, or 0 if clear
;
;-------------------------------------------------------------------------------
#region "Move Enemy Right"
MoveEnemyRight
        lda #1
        sta PLAYER_DIRECTION
        lda #0
        sta SCROLL_FIX_SKIP
        ;------------------------------------------ CHECK RIGHT MOVEMENT CAP

        ldx #2
        lda SPRITE_POS_X,x         ; load the sprite char X position
        ldy #1
        clc
        adc ENEMY_DISTANCE
        ldy #1
        cmp SPRITE_POS_X,y     ; check against the right edge of the screen
        bcc @rightMove                  ; Sprite X is < 35

@contRightCheck
        lda MAP_X_POS                   ; load the current MAP X Position          
        cmp #100                         ; map = 64 tiles wide, screen = 10 tiles wide
        bne @verifyRightPosition
        lda MAP_X_DELTA                 ; each tile is 4 characters wide (0-3)
        cmp #1                          ; if we hit this limit we don't scroll (or move)
        bne @verifyRightPosition
                                        ;at this point we will revert to move 
        lda #1
        sta SCROLL_FIX_SKIP
        rts

@verifyRightPosition      
        lda #1                          ; 1 here would set him in middle
        sta ActiveTimer                 ; because 53264 bit is set
        rts

;===============================================================================
; If Enemy touches a POLE below feet then Enemy sprite
; cannot move right onto the ladder.
;===============================================================================                               
@rightMove
        ldx #2                            
        jsr CheckBlockUnder        ;works good
        lda COLLIDER_ATTR
        cmp #COLL_POLE
        beq @enemymovesdownPole

;===============================================================================
; IF Enemy was hit, sprite doesn't move right 
;===============================================================================
        lda ENEMY_HIT
        bne @rightenemyIsDown

;; How far will sprite move within timer?
        jsr EnemyFireRightTimer

;; Don't move Enemy to right until FIRE_RIGHT=0
        lda FIRE_RIGHT
        bne @rightDone

        ldx #2
        jsr MoveSpriteRight             ; Move sprites one pixel right
        ldx #3
        jsr MoveSpriteRight

        lda #0                          ; move code 'clear'
        rts

@rightenemyIsDown
        lda #0
        ldx #2
        sta SPRITE_POS_X,x
        ldx #3
        sta SPRITE_POS_X,x
        rts

@rightDone
        rts

@enemymovesdownPole    
        rts

#endregion

;===============================================================================
; MOVE ENEMY LEFT
;===============================================================================
; Move the player one pixel to the left if possible, taking into account 
; scrolling, map limits
; and collision detection against the screen
;
; Returns A: any blocking or special character to the right, or 0 if clear
;-------------------------------------------------------------------------------
#region "Move Enemy Left"
MoveEnemyLeft
        lda #2
        sta PLAYER_DIRECTION
        lda #0                          ; Make sure scroll 'fix' is on
        sta SCROLL_FIX_SKIP

;================================================================
; Read Enemy Sprite(Head) - sbc #20
; If Enemy Sprite(Head) > Player(1) goto @leftMove

; So if the enemy sprite is standing beyond the Player sprite
; then move the enemy to the left toward the Player.

; If SPRITE_POS_x,(2) > SPRITE_POS_X,y(1)

        ldx #2
        lda SPRITE_POS_X,x         ; load the sprite char X position
        ldy #1
        sec
        sbc ENEMY_DISTANCE
        ldy #1
        cmp SPRITE_POS_X,y     ; check against the right edge of the screen
        bcs @leftMove                  ; Sprite X is < 35

@contLeftCheck
        lda MAP_X_POS                   ; Check for map pos X = 0
        bne @verifyLeftPosition                 
        lda MAP_X_DELTA                 ; check for map delta = 0
        bne @verifyLeftPosition
        rts

; Sprite is now at the far left hand corner
@verifyLeftPosition
        lda #1
        sta ActiveTimer
        rts

;===============================================================================
; If Enemy touches a POLE below feet then Enemy sprite
; cannot move left onto the ladder.
;=============================================================================== 
@leftMove      
        ldx #2                            
        jsr CheckBlockUnder             ;works good
        lda COLLIDER_ATTR
        cmp #COLL_POLE
        beq @moveDownPole

;===============================================================================
; IF Enemy was hit, sprite doesn't move left 
;===============================================================================
        lda ENEMY_HIT
        bne @leftenemyIsDown
        jsr EnemyFireRightTimer

        lda FIRE_LEFT
        bne @leftDone

        ldx #2
        jsr MoveSpriteLeft
        ldx #3
        jsr MoveSpriteLeft

        lda #0                          ; move code 'clear'
        rts

@leftenemyIsDown
        lda #50
        ldx #2
        sta SPRITE_POS_X,x
        ldx #3
        sta SPRITE_POS_X,x
        lda #0
        sta 53278
        rts

; Sprite hit a tile (other than the floor)
@leftDone
        rts

@moveDownPole
        rts

#endregion
;===============================================================================
; MOVE ENEMY DOWN
;===============================================================================
; Move the player one pixel down if possible, taking into account scrolling, 
; map limits and collision detection against the screen
;
; Returns A: any blocking or special character below, or 0 if clear
;
; Modifies X
;-------------------------------------------------------------------------------
#region "Move Enemy Down"
MoveEnemyDown
        lda SPRITE_CHAR_POS_Y,x
        cmp #ENEMY_DOWN_CAP
        bcc @downMove

        lda ENMAP_Y_POS
        cmp #$1B
        bne @downScroll
        lda ENMAP_Y_DELTA
        cmp #02
        bcc @downScroll
        rts

@downScroll
        ldx #2                          ; Check Sprite #2
        jsr EnemyCheckMoveDown          ; returns: 0 = can move : 1 = blocked
        beq @scroll
        rts                             ; return with contents of collison routine

@scroll
        lda ENMAP_Y_DELTA                 ; increment the MAP_Y_DELTA
        clc
        adc #1
        and #%0011                      ; Mask to a value between 0-3
        sta ENMAP_Y_DELTA

        cmp #0                          ; check for crossover to a new tile
        beq @newtile
        rts
@newtile
        lda MAP_Y_POS
        sta ENMAP_Y_POS
        inc ENMAP_Y_POS                   ; increment MAP Y POS on a new tile
        rts

@downMove
        lda #1
        sta ENEMYDOWNCAP
        ldx #2                          ; Check Sprite #2
        jsr EnemyCheckMoveDown          ; returns: 0 = can move : 1 = blocked
        bne @downDone                   ; retun with contents of collision code

        ldx #2                          ; = 0 so we can move the Sprite Down
        jsr MoveSpriteDown
        ldx #3
        jsr MoveSpriteDown
        lda #0                          ; return with clear code
@downDone
        rts

@moveDownPole
        rts
        lda #ENEMY_STATE_WALK_D
        jsr ChangeEnemyState
        jsr EnemyStateWalkDown
        rts

#endregion

;===============================================================================
; MOVE PLAYER RIGHT
;===============================================================================
; Move the player one pixel up if possible, taking into account scrolling, 
; map limits and collision detection against the screen
;
; Returns A: any blocking or special character below, or 0 if clear
;-------------------------------------------------------------------------------
#region "Move Enemy Up"
MoveEnemyUp
        sec
        lda ENEMY_SPRITE_CHAR_POS_Y
        cmp #ENEMY_UP_CAP
        bcs @upMove

        lda MAP_Y_POS
        bne @upScroll
        clc
        lda MAP_Y_DELTA
        cmp #1
        bcs @upScroll
        rts

@upScroll
        ldx #2
        jsr EnemyCheckMoveUp
        beq @scroll
        rts

@scroll
        lda #SCROLL_UP
        sta SCROLL_DIRECTION
        sta SCROLL_MOVING
        rts

@upMove
        ldx #2
        jsr EnemyCheckMoveUp
        bne @upDone

        ldx #2
        jsr MoveSpriteUp
        ldx #3
        jsr MoveSpriteUp
@upDone
        rts

#endregion

#region "Move Bullet Right"
MoveBulletRight
        ldx #2
        ldy #5
        lda SPRITE_POS_Y,x         ; Get enemy's Y position
        sta SPRITE_POS_X,y         ; Save in bullet Y position

        ldx #5
        lda SPRITE_POS_X,x         ; load the bullet's X position
        ldy #1
;        clc
;        adc ENEMY_DISTANCE
        cmp #50     ; check against the right edge of the screen
        bcc @moveBulletRight                  ; Sprite X is < 35

; Bullet has traveled across the screen
        ldx #5
        ldy #2
        lda SPRITE_POS_X,y         ; Get enemy sprite's X position
        sta SPRITE_POS_X,x         ; Save in bullet X location
        rts

;===============================================================================
; If Enemy touches a POLE below feet then Enemy sprite
; cannot move right onto the ladder.
;===============================================================================                               
@moveBulletRight

;===============================================================================
; IF Enemy was hit, sprite doesn't move right 
;===============================================================================
        ldx #5
        jsr MoveSpriteRight             ; Move sprites one pixel right

        lda #0                          ; move code 'clear'
        rts

#endregion

#region "Move Bullet Left"
MoveBulletLeft
        ldx #2
        ldy #4
        lda SPRITE_POS_Y,x         ; Get enemy's Y position
        sta SPRITE_POS_X,y         ; Save in bullet Y position

        ldx #4
        lda SPRITE_POS_X,x         ; load the bullet's X position
        ldy #1
;        clc
;        adc ENEMY_DISTANCE
        cmp #1     ; check against the right edge of the screen
        bcs @moveBulletLeft                  ; Sprite X is < 35

; Bullet has traveled across the screen
        ldx #4
        ldy #2
        lda SPRITE_POS_X,y         ; Get enemy sprite's X position
        sta SPRITE_POS_X,x         ; Save in bullet X location
        rts

;===============================================================================
; If Enemy touches a POLE below feet then Enemy sprite
; cannot move right onto the ladder.
;===============================================================================                               
@moveBulletLeft
;===============================================================================
; IF Enemy was hit, sprite doesn't move right 
;===============================================================================
        ldx #5
        jsr MoveSpriteLeft             ; Move sprites one pixel right

        lda #0                          ; move code 'clear'
        rts

#endregion

;===============================================================================
; DISABLE SPRITE
;===============================================================================
DisableEnemySprite
        lda $d01b               ; 53275
        and #32
        sta $d01b
        rts

;-------------------------------------------------------------------------------
;===============================================================================
; ENEMY STATES
;===============================================================================
; Player states are incremented by 2 as they are indexes to look up the address
; of the state code on the PLAYER_STATE_JUMPTABLE.  
; An address is 2 bytes (1 word) egro the index must increase by 2 bytes.
;-------------------------------------------------------------------------------
ENEMY_STATE_IDLE       = 0     ; standing still - awaiting input
ENEMY_STATE_WALK_R     = 2     ; Walking right
ENEMY_STATE_WALK_L     = 4     ; Walking left
ENEMY_STATE_WALK_D     = 6     ; Walking down
ENEMY_STATE_ROPE       = 8    ; climb rope
ENEMY_STATE_JUMP       = 10    ; Jumping
ENEMY_STATE_PUNCH_R    = 12    ; punch right
ENEMY_STATE_PUNCH_L    = 14    ; punch left
ENEMY_STATE_KICK_R     = 16    ; kick right
ENEMY_STATE_KICK_L     = 18    ; kick left
ENEMY_STATE_ATTACK_RIGHT = 20  ; Attack right
ENEMY_STATE_ATTACK_LEFT = 22   ; Attack right
ENEMY_STATE_RIGHT_DEAD = 24    ; Right enemy dead
ENEMY_STATE_LEFT_DEAD =  26    ; Left enemy dead
ENEMY_STATE_FIRING_RIGHT =  28 ; Enemy firing to right
ENEMY_STATE_FIRING_LEFT =  30  ; Enemy firing to left

ENEMY_SUBSTATE_ENTER   = 0     ; we have just entered this state
ENEMY_SUBSTATE_RUNNING = 1     ; This state is running normally
ENEMY_SUBSTAGE_RUNNING = 1

ENEMY_STATE_JUMPTABLE
        word EnemyStateIdle
        word EnemyStateWalkR
        word EnemyStateWalkL
        word EnemyStateWalkDown
        word EnemyStateRope
        word EnemyStateJump
        word EnemyStatePunchR
        word EnemyStatePunchL
        word EnemyStateKickR
        word EnemyStateKickL
        word EnemyStateAttackRight
        word EnemyStateAttackLeft
        word EnemyStateRightDead
        word EnemyStateLeftDead
        word EnemyStateFiringRight
        word EnemyStateFiringLeft

ENEMY_SUBSTAGE_JUMPTABLE
        word EnemyStateIdle
        word EnemyStateWalkR
        word EnemyStateWalkL
        word EnemyStateRope
        word EnemyStateJump
        word EnemyStatePunchR
        word EnemyStatePunchL
        word EnemyStateKickR
        word EnemyStateKickL
        word EnemyStateAttackRight
        word EnemyStateAttackLeft
        word EnemyStateRightDead
        word EnemyStateLeftDead        

;-------------------------------------------------------------------------------
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
#region "Change Enemy State"
ChangeEnemyState
        tax                                            ; transfer A to X
        sta ENEMY_STATE                                ; store the new player state                            
        lda #0                                        ; Set substate to ENTER
        sta ENEMY_SUBSTATE

        lda #1
        sta SPRITE_ANIM_PLAY

        lda ENEMY_STATE_JUMPTABLE,x                    ; lookup state to change to
        sta ZEROPAGE_POINTER_1                         ; and store it in ZEROPAGE_POINTER_1

        lda ENEMY_STATE_JUMPTABLE + 1,x
        sta ZEROPAGE_POINTER_1 + 1

        jmp (ZEROPAGE_POINTER_1)                       ; jump to state (to setup)
                                                       ; NOTE: This is NOT a jsr.
                                                       ; The state will act as an extension of
                                                       ; this routine then return
#endregion

ChangeEnemyStage
        sta ENEMY_STATE                                ; store the new player state                            
        lda #ENEMY_SUBSTAGE_RUNNING
        sta ENEMY_SUBSTAGE

        lda #1
        sta SPRITE_ANIM_PLAY
        rts

ChangeEnAnimState
        lda #0
        sta ENANIM_STATE
        rts

;===============================================================================
; UPDATE ENEMY STATE
;===============================================================================
; Update the player based on their state
;-------------------------------------------------------------------------------
#region "Update Enemy State"
UpdateEnemyState
        ldx ENEMY_STATE                        ; Load player state
        lda ENEMY_STATE_JUMPTABLE,x            ; fetch the state address from the jump table
        sta ZEROPAGE_POINTER_1                  ; store it in ZEROPAGE_POINTER_1
        lda ENEMY_STATE_JUMPTABLE +1,x
        sta ZEROPAGE_POINTER_1 + 1
        jmp (ZEROPAGE_POINTER_1)                ; jump to the right state

#endregion

#region "Set Enemy State"
SetEnemyState
        ldx ENEMY_SUBSTAGE                      ; Load player state
        lda ENEMY_SUBSTAGE_JUMPTABLE,x          ; fetch the state address from the jump table
        sta ZEROPAGE_POINTER_1                  ; store it in ZEROPAGE_POINTER_1
        lda ENEMY_SUBSTAGE_JUMPTABLE +1,x
        sta ZEROPAGE_POINTER_1 + 1
        rts
#endregion

;===============================================================================
; RESET ENEMY to ALIGN WITH PLAYER'S VERTICAL POSITION
;-------------------------------------------------------------------------------
; This is used when relocating a sprite's position on another screen/level
;===============================================================================
#region "Reset Enemy to Player Vertical"
ResetEnemytoPlayerVertical
        ldx #0
        lda SPRITE_POS_Y,x              ; Find Player sprite Y (head) pos
        ldx #2
        sta SPRITE_POS_Y,x              ; Set enemy Head(y) to Player Y
        ldx #1
        lda SPRITE_POS_Y,x              ; Find Player sprite Y (body) pos
        ldx #3
        sta SPRITE_POS_Y,x              ; Set enemy Body(y) to Player Y
        rts
#endregion

;===============================================================================
; CHECK FOR ENEMY COLLISION BETWEEN PLAYER SPRITE
;===============================================================================
#region "Enemy to Player Collision"
EnemytoPlayerCollision
        lda #0
        sta ENEMY_HIT
        ldx #1               
        ldy #3
        lda SPRITE_POS_X,x
        cmp SPRITE_POS_X,y
        bne @noEnemyCollis

; When a enemy strikes down our sprite, make sure that the 
; sprite Y position is always aligned on the same level as
; the enemies.

;        jsr ResetEnemytoPlayerVertical
        lda #1
        sta ENEMY_HIT
        rts
@noEnemyCollis
        lda #0
        sta ENEMY_HIT
        rts
#endregion

; SID Timer Random seed generator
; Used to ping when an enemy will walk onto the screen.

;===============================================================================
; ACTIVATE SID RANDOM GENERATOR TIMER
;===============================================================================
#region "Enemy Random Timer"
EnemyRandomTimer
        lda ActiveTimer
        bne @beginCount

; ActiveTimer=0 means EnemyVisible state is on
        rts

; If ActiveTimer >0 then sprites are not moving
@beginCount
        lda #10
        sta $d40e               ; Voice 3 frequency low byte 
        sta $d40f               ; Voice 3 frequency high byte           
        lda #$80                ; Noice waveform, gate bit off 
        sta $d412               ; Voice 3 control register

; Using a variable timer
        inc EnemyCountDown
        lda EnemyCountDown
        cmp #30
        bcs @enemyCDReached
        rts

@enemyCDReached
        lda $d41b
        sta EnemyTimer
        cmp #240                ; > 200
        bcs @notFound
        cmp #240                ; <100
        bcc @checkbelow240
        lda #0
        sta EnemyCountDown
        jmp @notFound

; Future: Could be used to purchase weapons (at store)
; Sword <190 = $19
; Club < 150 $150
; Whip <30   = $300 
  

; Later on we could set <50 = sprite abandonment. Meaning sprite left the 
; screen before deciding to attack.
; <30 = sprite is friendly, no attacks - static pedestrian

; Could also have a sprite enter the screen and leave quickly before
; approaching the Player (makes them harder to kill)

@checkbelow240
        cmp #190
        bcs SetEnemyRight       ; <190
;        cmp #180
;        bcc SetEnemyFiringRight
        cmp #170                                                
        bcc SetEnemyLeft        ; < 100
;        cmp #160
;        bcc SetEnemyFiringLeft
        lda #0
        sta EnemyCountDown
        rts

@notFound
        lda #ENEMY_STATE_IDLE
        jsr ChangeEnemyState
;        jsr EnemyStateIdle
        rts
#endregion

SetEnemyRight
        lda #0
        sta EnemyCountDown
        jsr EnemyVisible
        rts

SetEnemyFiringRight
;        jsr EnemyStateFiringRight
        rts

SetEnemyFiringLeft
;        jsr EnemyStateFiringLeft
        rts

SetEnemyLeft
        lda #0
        sta EnemyCountDown
        jsr EnemyVisible
        rts

;===============================================================================
; ENEMY CHECK: TO DETERMINE IF A SPAWN OCCURS
;-------------------------------------------------------------------------------
; If no floor exists, can't move enemy sprite left/right
;===============================================================================
#region "Enemy Visible"
EnemyVisible
        ldx #3                            
        jsr EnemyCheckBlockUnder
        lda COLLIDER_ATTR
        cmp #COLL_FLOOR
        beq @beginMoveRoutine

;        jsr ResetEnemytoPlayerVertical
; No floor was found under sprite's feet, so we exit.
@cantMove
        rts

@beginMoveRoutine
        lda #0
        sta ActiveTimer
        jsr EnemyActionState
        rts
#endregion

;===============================================================================
; ENEMY DIRECTION MOVEMENT DETERMINATION
;===============================================================================
; This is used to first reset the Enemy to Player vertical
; position and then see where Player is in relation to the
; enemy sprite and move towards the Player.
;-------------------------------------------------------------------------------
;===============================================================================
; ENEMY ACTION STATE
;===============================================================================
#region "Enemy Action State"
EnemyActionState

; Check if sprite is on the floor at start so he won't appear in the air
;        jsr ResetEnemytoPlayerVertical

; Check direction enemy moves based on where Player is.
; If Enemy is in front of Player, enemy moves left.
; If Enemy is behind Player, enemy moves right.

; How far will sprite move within timer?
;        jsr EnemyFireRightTimer

; Don't move Enemy to right until FIRE_RIGHT=0
;        lda FIRE_RIGHT
;        bne @exitStage

        lda ENEMY_BULLETS
        beq @moveEnSprite
;        jsr MoveBulletRight

@moveEnSprite
        ldx #2
        ldy #1
        lda SPRITE_POS_X,x           ; Enemy sprite X position
;        sec
;        sbc ENEMY_DISTANCE
        cmp SPRITE_POS_X,y           ; Player sprite X position
        bcs @movingDirLeftSprite

        lda SPRITE_POS_X,x
;        clc
;        adc ENEMY_DISTANCE
        cmp SPRITE_POS_X,y           ; Player sprite X position
        bcc @movingDirRightSprite

; Go back and start the timer again, which determines which sprite
; moves on random.
@exitStage
        lda #1
        sta ActiveTimer
        rts

@movingDirRightSprite
; Check if we are coming from the left side
        lda #ENEMY_STATE_WALK_R
        jsr ChangeEnemyState
;        jsr EnemyStateWalkR
        rts

; When sprite contacts a ladder/pole he starts moving Left
@movingDirLeftSprite
        lda #ENEMY_STATE_WALK_L
        jsr ChangeEnemyState
;        jsr EnemyStateWalkL
        rts

#endregion

;===============================================================================
; ENEMY STATE WALK RIGHT
;===============================================================================
#region "Enemy State Walk Right"
EnemyStateWalkR
        lda #1
        sta SPRITE_ANIM_PLAY                   ; pause our animation

        lda ENEMY_SUBSTATE
        bne @running

        ldx #2                                 ; Use sprite number 2
        lda #<ANIM_ENEMY_WALK_R                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_WALK_R
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                     ; initialize the animation
        lda #1                                 ; set substate to RUNNING
        sta ENEMY_SUBSTATE
        rts                                    ; wait till next frame to start
@running
        ldx #2
        jsr MoveEnemyRight              ; = 0 so we can move the Sprite Down
        ldx #3
        jsr MoveEnemyRight
        rts
#endregion;===============================================================================
; ENEMY STATE IDLE
;===============================================================================
#region "Enemy State Bullet"
EnemyStateBullet
;        lda #1
;        sta SPRITE_ANIM_PLAY                 ; pause our animation

;;        lda ENEMY_SUBSTATE
;;        bne @running

;        ldx #2                               ; Use sprite number 2
;        lda #<ANIM_ENEMY_BULLET                ; load animation in ZEROPAGE_POINTER_1
;        sta ZEROPAGE_POINTER_1
;        lda #>ANIM_ENEMY_BULLET
;        sta ZEROPAGE_POINTER_1 + 1

;        jsr InitSpriteAnim                   ; initialize the animation
;;        lda #1                               ; set substate to RUNNING
;;        sta ENEMY_SUBSTATE
;        rts                                  ; wait till next frame to start
@running
        rts

;===============================================================================
; ENEMY STATE IDLE
;===============================================================================
#region "Enemy State Idle"
EnemyStateIdle
        lda #1
        sta SPRITE_ANIM_PLAY                 ; pause our animation

        lda ENEMY_SUBSTATE
        bne @running

        ldx #2                               ; Use sprite number 2
        lda #<ANIM_ENEMY_IDLE                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_IDLE
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                   ; initialize the animation
        lda #1                               ; set substate to RUNNING
        sta ENEMY_SUBSTATE
        rts                                  ; wait till next frame to start
@running
        rts

#endregion

;===============================================================================
; ENEMY FIRE RIGHT TIMER
;-------------------------------------------------------------------------------
; This is used to check when to shoot at the Player
; Will be used later to have an enemy approach the
; Player, stop and shoot. Move again, stop and shoot, and repeat
;===============================================================================
#region "Enemy Fire Right Timer"
EnemyFireRightTimer
        lda #10
        sta $d40e               ; Voice 3 frequency low byte 
        sta $d40f               ; Voice 3 frequency high byte           
        lda #$80                ; Noise waveform, gate bit off 
        sta $d412               ; Voice 3 control register

        inc EnemyFireCD
        lda EnemyFireCD
        cmp #80
        bcs @enemyTimerComplete
        rts

@enemyTimerComplete
        lda $d41b
        sta EnemyTimer
        cmp #240
        bcs @timernotFound
        cmp #150
        bcs @waitToFire

@timernotFound
        lda #0
        sta EnemyFireCD
        lda #3
        sta PLAYER_DIRECTION
        rts

; Allows a delay to wait for enemy fire (enabling more walking)
@waitToFire
;        jsr MoveBulletLeft
        dec ENEMY_BULLETS
        lda ENEMY_BULLETS
        beq @readyToFire
        rts

@readyToFire
        lda #5
        sta WaitToFireCD
        sta ENEMY_BULLETS
        
        lda FiringHoldCD
        bne FiringHoldState

;        lda #ENEMY_STATE_FIRING_RIGHT
;        jsr ChangeEnAnimState
;        jsr ChangeEnemyState
        lda PLAYER_DIRECTION
        cmp #1
        bne @shootToLeft

@shootToRight
        jsr EnemyStateFiringRight
        lda #1
        sta FIRE_RIGHT
        jsr FiringHoldState
        rts

;@enemyFiringLeft
@shootToLeft
;        lda #ENEMY_STATE_FIRING_LEFT
;        jsr ChangeEnAnimState
;        jsr ChangeEnemyState
        jsr EnemyStateFiringLeft
        lda #1
        sta FIRE_LEFT
        jsr FiringHoldState
        rts

FiringHoldState
        inc FiringHoldCD
        lda FiringHoldCD
        cmp #4
        bcs @fireholdDone
        rts

@fireholdDone
        lda #0
        sta FIRE_RIGHT
        sta FIRE_LEFT
        sta FiringHoldCD
        rts       

#endregion

;===============================================================================
; ENEMY STATE WALK LEFT
;===============================================================================
#region "Enemy State Walk Left"
EnemyStateWalkL
        lda #1
        sta SPRITE_ANIM_PLAY                   ; start our animation

        lda ENEMY_SUBSTATE
        bne @running

        ldx #2                                 ; Use sprite number 2
        lda #<ANIM_ENEMY_WALK_L                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_WALK_L
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                     ; initialize the animation
        lda #1                                 ; set substate to RUNNING
        sta ENEMY_SUBSTATE
        rts                                    ; wait till next frame to start

@running
        ldx #2
        jsr MoveEnemyLeft              ; = 0 so we can move the Sprite Down
        ldx #3
        jsr MoveEnemyLeft
        rts

#endregion

;===============================================================================
; ENEMY STATE FIRING RIGHT
;===============================================================================
#region "Enemy State Firing Right"
EnemyStateFiringRight
        lda #1
        sta SPRITE_ANIM_PLAY                    ; start our animation

        ldx #2                                  ; Use sprite number 2
        lda #<ANIM_ENEMY_FIRING_RIGHT           ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_FIRING_RIGHT
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        rts

@running
        rts

        lda #ENEMY_STATE_IDLE
        jmp ChangePlayerState

        lda JOY_X
        beq @idle                       ; if JOY_X is 0 we are idling and need to change states
        bmi @idle                       ; if negative we are idling
        lda #ENEMY_STATE_IDLE
        jmp ChangePlayerState

@idle
        rts

        lda #ENEMY_STATE_IDLE
        jmp ChangePlayerState
        rts

#endregion

;===============================================================================
; ENEMY STATE FIRING LEFT
;===============================================================================
#region "Enemy State Firing Left"
EnemyStateFiringLeft
        lda #1
        sta SPRITE_ANIM_PLAY                    ; start our animation

        ldx #2                                  ; Use sprite number 2
        lda #<ANIM_ENEMY_FIRING_LEFT            ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_FIRING_LEFT
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                     ; initialize the animation
        rts                                    ; wait till next frame to start

@running
        lda JOY_X
        beq @idle                       ; if JOY_X is 0 we are idling and need to change states
        bmi @idle                       ; if negative we are idling
        rts
        lda #ENEMY_STATE_IDLE
        jmp ChangePlayerState

@idle
        rts

        lda #ENEMY_STATE_IDLE
        jmp ChangePlayerState
        jsr WaitFrame
        rts

#endregion

;===============================================================================
; ENEMY STATE WALK DOWN
;===============================================================================
#region "Enemy State Walk Down"
EnemyStateWalkDown
        lda #1
        sta SPRITE_ANIM_PLAY                   ; start our animation

        lda ENEMY_SUBSTAGE
        bne @running

        ldx #2                                 ; Use sprite number 2
        lda #<ANIM_ENEMY_WALK_D                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_WALK_D
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                     ; initialize the animation
        lda #ENEMY_SUBSTAGE_RUNNING            ; set substate to RUNNING
        sta ENEMY_SUBSTAGE
        rts                                    ; wait till next frame to start

@running
        ldx #2
        jsr MoveEnemyDown              ; = 0 so we can move the Sprite Down
        ldx #3
        jsr MoveEnemyDown
        rts

#endregion

;===============================================================================
; ENEMY STATE ATTACK RIGHT
;-------------------------------------------------------------------------------
; Used when enemy attacks the Player to the right
;===============================================================================
#region "Enemy State Attack Right"
EnemyStateAttackRight
        lda #1
        sta SPRITE_ANIM_PLAY                    ; pause our animation

        lda ENEMY_SUBSTATE
        bne @running

        ldx #2                                  ; Use sprite number 2
        lda #<ANIM_ENEMY_ATTACK_RIGHT           ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_ATTACK_RIGHT
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                     ; initialize the animation
        lda #1                                 ; set substate to RUNNING
        sta ENEMY_SUBSTATE
        rts                                    ; wait till next frame to start
@running
        rts
#endregion

;===============================================================================
; ENEMY STATE ATTACK LEFT    
;-------------------------------------------------------------------------------
;===============================================================================
#region "Enemy State Attack Left"
EnemyStateAttackLeft
        lda #1
        sta SPRITE_ANIM_PLAY                   ; pause our animation

        lda ENEMY_SUBSTATE
        bne @running

        ldx #2                                 ; Use sprite number 2
        lda #<ANIM_ENEMY_ATTACK_LEFT           ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_ATTACK_LEFT
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                     ; initialize the animation
        lda #1                                 ; set substate to RUNNING
        sta ENEMY_SUBSTATE
        rts                                    ; wait till next frame to start
@running
        rts
#endregion

;===============================================================================
; ENEMY STATE RIGHT DEAD
;===============================================================================
#region "Enemy State Right Dead"
EnemyStateRightDead
        lda #1
        sta SPRITE_ANIM_PLAY                    ; start our animation

        lda ENEMY_SUBSTATE
        bne @running

        ldx #2                                  ; Use sprite number 2
        lda #<ANIM_ENEMY_RIGHT_DEAD             ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_RIGHT_DEAD
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                     ; initialize the animation
        lda #ENEMY_SUBSTAGE_RUNNING            ; set substate to RUNNING
        sta ENEMY_SUBSTATE
        rts                                    ; wait till next frame to start

@running
        jsr WaitFrame
        rts

#endregion

;===============================================================================
; ENEMY STATE LEFT DEAD
;===============================================================================
#region "Enemy State Left Dead"
EnemyStateLeftDead
        lda #1
        sta SPRITE_ANIM_PLAY                    ; start our animation

        lda ENEMY_SUBSTAGE
        bne @running

        ldx #2                                  ; Use sprite number 2
        lda #<ANIM_ENEMY_LEFT_DEAD              ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_LEFT_DEAD
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                     ; initialize the animation
        lda #ENEMY_SUBSTAGE_RUNNING            ; set substate to RUNNING
        sta ENEMY_SUBSTAGE
        rts                                    ; wait till next frame to start

@running
        jsr WaitFrame
        rts

#endregion

;===============================================================================
; ENEMY STATE PUNCH RIGHT
;-------------------------------------------------------------------------------

; IMPORTANT: Checks when the Player can Move LEFT or RIGHT. No other state or 
; subroutine does this.

; The player is standing still and waiting input.
; Possible optimizations we are doublechecking CheckBlockUnder and CheckDown, 
; we can check once and store those in a temp variable and look them up 
; if needed.
;-------------------------------------------------------------------------------
#region "Enemy State Punch Right"
EnemyStatePunchR
        lda ENEMY_SUBSTATE                     ; Check for first entry to state
        bne @running

        ldx #0
        lda #<ANIM_PLAYER_PUNCH_R             ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  
        lda #>ANIM_PLAYER_PUNCH_R
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                     ; setup the animation for Idle
        lda #1                                 ; set the substate to Running
        sta ENEMY_SUBSTATE
        rts                                    ; wait till next frame to start

@running
        jsr JoystickReady
        beq @input
        rts                                    ; not ready for input, we return

@input                                         ; process valid joystick input
        beq @joyCheck

@joyCheck

        lda JOY_X
        beq @idle                       ; if JOY_X is 0 we are idling and need to change states
        bmi @idle                       ; if negative we are idling

@doneJoy
        rts
@idle
        lda #0
        sta SPRITE_ANIM_PLAY            ; pause our animation

        lda #ENEMY_STATE_IDLE
        jmp ChangeEnemyState

#endregion

;===============================================================================
; ENEMY STATE PUNCH LEFT
;-------------------------------------------------------------------------------

; IMPORTANT: Checks when the Player can Move LEFT or RIGHT. No other state or 
; subroutine does this.

; The player is standing still and waiting input.
; Possible optimizations we are doublechecking CheckBlockUnder and CheckDown, 
; we can check once and store those in a temp variable and look them up 
; if needed.
;-------------------------------------------------------------------------------
#region "Enemy State Punch Left"
EnemyStatePunchL
        lda ENEMY_SUBSTATE                     ; Check for first entry to state
        bne @running

        ldx #0
        lda #<ANIM_PLAYER_PUNCH_L              ; load animation list in ZEROPAGE_POINTER_1 
        sta ZEROPAGE_POINTER_1                  
        lda #>ANIM_PLAYER_PUNCH_L
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; setup the animation for Idle
        lda #1                                  ; set the substate to Running
        sta ENEMY_SUBSTATE
        rts                                    ; wait till next frame to start

@running
        lda #1
        sta SPRITE_ANIM_PLAY                    ; begin our animation when set to one

        jsr JoystickReady
        beq @input
        rts                                     ; not ready for input, we return

@input                                          ; process valid joystick input

        lda JOY_X
        beq @idle                       ; if JOY_X is 0 we are idling and need to change states
        bmi @idle                       ; if negative we are idling

@doneJoy
        lda #ENEMY_STATE_IDLE
        jmp ChangeEnemyState
@idle
        rts

#endregion

;===============================================================================
; ENEMY STATE ROPE
;-------------------------------------------------------------------------------
; Climbing a rope up 
;===============================================================================
#region "Enemy State Rope"
EnemyStateRope
        lda ENEMY_SUBSTATE                  ; test for first run
        bne @running

        ldx #2                              ; Use sprite number 0
        lda #<ANIM_ENEMY_CLIMB_ROPE         ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_ENEMY_CLIMB_ROPE
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                  ; initialize the animation
        lda #1                              ; set substate to RUNNING
        sta ENEMY_SUBSTATE
        rts                                 ; change takes effect next frame

@running
        lda ENEMY_TIMER                 ; A timer that slows down the enemy movement 
        bne @input                      ; If at zero, then the loop is over

        lda #8                          ; This area summons a raster value to
        sta ENEMY_SPEED                 ; switch the speed by using 'AND'


;======= NEW CHECK LINES ======
        lda SPRITE_CHAR_POS_Y           ; Check the downward Y movement
        cmp #PLAYER_DOWN_CAP            ; and set the limit boundaries
        bcc @downMove                   ; We are not at the limit, yet so branch

; Now we begin checking the MAP's Y position
        lda MAP_Y_POS
        cmp #$1B                        ; Wait until it's =27
        bne @input
        lda MAP_Y_DELTA                 ;When =27 then we can begin checking
        cmp #02                         ;the MAP_Y_DELTA pixels area.
        bcc @stopClimb                  ; We are still in the tile area
;=============================

; The Sprite is moving through the tile so
; alter the left and right movement to center it
; on the rope.
@downMove
        ldx #2
        lda SPRITE_POS_X_DELTA,x
        cmp #4                           ; they pass through if delta is 4
        beq @movespritedown              ; move sprite down since we passed through the tile
        bcc @less                        ; if less than 4, shift right one pixel

        jsr MoveEnemyLeft                ; not equal, not less, must be more - shift left one
        jmp @movespritedown
@less
        ldx #2
        jsr MoveEnemyRight
        ldx #3
        jsr MoveEnemyRight

@movespritedown
        ldx #2
        jsr MoveEnemyDown                ; = 0 so we can move the Sprite Down
        ldx #3
        jsr MoveEnemyDown

@stopClimb
        rts
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState

@nodownMove
@input
        rts
        lda #PLAYER_STATE_IDLE
        jmp ChangePlayerState
        rts
#endregion

;===============================================================================
; ENEMY STATE JUMP
;-------------------------------------------------------------------------------
;  Enemy is jumping
;===============================================================================
#region "Enemy State Jump"
EnemyStateJump
        lda ENEMY_SUBSTATE
        bne @running

        ldx #0
        lda #<ANIM_PLAYER_JUMP
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_JUMP
        sta ZEROPAGE_POINTER_1 + 1
        
        jsr InitSpriteAnim
        lda #1                          ; ENEMY_SUBSTATE_RUNNING
        sta ENEMY_SUBSTATE
        rts

@running
        lda #0                          ; clear the idle variable
        sta IDLE_VAR

        jsr JoystickReady
        beq @input
        rts

; Player jump is confirmed with a table

@input
@jumping
        inc PLAYER_JUMP_POS
        lda PLAYER_JUMP_POS
        cmp #35
        bne @jumpOn

        lda #0
        sta PLAYER_JUMP_POS
        jmp @jumpComplete

@jumpOn
        ldx PLAYER_JUMP_POS             ; check x for jump table (x = current state
                                        ; of increment PLAYER_JUMP_POS)
        lda PLAYER_JUMP_TABLE,x         ; check if at end of jump table = 0
        beq @jumpComplete

@jumpContinue
        ldx #2
        jsr MoveSpriteUp
        ldx #3
        jsr MoveSpriteUp
        jmp @jumping

@jumpBlocked
        lda #0
        sta PLAYER_JUMP_POS

@jumpComplete
        lda JOY_X                       ; horizontal movement
        beq @vertCheck                  ; check zero - horizontal input
        bmi @left                       ; negative = left

@right

@left
        lda #ENEMY_STATE_WALK_L        ; go to walk state left
        jsr ChangeEnemyState

@vertCheck
        lda JOY_Y                       ; check vertical joystick input
        beq @end                        ; zero means no input
        bmi @up                         ; negative means up
        bpl @down                       ; already checked for 0 - so this is positive
        rts

@up 
        ldx #2
        cmp #COLL_ROPE                  ; Check for rope under player 
        bne @end
        lda #ENEMY_STATE_JUMP          ; change to jump rope state
        jmp ChangeEnemyState

@down
        ldx #2                          ; if we are on a rope, can we move down?
        cmp #COLL_ROPE
        bne @noRope

        jsr EnemyCheckMoveDown               ; If we are at the end, there will be solid ground under us
        beq @goRopeClimb                ; No blocking and on rope? We change to climbing
        
                                        ; Otherwise we have no more checks.
        lda ENEMY_SPRITE_POS_X_DELTA          ; If not lined up on the rope we can a false positive
        cmp #4                          ; for collisions around a 'rope hole'
        beq @end

        bcc @deltaLess                  ; If less than 4 - shift left one
        jsr MoveEnemyLeft
        rts
@deltaLess
        jsr MoveEnemyRight
        rts

@goRopeClimb
        lda #ENEMY_STATE_ROPE
        jmp ChangeEnemyState

@noRope
@end
        rts

#endregion

;===============================================================================
; ENEMY STATE KICK RIGHT
;===============================================================================
#region "Enemy State Kick Right"
EnemyStateKickR
        lda ENEMY_SUBSTATE                     ; test for first run
        bne @running

        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_PLAYER_KICK_R                ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_KICK_R
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #1                                  ; set substate to RUNNING
        sta ENEMY_SUBSTATE
        rts                                     ; state change goes into effect next frame

@running
        jsr JoystickReady
        beq @input                              ; not ready for input
        rts
@input
        lda JOY_X       
        beq @vert_check                         ; X axis in 0 - check for up 
        bmi @idle                               ; if it's -1 (left) return to idle
                                                ; so it has to be 1 (right) - climb the stair
@vert_check
                                                ; TO DO : check for an up press
        lda #ENEMY_STATE_IDLE                   ; return to idle (which will likely go to fall)
        jmp ChangeEnemyState

@idle
        rts

#endregion

;===============================================================================
; ENEMY STATE KICK LEFT
;===============================================================================
#region "Enemy State Kick Left"
EnemyStateKickL
        lda ENEMY_SUBSTATE                     ; test for first run
        bne @running

        ldx #0                                 ; Use sprite number 0
        lda #<ANIM_PLAYER_KICK_L               ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_PLAYER_KICK_L
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #1                                  ; set substate to RUNNING
        sta ENEMY_SUBSTATE
        rts                                     ; state change goes into effect next frame

@running
        jsr JoystickReady
        beq @input                              ; not ready for input
        rts
@input
        lda JOY_X       
        beq @vert_check                         ; X axis in 0 - check for up 
        bmi @idle                               ; if it's -1 (left) return to idle
                                                ; so it has to be 1 (right) - climb the stair
@vert_check
        lda #ENEMY_STATE_IDLE                   ; return to idle (which will likely go to fall)
        jmp ChangeEnemyState

@idle
        rts

#endregion

;===============================================================================
; STATE FRAMEWORK
;-------------------------------------------------------------------------------
; A blank state template to make adding new states easier
;-------------------------------------------------------------------------------
#region "Player State Framework"
EnemyState_Framework
        lda ENEMY_SUBSTATE                     ; test for first run
        bne @running

        ldx #0                                  ; Use sprite number 0
        lda #<ANIM_NPC1                         ; load animation in ZEROPAGE_POINTER_1
        sta ZEROPAGE_POINTER_1
        lda #>ANIM_NPC1
        sta ZEROPAGE_POINTER_1 + 1

        jsr InitSpriteAnim                      ; initialize the animation
        lda #1                                  ; set substate to RUNNING
        sta ENEMY_SUBSTATE
        rts                                     ; change takes effect next frame

@running
        jsr JoystickReady
        beq @input                              ; not ready for input
        rts
                                                ; Process valid joystick input
@input
@right
@left

@vertCheck
@up 
@down
 
@end
        rts
#endregion

;===============================================================================
;===============================================================================
; PLAYER DATA
;-------------------------------------------------------------------------------

ENEMY_DATA

ENEMY_STATE
        byte 0
ENEMY_SUBSTATE
        byte 0  
ENEMY_SUBSTAGE 
        byte 0
ENEMY_JUMPUPRIGHT
        byte 0
ENEMY_JUMPUPLEFT
        byte 0
ENEMY_FALLFLAG
        byte 0
ENANIM_STATE
        byte 0

; Jump table from Endurion's code sample:
gamedeve.net/blog/949/entry-2250107-a-c64-game-step-7'

ENEMY_JUMP_POS
        byte 0
ENEMY_JUMP_TABLE
        ;byte 8,7,5,3,2,1,1,1,0,0
        byte 18,17,15,13,12,11,11,11,10,10
        byte 8,7,5,3,2,1,1,1,0,0
ENEMY_JUMP_TABLE_SIZE
        byte 10
ENEMY_FALL_POS
        byte 0
ENEMY_FALL_SPEED_TABLE
        byte 1,1,2,2,3,3,3,3,3,3

ENEMYDOWNCAP byte 0

 byte 0
ENEMY_TIMER byte 0
ENEMY_SPEED byte 0

ENEMY_BULLETS byte 5

FIRE_RIGHT byte 0
FIRE_LEFT byte 0
FiringHoldCD byte 0
WaitToFireCD byte 0

PLAYER_DIRECTION byte 0