;----------------------------------------
;;;;;;;-----marching-squares------;;;;;;;
;----------------------------------------
; Have to store as bits. Don't write initial prng values to PPUDATA
; Store in memory as 32 'columns' of data, 3 bytes each for 24 * 0-1 bits per column
; Data size would be 32*3 = 96 bytes big though...
;
;   Column
;       1    2    3    4   ...
;       byte byte byte byte
;       byte byte byte byte
;       byte byte byte byte

; Then marching squares can be applied to each bit
;
; So, consider looking at a mid table bit, at an offset into that byte
; Surrounding tile count is worked out from:
;
;       Byte-3      Byte        Byte+3
;
;       offset-1,   offset-1,   offset-1
;       offset,                 offset
;       offset+1,   offset+1,   offset+1
;
; Obviously edges need ignoring/wrapping/accounting for
;
;----------------------------------------
LookAtTile .macro
; parameters: 
; @Param \1 Byte number
; @Param \2 Offset into byte for bit
    .if \2 = 0                          ; if zero then no need to bitshift
    LDA backgroundDataTable, \1
    JMP .noBitShiftNecessary\@
    .endif
    .if \2 = -1                         ; if negative then need to wrap to previous byte, least significant bit
    LDA backgroundDataTable, \1-1
    LDX #0
    JMP .bitshift\@
    .endif
    .if \2 = 8                          ; if over 7 then need to wrap to next byte, most significant bit
    LDA backgroundDataTable, \1+1
    LDX #7
    JMP .bitshift\@
    .endif
    LDA backgroundDataTable, \1         ; else use given values
    LDX \2
.bitshift\@:
    LSR A                               ; Shift by the offset amount to get the bit we want
    DEX
    BNE .bitshift\@
.noBitShiftNecessary\@:
    CMP #0                              ; if bit == 1 then increment tile_value
    BNE .incrementTileCount\@
    JMP .finished\@
.incrementTileCount\@:
    INC tile_value
.finished\@:
    .endm
;----------------------------------------
SetBitToZero .macro
; parameters: 
; @Param \1 Byte number
; @Param \2 Offset into byte for bit
    LDX #%00000001
    LDY \2
.bitshift\@:
    ASL X                           ; bitshift left to move the bit into the offset position
    DEY
    BPL .bitshift\@
    LDA backgroundDataTable, \1
    AND X                           ; If already 0 then don't change
    BEQ .finished\@
    LDA backgroundDataTable, \1     ; Else subtract flag to set bit to 0
    SEC
    SBC X
.finished\@:
    .endm
;----------------------------------------
SetBitToOne .macro
; parameters: 
; @Param \1 Byte number
; @Param \2 Offset into byte for bit
    LDX #%00000001
    LDY \2
.bitshift\@:
    ASL X                           ; bitshift left to move the bit into the offset position
    DEY
    BPL .bitshift\@
    LDA backgroundDataTable, \1
    ORA X                           ; Set the bytes bit position to 1
    STA backgroundDataTable, \1
    .endm
;----------------------------------------
; Fills A register with the appropriate tile
analyseSquare .macro
; parameters: 
; @Param \1 Byte number
; @Param \2 Offset into byte for bit

;   0 1 2
;   3   4
;   5 6 7
    LDA #0              ; Set the tile value to 0 for a new tile
    STA tile_value

    LookAtTile \1 -3,   \2 -1
    LookAtTile \1 -3,   \2
    LookAtTile \1 -3,   \2 +1

    LookAtTile \1,      \2 -1
    LookAtTile \1,      \2 +1

    LookAtTile \1 +3,   \2 -1
    LookAtTile \1 +3,   \2
    LookAtTile \1 +3,   \2 +1
    
    LDY tile_value
    CPY #MARCHING_SQUARES_THRESHOLD
    BCS .returnCloud\@
    SetBitToZero \1, \2
    LDA #$00            ; Empty tile location
    JMP .finished\@
.returnCloud\@:
    SetBitToOne \1, \2
    LDA #$6F            ; Cloud tile location

.finished\@:
    .endm
;----------------------------------------
; Generates a column of background tiles in the appropriate memory position for the first nametable (no ledge)
GenerateGameBackground_Column_FullRandom:
    LDA #%00000100      ; Put PPU into skip 32 mode instead of 1
    STA PPUCTRL         ; Have to restore back to previous values later

    ; Reset the PPU high/low latch
    LDA PPUSTATUS

    LDA current_nametable_generating
    STA PPUADDR
    LDA generate_x
    STA PPUADDR

    LDX #2              ; Load in two rows of cloud to account for PAL displays
    LDA #$6F
.generateTopBorder:
    STA PPUDATA
    DEX
    BNE .generateTopBorder

    LDA #2              ; The area to fill is 3 * 8 = 24 large. We will branch when background_load_current_Y is minus so 3 loops
    STA background_load_current_Y

.fullByteUseLoop:
    LDY #8              ; Use Y reg here as prng clobbers X register
    JSR prng
    STA marchingSquaresProb
.sectionLoop:
    LDA marchingSquaresProb
    AND #1              ; Is the least significant bit a 1?
    BNE .drawCloud
    LDX #$00            ; Else draw empty tile
    JMP .tileChosen
.drawCloud:
    LDX #$6F            ; Draw cloud tile
.tileChosen:
    STX PPUDATA
    LSR marchingSquaresProb         ; bitshift the A register over to look at the next bit
    DEY
    BNE .sectionLoop    
    DEC background_load_current_Y   ; Check if we have generated all 
    BPL .fullByteUseLoop            ; Else done for this column

    ; 30 rows = 2 topBorder + 24 sky + 1 floor + 3 bricks underground

    LDA #$F0            ; Load one tile of floor
    STA PPUDATA
    LDX #3              ; Load three tiles of underground
    LDA #$F2            ; Underground tile location
.GenerateBricks:        ; Fill last 3 rows with brick tiles
    STA PPUDATA
    DEX
    BNE .GenerateBricks

    INC generate_x      ; Increment the counter/memory offset manager

    LDA #0              ; Have to force the scrolls back to #0 after generation
    STA PPUSCROLL
    STA PPUSCROLL
    LDA #%00000000      ; Set back to normal skip mode
    STA PPUCTRL
    RTS
;----------------------------------------
; Generates a column of background tiles in the appropriate memory position for the first nametable (no ledge)
GenerateGameBackground_Column_WithLedge_FullRandom:
    LDA #%00000100      ; Put PPU into skip 32 mode instead of 1
    STA PPUCTRL         ; Have to restore back to previous values later

    ; Reset the PPU high/low latch
    LDA PPUSTATUS

    LDA current_nametable_generating
    STA PPUADDR
    LDA generate_x
    STA PPUADDR
     
    LDA #$6F            ; Load in one row of cloud to account for PAL displays
    STA PPUDATA

    LDA #2              ; The area to fill is 3 * 8 = 24 large. We will branch when background_load_current_Y is minus so 3 loops
    STA background_load_current_Y

.fullByteUseLoop_Ledge:
    LDY #8              ; Use Y reg here as prng clobbers X register
    JSR prng
    STA marchingSquaresProb
.sectionLoop_Ledge:
    LDA marchingSquaresProb
    AND #1              ; Is the least significant bit a 1?
    BNE .drawCloud_Ledge
    LDX #$00            ; Else draw empty tile
    JMP .tileChosen_Ledge
.drawCloud_Ledge:
    LDX #$6F            ; Draw cloud tile
.tileChosen_Ledge:
    STX PPUDATA
    LSR marchingSquaresProb                ; bitshift the A register over to look at the next bit
    DEY
    BNE .sectionLoop_Ledge    
    DEC background_load_current_Y   ; Check if we have generated all 
    BPL .fullByteUseLoop_Ledge            ; Else done for this column

    ; 30 rows = 1 topBorder + 24 sky + 1 ledge + 1 floor + 3 bricks underground

    LDA #$F0            ; Load one tile of ledge
    STA PPUDATA
    LDA #$F0            ; Load one tile of floor
    STA PPUDATA
    LDX #3              ; Load three tiles of underground
    LDA #$F2            ; Underground tile location
.GenerateBricks_Ledge:        ; Fill last 3 rows with brick tiles
    STA PPUDATA
    DEX
    BNE .GenerateBricks_Ledge

    INC generate_x      ; Increment the counter/memory offset manager

    LDA #0              ; Have to force the scrolls back to #0 after generation
    STA PPUSCROLL
    STA PPUSCROLL
    LDA #%00000000      ; Set back to normal skip mode
    STA PPUCTRL
    RTS
;----------------------------------------
marchingSquares:
    LDA #%00000100      ; Put PPU into skip 32 mode instead of 1
    STA PPUCTRL         ; Have to restore back to previous values later

    ; Reset the PPU high/low latch
    LDA PPUSTATUS

    LDA current_nametable_generating
    STA PPUADDR
    LDA generate_x
    STA PPUADDR
    CMP #0                  ; If first row then fill with cloud tiles
    BNE .continue1
    JSR FillWithCloudTiles
    RTS
.continue1:
    LDA generate_x
    CMP #NUMBER_OF_TILES_PER_ROW-1
    BNE .continue2          ; If last row then fill with cloud tiles
    JSR FillWithCloudTiles
    RTS
.continue2:

    LDY #0                  ; The byte
    LDA #$6F                ; Load in one row of cloud to account for the border
    
.analyseNextTile:
   ; analyseSquare

;----------------------------------------
FillWithCloudTiles:
    LDX #30
    LDA #$6F
.cloudColumn:
    STA PPUDATA
    DEX
    BNE .cloudColumn
    RTS
;----------------------------------------