.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																				;LIBRARII SI FUNCTII
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc												

includelib canvas.lib
extern BeginDrawing: proc

public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																			  ;VARIABILE SI CONSTANTE

.data
window_title DB "Bomberman",0
area_width EQU 950
area_height EQU 950
area DD 0

counter DD 0 ; numara evenimentele de tip timer
counterBomb DD 0 ;numara timpul pana cand bomba explodeaza
counterExplosion DD 0 ;numara timpul scris pana la disparitia exploziei
counterEnemy DD 0	;pentru deplasarea inamicului

arg1 EQU 8
arg2 EQU 12														
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

button_up_x EQU area_width - 100	;Sageata Sus
button_up_y EQU area_height - 150

button_left_x EQU area_width - 150	;Sageata Stanga
button_left_y EQU area_height - 100

button_down_x EQU area_width - 100	;Sageata Jos
button_down_y EQU area_height - 50

button_right_x EQU area_width - 50	;Sageata Dreapta
button_right_y EQU area_height - 100

button_bomb_x EQU area_width - 100	;Buton Bomba
button_bomb_y EQU area_height - 100

bomberman_x DD 50		;coordonate Bomberman
bomberman_y DD 50

bomb_check DB 0	;verifica daca se poate plasa bomba
bomb_x DD 0	;coord bomba
bomb_y DD 0
explosion_check DD 0 ;verifica daca exista o explozie(pentru stergere)

enemy_x DD area_width-100,area_width-500	;coord inamic
enemy_y DD area_height-200,area_width-500
enemy_alive DD 1, 1	;verifica daca inamicul traieste

game_over_check DD 0 ; verifica daca jucatorul a pierdut

aux DD 0	;variabile auxiliare
aux1 DD 0
aux2 DD 0
random_aux DD 371
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																					;FUNCTIE CUVINTE
.code

; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width														
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0A7A6A5h
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																						   ;MACROURI
; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

; deseneaza o linie orizontala
line_horizontal macro x, y, len, color
local bucla_linie
	mov eax, y; EAX = y
	mov ebx, area_width
	mul ebx; EAX = y*area_width
	add EAX, x; EAX = y*area_width+x
	shl eax, 2; EAX = (y*area_width+x)*4
	add EAX, area
	
	mov ECX, len
bucla_linie:
	mov dword ptr [eax], color
	add EAX,4
loop bucla_linie
endm

;deseneaza o linie verticala
line_vertical macro x, y, len, color									
local bucla_line
	mov eax, y; EAX = y
	mov ebx, area_width
	mul ebx; EAX = y*area_width
	add EAX, x; EAX = y*area_width+x
	shl eax, 2; EAX = (y*area_width+x)*4
	add EAX, area
	
	mov ECX, len
bucla_line:
	mov dword ptr [eax], color
	add EAX,area_width*4
loop bucla_line
endm

;deseneaza un patrat(folosind liniile anterioare)
draw_square macro x,y, color
local square_loop
	mov EDI, y
	mov ESI, 0
	
	square_loop:
	line_horizontal x,EDI, 50, color
	inc ESI
	inc EDI
	cmp ESI, 50
	jne square_loop
endm

;macro ce deseneaza sageti
draw_arrow macro dir,x,y,color
local up, left, down, right, finish
	mov aux1, dir
	mov ESI, 50
	mov EDI, x
	mov aux, y
	
	cmp aux1, 1
	je up
	cmp aux1, 2
	je left
	cmp aux1, 3
	je down
	cmp aux1, 4
	je right
	
	down:
	line_horizontal EDI, aux, ESI, color
	inc EDI
	sub ESI, 2
	inc aux
	cmp ESI, 0
	jne down
	jmp finish
	
	up:
	line_horizontal EDI, aux, ESI, color
	inc EDI
	sub ESI, 2
	dec aux
	cmp ESI, 0
	jne up
	jmp finish
	
	left:
	line_vertical EDI, aux, ESI, color
	dec EDI
	sub ESI, 2
	inc aux
	cmp ESI, 0
	jne left
	jmp finish
	
	right:
	line_vertical EDI, aux, ESI, color
	inc EDI
	sub ESI, 2
	inc aux
	cmp ESI, 0
	jne right
	
	finish:
endm

;macro ce verifica apasarea butoanelor de directie
press_button macro x,y,button_x,button_y, diff_x, diff_y
local button_fail, bomb_case, defeat
	mov EAX, x
	cmp EAX, button_x
	jl button_fail
	cmp EAX, button_x+50
	jg button_fail
	mov EAX, y
	cmp EAX, button_y
	jl button_fail
	cmp EAX, button_y+50
	jg button_fail
	
	calculate_pozition bomberman_x,bomberman_y,diff_x, diff_y
	cmp dword ptr [EAX], 0FF69B4h
	je defeat
	
	calculate_pozition bomberman_x,bomberman_y,diff_x, diff_y
	cmp dword ptr [EAX], 0FFFFFFh
	jne button_fail
	
	calculate_pozition bomberman_x,bomberman_y,diff_x, diff_y
	cmp dword ptr [EAX], 0h
	je bomb_case
	
	draw_square bomberman_x, bomberman_y, 0FFFFFFh
	bomb_case:
	add bomberman_y, diff_y
	add bomberman_x, diff_x
	draw_square bomberman_x, bomberman_y, 0FF0000h
	jmp button_fail
	
	defeat:
	game_over
	
	button_fail:
endm

;macro ce verifica apasarea butonului bomba
press_button_bomb macro x,y
local button_fail
	mov EAX, x
	cmp EAX, button_bomb_x
	jl button_fail
	cmp EAX, button_bomb_x+50
	jg button_fail
	mov EAX, y
	cmp EAX, button_bomb_y
	jl button_fail
	cmp EAX, button_bomb_y+50
	jg button_fail
	
	cmp bomb_check, 0
	jne button_fail
	
	draw_square bomberman_x, bomberman_y, 0h
	mov bomb_check,1 
	mov EAX, bomberman_x
	mov bomb_x, EAX
	mov EAX, bomberman_y
	mov bomb_y, EAX
	
	button_fail:
endm

;macro ce calculeaza pozitia in functie de coordonate
calculate_pozition macro x,y,diff_x,diff_y
	mov EAX, y; EAX = y
	add EAX, diff_y
	mov EBX, area_width
	mul EBX; EAX = y*area_width 
	add EAX, x; EAX = y*area_width+x
	add EAX, diff_x
	shl EAX, 2; EAX = (y*area_width+x)*4
	add EAX, area
endm

;macro in cazul in care jucatorul pierde
game_over macro
	mov enemy_alive,0
	mov bomb_check,0 

	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 0A7A6A5h ;coloram toata harta gri
	push area
	call memset
	add esp, 12
	
	make_text_macro 'D', area, area_width/2-25, area_height/2
	make_text_macro 'E', area, area_width/2-15, area_height/2
	make_text_macro 'F', area, area_width/2-5, area_height/2
	make_text_macro 'E', area, area_width/2+5, area_height/2
	make_text_macro 'A', area, area_width/2+15, area_height/2
	make_text_macro 'T', area, area_width/2+25, area_height/2
	
	mov game_over_check, 1
	
	
endm

;macro pentru zonele afectate de explozie
explosion_radius macro x, y, diff_x, diff_y, color
local unbreakable, explosion_loop, breakable, crate, defeat, enemy
	mov ESI, bomb_x
	mov aux1, ESI
	mov ESI, bomb_y
	mov aux2, ESI
	
	mov aux, 0
	explosion_loop:
	calculate_pozition x,y, diff_x, diff_y
	cmp dword ptr [EAX], 0FF69B4h
	je enemy
	cmp dword ptr [EAX], 0FF0000h
	je defeat
	cmp dword ptr [EAX], 0A0522Dh
	je crate
	cmp dword ptr [EAX], 0F59B00h
	je breakable
	cmp dword ptr [EAX], 0FFFFFFh
	jne unbreakable
	breakable:
	add x, diff_x
	add y, diff_y
	draw_square x, y, color
	inc aux
	cmp aux, 4
	jne explosion_loop
	jmp unbreakable
	
	defeat:
	game_over
	jmp unbreakable
	
	crate:
	add x, diff_x
	add y, diff_y
	draw_square x, y, 0FFFFFFh
	jmp unbreakable
	
	enemy:
	add x, diff_x
	add y, diff_y
	draw_square x, y, 0FFFFFFh
	mov enemy_alive,0
	
	unbreakable:
	
	mov ESI, aux1
	mov bomb_x, ESI
	mov ESI, aux2
	mov bomb_y,ESI
	
endm

;macro-ul de control al exploziei
explosion macro x,y, color
local no_defeat, finish
	
	explosion_radius x, y, 50, 0, color
	explosion_radius x, y, -50, 0, color
	explosion_radius x, y, 0, -50, color
	explosion_radius x, y, 0, 50, color
	
	mov EAX, bomberman_x
	cmp bomb_x, EAX
	jne no_defeat
	mov EAX, bomberman_y
	cmp bomb_y, EAX
	jne no_defeat
	game_over
	jmp finish
	
	no_defeat:
	calculate_pozition bomb_x,bomb_y,0,0
	cmp dword ptr [eax], 0FFFFFFh
	jne finish
	draw_square bomb_x,bomb_y, color
	finish:
endm

;macro ce determina functionarea bombei
bomb_mechanism macro 
	cmp explosion_check,1
	je explosion_timer
	
	cmp bomb_check,1
	jne no_bomb
	
	;flick
	calculate_pozition bomb_x,bomb_y, 0, 0
	cmp dword ptr [EAX], 0h
	jne black
	draw_square bomb_x, bomb_y, 0F59B00h
	jmp off
	black:
	draw_square bomb_x, bomb_y, 0h
	off:
	
	cmp counterBomb, 10
	jne no_explosion
	
	mov counterBomb, 0
	
	mov explosion_check,1
	;explozia
	explosion bomb_x, bomb_y, 0F59B00h
	
	explosion_timer:
	inc counterExplosion
	cmp counterExplosion, 5
	jne no_bomb
	explosion bomb_x, bomb_y, 0FFFFFFh
	draw_square bomb_x,bomb_y, 0FFFFFFh
	mov counterExplosion, 0
	mov explosion_check,0
	mov bomb_check, 0
	
	jmp no_bomb
	
	no_explosion:
	inc counterBomb
	
	no_bomb:
endm

;macro ce determina o valoare aleatoare de (0-3)
random macro
	mov EAX, random_aux
	mul bomberman_y
	add EAX, bomberman_x
	mov aux1,773
	mov EDX, 0
	div aux1
	mov random_aux, EDX
	
	mov EAX, random_aux
	mov EBX,4
	mov EDX,0
	div EBX
endm

;macro ce determina miscarile inamicului
enemy_movement macro
local up,left,down,right, skip, defeat, reroll, no_movement, reset
	inc counterEnemy
	cmp counterEnemy, 5
	jne no_movement
	
	reroll:	
	random
	
	cmp EDX,0
	je up
	cmp EDX, 1
	je left
	cmp EDX, 2
	je down
	cmp EDX, 3
	je right
	
	up:
	mov aux, 0
	mov aux1, -50
	jmp skip
	
	left:
	mov aux, -50
	mov aux1, 0
	jmp skip
	
	right:
	mov aux, 50
	mov aux1, 0
	jmp skip
	
	down:
	mov aux, 0
	mov aux1, 50
	jmp skip
	
	skip:
	mov counterEnemy,0
	calculate_pozition enemy_x,enemy_y,aux, aux1
	cmp dword ptr [EAX], 0FF0000h
	je defeat
	
	calculate_pozition enemy_x,enemy_y,aux,aux1
	cmp dword ptr [EAX], 0FFFFFFh
	jne reroll
	
	reset:
	draw_square enemy_x, enemy_y, 0FFFFFFh
	
	mov EAX, aux
	add enemy_x, EAX
	mov EAX, aux1
	add enemy_y, EAX
	draw_square enemy_x, enemy_y, 0FF69B4h
	jmp no_movement
	
	defeat:
	game_over
	
	no_movement:
	
endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																							;PROCEDURI

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y

draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click ;s-a apasat pe ecran
	cmp eax, 2
	jz evt_timer ;nu s-a efectuat click pe nimic
	
	;intializeaza zona de joc
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 0A7A6A5h ;coloram toata harta gri
	push area
	call memset
	add esp, 12
	
	mov ESI, 50
	
	;trasam linii albe pe verticala si orizontala 
	horizontal_white:
	line_horizontal 0, ESI, area_width*50, 0FFFFFFh	
	add ESI, 100
	cmp ESI, area_height - 50
	jl horizontal_white
	
	mov EDI, 50
	
	vertical_white2:
	mov ESI, area_height-51
	vertical_white1:
	line_horizontal EDI, ESI, 50, 0FFFFFFh
	dec ESI
	cmp ESI, 50
	jne vertical_white1
	add EDI, 100
	cmp EDI, area_width-50
	jl vertical_white2
	
	mov ESI, area_height-50
	
	;completam marginile
	left_border:
	line_horizontal 0, ESI, 50, 0A7A6A5h
	dec ESI
	cmp ESI, 0
	jne left_border
	
	mov ESI, area_height-50
	
	right_border:
	line_horizontal area_height-50, ESI, 50, 0A7A6A5h	
	dec ESI
	cmp ESI, 0
	jne right_border
	
	;plasam jucatorul si inamicul
	draw_square 50, 50, 0FF0000h
	draw_square area_width-100, area_height-200, 0FF69B4h
	
	;initializam zona butoanelor de directie
	draw_square area_width-100, area_height-100, 0A7A6A5h 
	draw_square area_width-100, area_height-150, 0A7A6A5h
	draw_square area_width-150, area_height-100, 0A7A6A5h
	
	draw_arrow 1, area_width-100, area_height-110, 0h
	draw_arrow 3, area_width-100, area_height-40, 0h
	draw_arrow 2, area_width-110, area_height-100, 0h
	draw_arrow 4, area_width-40, area_height-100, 0h
	
	make_text_macro 'B', area, area_width-96, area_height-86
	make_text_macro 'O', area, area_width-86, area_height-86
	make_text_macro 'M', area, area_width-76, area_height-86
	make_text_macro 'B', area, area_width-66, area_height-86
	
	;punem cateva cutii
	draw_square 150, 500, 0A0522Dh
	draw_square 250, 200, 0A0522Dh
	draw_square 200, 250, 0A0522Dh
	draw_square 500, 350, 0A0522Dh
	draw_square 350, 50, 0A0522Dh
	draw_square 400, 650, 0A0522Dh
	draw_square 700, 650, 0A0522Dh
	draw_square 500, 650, 0A0522Dh
	draw_square 500, 850, 0A0522Dh
	draw_square 700, 250, 0A0522Dh
	draw_square 100, 450, 0A0522Dh
	
	jmp final_draw
	
evt_click:
	;verificam apasarea butoanelor
	cmp game_over_check,1
	je final_draw
	press_button[ebp+arg2], [ebp+arg3], button_up_x, button_up_y, 0, -50
	press_button [ebp+arg2], [ebp+arg3], button_left_x, button_left_y, -50, 0
	press_button [ebp+arg2], [ebp+arg3], button_down_x, button_down_y, 0, 50
	press_button [ebp+arg2], [ebp+arg3], button_right_x, button_right_y, 50, 0
	press_button_bomb [ebp+arg2], [ebp+arg3]
	
evt_timer:
	;verificam daca jucatorul a pierdut
	cmp game_over_check,1
	je final_draw
	
	;verificam bomba
	inc counter
	bomb_mechanism
	
	;verificam miscarile inamicului
	cmp enemy_alive,1
	jne final_draw
	enemy_movement
	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
																					           ;MAIN
start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	
	;apelam functia BEGIN DRAWING
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
