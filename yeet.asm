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
	
	; Write sprite data for sprite 0
	LDA #120	; yPos
	STA $0200
	LDA #0		; Tile number
	STA $0201
	LDA #0		; Attributes
	STA $0202
	LDA #128	; xPos
	STA $0203
	
	LDA #%10000000	; Enable NMI
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
	;Increment X position
	LDA $0203
	CLC
	ADC #1
	STA $0203
	
	;Increment Y Position
	LDA $0200
	CLC
	ADC #-1
	STA $0200

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
	
	