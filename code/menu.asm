;=============================================================================
; 32-bit Assembler Main - Menu
; CODE by: Arthur Chomé - Jérôme Botoko Ekila
; December 2017
;=============================================================================

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

;=============================================================================
; INCLUDES
;=============================================================================
INCLUDE "gui.inc"
INCLUDE "game.inc"
;=============================================================================
; CODE
;=============================================================================
CODESEG

; Procedure to exit the program
PROC exit
	USES eax
    
	call unsetupVideo
	mov	eax, 4c00h
	int 21h
	ret
ENDP exit

;=============================================================================
; Functions to prepare the state of the menu when going from one to another
;=============================================================================

;Procedure to set up the main menu:
;clear the screen first, draw the menu (options, arrow,...),
;set the state of the program to that of the menu
;& put the selection arrow on the first option.

PROC enterMainMenu

	call clearScreen
	call drawMenu
	mov [MENU_STATE], 0
	mov [ARROW], 0
	
	ret
ENDP enterMainMenu

PROC enterDifficultyMenu

	call clearScreen
	call drawDifficulty, [DIFFICULTY]
	mov [MENU_STATE], 1
	mov [ARROW], 0
	
	ret
ENDP enterDifficultyMenu

PROC enterHelpMenu
	USES eax
	
	call clearScreen
	call drawHelp

	@@helpLoop:
		call waitVBlank
		mov ah, 01h
		; function 01h (test key pressed)
		int 16h ; call keyboard BIOS
		jz @@helpLoop
		mov ah, 00h
		int 16h

		cmp ah, 01 ; scancode for ESCAPE key;
		jne @@helpLoop
	
	@@end:
	ret
ENDP enterHelpMenu

;=============================================================================
; Input Handlers for the main and difficulty menu
;=============================================================================
; Procedure to handle user input while in the main menu.
PROC handleUserInput

    mov ah, 01h ; function 01h (test key pressed)
    int 16h ; call keyboard BIOS
    jz @@noKeyPressed
    mov ah, 00h ;get keystroke from keyboard 
    int 16h
	
	;The first thing to check is if we have to close the program or not.
	@@n0:
		cmp ah, 01 ; scancode for ESCAPE key
		jne @@n1
		call exit
		jmp @@noKeyPressed
	
	;If the enter key gets pressed, you have to check which menu-option
	;has been chosen. This is done by checking the value in the variable [ARROW]
    @@n1:
	cmp al, 13 ; scancode for ENTER key
	jne @@up
		
		@@o1:
		cmp [ARROW], 0
		jne @@o2
		;; ClearScreen and run game (which is a loop and will return!)
		call clearScreen
		call runGame, [DIFFICULTY]
		;; Return to main menu
		call enterMainMenu
		jmp @@noKeyPressed
		
		@@o2:
		cmp [ARROW], 1
		jne @@o3
		call enterDifficultyMenu
		jmp @@noKeyPressed
		
		@@o3:
		cmp [ARROW], 2
		jne @@o4
		call enterHelpMenu
		call enterMainMenu
		jmp @@noKeyPressed
		
		@@o4:
		cmp [ARROW], 3
		jne @@noKeyPressed
		call exit
		jmp @@noKeyPressed
	
	;If the upkey is pressed, the arrow has to go up (if possible).	
	@@up:
		cmp ah, 80
		jne @@down
		call moveArrow, 1
		jmp @@noKeyPressed
	
	;Move the arrow down if possible.
	@@down:
		cmp ah, 72
		jne @@noKeyPressed
		call moveArrow, -1
		jmp @@noKeyPressed

    @@noKeyPressed:
    ret
ENDP handleUserInput

;Procedure for the user-input for when selecting in the difficulty menu
PROC handleUserInputDifficulty
	
    mov ah, 01h ; function 01h (test key pressed)
    int 16h ; call keyboard BIOS
    jz @@noKey
    mov ah, 00h
    int 16h
	
	@@n0:
    	cmp ah, 01 ; scancode for escape key
		jne @@n1
		call enterMainMenu
		jmp @@noKey
	
    ;Pressing 'enter' will select the option the selection arrow is on.
	@@n1:
		cmp al, 13 ; scancode for enter key
		jne @@up
		call selectDifficulty
		jmp @@noKey
		
    @@up:
		cmp ah, 80 
		jne @@down
		call moveArrow, 1
		jmp @@noKey
	
	@@down:
		cmp ah, 72 ;scan code for the down-key
		jne @@noKey
		call moveArrow, -1
		jmp @@noKey

    @@noKey:
    ret
ENDP handleUserInputDifficulty

;=============================================================================
; Aid functions
;=============================================================================
;Draws an unselected box on the previous difficulty and a selected box on the new one. (difficulty menu)
PROC selectDifficulty
	USES eax, ebx
	
	;Make sure the square on the right is empty instead of full
	;so the user sees the previous difficulty is not chosen anymore.
	call drawUnChoose, [DIFFICULTY]
	mov eax, [ARROW]
	;Change the difficulty to the one the arrow is pointing at.
	mov [DIFFICULTY], eax
	;Fill in the square on the interface of the chosen difficulty.
	call drawChoose, [DIFFICULTY]
	
	ret
ENDP selectDifficulty

; Moves the arrow with the given delta. Bounds are checked depending on the current menu.
PROC moveArrow
	ARG @@delta: dword
		USES eax
		
	mov eax, [ARROW]
	add eax, [@@delta]
	
	
	cmp eax, -1 ; Check if arrow already is on the first option.
	je @@end
	
	cmp [MENU_STATE], 0 ;Check if you're in the main menu (menu_state = 0).
	jne @@diffArrow
	
	; Arrow traversal in the main menu. This menu has 4 options.
	cmp eax, 4
	je @@end
	jmp @@move
	
	; Arrow traversal in the difficulty menu. This menu has 6 options.
	@@diffArrow:
	cmp eax, 6
	je @@end

	@@move:
	;The arrow can be moved.
	call drawArrow, eax
	;Update the arrow's position.
	mov [ARROW], eax
	;Make a sound to show the arrow moved.
	call beepSound
	
	@@end:
	ret
ENDP moveArrow


start:
    sti ; Set The Interrupt Flag
    cld ; Clear The Direction Flag

    push ds ; Put value of DS register on the stack
    pop es ; And write this value to ES

    ; Setup and initialization
    call setupVideo
	call drawMenu
	
	@@menuLoop:
		call handleUserInput
		call waitVBlank
		cmp [MENU_STATE], 0
		je @@menuLoop
	   
		@@difficultyLoop:
			call handleUserInputDifficulty
			call waitVBlank
			cmp [MENU_STATE], 1
			je  @@difficultyLoop
		jmp @@menuLoop
			
;=============================================================================
; DATA
;=============================================================================
DATASEG

	;; 0 = startscreen, 1 = difficulty-settings
	MENU_STATE dd 0 
	;; Arrow selection
	ARROW dd 0
	;; Chosen difficulty in the difficulty menu
	DIFFICULTY dd 0
	
;=============================================================================
; STACK
;=============================================================================
STACK 1000h

END start
