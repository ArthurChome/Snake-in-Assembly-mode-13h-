;=============================================================================
; 32-bit Assembly Snake  --  GUI file
;
; For use under DMPI 0.9 protected mode.
;=============================================================================

GLOBAL 	setupVideo:PROC, \
				unsetupVideo:PROC, \
				waitVBlank:PROC, \
				clearScreen:PROC, \
				drawSprite:PROC, \
				drawEmpty:PROC, \
				drawSnake:PROC, \
				drawApple:PROC, \
				drawScore: PROC, \
				drawPause: PROC,  \
				drawGameOver: PROC, \
				drawString:PROC, \
				drawMenu: PROC, \
				drawHelp: PROC, \
				drawChoose: PROC, \
				drawUnChoose: PROC, \
				drawDifficulty: PROC, \
				drawArrow: PROC,  \
				drawWall: PROC,  \
				drawNumber: PROC, \
				drawHorizontalLine: PROC, \
				beepSound: PROC

