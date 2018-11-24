;=============================================================================
; 32-bit Assembler Game - the game
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
INCLUDE "rand.inc"
INCLUDE "gui.inc"
INCLUDE "GAME.inc"

GRID_WIDTH EQU 39
GRID_HEIGHT EQU 24

;=============================================================================
; CODE
;=============================================================================
CODESEG

; Procedure to exit the program (triggered by ESC).
; GAME_STATE is checked on every gameloop. (if 0 -> game was exited)
PROC exit
	USES eax
	;Change the state of the game to zero to clarify
	;that the game is over and the snake (player) died.
    mov [GAME_STATE], 0
	mov eax, [SCORE]
	cmp eax, [HIGH_SCORE]
	jl @@endExit
	mov [HIGH_SCORE], eax
	
	@@endExit:
	mov [SCORE], 0
    ret
ENDP exit

; Procedure to initialize a new game
PROC initGameState
    ;Put the program's state to 1.
	mov [GAME_STATE], 1
	;This is the gamecounter that gets higher after every gameloop.
	mov [GAME_COUNTER_CURRENT], 0
	;When the gamecounter equals the value of this variable, the whole game gets updated.
	mov [GAME_COUNTER_MAX], 10
	
	mov [SCORE], 0
	
	; SNAKE_X/Y is an array of consecutive double words containing the grid position of a snake piece.
	; Elements at the same index form a tuple which forms the actual position
	mov [SNAKE_X], 4
	mov [SNAKE_Y], 8

	; Initial direction of the snake is positive on the x-axis (to the right).
	mov [DELTA_X], 1
    mov [DELTA_Y], 0
	; Initial length of the snake at the beginning of the game
	mov [SNAKE_LENGTH], 3
	
	mov eax, [SNAKE_LENGTH]
	;Loop to draw the initial snake in the game
	@@loopDrawSnake:
		call moveAndDrawSnake
		dec eax
		cmp eax, 0
		jg @@loopDrawSnake
	
	; Counter for keeping track how much time (gameloops) the apple has been on the grid.
	mov [APPLE_TIME], 0
	; Max amount of time (gameloops) the apple can stay in one spot before getting assigned a new position.
    mov [APPLE_LIFE], 40
	
	; Amount of points added to the score for eating an apple.
	mov [APPLE_POINT], 100
	
	; Generates a random position for the apple and places
	call placeRandomApple
	;Draw the apple on the newly generated position.
	call drawApple, [APPLE_X], [APPLE_Y]
	
	;Wallblocks are grouped in segments, this variable defines the length of these segments.
	mov [LENGTH_OF_WALL_SEGMENTS], 5
	;This variable specifies if the wall will be drawn vertically or horizontally.
	mov [DIRECTION_OF_SEGMENT], 0
	;Counts the number of wallblocks generated.
	mov [WALL_COUNTER], 0
	;Ths variable defines the minimum distance a wall must
	;have from the snakehead if the wall is on the same
	;height-position (y) as the snakehead.
	mov [MIN_X_SPACE_WALL_SNAKE], 8
	
	;This procedure generates a random number of walls.
	call generateWalls
	call drawScore, [HIGH_SCORE], 1
	
	ret
ENDP initGameState

; Handles the snake movement
PROC moveAndDrawSnake
    USES eax, ebx, ecx, edx
	;The next position for the snake head gets calculated.
    mov eax, [SNAKE_X]
    add eax, [DELTA_X]
    mov ebx, [SNAKE_Y]
    add ebx, [DELTA_Y]

    @@leftBound:
    cmp eax, -1
    jne @@rightBound
    mov eax, GRID_WIDTH

    @@rightBound:
    mov ecx, GRID_WIDTH
    inc ecx
    cmp eax, ecx
    jne @@upBound
    mov eax, 0

    @@upBound:
	cmp ebx, 2 ;upper bound
    jne @@downBound
    mov ebx, GRID_HEIGHT

    @@downBound:
    mov ecx, GRID_HEIGHT
    inc ecx
    cmp ebx, ecx
    jne @@inBounds
    mov ebx, 3 ; return snake at top bound

	;Erase the last snake-segment and draw a new snake-segment on the new coordinate of the snake head.
    @@inBounds:
    call waitVBlank
    mov ecx, [SNAKE_LENGTH]
    dec ecx
    call drawEmpty, [SNAKE_X+ecx*4], [SNAKE_Y+ecx*4]
    call drawSnake, eax, ebx
    
	mov edx, 0
	;This loop updates all the positions of all snakesegments to the new position of the snake.
    @@moveSnakePieces:
		cmp edx, [SNAKE_LENGTH]
		je @@end
		mov ecx, [SNAKE_X+edx*4]
		mov  [SNAKE_X+edx*4], eax
		mov eax, ecx
		mov ecx, [SNAKE_Y+edx*4]
		mov [SNAKE_Y+edx*4], ebx
		mov ebx, ecx
		inc edx
		jmp @@moveSnakePieces

    @@end:
    ret
ENDP moveAndDrawSnake

;This procedure calculates the values that have to be substracted or added
;to the old position of the snakehead to form his new position.
PROC changeDelta
    ARG @@new_x :dword, \
			@@new_y :dword
    USES eax

    @@deltaX:
    mov eax, [@@new_x]
    add eax, [DELTA_X]
    cmp eax, 0
    je @@deltaY
    mov eax, [@@new_x]
    mov [DELTA_X], eax

    @@deltaY:
    mov eax, [@@new_y]
    add eax, [DELTA_Y]
    cmp eax, 0
    je @@end
    mov eax, [@@new_y]
    mov [DELTA_Y], eax

    @@end:
    ret
ENDP changeDelta

; Checks if an apple was eaten by the head of the snake.
; If so the score is increased, a new apple placed and a sound played.
PROC checkEat
	USES ebx, ecx
	
	mov ecx, [SNAKE_X]
	mov ebx, [APPLE_X]
	cmp ecx, ebx
	jne @@noAppleCatch
	mov ecx, [SNAKE_Y]
	mov ebx, [APPLE_Y]
	cmp ecx, ebx
	jne @@noAppleCatch

    @@snakeCatchesApple:
	mov eax, [DIFFICULTY]
	mov ebx, 10
	mul ebx
	mov ecx, [APPLE_POINT]
	sub ecx, eax
	
	add [SCORE], ecx
	call beepSound
	call placeRandomApple
	inc [SNAKE_LENGTH]

    @@noAppleCatch:
	ret
ENDP checkEat

;This procedure calculates valid random x -and y-coordinates and resets the apple_time to 0.
PROC placeRandomApple
    USES ebx, edx

	@@calculateNewCoordinate:
		call rand
		mov ebx, GRID_WIDTH
		xor edx, edx
		div ebx
		mov [APPLE_X], edx
		call rand
		mov ebx, GRID_HEIGHT
		xor edx, edx
		div ebx
		mov [APPLE_Y], edx
		mov ebx, 3
		cmp [APPLE_Y], ebx
		jl @@calculateNewCoordinate
	
	mov ebx, -1
	@@checkSnakeX:
		inc ebx
		cmp ebx, [SNAKE_LENGTH]
		je @@wallsCheck
		mov edx, [SNAKE_X + ebx * 4]
		cmp edx, [APPLE_X]
		jne @@checkSnakeX
	
	mov ebx, -1
	@@checkSnakeY:
		inc ebx
		cmp ebx, [SNAKE_LENGTH]
		je @@wallsCheck
		mov edx, [SNAKE_Y + ebx * 4]
		cmp edx, [APPLE_Y]
		jne @@checkSnakeY
		
		jmp @@calculateNewCoordinate
	
	@@wallsCheck:
	mov ebx, -1
	@@wallsLoop:
		inc ebx
		cmp ebx, [NUMBER_OF_WALLS]
		je @@endProc
		mov ecx, [WALL_X + ebx*4]
		mov edx, [WALL_Y + ebx*4]
		cmp ecx, [APPLE_X]
		jne @@wallsLoop
		cmp edx, [APPLE_Y]
		je @@calculateNewCoordinate
		jne @@wallsLoop
	
	@@endProc:
	mov [APPLE_TIME], 0
	
	ret
ENDP placeRandomApple

;This procedure generates walls for the new game session
;and is only called at initialisation.
PROC generateWalls
	USES eax, ebx, ecx, edx 

	;This label creates a new segment
	@@createSegment:
		;Generate a random X-coordinate
		call rand
		;Make sure the randome x-coordinate isn't bigger than the gridwidth. 
		;To make sure that the wall wouldn't get out of bounds in case of a horizontal wallsegment, 
		; the maximum value of the coordinate is subtracted by the maximum segment length.
		mov ebx, GRID_WIDTH
		sub ebx, [LENGTH_OF_WALL_SEGMENTS]
		xor edx, edx
		div ebx
		
		;Change the x-wall-coordinate on offset eax*4 in variable
		;WALL_X to this new x-coordinate.
		mov eax, [WALL_COUNTER]
		mov [WALL_X + eax*4 ], edx

		;Generate a random Y-coordinate	
		call rand
		mov ebx, GRID_HEIGHT
		sub ebx, [LENGTH_OF_WALL_SEGMENTS]
		xor edx, edx
		div ebx
		cmp edx, 4
		jl @@createSegment
		;Change the y-wall-coordinate on offset eax*4 in variable
		;WALL_Y to this new y-coordinate.
		mov eax, [WALL_COUNTER]
		mov [WALL_Y + eax*4], edx

		cmp eax, [NUMBER_OF_WALLS]
		je @@en
		mov ecx, [WALL_X + eax*4]
		
		;Change the direction of the segment
		;(horizontal to vertical or the other way around)
		cmp [DIRECTION_OF_SEGMENT], 0
		je @@setTo1
		mov [DIRECTION_OF_SEGMENT], 0
		jmp @@checkHorizontalWall

		@@setTo1:
		mov [DIRECTION_OF_SEGMENT], 1

		@@checkVerticalWall:
		;Experimental procedure to make sure a wall doesn't spawn in front of the snake
		;available variables: eax & ebx
		mov ebx, ecx
		sub ebx, [SNAKE_X]
		cmp ebx, [MIN_X_SPACE_WALL_SNAKE]
		jg @@continue
		
		;check that -if the wall is vertical-
		;it doesn't intersect with the snake.
		@@checkY:
		mov ebx, edx
		sub ebx, [SNAKE_Y]
		cmp ebx, 1
		jg @@continue
		mov eax, [LENGTH_OF_WALL_SEGMENTS]
		neg eax
		cmp ebx, eax
		jl @@continue
		jmp @@createSegment
		
		;check that -if the wall is horizontal-
		;it doesn't get drawn in the snake.
		@@checkHorizontalWall:
		mov ebx, [SNAKE_X]
		sub ebx, ecx
		mov eax, [SNAKE_LENGTH]
		neg eax
		cmp ebx, eax
		jl @@continue
		mov ebx, [SNAKE_Y]
		cmp ebx, edx
		je @@createSegment

	@@continue:
	;Counter for the number of blocks created for
	;the new segment
	mov ebx, 0
	@@segmentLoop:
		cmp ebx, [LENGTH_OF_WALL_SEGMENTS]
		je @@createSegment
		mov eax, [WALL_COUNTER]
		cmp eax, [NUMBER_OF_WALLS]

		mov ecx, [WALL_X + eax*4]
		mov edx, [WALL_Y + eax*4]
		
		;Calculate the position of the next
		;wallblock if it the segment is horizontal.
		@@hor:
		cmp [DIRECTION_OF_SEGMENT], 0
		jne @@vert
		inc ecx
		jmp @@checkSnake

		;Calculate the position of the next
		;wallblock if it the segment is vertical.
		@@vert:
		cmp [DIRECTION_OF_SEGMENT], 1
		inc edx
		
		;make sure the position
		;of the next wallblock doesn't interact
		;with the snake.
		@@checkSnake:
		push ebx
		mov eax, -1
		@@snakeloop:
		inc eax
		cmp eax, [SNAKE_LENGTH]
		je @@changeCoordinates
		mov ebx, [SNAKE_X + eax*4]
		cmp ebx, ecx
		jne @@changeCoordinates
		mov ebx, [SNAKE_Y + eax*4]
		cmp ebx, edx 
		je @@createSegment

		;After all these tests, you can change the position.
		@@changeCoordinates:
		pop ebx
		mov eax, [WALL_COUNTER]
		cmp eax, [NUMBER_OF_WALLS]
		je @@en
		inc ebx

		inc eax
		mov [WALL_COUNTER], eax
		mov [WALL_X + eax*4], ecx
		mov [WALL_Y + eax*4], edx
		
		jmp @@segmentLoop

	;put the wallcounter to zero agai.
	@@en:
	mov [WALL_COUNTER], 0
	mov eax, 0
	ret
ENDP generateWalls

;Procedure to change the number of walls in the game session.
;Handy to change the difficulty of the game by adding or
;subtracting walls.
PROC noOfWalls
	USES eax
		ARG  @@new :dword
	mov eax, [@@new]
	mov [NUMBER_OF_WALLS], eax

	ret	
ENDP noOfWalls

;Changes the difficulty of the game by the given new difficulty and updates the amount of walls to generate
PROC changeDifficulty
	ARG  @@new :dword
		USES eax, ebx
	
	mov eax, [@@new]
	mov [DIFFICULTY], eax
	mov ebx, 10
	mul ebx
	mov [NUMBER_OF_WALLS], eax
	
    ret
ENDP changeDifficulty

PROC handleUserInput
	USES eax

	mov ah, 01h ; function 01h (test key pressed)
	int 16h		; call keyboard BIOS
	jz @@noKeyPressed	
	mov ah, 00h
	int 16h
	
	;process key code here (scancode in AH, ascii code in AL)
    cmp ah, 01 ; scancode for ESCAPE key
    jne @@gameState
    call exit
    jmp @@noKeyPressed
	
	@@gameState:
	
	@@n0:
	cmp ah, 25 ;scandode for 'p' 
	jne @@n1
	call pauseGame
	jmp @@noKeyPressed

	@@n1:
		cmp ah, 77	; arrow right 
		jne @@n2
		call changeDelta, 1, 0
		jmp @@noKeyPressed

	@@n2:
		cmp ah, 75	; arrow left
		jne @@n3
		call changeDelta, -1, 0
		jmp @@noKeyPressed

	@@n3:
		cmp ah, 80	; arrow down
		jne @@n4
		call changeDelta, 0, 1
		jmp @@noKeyPressed

	@@n4:
		cmp ah, 72	; arrow up
		jne @@noKeyPressed
		call changeDelta, 0, -1
		jmp @@noKeyPressed

	@@noKeyPressed:
	ret
ENDP handleUserInput

PROC pauseGame
	; 0 -> pause, 1 -> unpause
	call drawPause, offset 0

	@@pauseLoop:
		call waitVBlank

		mov ah, 01h ; function 01h (test key pressed)
		int 16h		; call keyboard BIOS
		jz @@pauseLoop
		
		; Get scan code
		mov ah, 00h
		int 16h
		
		@@pauseKey:
		cmp ah, 25
		jne @@escapeKey
		jmp @@endPause
		
		@@escapeKey:
		cmp ah, 01
		jne @@pauseLoop
		call exit
	
	@@endPause:
	; remove pause text
	call drawPause, offset 1
	
	ret
ENDP pauseGame

;This procedure draws every element of the game:
; the snake, the apple, the walls, the score, the line,...
PROC drawAll
	USES eax, ebx, ecx
	
    call waitVBlank
    call drawApple, [APPLE_X], [APPLE_Y]
	call drawScore, [SCORE], 0
	call drawHorizontalLine, 2
	mov [WALL_COUNTER], 0
	
	mov eax, 0
	@@DrawWalls:
		cmp eax, [NUMBER_OF_WALLS]
		je @@end
		mov ebx, [WALL_X + eax*4]
		mov ecx, [WALL_Y + eax*4]
		call drawWall, ebx, ecx
		inc eax
		jmp @@DrawWalls
	
	@@end:
    ret
ENDP drawAll

;This procedure gets called to update the game:
;check if there has been a collision between the snake and
;the wall or just the snake itself.
PROC updateGame
	USES eax, ebx, ecx, edx
	
	inc [GAME_COUNTER_CURRENT]
	mov eax, [GAME_COUNTER_CURRENT]
	mov ebx, [GAME_COUNTER_MAX]
	sub ebx, [DIFFICULTY]
	cmp eax, ebx
	jle @@endUpdate
	
	@@update:
	mov  [GAME_COUNTER_CURRENT], 0
		
	; moves all snakes pieces in the last pressed direction + draws them
	call moveAndDrawSnake
	; check if the snake head eats an apple
	call checkEat
		
	mov eax, 1
	@@snakeCrash:
		cmp eax, [SNAKE_LENGTH]
		je @@checkWallCrash
		mov ebx, [SNAKE_X]
		mov ecx, [SNAKE_X+eax*4]
		cmp ebx, ecx
		jne @@ReloopSnakeCrash
		mov ebx, [SNAKE_Y]
		mov ecx, [SNAKE_Y+eax*4]
		cmp ebx, ecx
		jne @@ReloopSnakeCrash
		call exit

		@@ReloopSnakeCrash:
		inc eax
		jmp @@snakeCrash
		
	@@checkWallCrash:
	mov eax, 0
	@@WallCrash:
		cmp eax, [NUMBER_OF_WALLS]
		je @@checkAppleTime
		mov ebx, [SNAKE_X]
		mov ecx, [WALL_X+eax*4]
		cmp ebx, ecx
		jne @@ReloopWallCrash
		mov ebx, [SNAKE_Y]
		mov ecx, [WALL_Y+eax*4]
		cmp ebx, ecx
		jne @@ReloopWallCrash
		call exit

		@@ReloopWallCrash:
		inc eax
		jmp @@WallCrash
			
	@@checkAppleTime:
	mov eax, [APPLE_TIME]
	cmp eax, [APPLE_LIFE]
	je @@timeElapsed
	mov eax, [APPLE_TIME]
	inc eax
	mov [APPLE_TIME], eax
	jmp  @@endUpdate
	
	@@timeElapsed:
    call drawEmpty, [APPLE_X], [APPLE_Y]
    call placeRandomApple
	
	@@endUpdate:
	ret
ENDP updateGame

;This procedure gets called to start the game.
PROC runGame
	ARG  @@difficulty :dword
	USES eax
	
	call changeDifficulty, [@@difficulty]
	call initGameState

	@@gameLoop:
		call handleUserInput
		cmp [GAME_STATE], 0 ; Exit (by escape) was triggered
		je @@endGame
		call updateGame
		call drawAll
		cmp [GAME_STATE], 1
		je @@gameLoop
	
	@@gameOver:
	call drawGameOver
	call clearScreen
	call drawAll
	
	@@endGame:
	call clearScreen

	ret
ENDP runGame
	
;=============================================================================
; DATA
;=============================================================================
DATASEG

	GAME_STATE dd 1 ;0 = game is over - return to menu
								;1 = game
								
UDATASEG
	
	;These variables help time the refresh rate.
	GAME_COUNTER_CURRENT dd ?
	GAME_COUNTER_MAX dd ?
	
	;Variables about the snake like its position (x & y) and its length.
	SNAKE_X dd  40*25 dup(?)
	SNAKE_Y dd 40*25 dup(?)
	SNAKE_LENGTH dd ?
	
	;Represent the next direction chosen
	DELTA_X dd ?
	DELTA_Y dd ?
	
	;Apple-variables: its position and the points
	;the player gets for eating it.
	APPLE_X dd ?
	APPLE_Y dd ?
	APPLE_POINT dd ?
	
	APPLE_LIFE dd ?
	APPLE_TIME dd ?
	
	DIFFICULTY dd ? ;the difficulties for the game range from 0 to 5.
	SCORE dd ?
	HIGH_SCORE dd ? ;zero at the initialisation of the game.
								 ;The highest score ever played will be saved in here.
	
	WALL_X dd 40*25 dup(?)
	WALL_Y dd 40*25 dup(?)
	NUMBER_OF_WALLS dd ?
	LENGTH_OF_WALL_SEGMENTS dd ?
	DIRECTION_OF_SEGMENT dd ?
	WALL_COUNTER dd ?
	MIN_X_SPACE_WALL_SNAKE dd ?
	
END


