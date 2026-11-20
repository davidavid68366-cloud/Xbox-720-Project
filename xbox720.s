.set noreorder
.option pic0

.equ SYS_read,       4003
.equ SYS_write,      4004
.equ SYS_open,       4005
.equ SYS_close,      4006
.equ SYS_exit,       4001
.equ SYS_ioctl,      4054
.equ SYS_gettimeofday, 4078
.equ SYS_nanosleep,  4166
.equ TCGETS,         0x5401
.equ TCSETS,         0x5402

.equ MAP_W,          40
.equ MAP_H,          20
.equ MAX_SNAKE,      800

.data
.align 2
menu_title: .asciz "\033[2J\033[H\033[1;32m========================================\n                 XBOX 720\n           MIPS ARCADE SYSTEM\033[0m\n\n         [1] GUESS THE NUMBER\n         [2] SNAKE\n\n         [0] EXIT\n\n========================================\nSELECT GAME: "
msg_invalid: .asciz "Invalid input. Please try again.\n"
msg_guess_intro: .asciz "\033[2J\033[H=== GUESS THE NUMBER ===\nI'm thinking of a number from 1 to 100.\n"
msg_guess_prompt: .asciz "Your guess (1-100): "
msg_low: .asciz "Too low!\n"
msg_high: .asciz "Too high!\n"
msg_correct: .asciz "\033[1;32mCorrect! Attempts: \033[0m"
msg_guess_again: .asciz "\n[1] Play again   [0] Main menu: "
msg_title_line: .asciz "\033[H\033[2J\033[1;32mXBOX 720\033[0m\n"
msg_score: .asciz "Score: "
msg_board_top: .asciz "\n+----------------------------------------+\n"
msg_gameover: .asciz "\n\033[1;31mGAME OVER\033[0m\nScore: "
msg_snake_again: .asciz "\n[1] Restart   [0] Main menu: "
msg_controls: .asciz "\nW A S D = MOVE       Q = QUIT\n"
msg_goodbye: .asciz "\nThanks for playing XBOX 720!\n"
newline: .asciz "\n"

.align 2
input_buffer: .space 128
input_char: .space 4
rng_seed: .word 0
secret_number: .word 0
attempt_count: .word 0
snake_x: .space 3200
snake_y: .space 3200
snake_len: .word 0
snake_dir: .word 0
snake_score: .word 0
food_x: .word 0
food_y: .word 0
next_x: .word 0
next_y: .word 0
snake_eating: .word 0
terminal_active: .word 0
term_saved: .space 64
term_work: .space 64
timespec: .space 8
board: .space 800

.text
.globl _start
.globl main
_start:
    jal main
    nop
    j exit_game
    nop

# Write a zero-terminated string from a0.
print_z:
    move $t0, $a0
    move $t1, $a0
1:
    lbu $t2, 0($t1)
    beqz $t2, 2f
    nop
    addiu $t1, $t1, 1
    b 1b
    nop
2:
    subu $a2, $t1, $t0
    move $a1, $t0
    li $a0, 1
    li $v0, SYS_write
    syscall
    jr $ra
    nop

# Read a line into input_buffer, including no newline. Returns length in v0.
read_input:
    la $t0, input_buffer
    move $t1, $zero
1:
    slti $t2, $t1, 126
    beqz $t2, 3f
    nop
    li $v0, SYS_read
    li $a0, 0
    la $a1, input_char
    li $a2, 1
    syscall
    blez $v0, 3f
    nop
    lbu $t3, input_char
    li $t4, 10
    beq $t3, $t4, 3f
    nop
    li $t4, 13
    beq $t3, $t4, 3f
    nop
    addu $t4, $t0, $t1
    sb $t3, 0($t4)
    addiu $t1, $t1, 1
    b 1b
    nop
3:
    addu $t4, $t0, $t1
    sb $zero, 0($t4)
    move $v0, $t1
    jr $ra
    nop

# Parse decimal input_buffer. v0=value, v1=1 if valid.
parse_number:
    la $t0, input_buffer
    lbu $t1, 0($t0)
    beqz $t1, 4f
    nop
    move $t2, $zero
1:
    lbu $t1, 0($t0)
    beqz $t1, 3f
    nop
    sltiu $t3, $t1, 48
    bnez $t3, 4f
    nop
    sltiu $t3, $t1, 58
    beqz $t3, 4f
    nop
    addiu $t1, $t1, -48
    sll $t4, $t2, 3
    sll $t5, $t2, 1
    addu $t2, $t4, $t5
    addu $t2, $t2, $t1
    sltiu $t3, $t2, 10000
    beqz $t3, 4f
    nop
    addiu $t0, $t0, 1
    b 1b
    nop
3:
    move $v0, $t2
    li $v1, 1
    jr $ra
    nop
4:
    move $v0, $zero
    move $v1, $zero
    jr $ra
    nop

print_title:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    la $a0, menu_title
    jal print_z
    nop
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra
    nop

show_menu:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    jal print_title
    nop
    jal read_input
    nop
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra
    nop

# xorshift32 PRNG; returns an unsigned value reduced to 0..99.
generate_random:
    lw $t0, rng_seed
    sll $t1, $t0, 13
    xor $t0, $t0, $t1
    srl $t1, $t0, 17
    xor $t0, $t0, $t1
    sll $t1, $t0, 5
    xor $t0, $t0, $t1
    bnez $t0, 1f
    nop
    li $t0, 0x6d2b79f5
1:
    sw $t0, rng_seed
    li $t1, 100
    divu $t0, $t1
    mfhi $v0
    jr $ra
    nop

guess_game:
    addiu $sp, $sp, -32
    sw $ra, 28($sp)
    sw $s0, 24($sp)
1:
    jal generate_random
    nop
    addiu $t0, $v0, 1
    sw $t0, secret_number
    sw $zero, attempt_count
    la $a0, msg_guess_intro
    jal print_z
    nop
2:
    la $a0, msg_guess_prompt
    jal print_z
    nop
    jal read_input
    nop
    beqz $v0, 8f
    nop
    jal parse_number
    nop
    beqz $v1, 7f
    nop
    sltiu $t0, $v0, 1
    bnez $t0, 7f
    nop
    sltiu $t0, $v0, 101
    beqz $t0, 7f
    nop
    lw $t0, attempt_count
    addiu $t0, $t0, 1
    sw $t0, attempt_count
    lw $t1, secret_number
    beq $v0, $t1, 4f
    nop
    sltu $t2, $v0, $t1
    beqz $t2, 3f
    nop
    la $a0, msg_low
    jal print_z
    nop
    b 2b
    nop
3:
    la $a0, msg_high
    jal print_z
    nop
    b 2b
    nop
4:
    la $a0, msg_correct
    jal print_z
    nop
    lw $a0, attempt_count
    jal print_uint
    nop
    la $a0, msg_guess_again
    jal print_z
    nop
    jal read_input
    nop
    beqz $v0, 8f
    nop
    jal parse_number
    nop
    beqz $v1, 6f
    nop
    li $t0, 1
    beq $v0, $t0, 1b
    nop
    b 6f
    nop
7:
    la $a0, msg_invalid
    jal print_z
    nop
    b 2b
    nop
6:
8:
    lw $s0, 24($sp)
    lw $ra, 28($sp)
    addiu $sp, $sp, 32
    jr $ra
    nop

# Print unsigned a0 as decimal.
print_uint:
    addiu $sp, $sp, -32
    sw $ra, 28($sp)
    addiu $t0, $sp, 24
    move $t1, $zero
    bnez $a0, 1f
    nop
    addiu $t0, $t0, -1
    li $t2, 48
    sb $t2, 0($t0)
    li $t1, 1
    b 3f
    nop
1:
    li $t2, 10
2:
    divu $a0, $t2
    mfhi $t3
    mflo $a0
    addiu $t3, $t3, 48
    addiu $t0, $t0, -1
    sb $t3, 0($t0)
    addiu $t1, $t1, 1
    bnez $a0, 2b
    nop
3:
    li $v0, SYS_write
    li $a0, 1
    move $a1, $t0
    move $a2, $t1
    syscall
    lw $ra, 28($sp)
    addiu $sp, $sp, 32
    jr $ra
    nop

main:
    # Seed with kernel time; use a nonzero fallback if unavailable.
    la $a0, timespec
    addiu $a1, $a0, 8
    li $v0, SYS_gettimeofday
    syscall
    lw $t0, timespec
    lw $t1, timespec+4
    xor $t0, $t0, $t1
    bnez $t0, 1f
    nop
    li $v0, 4020
    syscall
    move $t0, $v0
    bnez $t0, 1f
    nop
    li $t0, 0x13579bdf
1:
    sw $t0, rng_seed
2:
    jal show_menu
    nop
    beqz $v0, 9f
    nop
    jal parse_number
    nop
    beqz $v1, 8f
    nop
    beqz $v0, 9f
    nop
    li $t0, 1
    beq $v0, $t0, 3f
    nop
    li $t0, 2
    beq $v0, $t0, 4f
    nop
8:
    la $a0, msg_invalid
    jal print_z
    nop
    b 2b
    nop
3:
    jal guess_game
    nop
    b 2b
    nop
4:
    jal snake_game
    nop
    b 2b
    nop
9:
    j exit_game
    nop

# Initialize snake state and put the initial head at (20,10), moving right.
snake_initialize:
    li $t0, 3
    sw $t0, snake_len
    sw $zero, snake_score
    sw $zero, snake_dir
    li $t1, 20
    sw $t1, snake_x
    addiu $t1, $t1, -1
    sw $t1, snake_x+4
    addiu $t1, $t1, -1
    sw $t1, snake_x+8
    li $t2, 10
    sw $t2, snake_y
    sw $t2, snake_y+4
    sw $t2, snake_y+8
    jal snake_spawn_food
    nop
    jr $ra
    nop

# Spawn food in the playable area, avoiding all snake segments.
snake_spawn_food:
1:
    jal generate_random
    nop
    li $t0, 38
    divu $v0, $t0
    mfhi $t1
    addiu $t1, $t1, 1
    sw $t1, food_x
    jal generate_random
    nop
    li $t0, 18
    divu $v0, $t0
    mfhi $t2
    addiu $t2, $t2, 1
    sw $t2, food_y
    move $t3, $zero
    lw $t4, snake_len
2:
    beq $t3, $t4, 4f
    nop
    sll $t5, $t3, 2
    la $t6, snake_x
    addu $t6, $t6, $t5
    lw $t7, 0($t6)
    bne $t7, $t1, 3f
    nop
    la $t6, snake_y
    addu $t6, $t6, $t5
    lw $t7, 0($t6)
    beq $t7, $t2, 1b
    nop
3:
    addiu $t3, $t3, 1
    b 2b
    nop
4:
    jr $ra
    nop

# v0=1 when next head position hits a wall or the body.
snake_collision:
    lw $t0, next_x
    slti $t1, $t0, 1
    bnez $t1, 1f
    nop
    sltiu $t1, $t0, 39
    beqz $t1, 1f
    nop
    lw $t0, next_y
    slti $t1, $t0, 1
    bnez $t1, 1f
    nop
    sltiu $t1, $t0, 19
    beqz $t1, 1f
    nop
    move $t2, $zero
    lw $t3, snake_len
2:
    beq $t2, $t3, 3f
    nop
    sll $t4, $t2, 2
    la $t5, snake_x
    addu $t5, $t5, $t4
    lw $t6, 0($t5)
    lw $t7, next_x
    bne $t6, $t7, 4f
    nop
    la $t5, snake_y
    addu $t5, $t5, $t4
    lw $t6, 0($t5)
    lw $t7, next_y
    beq $t6, $t7, 1f
    nop
4:
    addiu $t2, $t2, 1
    b 2b
    nop
3:
    move $v0, $zero
    jr $ra
    nop
1:
    li $v0, 1
    jr $ra
    nop

# Advance by one cell; returns v0=1 on collision.
snake_update:
    lw $t0, snake_x
    lw $t1, snake_y
    lw $t2, snake_dir
    beqz $t2, 1f
    nop
    li $t3, 1
    beq $t2, $t3, 2f
    nop
    li $t3, 2
    beq $t2, $t3, 3f
    nop
    addiu $t1, $t1, -1
    b 4f
    nop
1:
    addiu $t0, $t0, 1
    b 4f
    nop
2:
    addiu $t1, $t1, 1
    b 4f
    nop
3:
    addiu $t0, $t0, -1
4:
    sw $t0, next_x
    sw $t1, next_y
    sw $zero, snake_eating
    lw $t3, food_x
    bne $t0, $t3, 5f
    nop
    lw $t3, food_y
    bne $t1, $t3, 5f
    nop
    li $t3, 1
    sw $t3, snake_eating
5:
    jal snake_collision
    nop
    bnez $v0, 9f
    nop
    lw $t4, snake_len
    lw $t5, snake_eating
    beqz $t5, 6f
    nop
    addiu $t4, $t4, 1
    sw $t4, snake_len
    lw $t6, snake_score
    addiu $t6, $t6, 10
    sw $t6, snake_score
6:
    addiu $t4, $t4, -1
7:
    blez $t4, 8f
    nop
    sll $t5, $t4, 2
    addiu $t6, $t5, -4
    la $t7, snake_x
    addu $t8, $t7, $t6
    lw $t9, 0($t8)
    addu $t8, $t7, $t5
    sw $t9, 0($t8)
    la $t7, snake_y
    addu $t8, $t7, $t6
    lw $t9, 0($t8)
    addu $t8, $t7, $t5
    sw $t9, 0($t8)
    addiu $t4, $t4, -1
    b 7b
    nop
8:
    lw $t0, next_x
    sw $t0, snake_x
    lw $t1, next_y
    sw $t1, snake_y
    lw $t2, snake_eating
    beqz $t2, 9f
    nop
    jal snake_spawn_food
    nop
    move $v0, $zero
9:
    jr $ra
    nop

# Draw a complete frame. Board is rebuilt in memory then written by rows.
snake_render:
    addiu $sp, $sp, -32
    sw $ra, 28($sp)
    sw $s0, 24($sp)
    # Fill 800 cells with spaces.
    la $t0, board
    li $t1, 800
    li $t2, 32
1:
    sb $t2, 0($t0)
    addiu $t0, $t0, 1
    addiu $t1, $t1, -1
    bnez $t1, 1b
    nop
    # Top and bottom walls.
    la $t0, board
    li $t1, 0
2:
    li $t2, 35
    addu $t3, $t0, $t1
    sb $t2, 0($t3)
    addiu $t4, $t1, 760
    addu $t3, $t0, $t4
    sb $t2, 0($t3)
    addiu $t1, $t1, 1
    slti $t4, $t1, 40
    bnez $t4, 2b
    nop
    # Side walls.
    li $t1, 1
3:
    sll $t2, $t1, 5
    sll $t3, $t1, 3
    addu $t2, $t2, $t3
    addu $t2, $t2, $t0
    li $t3, 35
    sb $t3, 0($t2)
    addiu $t2, $t2, 39
    sb $t3, 0($t2)
    addiu $t1, $t1, 1
    slti $t4, $t1, 19
    bnez $t4, 3b
    nop
    # Food.
    lw $t1, food_y
    sll $t2, $t1, 5
    sll $t3, $t1, 3
    addu $t2, $t2, $t3
    lw $t1, food_x
    addu $t2, $t2, $t1
    addu $t2, $t2, $t0
    li $t3, 64
    sb $t3, 0($t2)
    # Body, from tail toward head; head overwrites its cell last.
    lw $t4, snake_len
    addiu $t4, $t4, -1
4:
    bltz $t4, 6f
    nop
    sll $t5, $t4, 2
    la $t6, snake_x
    addu $t6, $t6, $t5
    lw $t7, 0($t6)
    la $t6, snake_y
    addu $t6, $t6, $t5
    lw $t8, 0($t6)
    sll $t9, $t8, 5
    sll $t6, $t8, 3
    addu $t9, $t9, $t6
    addu $t9, $t9, $t7
    addu $t9, $t9, $t0
    li $t6, 111
    sb $t6, 0($t9)
    addiu $t4, $t4, -1
    b 4b
    nop
6:
    lw $t7, snake_x
    lw $t8, snake_y
    sll $t9, $t8, 5
    sll $t6, $t8, 3
    addu $t9, $t9, $t6
    addu $t9, $t9, $t7
    addu $t9, $t9, $t0
    li $t6, 79
    sb $t6, 0($t9)
    la $a0, msg_title_line
    jal print_z
    nop
    la $a0, msg_score
    jal print_z
    nop
    lw $a0, snake_score
    jal print_uint
    nop
    la $a0, msg_board_top
    jal print_z
    nop
    la $s0, board
    li $t0, 0
7:
    li $a0, 1
    la $a1, pipe_char
    li $a2, 1
    li $v0, SYS_write
    syscall
    li $a0, 1
    move $a1, $s0
    li $a2, 40
    li $v0, SYS_write
    syscall
    li $a0, 1
    la $a1, pipe_newline
    li $a2, 2
    li $v0, SYS_write
    syscall
    addiu $s0, $s0, 40
    addiu $t0, $t0, 1
    slti $t1, $t0, 20
    bnez $t1, 7b
    nop
    la $a0, msg_board_top
    jal print_z
    nop
    la $a0, msg_controls
    jal print_z
    nop
    lw $s0, 24($sp)
    lw $ra, 28($sp)
    addiu $sp, $sp, 32
    jr $ra
    nop

# Setup noncanonical/no-echo terminal mode; returns with terminal_active set.
snake_terminal_on:
    sw $zero, terminal_active
    li $v0, SYS_ioctl
    li $a0, 0
    li $a1, TCGETS
    la $a2, term_saved
    syscall
    bltz $v0, 2f
    nop
    la $t0, term_saved
    la $t1, term_work
    li $t2, 40
1:
    lbu $t3, 0($t0)
    sb $t3, 0($t1)
    addiu $t0, $t0, 1
    addiu $t1, $t1, 1
    addiu $t2, $t2, -1
    bnez $t2, 1b
    nop
    lw $t0, term_work+12
    li $t1, -11
    and $t0, $t0, $t1
    sw $t0, term_work+12
    sb $zero, term_work+22
    sb $zero, term_work+23
    li $v0, SYS_ioctl
    li $a0, 0
    li $a1, TCSETS
    la $a2, term_work
    syscall
    bltz $v0, 2f
    nop
    li $t0, 1
    sw $t0, terminal_active
2:
    jr $ra
    nop

snake_terminal_off:
    lw $t0, terminal_active
    beqz $t0, 1f
    nop
    li $v0, SYS_ioctl
    li $a0, 0
    li $a1, TCSETS
    la $a2, term_saved
    syscall
    sw $zero, terminal_active
1:
    jr $ra
    nop

# Configure the new direction from input byte t0, ignoring a 180-degree turn.
snake_set_direction:
    move $t1, $zero
    li $t2, 119
    beq $t0, $t2, 1f
    nop
    li $t2, 87
    beq $t0, $t2, 1f
    nop
    li $t2, 100
    beq $t0, $t2, 2f
    nop
    li $t2, 68
    beq $t0, $t2, 2f
    nop
    li $t2, 115
    beq $t0, $t2, 3f
    nop
    li $t2, 83
    beq $t0, $t2, 3f
    nop
    li $t2, 97
    beq $t0, $t2, 4f
    nop
    li $t2, 65
    beq $t0, $t2, 4f
    nop
    jr $ra
    nop
1:
    li $t1, 3
    b 5f
    nop
2:
    li $t1, 0
    b 5f
    nop
3:
    li $t1, 1
    b 5f
    nop
4:
    li $t1, 2
5:
    lw $t2, snake_dir
    addiu $t3, $t2, 2
    andi $t3, $t3, 3
    beq $t1, $t3, 6f
    nop
    sw $t1, snake_dir
6:
    jr $ra
    nop

snake_game_over:
    addiu $sp, $sp, -24
    sw $ra, 20($sp)
    la $a0, msg_gameover
    jal print_z
    nop
    lw $a0, snake_score
    jal print_uint
    nop
    la $a0, msg_snake_again
    jal print_z
    nop
    jal read_input
    nop
    beqz $v0, 1f
    nop
    jal parse_number
    nop
    li $t0, 1
    bne $v0, $t0, 1f
    nop
    li $v0, 1
    b 2f
    nop
1:
    move $v0, $zero
2:
    lw $ra, 20($sp)
    addiu $sp, $sp, 24
    jr $ra
    nop

snake_game:
    addiu $sp, $sp, -32
    sw $ra, 28($sp)
1:
    jal snake_initialize
    nop
    jal snake_terminal_on
    nop
2:
    jal snake_render
    nop
    # Nonblocking one-byte input. A zero-byte read means no key was pressed.
    li $v0, SYS_read
    li $a0, 0
    la $a1, input_char
    li $a2, 1
    syscall
    blez $v0, 3f
    nop
    lbu $t0, input_char
    li $t1, 113
    beq $t0, $t1, 7f
    nop
    li $t1, 81
    beq $t0, $t1, 7f
    nop
    jal snake_set_direction
    nop
3:
    jal snake_update
    nop
    bnez $v0, 6f
    nop
    # Delay = max(80ms, 320ms - 15ms per food).
    lw $t0, snake_score
    li $t1, 10
    divu $t0, $t1
    mflo $t0
    li $t1, 15000000
    multu $t0, $t1
    mflo $t2
    li $t3, 320000000
    subu $t3, $t3, $t2
    li $t4, 80000000
    sltu $t5, $t3, $t4
    beqz $t5, 4f
    nop
    move $t3, $t4
4:
    sw $zero, timespec
    sw $t3, timespec+4
    li $v0, SYS_nanosleep
    la $a0, timespec
    move $a1, $zero
    syscall
    b 2b
    nop
6:
    jal snake_terminal_off
    nop
    jal snake_game_over
    nop
    li $t0, 1
    beq $v0, $t0, 1b
    nop
    b 8f
    nop
7:
    jal snake_terminal_off
    nop
    la $a0, newline
    jal print_z
    nop
8:
    lw $ra, 28($sp)
    addiu $sp, $sp, 32
    jr $ra
    nop

pipe_char: .byte 124
pipe_newline: .byte 124,10

exit_game:
    jal snake_terminal_off
    nop
    la $a0, msg_goodbye
    jal print_z
    nop
    li $a0, 0
    li $v0, SYS_exit
    syscall
    b exit_game
    nop
