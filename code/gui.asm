;=============================================================================
; 32-bit Assembler Graphical User Interface
; CODE by: Arthur Chomé - Jérôme Botoko Ekila
; December 2017
;=============================================================================

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

SCREEN_WIDTH EQU 320
SCREEN_HEIGHT EQU 200
TILE_SIZE EQU 8

;=============================================================================
; INCLUDES
;=============================================================================
INCLUDE "gui.inc"
;=============================================================================
; CODE
;=============================================================================
CODESEG

;Thus procedure sets up the video mode 13h.
;This allows us to display pixels on the screen.
;By coloring the pixels, you can change what's drawn on the screen.
PROC setupVideo
	USES eax

	mov	ax, 13h
	int 10h

	ret
ENDP setupVideo

;Close the video mode 13h: the screen gets closed.
PROC unsetupVideo
	USES eax

	mov	ax, 03h
	int 10h

	ret
ENDP unsetupVideo

; Procedure to wait for a v-blank event (synchronizes game loop to 60Hz in mode 13h)
PROC waitVBlank
	USES eax, edx

	mov dx, 03dah
	@@waitVBlank_wait1:
	in al, dx
	and al, 8
	jnz @@waitVBlank_wait1
	@@waitVBlank_wait2:
	in al, dx
	and al, 8
	jz @@waitVBlank_wait2
	
	cld ;clear the direction flag
    mov esi, offset videoBuffer
    mov edi, 0a0000h 
    mov ecx, 64000 / 4 ; 320 * 200 , but copy groups four bytes
    rep movsd             ; moves a dword and updates ecx , e s i and edi
	ret
ENDP waitVBlank

;=============================================================================
; All functions to draw sprites in to the game
;=============================================================================

; Draws a sprite on a position (x, y) given a sprite and this position
PROC drawSprite
	ARG @@spritePtr :dword, \
			@@x:dword, \
			@@y:dword
	LOCAL @@w:dword, @@h:dword
	USES eax , ebx , ecx , edx , esi , edi
	
	mov esi , [@@spritePtr ]
	xor eax , eax
	lodsw ; read width in AX
	mov [@@w] , eax
	lodsw ; read height in AX
	mov [@@h] , eax
	mov edi , offset videoBuffer
	mov eax , [@@y]
	mov ebx , SCREEN_WIDTH
	mul ebx
	add edi , eax
	add edi , [@@x] ; EDI points to first pixel
	mov ecx , [@@h]
	@@drawLine :
		push ecx
		mov ecx , [@@w] ; need to copy a line of the sprite 
		rep movsb ; copy from esi to edi
		add edi , SCREEN_WIDTH
		sub edi , [@@w] ; edi now points to the next line in dst
		pop ecx
		dec ecx
		jnz @@drawLine
	ret
ENDP drawSprite

; Converts the grid positions to the right pixel position and calls drawSprite with the newly calculated pixel positions
PROC drawGridSprite
    ARG @@spritePtr :dword, \
            @@x:dword, \
            @@y:dword
    USES eax

	;Move the given x-coordinate to register eax.
    mov eax, [@@x]
	;The x-coordinate on the grid gets multiplied by the tile-size to form the true position on the screen.
	imul eax, TILE_SIZE
	;Update the argument-variable to the true x-coordinate
    mov [@@x], eax
	
	;Do the same for the y-coördinate: give it its true position on the screen based on the grid-coordinates.
    mov eax, [@@y]
    imul eax, TILE_SIZE
    mov [@@y], eax
    call drawSprite, [@@spritePtr], [@@x], [@@y]
    ret
ENDP drawGridSprite

; Draws a string on a grid position (x, y) with a given length.
PROC drawString
	ARG @@sprite:dword, \
            @@x:dword, \
			@@y:dword, \
			@@length: dword
	USES eax, ebx, ecx

	mov eax, 0
	@@startDrawLoop:
		cmp eax, [@@length]
		je @@endDrawLoop
		mov ebx, eax
		add ebx, [@@x]
		mov ecx, [@@sprite]
		call drawGridSprite, [DWORD PTR ecx + eax * 4], ebx, [@@y]
		inc eax
		jmp @@startDrawLoop

	@@endDrawLoop:
	ret
ENDP drawString

;An empty-sprite is drawn.
;Used to erase specific screensections like a short text
;or the apple that has to change position.
PROC drawEmpty
	ARG @@x:dword, \
            @@y:dword

	call drawGridSprite, offset _emptySprite, [@@x], [@@y]
    ret
ENDP drawEmpty

;Draws a snakeblock using procedure 'drawGridSprite'
PROC drawSnake
	ARG @@x:dword, \
            @@y:dword

	call drawGridSprite, offset _snakeSprite, [@@x], [@@y]
    ret
ENDP drawSnake

;Draws the apple on the given gridposition.
PROC drawApple
	ARG @@x:dword, \
            @@y:dword

	call drawGridSprite, offset _appleSprite, [@@x], [@@y]
    ret
ENDP drawApple

;Draws the wall on the given gridposition.
PROC drawWall
		ARG @@x:dword, \
			@@y:dword
		
	call drawGridSprite, offset _wallSprite, [@@x], [@@y]
	ret
ENDP drawWall

; Draws a boundary on the upper level
PROC drawHorizontalLine
	ARG @@y: dword
	USES eax
	
	mov eax, 0
	@@horizontalLoop:
		call drawGridSprite, offset _horizontalLineSprite, eax, 2 ; Draw line at height two
		inc eax
		cmp eax, 40
		jl @@horizontalLoop
	
	ret
ENDP drawHorizontalLine

; Draws the string _Pause on to the screen, given is 0 or 1. 
; 0 indicates that the game was unpaused and the pause_string should be removed, otherwise draw the string
PROC drawPause
	ARG @@option: dword
		USES ebx
	
	mov ebx, [@@option]
	;Based on the given argument, we will draw or erase the words "game paused"
	cmp ebx, 0
	jne @@UnPause
	
	@@Pause:
	call drawString, offset _Pause, 31, 1, 8
	jmp @@endDrawPause
		
	@@UnPause:
	call drawString, offset _Empty, 31, 1, 8
		
	@@endDrawPause:
	ret
ENDP drawPause

;This procedure draws the score.
PROC drawScore
	ARG @@score: dword, \
		@@option: dword
	
	cmp [@@option], 0
	jne @@drawHighScore
	
	
	@@drawCurrentScore:
	call drawString, offset _Score, 1, 1, 7
	call drawNumber, [@@score], 56
	jmp @@endDrawScore
	
	@@drawHighScore:
	call drawString, offset _HighScore, 14, 1, 11
	call drawNumber, [@@score], 192
	
	@@endDrawScore:
	ret
ENDP drawScore

PROC drawNumber
	ARG @@number: dword, \
		@@x: dword
		USES eax, ebx, ecx, edx

	mov ecx, [@@x]
	call drawSprite, [_digits], [@@x], 8
	;We'll need a loop to calculate the offset to the left
	mov eax, [@@number]
	cmp eax, 0
	je @@endNumber
	
	sub ecx, 8
	@@offsetLoop:
		mov edx, 0
		mov ebx, 10
		div ebx
		add ecx, 8
		cmp eax, 0
		jne @@offsetLoop
	
	mov eax, [@@number]
	@@numberLoop:
		mov edx, 0
		mov ebx, 10
		div ebx
		call drawSprite, [_digits + edx*4], ecx, 8
		sub ecx, 8
		cmp eax, 0
		jne @@numberLoop
    
	@@endNumber:
	ret
ENDP drawNumber

;Procedure to clean the screen.
;Every pixel on the mode 13h screen will be changed to black.
PROC clearScreen
	USES ecx

	mov ecx, 0
	;The loop will change every pixel to _black.
	;_black is a sprite who's just a black pixel of size 1.
    @@drawLoop:
		call drawSprite, offset _black, ecx, 0
		inc ecx
		;Look if every pixel has been blackened (64000 pixels).
		cmp ecx, SCREEN_WIDTH * SCREEN_HEIGHT
		jne @@drawLoop

    @@endLoop:
    ret
ENDP clearScreen

;'Game over' gets drawn and stays on the screen for some seconds.
;This delay is to make sure the player sees and realizes he has lost.
PROC drawGameOver
	USES eax
	
	call waitVBlank
	call drawString, offset _GameOver, 12, 12, 15
	
	mov eax, 0
	@@stall:
		call waitVBlank
		inc eax
		cmp eax, 150
		jl @@stall
	ret
ENDP drawGameOver

;=============================================================================
; Main Menu
;=============================================================================

; The menu gets drawn with its 4 options.
PROC drawMenu
	USES eax
	
	mov eax, 11 ; base height of the first option
	mov [ARROW_Y], eax
	;Draw the menu's title.
	call drawString, offset _Menu, 17, 7, 5
	;Draw the menu's options.
	call drawString, offset _OPTION1, 15, 11, 9
	call drawString, offset _OPTION2, 13, 13, 12
	call drawString, offset _OPTION3, 17, 15, 4
	call drawString, offset _OPTION4, 17, 17, 4

	;Draw the current arrow
	call drawGridSprite, offset _ArrowSprite, [ARROW_X], [ARROW_Y]

	ret
ENDP drawMenu

;Procedure to draw the selection arrow: can be for the difficulty menu or the main menu.
PROC drawArrow
	ARG @@new_arrow:dword
		USES eax
	
	mov eax, [@@new_arrow] ;the arrow is drawn relative to the first option
	mov ebx, 2
	mul ebx 			; boxes are spaced two distances from each other
	add eax, 11 		; base height of the first option
	
	call drawGridSprite, offset _emptySprite, [ARROW_X], [ARROW_Y] ;undraw previous arrow
	call drawGridSprite, offset _ArrowSprite, [ARROW_X], eax 			   ;draw new arrow
	mov [ARROW_Y], eax
	
	ret
ENDP drawArrow

;Procedure to fill in the square (right) of the selected option.
;The user can see than which option is chosen.
PROC drawChoose
	call drawGridSprite, offset _selectedBoxSprite, 23, [ARROW_Y]
	ret
ENDP drawChoose

;Procedure to unchoose a difficulty.
;The filled square of the difficulty will be an empty square.
PROC drawUnChoose
	ARG @@box: dword
	USES eax, ebx

	mov eax, [@@box] ;the box is drawn relative to the first box
	mov ebx, 2 
	mul ebx ; boxes are spaced two distances from each other
	add eax, 11 ; base height of the first box
	call drawGridSprite, offset _checkBoxSprite, 23, eax
	
	ret
ENDP drawUnChoose

;This procedure will draw the difficulty menu.
;This means the title, 
PROC drawDifficulty;
	ARG @@box: dword
	USES eax, ebx

	;Draw the title: "select difficulty".
	call drawString, offset _DIFFICULTY_TITLE, 11, 7, 17
	
	;1st difficulty: "baby"
	call drawString, offset _DIFFICULTY_1, 14, 11, 4
	call drawGridSprite, offset _checkBoxSprite, 23, 11
	
	;2nd difficulty: "easy"
	call drawString, offset _DIFFICULTY_2, 14, 13, 4
	call drawGridSprite, offset _checkBoxSprite, 23, 13

	;3rd difficulty: "normal"
	call drawString, offset _DIFFICULTY_3,14, 15, 6
	call drawGridSprite, offset _checkBoxSprite, 23, 15

	;4th difficulty: "hard"
	call drawString, offset _DIFFICULTY_4, 14, 17, 4
	call drawGridSprite, offset _checkBoxSprite, 23, 17

	;5th difficulty: "expert"
	call drawString, offset _DIFFICULTY_5, 14, 19, 6
	call drawGridSprite, offset _checkBoxSprite, 23, 19

	;6th difficulty: "insane"
	call drawString, offset _DIFFICULTY_6, 14, 21, 6
	call drawGridSprite, offset _checkBoxSprite, 23, 21

	
	;After this: you will have to overwrite the empty selection box
	;of the chosen option by a filled (white) selection box.
	mov eax, [@@box]
	mov ebx, 2 ; options are spaced two distances from each other
	mul ebx
	add eax, 11 ; base height of the first option (option1)
	call drawGridSprite, offset _selectedBoxSprite, 23, eax
	mov eax, 11 ; base height of the first option (option1)
	mov [ARROW_Y], eax
	call drawGridSprite, offset _ArrowSprite, [ARROW_X], [ARROW_Y]

	ret
ENDP drawDifficulty

;=============================================================================
; Help menu
;=============================================================================

;This procedure draws all the strings and sprites for the help section.
;Nothing complicated happens here, this procedure just colors pixels.
PROC drawHelp

	call drawString, offset _HELP_TEXT, 6, 5, 28
	call drawSnake, offset 34, 9
	call drawString, offset _SNAKE_TEXT, 6, 9, 27
	call drawApple, offset 34, 11
	call drawString, offset _APPLE_TEXT1, 6, 11, 27
	call drawString, offset _APPLE_TEXT2, 6, 13, 23
	call drawString, offset _PAUSE_HELP_TEXT, 6, 17, 25
	call drawString, offset _EXIT_TEXT, 6, 19, 20
	
	ret
ENDP drawHelp

;=============================================================================
; Sound
;=============================================================================
;This procedure generates a short beep
PROC beepSound
	USES eax, ebx, ecx

	mov al, 182 ; meaning that we're about to load
    out 43h, al ; a new countdown value

    mov ax, 100        
    out 42h, al ; Output low byte.
    mov al, ah ; Output high byte.
    out 42h, al               

    in al, 61h ; to connect the speaker to timer 2
                            
    or al, 35  
	;This command sends the sound out of the speakers
    out 61h, al ; Send the new value
	
	;slow down the procedure to make sure
	;the beep sound can still be heard.
	call waitVBlank
	and al, 11111100b
	out 61h, al
	
	ret
ENDP beepSound

;=============================================================================
; DATA
;=============================================================================
DATASEG
	
	; This variable keeps all the pixels that are drawn on the 13h mode screen
	videoBuffer db 64000 dup(?) 
	
	; Game text:
	
	;This variable contains the sprites needed to spell "score: ", they're represented as a list.
	_Score dd _SpriteS, _SpriteC, _SpriteO, _SpriteR, _SpriteE, _ColonSprite, _emptySprite
	_HighScore dd _SpriteH, _SpriteI, _SpriteG, _SpriteH, _SpriteS, _SpriteC, _SpriteO, _SpriteR, _SpriteE, _ColonSprite, _emptySprite
	
	;Digits are being drawn by using the current digit as an offset for the variable(list) "_digits"
	_digits dd  _Sprite0,  _Sprite1, _Sprite2, _Sprite3, \
					 _Sprite4, _Sprite5, _Sprite6, _Sprite7, \
					  _Sprite8, _Sprite9
	
	;This listvariable spells "game paused"
	_Pause dd _SpriteP, _SpriteA, _SpriteU, _SpriteS,_SpriteE, _emptySprite, \
								_SpriteO, _SpriteN
	
	; "dead: try again"
	_GameOver dd _SpriteD, _SpriteE, _SpriteA, _SpriteD, _ColonSprite, _emptySprite, \
								_SpriteT, _SpriteR, _SpriteY, _emptySprite, \
								_SpriteA, _SpriteG, _SpriteA, _SpriteI, _SpriteN
	
	_Empty dd _emptySprite, _emptySprite, _emptySprite, _emptySprite, _emptySprite, \
					_emptySprite, _emptySprite, _emptySprite, _emptySprite, _emptySprite, _emptySprite
	
	; Arrows shared by main menu and difficulty menu
	ARROW_X dd 11
	ARROW_Y dd 11
	
	; Main menu text
	;This list contains all the sprites to spell "snake".
	_Menu dd _SpriteS, _SpriteN, _SpriteA, _SpriteK, _SpriteE

	;List variable with "game over" in spriteformat as content.
	_OPTION1 dd _SpriteP, _SpriteL, _SpriteA, _SpriteY, _emptySprite, _SpriteG, _SpriteA, _SpriteM, _SpriteE 
	
	;"Difficulties"
	_OPTION2 dd _SpriteD, _SpriteI, _SpriteF, _SpriteF, _SpriteI, \
							_SpriteC, _SpriteU, _SpriteL, _SpriteT, _SpriteI, _SpriteE, _SpriteS
	
	_OPTION3 dd  _SpriteH, _SpriteE, _SpriteL, _SpriteP
	
	_OPTION4 dd _SpriteE, _SpriteX, _SpriteI, _SpriteT
	
	; Difficulty menu text	
	_DIFFICULTY_TITLE dd _SpriteS, _SpriteE, _SpriteL, _SpriteE, _SpriteC, _SpriteT, _emptySprite, \
										_SpriteD, _SpriteI, _SpriteF, _SpriteF, _SpriteI, \
										_SpriteC, _SpriteU, _SpriteL, _SpriteT, _SpriteY		

	;Different difficulties									
	_DIFFICULTY_1 dd _SpriteB, _SpriteA, _SpriteB, _SpriteY 
	_DIFFICULTY_2 dd _SpriteE, _SpriteA, _SpriteS, _SpriteY
	_DIFFICULTY_3 dd _SpriteN, _SpriteO, _SpriteR, _SpriteM, _SpriteA, _SpriteL
	_DIFFICULTY_4 dd _SpriteH, _SpriteA, _SpriteR, _SpriteD
	_DIFFICULTY_5 dd _SpriteE, _SpriteX, _SpriteP, _SpriteE, _SpriteR, _SpriteT
	_DIFFICULTY_6 dd _SpriteI, _SpriteN, _SpriteS, _SpriteA, _SpriteN, _SpriteE

	; Help texts: all the lists of sprites necessary to form the helpsection of the menu.
	_HELP_TEXT dd _SpriteW, _SpriteE, _SpriteL, _SpriteC, _SpriteO, _SpriteM, _SpriteE, _emptySprite, \
								_SpriteT, _SpriteO, _emptySprite, _SpriteT, _SpriteH, _SpriteE, _emptySprite, \
								_SpriteH, _SpriteE, _SpriteL, _SpriteP, _emptySprite, _SpriteS, _SpriteE, _SpriteC, _SpriteT, _SpriteI, _SpriteO, _SpriteN, _emptySprite
	_SNAKE_TEXT dd _SpriteT, _SpriteH, _SpriteE,  _SpriteS, _SpriteE, _emptySprite, _SpriteB, _SpriteL, _SpriteO, _SpriteC, _SpriteK, _SpriteS,  _emptySprite, \
								_SpriteF, _SpriteO, _SpriteR, _SpriteM, _emptySprite, _SpriteT, _SpriteH, _SpriteE, _emptySprite, \
								_SpriteS, _SpriteN, _SpriteA, _SpriteK, _SpriteE
	_APPLE_TEXT1 dd _SpriteT, _SpriteH, _SpriteE, _emptySprite, _SpriteS, _SpriteN, _SpriteA, _SpriteK, _SpriteE, _emptySprite, \
								_SpriteH, _SpriteA, _SpriteS, _emptySprite, _SpriteT,  _SpriteO, _emptySprite, \
								_SpriteE, _SpriteA, _SpriteT, _emptySprite,_SpriteA, _SpriteP, _SpriteP, _SpriteL, _SpriteE, _SpriteS
	_APPLE_TEXT2 dd _SpriteA, _SpriteP, _SpriteP, _SpriteL, _SpriteE, _SpriteS, _emptySprite, \
								_SpriteA, _SpriteP, _SpriteP, _SpriteE, _SpriteA, _SpriteR, _emptySprite, _SpriteA, _SpriteT, _emptySprite, \
								_SpriteR, _SpriteA, _SpriteN, _SpriteD, _SpriteO, _SpriteM
	_PAUSE_HELP_TEXT dd 	_SpriteP, _SpriteR, _SpriteE,  _SpriteS, _SpriteS, _emptySprite, _SpriteP, _emptySprite, \
										_SpriteT, _SpriteO, _emptySprite, _SpriteP, _SpriteA, _SpriteU, _SpriteS, _SpriteE, _emptySprite, \
										_SpriteT, _SpriteH, _SpriteE, _emptySprite, _SpriteG, _SpriteA, _SpriteM, _SpriteE						
	_EXIT_TEXT dd _SpriteP, _SpriteR, _SpriteE,  _SpriteS, _SpriteS, _emptySprite, \
							_SpriteE, _SpriteS, _SpriteC, _SpriteA, _SpriteP, _SpriteE, _emptySprite, _SpriteT, _SpriteO, \
							_emptySprite, _SpriteE, _SpriteX, _SpriteI, _SpriteT
	
	;SPRITES
	
	
	_black  dw 1,1
		db 0

	;Sprite for a snake block.	
	_snakeSprite dw 8, 8 ; width & height van de sprite
		  db 10, 13, 13, 13, 13, 13, 13, 12
		  db 10, 15, 15, 15, 15, 15, 15, 12
		  db 10, 15, 15, 15, 15, 15, 15, 12
		  db 10, 13, 13, 13, 13, 13, 13, 12
		  db 10, 13, 13, 13, 13, 13, 13, 12
		  db 10, 15, 15, 15, 15, 15, 15, 12
		  db 10, 15, 15, 15, 15, 15, 15, 12
		  db 10, 13, 13, 13, 13, 13, 13, 12
  
	;Sprite for an apple.
	_appleSprite dw 8, 8 ; width & height van de sprite
		  db 0, 0, 0, 2, 2, 0, 0, 0
		  db 0, 4, 4, 4, 4, 4, 4, 0
		  db 4, 4, 4, 4, 4, 4, 4, 4
		  db 4, 4, 4, 4, 4, 4, 4, 4
		  db 4, 4, 4, 4, 4, 4, 4, 4
		  db 4, 4, 4, 4, 4, 4, 4, 4
		  db 4, 4, 4, 4, 4, 4, 4, 4
		  db 0, 0, 4, 4, 4, 4, 0, 0
		
	;Sprite for a wall (full green).
	_wallSprite dw 8, 8 ; width & height of the sprite
		  db 2, 2, 2, 2, 2, 2, 2, 2
		  db 2, 2, 2, 2, 2, 2, 2, 2
		  db 2, 2, 2, 2, 2, 2, 2, 2
		  db 2, 2, 2, 2, 2, 2, 2, 2
		  db 2, 2, 2, 2, 2, 2, 2, 2
		  db 2, 2, 2, 2, 2, 2, 2, 2
		  db 2, 2, 2, 2, 2, 2, 2, 2
		  db 2, 2, 2, 2, 2, 2, 2, 2
	
	;To draw a horizontal line: it's used on top of the screen
    ;to specify the limit	
	_horizontalLineSprite dw 8, 8
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 15, 15, 15, 15, 15, 15, 15, 15
  
	;This is just a black block. 
  _emptySprite dw 8, 8
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0	
		  
	;Sprite for the selection arrow.
	_ArrowSprite dw 8, 8
		  db 0, 0, 15, 0, 0, 0, 0, 0
		  db 0, 0, 15, 15, 0, 0, 0, 0
		  db 0, 0, 15, 15, 15, 0, 0, 0
		  db 0, 0, 15, 15, 15, 15, 0, 0
		  db 0, 0, 15, 15, 15, 15, 0, 0
		  db 0, 0, 15, 15, 15, 0, 0, 0
		  db 0, 0, 15, 15, 0, 0, 0, 0
		  db 0, 0, 15, 0, 0, 0, 0, 0
  
	;Sprite for an empty selection arrow.
	_checkBoxSprite dw 8, 8
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 15, 15, 15, 15, 15, 15, 0
		  db 0, 15, 0, 0, 0, 0, 15, 0
		  db 0, 15, 0, 0, 0, 0, 15, 0
		  db 0, 15, 0, 0, 0, 0, 15, 0
		  db 0, 15, 0, 0, 0, 0, 15, 0
		  db 0, 15, 15, 15, 15, 15, 15, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
  
	;Sprite for a filled/selected/white selection arrow.
	_selectedBoxSprite dw 8, 8
		  db 0, 0, 0, 0, 0, 0, 0, 0
		  db 0, 15, 15, 15, 15, 15, 15, 0
		  db 0, 15, 15, 15, 15, 15, 15, 0
		  db 0, 15, 15, 15, 15, 15, 15, 0
		  db 0, 15, 15, 15, 15, 15, 15, 0
		  db 0, 15, 15, 15, 15, 15, 15, 0
		  db 0, 15, 15, 15, 15, 15, 15, 0
		  db 0, 0, 0, 0, 0, 0, 0, 0
  
  
  ;Alphabet & numbers.
  
  _Sprite0 dw 8, 8
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  
  
  _Sprite1 dw 8, 8
  db 0, 0, 0, 0, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  
  _Sprite2 dw 8, 8
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 15, 0, 0, 0
  db 0, 0, 0, 15, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  
  _Sprite3 dw 8, 8
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  
  _Sprite4 dw 8, 8
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 0, 0, 15, 15, 0, 0
  db 0, 0, 0, 0, 15, 15, 0, 0
  db 0, 0, 0, 0, 15, 15, 0, 0
  
  _Sprite5 dw 8, 8
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  
  _Sprite6 dw 8, 8
  db 0, 0, 0, 0, 15, 15, 0, 0
  db 0, 0, 0, 15, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  
  _Sprite7 dw 8, 8
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 15, 0, 0, 0
  db 0, 0, 0, 0, 15, 0, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 0, 15, 0, 0, 0, 0
  db 0, 0, 0, 15, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  
  _Sprite8 dw 8, 8
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  
  _Sprite9 dw 8, 8
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 0, 15, 15, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  
  ;Sprites for letters
  _SpriteA dw 8, 8
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  _SpriteB dw 8, 8
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  
  _SpriteC dw 8, 8
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  
  _SpriteD dw 8, 8
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  
  _SpriteE dw 8, 8
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  
  _SpriteF dw 8, 8
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  
  _SpriteG dw 8, 8
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  
  _SpriteH dw 8, 8
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0

  
    _SpriteI dw 8, 8
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  
  _SpriteJ dw 8, 8
  db 0, 0, 0, 0, 15, 15, 0, 0
  db 0, 0, 0, 0, 15, 15, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 0, 15, 15, 0, 0
  db 0, 0, 0, 0, 15, 15, 0, 0
  db 0, 0, 15, 0, 15, 15, 0, 0
  db 0, 0, 15, 0, 15, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  
  _SpriteK dw 8, 8
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 15, 0, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 0, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  
  _SpriteL dw 8, 8
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 15, 0, 0, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  
  _SpriteM dw 8, 8
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 15, 0, 0, 15, 15, 0
  db 0, 15, 0, 15, 15, 0, 15, 0
  db 0, 15, 0, 15, 15, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  
  _SpriteN dw 8, 8
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 0, 15, 0, 0
  db 0, 0, 15, 15, 0, 15, 0, 0
  db 0, 0, 15, 0, 15, 15, 0, 0
  db 0, 0, 15, 0, 15, 15, 0, 0
  db 0, 0, 15, 0, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  
  _SpriteO dw 8, 8
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, , 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  
  _SpriteP dw 8, 8
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  
   _SpriteQ dw 8, 8
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 15, 15, , 0
  db 0, 0, 0, 15, 15, 15, 0, 0

  
   _SpriteR dw 8, 8
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  
   _SpriteS dw 8, 8
  db 0, 0, 0, 15, 15, 15, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 0, 15, 0, 0, 0, 0
  db 0, 0, 0, 0, 15, 0, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 15, 15, 15, 0, 0, 0
  
   _SpriteT dw 8, 8
  db 0, 15, 15, 15, 15, 15, 15, 0
  db 0, 15, 15, 15, 15, 15, 15, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  
   _SpriteU dw 8, 8
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  
   _SpriteV dw 8, 8
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  
   _SpriteW dw 8, 8
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 15, 15, 0, 15, 0
  db 0, 15, 0, 15, 15, 0, 15, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  
  _SpriteX dw 8, 8
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  
  _SpriteY dw 8, 8
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 15, 0, 0, 0, 0, 15, 0
  db 0, 0, 15, 0, 0, 15, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  
  _SpriteZ dw 8, 8
  db 0, 0, 15, 15, 15, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 0, 15, 0, 0
  db 0, 0, 0, 0, 15, 0, 0, 0
  db 0, 0, 0, 15, 0, 0, 0, 0
  db 0, 0, 0, 15, 0, 0, 0, 0
  db 0, 0, 15, 0, 0, 0, 0, 0
  db 0, 0, 15, 15, 15, 15, 0, 0
  
  ;Sprite for double point.
  _ColonSprite dw 8, 8
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 15, 15, 0, 0, 0
  db 0, 0, 0, 0, 0, 0, 0, 0
  
  END