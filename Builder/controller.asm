  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

    
  .bank 0
  .org $C000 
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down



LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $20, decimal 32
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down
              
              

  LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
  STA $2000

  LDA #%00010000   ; enable sprites
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop
  
 

NMI:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer


LatchController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016       ; tell both the controllers to latch buttons
  LDA $4016
  LDA $4016
  LDA $4016
  LDA $4016


ReadA: 
  LDA $4016       ; player 1 - A
  AND #%00000001  ; only look at bit 0
  BEQ ReadADone   ; branch to ReadADone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)			  
  LDA $0200
  SEC
  SBC #$01
  STA $0200
  
  LDA $0204
  SEC
  SBC #$01
  STA $0204
  
  LDA $0208
  SEC
  SBC #$01
  STA $0208
 
  LDA $020C
  SEC
  SBC #$01
  STA $020C
  
  
  
ReadADone:        ; handling this button is done
  

ReadB: 
  LDA $4016       ; player 1 - B
  AND #%00000001  ; only look at bit 0
  BEQ ReadBDone   ; branch to ReadBDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)

  LDA $0200       ; load sprite X position
  CLC            ; make sure the carry flag is clear
  ADC #$01        ; A = A + 1
  STA $0200       ; save sprite X position
  
  LDA $0204
  CLC
  ADC #$01
  STA $0204
  
  LDA $0208
  CLC
  ADC #$01
  STA $0208
  
  LDA $020C
  CLC
  ADC #$01
  STA $020C				  
  
ReadBDone:        ; handling this button is done

ReadLeft:
  LDA $4016
  AND #%00000001
  BEQ ReadLeftDone
  
  LDA $0203
  SEC
  SBC #$01
  STA $0203
  
  LDA $0207
  SEC
  SBC #$01
  STA $0207
  
  LDA $020B
  SEC
  SBC #$01
  STA $020B
  
  LDA $020F
  SEC
  SBC #$01
  STA $020F
  

  
ReadLeftDone:

ReadRight:
  LDA $4016
  AND #%00000001
  BEQ ReadRightDone
  
    LDA $0203
  CLC
  ADC #$01
  STA $0203
  
  LDA $0207
  CLC
  ADC #$01
  STA $0207
  
  LDA $020B
  CLC
  ADC #$01
  STA $020B
  
  LDA $020F
  CLC
  ADC #$01
  STA $020F
  
ReadRightDone:

  RTI             ; return from interrupt
 
;;;;;;;;;;;;;;  
  
  
  
  .bank 1
  .org $E000
palette:
  .db $0F,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F
  .db $0F,$1C,$15,$14,$31,$02,$38,$3C,$0F,$1C,$15,$14,$31,$02,$38,$3C

sprites:
     ;vert tile attr horiz
  .db $60, $32, $00, $80   ;sprite 0
  .db $60, $33, $00, $88   ;sprite 1
  .db $68, $34, $00, $80   ;sprite 2
  .db $68, $35, $00, $88   ;sprite 3

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 2
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1