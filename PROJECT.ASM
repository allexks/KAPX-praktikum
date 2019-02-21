; Alexander Ignatov 62136
MODEL SMALL

.STACK  100H

.DATA
title_text      DB      "                   Yalishanda's File Encrypter and Decrypter                     "
len_title       EQU     $ - title_text

title_color     EQU     0CH
buttons_color   EQU     47H
buttons_flash   EQU     0CFH
statusbar_color EQU     70H
unsaved_color   EQU     74H

file_pointer    DW      ?
file_content    DB      201 dup(00)
max_bytes_read  EQU     200
file_read_size  DW      0000

filepath        DB      60H dup (00)
max_filepath_ln EQU     $ - filepath - 1

encryption_key  EQU     42

encryption_cnt  DB      00
is_saved        DB      00


menu_encrypt    DB      '1'
menu_decrypt    DB      '2'
menu_save       DB      'S'
menu_save_other DB      'X'
menu_quit       DB      'ESC'
len_menu_quit   EQU     $ - menu_quit

filepath_prompt DB      'Please input filepath: $'
curr_file_str   DB      'Current file: $'
encrypt_str     DB      'Encrypt$'
decrypt_str     DB      'Decrypt$'
save_str        DB      'Save$'
save_other_str  DB      'Save as...$'
quit_str        DB      'Quit$'
new_line        DB      0DH, 0AH, '$'
error_open_msg  DB      'Could not open file.', 0DH, 0AH, '$'
error_msg       DB      'Sorry, an error occurred. (##)', 0DH, 0AH, '$'
.CODE
MAIN:
        MOV AX, @DATA
        MOV DS, AX

        call clear_screen
        call input_filepath
        call open_file
        call read_file

        main_loop:
                call clear_screen
                call display_buttons
                call refresh_content

                call char_input_without_echo
                CMP AL, menu_encrypt
                je on_press_encrypt
                CMP AL, menu_decrypt
                je on_press_decrypt
                CMP AL, menu_save
                je on_press_save
                CMP AL, 's'
                je on_press_save
                CMP AL, menu_save_other
                je on_press_save_as
                CMP AL, 'x'
                je on_press_save_as
                CMP AL, 1BH     ; ESC
                jne main_loop

        call close_file

        jmp exit

; ---------- MENU PROCEDURES -------------
on_press_encrypt:
        CMP encryption_cnt, 3
        jge main_loop
        MOV SI, 1
        INC encryption_cnt
        INC is_saved
        jmp change_string

on_press_decrypt:
        CMP encryption_cnt, -3
        jle main_loop
        MOV SI, 2
        DEC encryption_cnt
        DEC is_saved
        jmp change_string

on_press_save:
        call close_file
        call new_file   ; TRUNCATES FILE

        MOV AH, 40H
        MOV BX, file_pointer
        MOV CX, file_read_size
        LEA DX, file_content
        INT 21H

        MOV BYTE PTR is_saved, 00
        jmp main_loop

on_press_save_as:
        MOV BYTE PTR encryption_cnt, 00
        call close_file
        call clear_screen
        call input_filepath
        call new_file
        jmp on_press_save

; ---------- HELPER FUNCTIONS ------------
move_cursor:
        ; DH:DL = row:col
        MOV AH, 02H
        INT 10H
        RET

get_cursor_pos:
        MOV AH, 03H
        INT 10H
        RET ; DH:DL = row:col


cout_color_char:
        ; AL = char
        ; CX = number of times
        ; BL = color (graphics mode)
        ;   or attribute (text mode)
        MOV AH, 09H
        INT 10H
        RET

cout_basic_char:
        ; AL = char
        ; CX = number of times
        MOV AH, 0AH
        INT 10H
        RET

char_input_with_echo:
        MOV AH, 01H
        INT 21H
        RET ; AL = character read

char_input_without_echo:
        MOV AH, 08H
        INT 21H
        RET ; AL = character read

print_string:
        ; DS:DX = pointer to a string$
        MOV AH, 09H
        INT 21H
        RET

read_file:
        MOV AH, 3FH
        MOV BX, file_pointer
        MOV CX, max_bytes_read
        LEA DX, file_content
        INT 21H

        jc bad_exit

        MOV file_read_size, AX
        RET

close_file:
        MOV AH, 3EH
        MOV BX, file_pointer
        INT 21H
        RET

bad_exit:
        ; assuming error code == AX
        MOV [error_msg + 27], AL
        LEA DX, error_msg
        call print_string
        jmp exit

; ---------- HELPER PROCEDURES -----------
change_string:
        CMP file_read_size, 0
        je operation_exit

        MOV DI, 0000
        operation_loop:
                MOV AL, file_content[DI]
                CMP AL, ' '
                jl continue
                CMP AL, 'z'
                jg continue
                CMP SI, 1 ; ENCRYPTION MODE
                je encrypt_char
                CMP SI, 2 ; DECRYPTION MODE
                je decrypt_char
                continue:
                        MOV file_content[DI], AL
                        INC DI
                        CMP DI, file_read_size
                        je operation_exit
                        jmp operation_loop
        encrypt_char:

                ADD AL, encryption_key
                CMP AL, 'z'
                jg overflow_handle
                jo overflow_handle
                jmp continue
        overflow_handle:
                SUB AL, 'z'
                ADD AL, ' '
                DEC AL
                jmp continue
        decrypt_char:
                SUB AL, encryption_key
                jc underflow_handle
                CMP AL, ' '
                jl underflow_handle
                jmp continue
        underflow_handle:
                ADD AL, 'z'
                SUB AL, ' '
                INC AL
                jmp continue
        operation_exit:
                jmp main_loop
refresh_content:
        MOV DX, 0200H
        call move_cursor
        CMP file_read_size, 0
        je return
        MOV SI, 0000
        print_contents:
                MOV DX, SI
                MOV DH, 02
                call move_cursor
                MOV DL, file_content[SI]
                ; MOV CX, 1
                ; call cout_basic_char
                MOV AH, 02H
                INT 21H

                INC SI
                CMP SI, file_read_size
                je return
                jmp print_contents
        return:
                RET

clear_screen:
        MOV AH, 00
        MOV AL, 03
        INT 10H

        MOV SI, 0000
        header_loop:
                MOV DX, SI
                call move_cursor
                MOV AL, [title_text + SI]
                MOV CX, 1
                MOV BL, title_color
                call cout_color_char

                INC SI
                CMP SI, len_title
                je dashes

                jmp header_loop
        dashes:
                MOV DX, 0100H   ; ROW #1
                call move_cursor
                MOV AL, '-'
                MOV CX, 80
                call cout_color_char

        revert_cursor:
                MOV DX, 0200H   ; ROW #2
                call move_cursor
                RET

input_filepath:
        LEA DX, filepath_prompt
        call print_string

        MOV DI, 0000
        inp_loop:
                call char_input_with_echo
                CMP AL, 0DH ; == '\r'
                je input_ok

                MOV [filepath + DI], AL
                INC DI
                CMP DI, max_filepath_ln
                je input_bad
                jmp inp_loop
        input_bad:
                LEA DX, new_line
                call print_string
                jmp input_filepath
        input_ok:
                MOV [filepath + DI], 00
                RET

open_file:
        MOV AH, 3DH
        MOV AL, 02H
        LEA DX, filepath
        INT 21H

        jc open_error

        MOV file_pointer, AX
        RET ; AX = new file pointer

        open_error:
                LEA DX, error_open_msg
                call print_string
                call input_filepath
                jmp open_file


new_file:
        MOV AH, 3CH
        MOV CX, 00H
        LEA DX, filepath
        INT 21H

        jc new_error

        MOV file_pointer, AX
        RET ; AX = new file pointer

        new_error:
                LEA DX, error_open_msg
                call print_string
                call input_filepath
                jmp new_file

display_menu:
        display_buttons:
        MOV DX, 1700H
        call move_cursor

        CMP encryption_cnt, 3
        jge not_enabled
        MOV BL, buttons_flash
        jmp display_encrypt_option
        not_enabled:
                MOV BL, buttons_color
        display_encrypt_option:
        MOV AL, menu_encrypt
        MOV CX, 1
        call cout_color_char
        ADD DL, 2
        call move_cursor
        LEA DX, encrypt_str
        call print_string
        call get_cursor_pos
        ADD DL, 4
        call move_cursor

        CMP encryption_cnt, -3
        jle not_enabled_2
        MOV BL, buttons_flash
        jmp display_decrypt_option
        not_enabled_2:
                MOV BL, buttons_color
        display_decrypt_option:
        MOV AL, menu_decrypt
        MOV CX, 1
        call cout_color_char
        ADD DL, 2
        call move_cursor
        LEA DX, decrypt_str
        call print_string
        call get_cursor_pos
        ADD DL, 12
        call move_cursor

        CMP is_saved, 0
        je not_enabled_3
        MOV BL, buttons_flash
        jmp display_save_option
        not_enabled_3:
                MOV BL, buttons_color
        display_save_option:
        MOV AL, menu_save
        MOV CX, 1
        call cout_color_char
        ADD DL, 2
        call move_cursor
        LEA DX, save_str
        call print_string
        call get_cursor_pos
        ADD DL, 4
        call move_cursor

        CMP is_saved, 0
        je not_enabled_4
        MOV BL, buttons_flash
        jmp display_save_as_option
        not_enabled_4:
                MOV BL, buttons_color
        display_save_as_option:
        MOV AL, menu_save_other
        MOV CX, 1
        call cout_color_char
        ADD DL, 2
        call move_cursor
        LEA DX, save_other_str
        call print_string
        call get_cursor_pos
        ADD DL, 15
        call move_cursor

        MOV BL, buttons_flash
        MOV SI, 0000
        print_esc:
                MOV AL, menu_quit[SI]
                MOV CX, 1
                call cout_color_char
                INC DL
                call move_cursor
                INC SI
                CMP SI, 3
                jne print_esc
        INC DL
        call move_cursor
        LEA DX, quit_str
        call print_string

        MOV DX, 1800H
        call move_cursor

        MOV AL, ' '
        MOV BL, statusbar_color
        MOV CX, 80
        call cout_color_char

        LEA DX, curr_file_str
        call print_string

        call get_cursor_pos
        call move_cursor

        CMP BYTE PTR is_saved, 00
        jne unsaved_file_color
        jmp print_filepath

        unsaved_file_color:
                MOV BL, unsaved_color

        print_filepath:
        MOV DI, DX
        MOV SI, 0000
        print_filepath_loop:
                MOV DX, DI
                MOV DH, 18H
                call move_cursor
                MOV AL, filepath[SI]
                MOV CX, 1
                call cout_color_char

                INC SI
                INC DI
                CMP BYTE PTR filepath[SI], 00
                je fix_cursor
                jmp print_filepath_loop

        fix_cursor:
                MOV DX, 0200H
                call move_cursor
                RET



; ------ "Open your eyes, Nicholas." ------
exit:
        MOV AH, 00
        MOV AL, 02
        INT 10H

        MOV AX, 4C00H
        INT 21H

END MAIN
