	.inesprg 1
	.ineschr 1
	.inesmap 0 
	.inesmir 1
  
  ;---------------------------------
  
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

BUTTON_A 		= %10000000
BUTTON_B 		= %01000000
BUTTON_SELECT 	= %00100000
BUTTON_START 	= %00010000
BUTTON_UP 		= %00001000
BUTTON_DOWN 	= %00000100
BUTTON_LEFT 	= %00000010
BUTTON_RIGHT 	= %00000001

ENEMY_SQUAD_WIDTH = 6
ENEMY_SQUAD_HEIGHT = 4
NUM_ENEMIES = ENEMY_SQUAD_WIDTH * ENEMY_SQUAD_HEIGHT
ENEMY_SPACING = 16
ENEMY_DESCENT_SPEED = 4

	.rsset $0010
joypad1_state .rs 1
bullet_active .rs 1
bullet_active_follower .rs 1
bullet_active_enemy .rs 1	
hand_active .rs 1
temp_x .rs 1
temp_y .rs 1
hand_framesActive .rs 1
hand_framesToDespawn .rs 1
enemy_info .rs 4 * NUM_ENEMIES

	.rsset $0200
sprite_player .rs 4
sprite_bullet .rs 4 
sprite_bullet_follower .rs 4
sprite_hand .rs 4
sprite_enemy0 .rs 4 * NUM_ENEMIES
sprite_bullet_enemy .rs 4

	.rsset $0000
SPRITE_Y .rs 1
SPRITE_TILE .rs 1
SPRITE_ATTRIB .rs 1
SPRITE_X .rs 1

	.rsset $0000
ENEMY_SPEED .rs 1
ENEMY_ALIVE .rs 1
ENEMY_FOLLOWING .rs 1

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
	
	; Write address 3F10 to the PPU
	; 3F10 is where the background colour is stored
	; 3F10 has to be done in two parts as NES can only handle two digits at a time.
	; These values don't override each other because 2006 is a special memory location
	LDA #$3F
	STA PPUADDR
	LDA #$10
	STA PPUADDR
	
	; Write the colour to the PPU.
	LDA #$04					; Defines the colour
	STA PPUDATA
	
	
	; Write colour palletes
	; Stores sprite colours for the enemies
	LDA #$19
	STA PPUDATA
	
	LDA #$09
	STA PPUDATA
	
	LDA #$30
	STA PPUDATA
	
	; Stores sprite colours for the player
	LDA #$06
	STA PPUDATA
	
	LDA #$30
	STA PPUDATA
	
	LDA #$36
	STA PPUDATA
	
	; Stores sprite colours for the arrow
	
	LDA #$17
	STA PPUDATA
	
	LDA #$00
	STA PPUDATA
	
	LDA #$20
	STA PPUDATA
	
	; Store sprite colours for the hand
	LDA #$36
	STA PPUDATA
	
	LDA #$11
	STA PPUDATA
	
	LDA #$33
	STA PPUDATA
	
	; Define data for hand time alive
	LDA #60
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
	
	; Write sprite data for enemy bullet.
	LDA #60
	STA sprite_bullet_enemy + SPRITE_Y
	LDA #16
	STA sprite_bullet_enemy + SPRITE_TILE
	LDA #0
	STA sprite_bullet_enemy + SPRITE_ATTRIB
	LDA #128
	STA sprite_bullet_enemy + SPRITE_X
	
	; Initialise enemies
	LDX #0
	LDA #ENEMY_SQUAD_HEIGHT * ENEMY_SPACING
	STA temp_y
InitEnemiesLoopY:
	LDA #ENEMY_SQUAD_WIDTH * ENEMY_SPACING
	STA temp_x
InitEnemiesLoopX:
	; Accumlator = temp_x here
	STA sprite_enemy0 + SPRITE_X, x
	LDA temp_y
	STA sprite_enemy0 + SPRITE_Y, x
	LDA #0
	STA sprite_enemy0 + SPRITE_ATTRIB, x
	LDA #1
	STA sprite_enemy0 + SPRITE_TILE, x
	STA enemy_info+ENEMY_SPEED, x
	STA enemy_info+ENEMY_ALIVE, x
	STA enemy_info+ENEMY_FOLLOWING, x
	; Increase X by 4 per loop (one for each bit used in sprite data).
	TXA
	CLC
	ADC #4
	TAX
	; Loop check for x value
	LDA temp_x
	SEC
	SBC #ENEMY_SPACING
	STA temp_x
	BNE InitEnemiesLoopX
	; Loop check for y value
	LDA temp_y
	SEC
	SBC #ENEMY_SPACING
	STA temp_y
	BNE InitEnemiesLoopY
	
	RTS ; End subroutine
  
; end of inifnate loop
  
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
	LDA JOYPAD1
	LSR A
	ROL joypad1_state
	INX
	CPX #8
	BNE ReadController
	
	; React to Right button
	LDA joypad1_state
	AND #BUTTON_RIGHT
	BEQ ReadRight_Done
	LDA sprite_player + SPRITE_X
	CLC
	ADC #1
	STA sprite_player + SPRITE_X
ReadRight_Done:

	;React to Left button
	LDA joypad1_state
	AND #BUTTON_LEFT
	BEQ ReadLeft_Done
	LDA sprite_player + SPRITE_X
	CLC
	ADC #-1
	STA sprite_player + SPRITE_X
	
ReadLeft_Done:

;React to Up button
	LDA joypad1_state
	AND #BUTTON_UP
	BEQ ReadUp_Done
	LDA sprite_player + SPRITE_Y
	CLC
	ADC #-1
	STA sprite_player + SPRITE_Y
	
ReadUp_Done:	

;React to Down button
	LDA joypad1_state
	AND #BUTTON_DOWN
	BEQ ReadDown_Done
	LDA sprite_player + SPRITE_Y
	CLC
	ADC #1
	STA sprite_player + SPRITE_Y
	
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
	
	;Update Enemies
	LDX #(NUM_ENEMIES - 1) * 4
	LDY #(NUM_ENEMIES - 1)
UpdateEnemiesLoop:
	;Check if enemy is alive
	LDA enemy_info + ENEMY_ALIVE, x
	BNE UpdateEnemies_Start
	JMP UpdateEnemies_Next
UpdateEnemies_Start:

	LDA enemy_info + ENEMY_FOLLOWING, x		; Check if the enemy is following the player.
	BNE EnemiesInFormation					; Branch to after if not.

	
	LDA sprite_player + SPRITE_X			; Load players's x pos.
	STA sprite_enemy0 + SPRITE_X, x			; Set enemies x pos to players.
	LDA sprite_player + SPRITE_Y			; Load player's y pos
	ADC #10									; Add offset to player's y pos.
	STA sprite_enemy0 + SPRITE_Y, x			; Store enemies new y pos 
	JMP UpdateEnemies_Next
EnemiesInFormation:
	LDA sprite_enemy0 + SPRITE_X, x
	CLC
	ADC enemy_info + ENEMY_SPEED, x
	STA sprite_enemy0 + SPRITE_X, x
	CMP #256 - ENEMY_SPACING
	BCS UpdateEnemies_Reverse
	CMP #ENEMY_SPACING
	BCC UpdateEnemies_Reverse
	JMP UpdateEnemies_NoReverse
UpdateEnemies_Reverse:
	; Reverse Enemy Direction
	LDA #0
	SEC
	SBC enemy_info+ENEMY_SPEED, x
	STA enemy_info+ENEMY_SPEED, x
	LDA sprite_enemy0+SPRITE_Y, x
	CLC
	ADC #ENEMY_DESCENT_SPEED
	STA sprite_enemy0+SPRITE_Y, x
		
UpdateEnemies_NoReverse 
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
	STA enemy_info+ENEMY_FOLLOWING, x 			; Stop the enemy from moving
	LDA #$FF
	STA sprite_hand + SPRITE_Y					; Move hand offscreen
	
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
	;JSR InitaliseGame
	;JMP UpdateEnemies_End
	LDA #0
	STA HAS_FOLLOWER
	
UpdatePlayer_NoEnemyBulletCollision:

UpdateEnemies_Next:
	
	TXA 			; Decrement x{
	CLC
	ADC #-4
	TAX				; }
	DEY				; Decremnt y
	BMI UpdateEnemies_End
	JMP UpdateEnemiesLoop
UpdateEnemies_End:
	
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
	
	