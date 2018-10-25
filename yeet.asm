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
temp_x .rs 1
temp_y .rs 1
enemy_info .rs 4 * NUM_ENEMIES

	.rsset $0200
sprite_player .rs 4
sprite_bullet .rs 4
sprite_enemy0 .rs 4 * NUM_ENEMIES

	.rsset $0000
SPRITE_Y .rs 1
SPRITE_TILE .rs 1
SPRITE_ATTRIB .rs 1
SPRITE_X .rs 1
ENEMY_SPEED .rs 1





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
	
	; Write address $3f10 to the PPU
	LDA #$04
	STA PPUDATA
	
	
	; Stores sprite colours 0
	LDA #$1A
	STA PPUDATA
	
	LDA #$15
	STA PPUDATA
	
	LDA #$FD
	STA PPUDATA
	
	; Stores sprite colours 0
	LDA #$30
	STA PPUDATA
	
	LDA #$20
	STA PPUDATA
	
	LDA #$25
	STA PPUDATA
 
	
	; Write sprite data for sprite 0 (the player)
	LDA #120	; yPos
	STA sprite_player + SPRITE_Y
	LDA #0		; Tile number
	STA sprite_player + SPRITE_TILE
	LDA #0		; Attributes
	STA sprite_player + SPRITE_ATTRIB
	LDA #128	; xPos
	STA sprite_player + SPRITE_X
	
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
	LDA #1
	STA sprite_enemy0 + SPRITE_TILE, x
	LDA #0
	STA sprite_enemy0 + SPRITE_ATTRIB, x
	LDA #1
	STA enemy_info+ENEMY_SPEED, x
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
	
	
	LDA #%10000001	; Enable NMI
	STA PPUCTRL
	
	LDA #%00010000	;Enable Sprites
	STA PPUMASK
	
	
	
	
	
	
; starts an infinate loop
forever:
  JMP forever
  
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
	
	LDA sprite_player + SPRITE_Y	; yPos
	STA sprite_bullet + SPRITE_Y
	LDA #2		; Tile number
	STA sprite_bullet + SPRITE_TILE
	LDA #0		; Attributes
	STA sprite_bullet + SPRITE_ATTRIB
	LDA sprite_player + SPRITE_X	; xPos
	STA sprite_bullet + SPRITE_X
ReadA_Done:
	
	;Update bullet pos
	LDA bullet_active
	BEQ UpdateBullet_Done ; If bullet active = 0 skip the bullet code
	LDA sprite_bullet + SPRITE_Y
	SEC
	SBC #1
	STA sprite_bullet + SPRITE_Y
	BCS UpdateBullet_Done
	; If carry flag is clear the bullet has left the screen, therefore we can destroy it.
	LDA #0
	STA bullet_active
UpdateBullet_Done:
	
	;Update Enemies
	LDX #(NUM_ENEMIES - 1) * 4
	LDY #(NUM_ENEMIES - 1)
UpdateEnemiesLoop:
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
	TXA 			; Decrement x{
	CLC
	ADC #-4
	TAX				; }
	DEY				; Decremnt y
	BPL UpdateEnemiesLoop
	
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
	
	