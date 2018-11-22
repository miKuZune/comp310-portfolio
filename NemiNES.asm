	.inesprg 1
	.ineschr 1
	.inesmap 0 
	.inesmir 1
  
  ;---------------------------------
  
  
; Store references to positions in memory.
PPUCTRL = $2000
PPUMASK = $2001
PPUSTATUS = $2002
OAMADDR = $2003
OAMDATA = $2004
PPUSCROLL = $2005
PPUADDR = $2006
PPUDATA = $2007
OAMDMA = $4014
JOYPAD1 = $4016
JOYPAD2 = $4017

; Stores the offsets to access specific buttons on the controller.
BUTTON_A 		= %10000000
BUTTON_B 		= %01000000
BUTTON_SELECT 	= %00100000
BUTTON_START 	= %00010000
BUTTON_UP 		= %00001000
BUTTON_DOWN 	= %00000100
BUTTON_LEFT 	= %00000010
BUTTON_RIGHT 	= %00000001

; Store information about enemies.
ENEMY_SQUAD_WIDTH = 6
ENEMY_SQUAD_HEIGHT = 4
NUM_ENEMIES = ENEMY_SQUAD_WIDTH * ENEMY_SQUAD_HEIGHT
ENEMY_SPACING = 16
ENEMY_DESCENT_SPEED = 4

; Store information about enemies.
	.rsset $0010
joypad1_state .rs 1
bullet_active .rs 1						; Store whether the player's bullet is active or not.
bullet_active_follower .rs 1			; Store whether the follower's bullet is active or not.
bullet_active_enemy .rs 1				; Store whether the enemies bullet is active or not.
hand_active .rs 1						; Store whether the player's hand to gain followers is active.
temp_x .rs 1
temp_y .rs 1
hand_framesActive .rs 1					; Counts down frames 
hand_framesToDespawn .rs 1				; Stores how many frames 
enemy_info .rs 4 * NUM_ENEMIES


;Stores sprite information: yPos, tile from the sprite sheet, colour palette attribute, xPos
	.rsset $0200
sprite_player .rs 4						; Stores the player sprite.
sprite_bullet .rs 4 					; Stores the player's bullet sprite.
sprite_bullet_follower .rs 4			; Stores the follower's bullet sprite.
sprite_hand .rs 4						; Stores the player's hand sprite.
sprite_enemy0 .rs 4 * NUM_ENEMIES		; Stores enemy sprite for the number of enemies specified.
sprite_follower .rs 4					; Stores the player's follower sprite.
sprite_bullet_enemy .rs 4				; Stores the enemy bullet sprite.

; Stores offsets to easily call information from sprites.
	.rsset $0000
SPRITE_Y .rs 1			; Sprite's yPos - +1
SPRITE_TILE .rs 1		; Sprite's sprite sheet tile - +2
SPRITE_ATTRIB .rs 1		; Sprite's colour palette - +3
SPRITE_X .rs 1			; Sprite's xPos - +4

	.rsset $0000
ENEMY_SPEED .rs 1		; Store's how many pixels the enemies move per frame.
ENEMY_ALIVE .rs 1		; Store's whether the enemy is alive or not. Used to decide if the enemy should be skipped in the loop.


; Store information about colliders.
ENEMY_HITBOX_WIDTH = 8
ENEMY_HITBOX_HEIGHT = 8

BULLET_HITBOX_WIDTH = 8
BULLET_HITBOX_HEIGHT = 7
BULLET_X = 0
BULLET_Y = 1

HAND_HITBOX_WIDTH = 8
HAND_HITBOX_HEIGHT = 8
HAND_X = 0
HAND_Y = 0

; Other information.
BULLET_SPEED = 3

HAS_FOLLOWER = 0

	bank 0
	.org $C000
  
  
  ; Initialisation based upon: https://wiki.nesdev.com/w/index.php/Init_code
RESET:
    SEI        ; ignore IRQs
    CLD        ; disable decimal mode
    LDX #$40
    STX $4017  ; disable APU frame IRQ
    LDX #$ff
    TXS        ; Set up stack
    INX        ; now X = 0
    STX PPUCTRL  ; disable NMI
    STX PPUMASK  ; disable rendering
    STX $4010  ; disable DMC IRQs

    ; Optional (omitted):
    ; Set up mapper and jmp to further init code here.

    ; If the user presses Reset during vblank, the PPU may reset
    ; with the vblank flag still true.  This has about a 1 in 13
    ; chance of happening on NTSC or 2 in 9 on PAL.  Clear the
    ; flag now so the @vblankwait1 loop sees an actual vblank.
    BIT PPUSTATUS

    ; First of two waits for vertical blank to make sure that the
    ; PPU has stabilized
vblankwait1:  
    BIT PPUSTATUS
    BPL vblankwait1

    ; We now have about 30,000 cycles to burn before the PPU stabilizes.
    ; One thing we can do with this time is put RAM in a known state.
    ; Here we fill it with $00, which matches what (say) a C compiler
    ; expects for BSS.  Conveniently, X is still 0.
    TXA
CLRMEM:
	LDA #0
    STA $000,x
    STA $100,x
    STA $300,x
    STA $400,x
    STA $500,x
    STA $600,x
    STA $700,x  ; Remove this if you're storing reset-persistent data

    ; We skipped $200,x on purpose.  Usually, RAM page 2 is used for the
    ; display list to be copied to OAM.  OAM needs to be initialized to
    ; $EF-$FF, not 0, or you'll get a bunch of garbage sprites at (0, 0).

	LDA #$FF
	STA $200,x
	
    INX
    BNE CLRMEM

    ; Other things you can do between vblank waits are set up audio
    ; or set up other mapper registers.
  

  
vblankwait2:
    BIT PPUSTATUS
    BPL vblankwait2
	
	; end of initialisation code
	
	JSR InitaliseGame
	
	LDA #%10000001	; Enable NMI
	STA PPUCTRL
	
	LDA #%00010000	;Enable Sprites
	STA PPUMASK	
	; -------------------------------------------------	
; starts an infinate loop
forever:
  JMP forever
  
InitaliseGame: ; Begin subroutine
	
	; Reset the PPU high/low latch
	LDA PPUSTATUS
	
	; Write address 3F10 to the PPU .
	; 3F10 is where the background colour is stored
	; 3F10 has to be done in two parts as NES can only handle two digits at a time.
	; These values don't override each other because 2006 is a special memory location
	LDA #$3F
	STA PPUADDR
	LDA #$10
	STA PPUADDR
	
	; Write the background colour to the PPU.
	LDA #$FF					; Defines the colour of the background
	STA PPUDATA
	
	
	; Write colour palletes
	; Stores sprite colours for the enemies
	LDA #$19				; Light green.
	STA PPUDATA
	
	LDA #$09				; Dark green.
	STA PPUDATA
	
	LDA #$30				; White.
	STA PPUDATA
	
	; Stores sprite colours for the player
	LDA #$06				; Red/Brown
	STA PPUDATA
		
	LDA #$30				; White.
	STA PPUDATA
	
	LDA #$36				; Pale pink - for skin colour.
	STA PPUDATA
	
	; Stores sprite colours for the arrow
	
	LDA #$17				; Light brown.
	STA PPUDATA
	
	LDA #$00				; Dark grey.
	STA PPUDATA
	
	LDA #$20				; Green
	STA PPUDATA
	
	; Store sprite colours for the hand
	LDA #$36				; Pale pink.
	STA PPUDATA
	
	LDA #$11				; Blue.
	STA PPUDATA		
	
	LDA #$33				; Lavender colour
	STA PPUDATA
	
	; Define data for hand time alive
	LDA #60							; Will stay alive for 60 seconds. NES does 60 fps, so this is for one second.
	STA hand_framesToDespawn
 
	
	; Write sprite data for sprite 0 (the player)
	LDA #120	; yPos
	STA sprite_player + SPRITE_Y
	LDA #0		; Tile number
	STA sprite_player + SPRITE_TILE
	LDA #1		; Attributes
	ORA #%01000000
	STA sprite_player + SPRITE_ATTRIB
	LDA #128	; xPos
	STA sprite_player + SPRITE_X
	
	; Write sprite data for enemy bullet. xPos is in the middle, comes down from the top.
	LDA #0		; yPos
	STA sprite_bullet_enemy + SPRITE_Y
	LDA #16		; Tile number
	STA sprite_bullet_enemy + SPRITE_TILE
	LDA #0		; Attributes
	STA sprite_bullet_enemy + SPRITE_ATTRIB
	LDA #128	; xPos
	STA sprite_bullet_enemy + SPRITE_X
	
	; Write sprite data for follower, starts off screen.
	LDA #$FF	; yPos
	STA sprite_follower + SPRITE_Y
	LDA #1		; tile number, attribute, xPos.
	STA sprite_follower + SPRITE_TILE
	STA sprite_follower + SPRITE_ATTRIB
	STA sprite_follower + SPRITE_X
	
	; Initialise enemies
	LDX #0										; Store 0 in X	
	LDA #ENEMY_SQUAD_HEIGHT * ENEMY_SPACING		; Load the Y pos of the enemies, from the height given and the given spacing between enemies.
	STA temp_y									; Store the calculated y pos.
InitEnemiesLoopY:
	LDA #ENEMY_SQUAD_WIDTH * ENEMY_SPACING		; Load the xPos of the enemies, from the width and spacing.
	STA temp_x									; Store the calculated xPos.
InitEnemiesLoopX:
	; Accumlator still has the calculated x Pos stored.
	STA sprite_enemy0 + SPRITE_X, x				; Give the enemy sprite the calculated x pos.
	LDA temp_y									; Load the calculated y pos.
	STA sprite_enemy0 + SPRITE_Y, x				; Give the enemy sprite the calculated y pos.	
	LDA #0										; Load 0.
	STA sprite_enemy0 + SPRITE_ATTRIB, x		; Store 0 in the colour palette attribute
	LDA #1										; Load 1.
	STA sprite_enemy0 + SPRITE_TILE, x			; Give the sprite tile the value 1. Set the sprite that is shown to the 2nd tile in the sprite sheet.
	STA enemy_info+ENEMY_SPEED, x				; Give the enemies speed a value of 1.
	STA enemy_info+ENEMY_ALIVE, x				; Set the enemy to alive.
	
	; Increase X by 4 per loop (one for each bit used in sprite data).
	TXA
	CLC
	ADC #4
	TAX
	
	; Loop check for x value
	LDA temp_x				; Load the current x pos that was used in the loop.
	SEC						; Set the carry flag.
	SBC #ENEMY_SPACING		; Take away spacing between enemies.
	STA temp_x				; Store new value.
	BNE InitEnemiesLoopX	; If not 0 branch back to start of x loop.
	
	; Loop check for y value
	LDA temp_y				; Load the current y pos.
	SEC
	SBC #ENEMY_SPACING		; Take the enemy spacing away.
	STA temp_y				; Store new Y pos.
	BNE InitEnemiesLoopY	; If not 0 loop back to start of y loop.
	
	RTS ; End subroutine
  
; end of infinite loop
  
;----------------------------------------------------------------------------

; NMI - called every frame
NMI:

	;Initalise first controller
	LDA #1
	STA JOYPAD1
	LDA #0
	STA JOYPAD1
	
	;Read Joypad state
	LDX #0
	STX joypad1_state
ReadController:
	LDA JOYPAD1				; Load the value stored at JOYPAD1
	LSR A					; Logical shift right of A.
	ROL joypad1_state		; rotate bits in joypad1_state
	INX						; Increment x.
	CPX #8					; Compare x against 8.
	BNE ReadController		; Branch to ReadController if not 8.
	
	; React to Right button
	LDA joypad1_state		; Load joypad1_state	
	AND #BUTTON_RIGHT		; Offset to get the right button.
	BEQ ReadRight_Done		; Skip if not pressed.
	LDA sprite_player + SPRITE_X	; Load the players x pos.
	CLC								; Clear carry flag.
	ADC #1							; Add 1 to the x pos.
	STA sprite_player + SPRITE_X	; Store new x pos.
ReadRight_Done:

	;React to Left button
	LDA joypad1_state		; Load joypad1_state	
	AND #BUTTON_LEFT		; Offset to get the left button.
	BEQ ReadLeft_Done		; Skip if not pressed.
	LDA sprite_player + SPRITE_X		; Load the the player's x pos.
	CLC									; Clear carry flag.
	ADC #-1								; Take 1 from the x pos.
	STA sprite_player + SPRITE_X		; Store new x pos.
	
ReadLeft_Done:

;React to Up button
	LDA joypad1_state
	AND #BUTTON_UP
	BEQ ReadUp_Done
	LDA sprite_player + SPRITE_Y	; Load players y pos.
	CLC								; Clear carry flag.
	ADC #-1							; Take 1 from the y pos (move up).
	STA sprite_player + SPRITE_Y	; Store new y.
	
ReadUp_Done:	

;React to Down button
	LDA joypad1_state
	AND #BUTTON_DOWN
	BEQ ReadDown_Done
	LDA sprite_player + SPRITE_Y	; Load player's y pos.
	CLC								; Clear carry flag.	
	ADC #1							; Add 1 to y pos.
	STA sprite_player + SPRITE_Y	; Store new y.
	
ReadDown_Done:	

;React to A button
	LDA joypad1_state
	AND #BUTTON_A
	BEQ ReadA_Done
	;Spawn a bullet if one is not active
	LDA bullet_active
	BNE ReadA_Done
	;No bullet active so spawn one.
	LDA #1
	STA bullet_active
	
	; Set the bullet position to the be the player's position.
	LDA sprite_player + SPRITE_Y	; yPos
	STA sprite_bullet + SPRITE_Y
	LDA #2		; Sprite sheet tile number
	STA sprite_bullet + SPRITE_TILE
	LDA #2		; Colour palette attribute.
	STA sprite_bullet + SPRITE_ATTRIB
	LDA sprite_player + SPRITE_X	; xPos
	STA sprite_bullet + SPRITE_X
	
	; Check if the player has a follower.
	LDA HAS_FOLLOWER
	BEQ ReadA_Done
	; Check if the follower's bullet is already active.
	LDA bullet_active_follower
	BNE ReadA_Done
	; Set the follower's bullet to active.
	LDA #1
	STA bullet_active_follower
	; Set the followers bullet position
	LDA sprite_player + SPRITE_Y			; y Pos
	ADC #10									; Add the offset to the follower.
	STA sprite_bullet_follower + SPRITE_Y	; Store new y pos
	LDA #2									; Load bullet img
	STA sprite_bullet_follower + SPRITE_TILE	; Store bullet img
	LDA #0										; Load follower bullet colour palette
	STA sprite_bullet_follower + SPRITE_ATTRIB	; Store new palette
	LDA sprite_player + SPRITE_X				; Store player's x position
	STA sprite_bullet_follower + SPRITE_X		; Set follower's bullet x position to be that of the players.
	NOP
ReadA_Done:

;React to B button
	
	LDA joypad1_state
	AND #BUTTON_B
	BEQ ReadB_Done
	
	;Spawn Hand if not active
	LDA hand_active
	BNE ReadB_Done
	;Spawn hand
	LDA #1
	STA hand_active
	LDA hand_framesToDespawn
	STA hand_framesActive
	
	; Set the hand's position and attributes.
	LDA sprite_player + SPRITE_Y
	ADC #-10
	STA sprite_hand + SPRITE_Y
	LDA #3			; Sprite sheet tile number
	STA sprite_hand + SPRITE_TILE
	LDA #3			; Colour palette attribute.
	STA sprite_hand + SPRITE_ATTRIB
	LDA sprite_player + SPRITE_X
	STA sprite_hand + SPRITE_X

ReadB_Done:
	
	;Update player's bullet pos
	LDA bullet_active
	BEQ UpdateBullet_Done ; If bullet active = 0 skip the bullet code
	LDA sprite_bullet + SPRITE_Y
	SEC
	SBC #BULLET_SPEED
	STA sprite_bullet + SPRITE_Y
	BCS UpdateBullet_Done
	; If carry flag is clear the bullet has left the screen, therefore we can destroy it.
	LDA #0
	STA bullet_active
UpdateBullet_Done:
	
	;Update follower's bullet.
	LDA bullet_active_follower
	BEQ UpdateBullet_Done_Follower
	;Move the follower's bullet up by 1 pixel per frame.
	LDA sprite_bullet_follower + SPRITE_Y
	SEC
	SBC #BULLET_SPEED
	STA sprite_bullet_follower + SPRITE_Y
	;Check if the follower's bullet has left the screen.
	BCS UpdateBullet_Done_Follower
	LDA #0
	STA bullet_active_follower

	
UpdateBullet_Done_Follower:

	; Update enemies bullet.
	LDA sprite_bullet_enemy + SPRITE_Y
	ADC #1
	STA sprite_bullet_enemy + SPRITE_Y

; Handle the hand rendering
	LDA hand_active
	BEQ HandUpdate_Done		; Skip if the hand is not active.
	LDA hand_framesActive
	SEC
	SBC #1
	STA hand_framesActive
	BNE HandUpdate_Done		; Check if the hand needs to be reset.
	LDA #0					; Load 0 into the accumulator.
	STA hand_active			; Set the hand_active to 0 so it is not active.
	STA sprite_hand + SPRITE_Y 	; Set the hand's y position to offscreen.
	
HandUpdate_Done:

	LDA HAS_FOLLOWER		; Load the value of HAS_FOLLOWER
	BEQ No_Follower			; If  = 1, no follower so branch to no follower.
	


; Has a follower.
; Place the follower sprite underneath the player.
	LDA sprite_player + SPRITE_Y	; Load player y pos.
	ADC #10							; Add 10
	STA sprite_follower + SPRITE_Y	; Give follower new y pos.
	LDA sprite_player + SPRITE_X	; Load the players x pos.
	STA sprite_follower + SPRITE_X	; Give the follower new x pos.
	JMP FollowerUpdate_Done			; Jump to after the no follower code.

No_Follower:
	LDA #$FF						; Load hex equivalent of 255  (off screen)
	STA sprite_follower + SPRITE_Y	; Give the follower sprite the new y pos.
	
	LDA #0							; Load 0.
	STA sprite_follower + SPRITE_X	; Give follower new x pos.
	

FollowerUpdate_Done:
	
	;Update Enemies
	LDX #(NUM_ENEMIES - 1) * 4
	LDY #(NUM_ENEMIES - 1)
UpdateEnemiesLoop:
	;Check if enemy is alive
	LDA enemy_info + ENEMY_ALIVE, x
	BNE UpdateEnemies_Start				; Branch to handling enemy movement.
	JMP UpdateEnemies_Next				; Jump to end of this increment of the loop.
UpdateEnemies_Start:
EnemiesInFormation:
	LDA sprite_enemy0 + SPRITE_X, x		; Load sprite x pos.
	CLC									; Clear carry flag.
	ADC enemy_info + ENEMY_SPEED, x		; Add enemies speed. Moves the enemy along that number of pixels.
	STA sprite_enemy0 + SPRITE_X, x		; Store new x pos.
	CMP #256 - ENEMY_SPACING			; See if the enemy has collided with the right end of the screen.
	BCS UpdateEnemies_Reverse			; If has then reverse then branch to enemy reverse.
	CMP #ENEMY_SPACING					; See if the enemy has collided with the left end of the screen.
	BCC UpdateEnemies_Reverse			; Branch to reverse if so.
	JMP UpdateEnemies_NoReverse			; If not branched then skip over the reverse code.
	
UpdateEnemies_Reverse:
	; Reverse Enemy Direction
	LDA #0							; Load 0.
	SEC								
	SBC enemy_info+ENEMY_SPEED, x	; Take current enemy speed from 0. If the speed was 1 it's 0 - 1 so the new speed is negative. If the speed is -1 then it's 0 - -1 which is 1.
	STA enemy_info+ENEMY_SPEED, x	; Store new speed.
	LDA sprite_enemy0+SPRITE_Y, x	; Load sprite's y pos.
	CLC								; Clear carry flag.
	ADC #ENEMY_DESCENT_SPEED		; Add the enemy descent speed. Moves the enemies down when they hit the side.
	STA sprite_enemy0+SPRITE_Y, x	; Store new y pos.
		
UpdateEnemies_NoReverse 

	; Begin handling collisions.
											 ;\1		\2		\3				\4			\5			\6			\7
CheckCollisionWithEnemy .macro ; parameters: object_x, object_y, object_hit_x, object_hit_y, object_w, object_h, no_collision_label
	; If there is a collision, execution continues immediately after this macro
	; Else, jump to no_collision_label
	; Check if enemy collides with object.
	LDA sprite_enemy0+SPRITE_X,x 	; Calculate enemyPosX - bulletWidth - 1 (x1 - w2 - 1)
	.if \3 > 0
	SEC
	SBC \3
	.endif
	SEC
	SBC \5+1						; Assumes all sprites have a size of 8 pixels
	CMP \1							; Compare against object x2
	BCS \7							; Branch if x1 -w2 >= x2
	
	CLC
	ADC #\5+1+ENEMY_HITBOX_WIDTH	; Calculate xEnemy + wEnemy (x1+w1) assuming w1 = 8
	CMP \1							; Compare x1+w1 < x2
	BCC \7
	
	LDA sprite_enemy0+SPRITE_Y,x 	; Calculate enemyPosy - objectWidth (y1 - h2)
	.if \3 > 0
	SEC
	SBC \4
	.endif
	SEC
	SBC \6+1						; Assumes all sprites have a size of 8 pixels
	CMP \2							; Compare against object y2
	BCS \7						 	; Branch if y1 -h2 >= y2
	
	CLC
	ADC \6+1+ENEMY_HITBOX_HEIGHT	; Calculate yEnemy + hEnemy (y1+h1) assuming h1 = 8
	CMP \2							; Compare y1+h1 < y2
	BCC \7
	
	.endm							; End macro
	
	; Check Bullet Collision With Enemy
	CheckCollisionWithEnemy sprite_bullet+SPRITE_X, sprite_bullet+SPRITE_Y, #BULLET_X, #BULLET_Y, #BULLET_HITBOX_WIDTH, #BULLET_HITBOX_HEIGHT, UpdateEnemies_NoCollision
	; Handle bullet enemy collision.
	LDA #0							; Destroy bullet
	STA bullet_active				; Stop bullet from moving
	STA enemy_info+ENEMY_ALIVE, x	; Stop enemy from moving.
	LDA #$FF						; Store value of 255
	STA sprite_bullet + SPRITE_Y	; Move bullet to position 255 (offscreen)
	STA sprite_enemy0+SPRITE_Y, x	; Move Enemy offscreen

UpdateEnemies_NoCollision:	
	; Check follower's bullet collision with enemy.
	CheckCollisionWithEnemy sprite_bullet_follower+SPRITE_X, sprite_bullet_follower+SPRITE_Y, #BULLET_X, #BULLET_Y, #BULLET_HITBOX_WIDTH, #BULLET_HITBOX_HEIGHT, UpdateEnemies_NoCollisionWithFollowerBullet
	LDA #0
	STA bullet_active_follower				; Bullet becomes inactive.
	STA enemy_info+ENEMY_ALIVE, x			; Enemy becomes inactive.
	LDA #$FF								; Store 255
	STA sprite_bullet_follower + SPRITE_Y	; Move bullet offscreen.
	STA sprite_enemy0+SPRITE_Y, x			; Move enemy offscreen.
	
UpdateEnemies_NoCollisionWithFollowerBullet:

	; Check hand collision with enemy
	CheckCollisionWithEnemy sprite_hand+SPRITE_X, sprite_hand+SPRITE_Y, #HAND_X, #HAND_Y, #HAND_HITBOX_WIDTH, #HAND_HITBOX_HEIGHT, UpdateEnemies_NoHandCollision
	; Handle hand enemy collision.
	
	LDA #0										; Load 0 into accumulator
	STA hand_active								; Set the hand to inactive.
	STA enemy_info+ENEMY_ALIVE, x 				; Stop the enemy from moving
	LDA #$FF
	STA sprite_hand + SPRITE_Y					; Move hand offscreen
	STA sprite_enemy0 + SPRITE_Y, x
	
	LDA #2										; Load new colour palette id into accumulator
	STA sprite_enemy0 + SPRITE_ATTRIB, x		; Change the colour palette for the enemy.
	LDA #1										; Store 1/true in the accumulator
	STA HAS_FOLLOWER							; Store that the player has a follower now.

	
UpdateEnemies_NoHandCollision:
	
	; Check collision with player character
	CheckCollisionWithEnemy sprite_player+SPRITE_X, sprite_player+SPRITE_Y, #0, #0, #8, #8, UpdateEnemies_NoCollisionWithPlayer
	
	;Handle collision
	JSR InitaliseGame
	JMP UpdateEnemies_End
	
UpdateEnemies_NoCollisionWithPlayer:




UpdateEnemies_Next:
	
	TXA 			; Decrement x{
	CLC
	ADC #-4
	TAX				; }
	DEY				; Decremnt y
	BMI UpdateEnemies_End
	JMP UpdateEnemiesLoop
UpdateEnemies_End:
	
CheckCollisionWithPlayer .macro; parameters: objectX, objectY, object_hit_x, object_hit_y, object_w, object_h, no_collision_label
	; If there is a collision the code will continue from after the macro.
	; If there is no collision then it will continue from the no_collision_label
	
	LDA sprite_player+SPRITE_X 	; Calculate enemyPosX - bulletWidth - 1 (x1 - w2 - 1)
	.if \3 > 0
	SEC
	SBC \3
	.endif
	SEC
	SBC \5+1						; Assumes all sprites have a size of 8 pixels
	CMP \1							; Compare against object x2
	BCS \7							; Branch if x1 -w2 >= x2
	
	CLC
	ADC #\5+1+ENEMY_HITBOX_WIDTH	; Calculate xEnemy + wEnemy (x1+w1) assuming w1 = 8. Uses the same hitbox width and heights as the player and enemy sprites are both 8x8.
	CMP \1							; Compare x1+w1 < x2
	BCC \7
	
	LDA sprite_player+SPRITE_Y 	; Calculate enemyPosy - objectWidth (y1 - h2)
	.if \3 > 0
	SEC
	SBC \4
	.endif
	SEC
	SBC \6+1						; Assumes all sprites have a size of 8 pixels
	CMP \2							; Compare against object y2
	BCS \7						 	; Branch if y1 -h2 >= y2
	
	CLC
	ADC \6+1+ENEMY_HITBOX_HEIGHT	; Calculate yEnemy + hEnemy (y1+h1) assuming h1 = 8
	CMP \2							; Compare y1+h1 < y2
	BCC \7
	
	.endm							; End macro

	
	; Check if enemy bullet collides with player.
	CheckCollisionWithPlayer sprite_bullet_enemy+SPRITE_X, sprite_bullet_enemy+SPRITE_Y, #0, #0, #8, #8, UpdatePlayer_NoEnemyBulletCollision
	
	; Handle player + enemy bullet collision.
	LDA HAS_FOLLOWER
	BEQ NoFollower_OnCollision

	; If there is a follower this code will run.
	LDA #0						; Store 0 to represent false.
	STA HAS_FOLLOWER			; Set the Has_Follower to false.
	LDA #$FF 					; Store hex equivalent to 255
	STA sprite_bullet_enemy + SPRITE_Y		; Move sprite off the screen.
	
	JMP UpdatePlayer_NoEnemyBulletCollision		; Jump to the end of the bullet collision with player code.
	
NoFollower_OnCollision:			; No follower will result in this code being run.
	JSR InitaliseGame
	JMP UpdateEnemies_End

	
UpdatePlayer_NoEnemyBulletCollision:
	
	
	;copy sprite data to the PPU.
	LDA #0
	STA OAMADDR
	LDA #$02
	STA OAMDMA
	

  RTI		; Return from interrupt
  

	
;----------------------------------------------------------------------------

	.bank 1
	.org $FFFA
	.dw NMI
	.dw RESET
	.dw 0
  
;-----------------------------------------------------------------------------

	.bank 2
	.org $0000
	.incbin "Sprites.nes"
	
	