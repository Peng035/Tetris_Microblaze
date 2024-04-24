/*
 *
 * Xilinx, Inc.
 * XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" AS A
 * COURTESY TO YOU.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION AS
 * ONE POSSIBLE   IMPLEMENTATION OF THIS FEATURE, APPLICATION OR
 * STANDARD, XILINX IS MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION
 * IS FREE FROM ANY CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE
 * FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION
 * XILINX EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO
 * THE ADEQUACY OF THE IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO
 * ANY WARRANTIES OR REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE
 * FROM CLAIMS OF INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.
 */
 /* Micro Tetris, based on an obfuscated tetris, 1989 IOCCC Best Game
 *
 * Copyright (c) 1989  John Tromp <john.tromp@gmail.com>
 * Copyright (c) 2009-2021  Joachim Wiberg <troglobit@gmail.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * See the following URLs for more information, first John Tromp's page about
 * the game http://homepages.cwi.nl/~tromp/tetris.html then there's the entry
 * page at IOCCC http://www.ioccc.org/1989/tromp.hint
 */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xintc.h"
#include "intc_header.h"
#include "xgpio.h"
#include "gpio_header.h"
#include "xtmrctr.h"
#include "tmrctr_header.h"
#include "tmrctr_intr_header.h"
#include "xil_printf.h"
#include "xil_exception.h"

#define DEBUG_C   1     // macro switch for print info

/* the board */
#define      B_COLS 32      // this number should be the GPU col + 2, since no boarder in GPU yet
#define      B_ROWS 30      // this number should be the GPU row + 2, since no boarder in GPU yet
#define      B_SIZE (B_ROWS * B_COLS)

// offset to convert the 2D position into an 1D integer array
#define TL     -B_COLS-1	/* top left */
#define TC     -B_COLS		/* top center */
#define TR     -B_COLS+1	/* top right */
#define ML     -1		/* middle left */
#define MR     1		/* middle right */
#define BL     B_COLS-1		/* bottom left */
#define BC     B_COLS		/* bottom center */
#define BR     B_COLS+1		/* bottom right */

/* These can be overridden by the user. */
#define DEFAULT_KEYS "abcdefgh"
#define KEY_LEFT   0
#define KEY_RIGHT  1
#define KEY_ROTATE 2
#define KEY_DROP   3
#define KEY_PAUSE  4
#define KEY_QUIT   5
#define KEY_RESET  6
#define KEY_REMAIN 7

#define CMD_DRAW            0
#define CMD_CLR_ONE         1
#define CMD_CLR_LINE        2
#define CMD_CLR_BOARD       3

// mcaros for sprite shapes
#define S_L_LEFT     0b000
#define S_L_RIGHT    0b001
#define S_Z_RIGHT    0b010
#define S_Z_LEFT     0b011
#define S_T          0b100
#define S_SQR        0b101
#define S_STICK      0b110

#define S_EMPTY      -1

// We only use GPIO 1
#define GPIO_OUT_CHANNEL 1


// instance of the controllers of peripheral devices
static XIntc intc;
static XGpio Gpio_out;
static XTmrCtr _axi_timer;

// buffer for GPIO output
static uint32_t gpio_out_buff = 0;

// Game logic related
static volatile int running = 1;
// the freeze flag of the game
// 0: unfreezed, 1: freezed
static int freeze_flag = 0;

static char *keys = DEFAULT_KEYS;
//static int level = 1;
static int points = 0;
static int lines_cleared = 0;
static int board[B_SIZE];

static int *peek_shape;		/* peek preview of next shape */
static int  pcolor;
static int *shape;
static int  color;

static int old_shape;
static int old_pos;
static int s_new_pos;

// the int representation of button press
static char ctrl_key;

// refresh flag set by the timer interrupt
static int refresh_flag = 1;

// used to generate random next shape
static unsigned long int next_rand = 1;

// 5*19 2D int array , each row represent info of a shape (5 elements)
// [0] index of shape, [1],[2],[3] block offset
// [4] color of the shape
static int shapes[] = {
	 7, TL, TC, MR, 2,	/* ""__   */            // 0
	 8, TR, TC, ML, 3,	/* __""   */            // 5
	 9, TL, TC, TR, 1,	/* "|"    */            // 10  modified according to GPU
	 3, TL, TC, ML, 4,	/* square */            // 15
	12, ML, BL, MR, 5,	/* |"""   */            // 20
	15, ML, BR, MR, 6,	/* """|   */            // 25
	18, ML, MR,  2, 7,	/* ---- sticks out */   // 30
	 0, TC, ML, BL, 2,	/* /    */              // 35
	 1, TL, ML, BC, 3,	/* \    */              // 40
	10, TC, MR, BC, 1,	/* |-   */              // 45
	11, TC, ML, MR, 1,	/* _|_  */              // 50
	 2, TC, ML, BC, 1,	/* -|   */              // 55
	13, TC, BC, BR, 5,	/* |_   */              // 60
	14, TR, ML, MR, 5,	/* ___| */              // 65
	 4, TL, TC, BC, 5,	/* "|   */              // 70
	16, TR, TC, BC, 6,	/* |"   */              // 75
	17, TL, MR, ML, 6,	/* |___ */              // 80
	 5, TC, BC, BL, 6,	/* _| */                // 85
	 6, TC, BC,  2 * B_COLS, 7, /* | sticks out */
};

/* Check if shape fits in the current position */
static int fits_in(int *s, int pos)
{
	if (board[pos] || board[pos + s[1]] || board[pos + s[2]] || board[pos + s[3]])
		return 0;

	return 1;
}


   // function send new sprite via GPIO
   // cmd: 0 draw new sprite at pos
   // cmd: 1 clear sprite at pos
   // cmd: 2 clear line start with pos, move the upper line down
   // cmd: 3 clear the entire board
 static void  update_board(int s_type, int s_pos, int cmd)
 {
    int new_pos, row_index, col_index;

    // clear the buff
    gpio_out_buff = 0;

    // clear the valid bit of GPIO
    XGpio_DiscreteWrite(&Gpio_out, GPIO_OUT_CHANNEL, gpio_out_buff);

    // convert the pos from center of 3X3 blocks
    // into the top left corner of a 4X4 blocks
    // this also needs to be in consistent with GPU
    // new_pos is [0, 575] since it is 24X24
    // which need 10 bits to represent
    new_pos = s_pos-B_COLS-1;
    // the column index of the top-left corner of the sprite
    col_index = new_pos % B_COLS;
    // the row index of the top-left corner of the sprite
    row_index = new_pos / B_COLS;

    // 23 valid bit; 22-19 command bits
    // 18-16 color bits
    // 15-13 type of sprite
    // 12-11 rotation of sprite
    // 10-6 row coordinate
    // 5-0 column coordinate

    // set bit 23: the valid flag
    gpio_out_buff |= 0b1 << 23;

    // set the command bits
    switch(cmd){
        case CMD_DRAW:
            #ifdef DEBUG_C
                print("\nDraw new sprite\r\n");
            #endif
            break;
        case CMD_CLR_ONE:
            // cmd 0001
            gpio_out_buff |= 0b01 << 19;
            #ifdef DEBUG_C
                print("\nClear old sprite\r\n");
            #endif
            break;
        case CMD_CLR_LINE:
            // cmd 0010
            gpio_out_buff |= 0b10 << 19;
            #ifdef DEBUG_C
                print("\nClear a Line\r\n");
            #endif
            break;
        case CMD_CLR_BOARD:
            // cmd 0011
            gpio_out_buff |= 0b11 << 19;
            #ifdef DEBUG_C
                print("\nClear the entire board\r\n");
            #endif
            break;
        default: ;
    }


    switch (s_type)
    {
    case 13:    // L rotation 00
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_L_LEFT + 1) << 16;
        // type
        gpio_out_buff |= S_L_LEFT << 13;
        // rotation
        gpio_out_buff |= 0b00 << 11;
        break;
    case 14:    // L rotate 01
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_L_LEFT + 1) << 16;
        // type
        gpio_out_buff |= S_L_LEFT << 13;
        // rotation
        gpio_out_buff |= 0b01 << 11;
        break;
    case 4:    // L rotate 10
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_L_LEFT + 1) << 16;
        // type
        gpio_out_buff |= S_L_LEFT << 13;
        // rotation
        gpio_out_buff |= 0b10 << 11;
        break;
    case 12:    // L rotate 11
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_L_LEFT + 1) << 16;
        // type
        gpio_out_buff |= S_L_LEFT << 13;
        // rotation
        gpio_out_buff |= 0b11 << 11;
        break;
    case 5:    // _| rotate 00
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_L_RIGHT + 1) << 16;
        // type
        gpio_out_buff |= S_L_RIGHT << 13;
        // rotation
        // rotation 00
        break;
    case 17:    // _| rotate 01
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_L_RIGHT + 1) << 16;
        // type
        gpio_out_buff |= S_L_RIGHT << 13;
        // rotation
        gpio_out_buff |= 0b01 << 11;
        break;
    case 16:    // _| rotate 10
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_L_RIGHT + 1) << 16;
        // type
        gpio_out_buff |= S_L_RIGHT << 13;
        // rotation
        gpio_out_buff |= 0b10 << 11;
        break;
    case 15:    // _| rotate 11
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_L_RIGHT + 1) << 16;
        // type
        gpio_out_buff |= S_L_RIGHT << 13;
        // rotation
        gpio_out_buff |= 0b11 << 11;
        break;
    case 1:    // Z mirror rotate 00
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_Z_RIGHT + 1) << 16;
        // type
        gpio_out_buff |= S_Z_RIGHT << 13;
        // rotation
        gpio_out_buff |= 0b00 << 11;
        break;
    case 8:    // Z mirror rotate 11
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_Z_RIGHT + 1) << 16;
        // type
        gpio_out_buff |= S_Z_RIGHT << 13;
        // rotation
        gpio_out_buff |= 0b11 << 11;
        break;
    case 0:    // Z rotate 00
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_Z_LEFT + 1) << 16;
        // type
        gpio_out_buff |= S_Z_LEFT << 13;
        // rotation
        gpio_out_buff |= 0b00 << 11;
        break;
    case 7:    // Z rotate 11
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_Z_LEFT + 1) << 16;
        // type
        gpio_out_buff |= S_Z_LEFT << 13;
        // rotation
        gpio_out_buff |= 0b11 << 11;
        break;
    case 9:    // T rotate 00
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_T + 1) << 16;
        // type
        gpio_out_buff |= S_T << 13;
        // rotation
        gpio_out_buff |= 0b00 << 11;
        break;
    case 10:    // T rotate 01
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_T + 1) << 16;
        // type
        gpio_out_buff |= S_T << 13;
        // rotation
        gpio_out_buff |= 0b01 << 11;
        break;
    case 11:    // T rotate 10
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_T + 1) << 16;
        // type
        gpio_out_buff |= S_T << 13;
        // rotation
        gpio_out_buff |= 0b10 << 11;
        break;
    case 2:    // T rotate 11
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_T + 1) << 16;
        // type
        gpio_out_buff |= S_T << 13;
        // rotation
        gpio_out_buff |= 0b11 << 11;
        break;
    case 3:    // square rotate 00
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_SQR + 1) << 16;
        // type
        gpio_out_buff |= S_SQR << 13;
        // rotation
        gpio_out_buff |= 0b00 << 11;
        break;
    case 6:    // | rotate 00
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_STICK + 1) << 16;
        // type
        gpio_out_buff |= S_STICK << 13;
        // rotation
        gpio_out_buff |= 0b00 << 11;
        break;
    case 18:    // | rotate 01
        // color 0 means black, so color = type + 1
        gpio_out_buff |= (S_STICK + 1) << 16;
        // type
        gpio_out_buff |= S_STICK << 13;
        // rotation
        gpio_out_buff |= 0b01 << 11;
        break;

    default:
        break;
    }

    // row index
    gpio_out_buff |= (row_index & 0b11111) << 6 ;
    //col index
    gpio_out_buff |= col_index & 0b111111;

    #ifdef DEBUG_C
		if (cmd == CMD_DRAW){
			xil_printf("\r\nSprite Type = %d\r\n", s_type);
			xil_printf("\r\nRotation Type = %d\r\n", (gpio_out_buff>>11) & 3);
			xil_printf("\r\nRow Index  =  %d\r\n", row_index);
			xil_printf("\r\nCol Index  =  %d\r\n", col_index);
		}
	#endif



    // write the GPIO output
    XGpio_DiscreteWrite(&Gpio_out, GPIO_OUT_CHANNEL, gpio_out_buff);

 }

//  place shape at pos with color in softeware
static void place(int *s, int pos, int c)
{
    // each sprite has 4 blocks
    // pos is the center coordinates
    // s[1] s[2] s[3] are the offset of the other three blocks
    // such TL, BR
	board[pos] = c;
	board[pos + s[1]] = c;
	board[pos + s[2]] = c;
	board[pos + s[3]] = c;

    #ifdef DEBUG_C
		if(!c){
			xil_printf("\n[Place called] Current POS is = %d\r\n\nCurrent shape is: %d \r\n\n", pos, s[0]);
		}

    #endif

}


// my function to generate a pseudo random number
// on bare-metal Microblaze
int my_rand(void) {
    next_rand = next_rand * 1023515645 + 12345;
    return (unsigned int)(next_rand / 65536) % 32768;
}
// my function to create random seed on Microblaze
void my_srand(unsigned int seed) {
    next_rand = seed;
}

// use random value to generate next shape
static int *next_shape(void)
{
    // 7 different shapes, 5 attributes of each shape
	int  pos  = my_rand() % 7 * 5;
	int *next = peek_shape;

	peek_shape = &shapes[pos];
	pcolor = peek_shape[4];

    // recursive call to gaurantee a valid shape chosed
	if (!next){
		return next_shape();
    }

	color = next[4];

	#ifdef DEBUG_C
        xil_printf("\nNext shape is generated, shape = %d color = %d\r\n", next[0], next[4]);

	#endif

	return next;
}


// use a switch to generate interrupt to clear
// the running flag
void exit_handler(void *CallbackRef)
{
	running = 0;
    // clear the interrupt need to implement
    // XIntc_Acknowledge
}

// interrupt handlers of the interrupt IP block
// upper button to freeze/Unfreeze
void IntrButton_U_Handler(void *CallbackRef){
    // toggle the freeze flag
    freeze_flag = !freeze_flag;

    if(freeze_flag){
        ctrl_key = keys[KEY_PAUSE];
    }else{
        ctrl_key = keys[KEY_REMAIN];
    }

    // set the refresh flag
    refresh_flag = 1;

#ifdef DEBUG_C
	// print("Enter Button UP Interrupt Handler\n");
    if (freeze_flag) {
        print("Freeze the Game\r\n");
    }
    else{
        print("Unfreeze the Game\r\n");
    }
#endif

	// clear interrupt in Interrupt block
	XIntc_Acknowledge(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_U_INTR);
}

// Left
void IntrButton_L_Handler(void *CallbackRef){
    // set the refresh flag
    refresh_flag = 1;
#ifdef DEBUG_C
	print("Enter Button Left Interrupt Handler\r\n");
#endif
	// only handle the button when it is Not frozen
	if (!freeze_flag){
		ctrl_key = keys[KEY_LEFT];
	}
	// clear interrupt in Interrupt block
	XIntc_Acknowledge(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_L_INTR);
}

// Right
void IntrButton_R_Handler(void *CallbackRef){
    // set the refresh flag
    refresh_flag = 1;
#ifdef DEBUG_C
	print("Enter Button Right Interrupt Handler\r\n");
#endif

	// only handle the button when it is Not frozen
	if (!freeze_flag){
		ctrl_key = keys[KEY_RIGHT];
	}

	// clear interrupt in Interrupt block
	XIntc_Acknowledge(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_R_INTR);
}

// button Down means drop
void IntrButton_D_Handler(void *CallbackRef){
    // set the refresh flag
    refresh_flag = 1;
#ifdef DEBUG_C
	print("Enter Button Down Interrupt Handler\r\n");
#endif

	// only handle the button when it is Not frozen
	if (!freeze_flag){
		ctrl_key = keys[KEY_DROP];
	}

	// clear interrupt in Interrupt block
	XIntc_Acknowledge(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_D_INTR);
}

// button C means rotate
void IntrButton_C_Handler(void *CallbackRef){
    // set the refresh flag
    refresh_flag = 1;

#ifdef DEBUG_C
	print("Enter Button Center Interrupt Handler\r\n");
#endif
	// only handle the button when it is Not frozen
	if (!freeze_flag){
		ctrl_key = keys[KEY_ROTATE];
	}

	// clear interrupt in Interrupt block
	XIntc_Acknowledge(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_C_INTR);
}

// Restart Switch handler, Intr_Restart_Handler
void Intr_Restart_Handler(void *CallbackRef){
    // set the refresh flag
    refresh_flag = 1;
    // clear the freeze flag
    freeze_flag = 0;

#ifdef DEBUG_C
	print("Enter Restart Interrupt Handler\r\n");
#endif
    ctrl_key = keys[KEY_RESET];
	// clear interrupt in Interrupt block
	XIntc_Acknowledge(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_RESTART_S_INTR);
}

void IntrTimerHandler(void *CallbackRef){

	//  need to implement own functionality
#ifdef DEBUG_C
	print("Enter Timer Interrupt Handler\r\n");
#endif

	XTmrCtr *TmrCtrPtr = NULL;
	u8 TmrCtrNumber;
	u32 ControlStatusReg;

	//clear the old sprite in GPU
//	update_board(shape[0],old_pos,CMD_CLR_ONE);

	// draw new sprite
	update_board(shape[0],s_new_pos,CMD_DRAW);

    // clear the valid flag of GPIO
    XGpio_DiscreteWrite(&Gpio_out, GPIO_OUT_CHANNEL, gpio_out_buff & 0b0011111111111111);

    // set the refresh flag
    refresh_flag = 1;

    // only handle the button when it is Not frozen
    // assign remain to the ctrl_key
	if (!freeze_flag){
		ctrl_key = keys[KEY_REMAIN];
	}

	/*
	 * Verify that each of the inputs are valid.
	 */
	Xil_AssertVoid(CallbackRef != NULL);

	/*
	 * Convert the non-typed pointer to an timer/counter instance pointer
	 * such that there is access to the timer/counter
	 */
	TmrCtrPtr = (XTmrCtr *) CallbackRef;

	/*
	 * Loop thru each timer counter in the device and call the callback
	 * function for each timer which has caused an interrupt
	 */
	for (TmrCtrNumber = 0; TmrCtrNumber < XTC_DEVICE_TIMER_COUNT; TmrCtrNumber++) {

		ControlStatusReg = XTmrCtr_ReadReg(TmrCtrPtr->BaseAddress,
				TmrCtrNumber,
				XTC_TCSR_OFFSET);
		/*
		 * Check if interrupt is enabled
		 */
		if (ControlStatusReg & XTC_CSR_ENABLE_INT_MASK) {

			/*
			 * Check if timer expired and interrupt occured
			 */
			if (ControlStatusReg & XTC_CSR_INT_OCCURED_MASK) {
				/*
				 * Increment statistics for the number of
				 * interrupts and call the callback to handle
				 * any application specific processing
				 */
				TmrCtrPtr->Stats.Interrupts++;
				TmrCtrPtr->Handler(TmrCtrPtr->CallBackRef,
						TmrCtrNumber);
				/*
				 * Read the new Control/Status Register content.
				 */
				ControlStatusReg =
						XTmrCtr_ReadReg(TmrCtrPtr->BaseAddress,
								TmrCtrNumber,
								XTC_TCSR_OFFSET);
				/*
				 * If in compare mode and a single shot rather
				 * than auto reload mode then disable the timer
				 * and reset it such so that the interrupt can
				 * be acknowledged, this should be only temporary
				 * till the hardware is fixed
				 */
				if (((ControlStatusReg &
						XTC_CSR_AUTO_RELOAD_MASK) == 0) &&
						((ControlStatusReg &
								XTC_CSR_CAPTURE_MODE_MASK) == 0)) {
					/*
					 * Disable the timer counter and
					 * reset it such that the timer
					 * counter is loaded with the
					 * reset value allowing the
					 * interrupt to be acknowledged
					 */
					ControlStatusReg &=
							(u32)~XTC_CSR_ENABLE_TMR_MASK;

					XTmrCtr_WriteReg(
							TmrCtrPtr->BaseAddress,
							TmrCtrNumber,
							XTC_TCSR_OFFSET,
							ControlStatusReg |
							XTC_CSR_LOAD_MASK);

					/*
					 * Clear the reset condition,
					 * the reset bit must be
					 * manually cleared by a 2nd write
					 * to the register
					 */
					XTmrCtr_WriteReg(
							TmrCtrPtr->BaseAddress,
							TmrCtrNumber,
							XTC_TCSR_OFFSET,
							ControlStatusReg);
				}

				/*
				 * Acknowledge the interrupt by clearing the
				 * interrupt bit in the timer control status
				 * register, this is done after calling the
				 * handler so the application could call
				 * IsExpired, the interrupt is cleared by
				 * writing a 1 to the interrupt bit of the
				 * register without changing any of the other
				 * bits
				 */
				XTmrCtr_WriteReg(TmrCtrPtr->BaseAddress,
						TmrCtrNumber,
						XTC_TCSR_OFFSET,
						ControlStatusReg |
						XTC_CSR_INT_OCCURED_MASK);
			}
		}
	}


}


int main() {
    int status;
    u32 DataRead;

    int  i, j, *ptr;
	int pos = B_COLS+B_COLS/2;  //  the center of second row, starting point
	int *backup;

	char curr_key;

#ifdef DEBUG_C

	int temp_cnt_1 = 0;
#endif
	// save the old pos
	old_pos = pos;
	s_new_pos = pos;

    Xil_ICacheEnable();
    Xil_DCacheEnable();
    print("---Entering main---\r\n");

    // Initialize GPIO_out controller
    status = XGpio_Initialize(&Gpio_out, XPAR_GPIO_0_DEVICE_ID);
    XGpio_LookupConfig(XPAR_GPIO_0_DEVICE_ID);
    XGpio_SetDataDirection(&Gpio_out, 1, 0);

    // Initialize timer controller
    status = XTmrCtr_Initialize(&_axi_timer, XPAR_TMRCTR_0_DEVICE_ID);
    XTmrCtr_SetResetValue(&_axi_timer, 0, 0xAFFFFFF);
    XTmrCtr_SetOptions(&_axi_timer, 0, XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION | XTC_DOWN_COUNT_OPTION);

    // Initialize interrupt controller
    status = XIntc_Initialize(&intc, XPAR_INTC_0_DEVICE_ID);
    #ifdef DEBUG_C
        if (status == XST_SUCCESS) {
            print("Interrupt Block initialization succeed\r\n");
        } else {
            print("Interrupt Block initialization FAILED\r\n");
        }
    #endif

    // Connect interrupt handlers for buttons
    status = XIntc_Connect(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_U_INTR, (XInterruptHandler)IntrButton_U_Handler, &Gpio_out);
    status = XIntc_Connect(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_L_INTR, (XInterruptHandler)IntrButton_L_Handler, &Gpio_out);
    status = XIntc_Connect(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_R_INTR, (XInterruptHandler)IntrButton_R_Handler, &Gpio_out);
    status = XIntc_Connect(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_D_INTR, (XInterruptHandler)IntrButton_D_Handler, &Gpio_out);
    status = XIntc_Connect(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_C_INTR, (XInterruptHandler)IntrButton_C_Handler, &Gpio_out);
    status = XIntc_Connect(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_RESTART_S_INTR, (XInterruptHandler)Intr_Restart_Handler, &Gpio_out);


    // Enable interrupts for buttons
    XIntc_Enable(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_U_INTR);
    XIntc_Enable(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_L_INTR);
    XIntc_Enable(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_R_INTR);
    XIntc_Enable(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_D_INTR);
    XIntc_Enable(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_BUTTON_C_INTR);
    XIntc_Enable(&intc, XPAR_MICROBLAZE_RISCV_0_AXI_INTC_SYSTEM_RESTART_S_INTR);



    // Connect interrupt handler for timer
    status = XIntc_Connect(&intc, XPAR_INTC_0_TMRCTR_0_VEC_ID, (XInterruptHandler)IntrTimerHandler, &_axi_timer);

#ifdef DEBUG_C
    if (status == XST_SUCCESS) {
        print("Connect Timer interrupt succeed\r\n");
    } else {
        print("Connect Timer interrupt FAILED\r\n");
    }
#endif

    // Enable interrupt vector in interrupt controller
    XIntc_Enable(&intc, XPAR_INTC_0_TMRCTR_0_VEC_ID);

    // Start interrupt controller
    XIntc_Start(&intc, XIN_REAL_MODE);

    // Initialize exception table and register interrupt controller handler
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XIntc_InterruptHandler, &intc);
    Xil_ExceptionEnable();

    // Start timer
    XTmrCtr_Start(&_axi_timer, 0);

    // initialize board in both software and GPU
	ptr = board;
	for (i = B_SIZE; i; i--){
        // i < 2*B_COLS+1 the bottom line of the table
        // i % B_COLS < 2 the left and right boarder of the table
        *ptr++ = i < 2*B_COLS+1 || i % B_COLS < 2 ? 7 : 0;
    }
    update_board(S_EMPTY,0,CMD_CLR_BOARD);

    // Read timer counter
    XTmrCtr *temp = &_axi_timer;
    DataRead = XTmrCtr_ReadReg(temp->BaseAddress, 0, XTC_TCR_OFFSET);
	
    // generate a random seed according to time
    my_srand(DataRead);
    // get next shape
    shape = next_shape();
    old_shape = *shape;

    ctrl_key = keys[KEY_REMAIN];

	while (running) {

		curr_key =  ctrl_key;

        if (curr_key == keys[KEY_RESET])
        {
			// Initialize board, grey border
			ptr = board;
			for (i = B_SIZE; i; i--)
			{
				// i < 2*B_COLS+1 the bottom line of the table
				// i % B_COLS < 2 the left and right boarder of the table
				*ptr++ = i < 2*B_COLS+1 || i % B_COLS < 2 ? 60 : 0;
			}
            update_board(S_EMPTY,0,CMD_CLR_BOARD);
        }
        // refresh the board when the time/button interrupt happens
        if(refresh_flag) {

		#ifdef DEBUG_C
        	temp_cnt_1++;
        	xil_printf("\nRefresh operation for %d times\r\n", temp_cnt_1);
        	xil_printf("\ncurr_key = %c\r\n", curr_key);
        	xil_printf("\nOld pos = %d\r\n", pos);
		#endif

            // if this cycle is due to timer
            if (curr_key == keys[KEY_REMAIN])
        	{
                // chech if the sprite can move downwards further
                if (fits_in(shape, pos + B_COLS))
                {
                	// save the old pos
					old_pos = pos;
                    //clear the old sprite for GPU
                    update_board(shape[0],old_pos,CMD_CLR_ONE);
                    // clear old sprit for game logic
                    place(shape, pos, 0);

                    // move to next position
                    pos += B_COLS;
                    s_new_pos = pos;
                }
                else        // cannot drop further
                {
                    // place the shape in software
                    place(shape, pos, color);
                    // draw the shape with GPU, shape[0] is the type index of shape
                    update_board(shape[0],pos,CMD_DRAW);

                    // scan the blocks of the board except the boarder to find full line
                    for (j = 0; j < B_SIZE-2*B_COLS; j = B_COLS * (j / B_COLS + 1)) {
                        for (; board[++j];) {
                            if (j % B_COLS == B_COLS-2) {
                                lines_cleared++;

                                // clear the line with GPU, j-B_COLs+3 is the start pos of the line
                                // GPU should move the upper line down
                                update_board(S_EMPTY,j-B_COLS+3,CMD_CLR_LINE);

                                // clear the line in software code
                                for (; j % B_COLS; board[j--] = 0)
                                ;

                                // move the upper row down after clear one line
                                for (; --j; board[j + B_COLS] = board[j])
                                ;

                            }
                        }
                    }

                    old_shape = *shape;
                    shape = next_shape();


                    if (!fits_in(shape, pos = B_COLS+B_COLS/2)){
                        // when it is full pause there
                        ctrl_key = keys[KEY_PAUSE];
                        // only when freeze flag is set the interrupt will not change ctrl_key, except the pause/unpause button
                        freeze_flag =1;

                        #ifdef DEBUG_C
                            print("\nFull! Stop!\r\n");
                        #endif
                    }else{
                        // increase the point when the next shape is ready and it is not full
                         ++points;
                    }

                    s_new_pos = pos;

                }
            }

            if (curr_key == keys[KEY_LEFT]) {


                if (fits_in(shape, pos-1)){
                	// clear old sprit for game logic
					place(shape, pos, 0);
					// save the old pos
					old_pos = pos;
	                // change pos
					--pos;
					s_new_pos = pos;
					//clear the old sprite in GPU
					update_board(shape[0],old_pos,CMD_CLR_ONE);
                }

            }

            if (curr_key ==  keys[KEY_ROTATE]) {
                backup = shape;
                old_shape = *shape;
                shape = &shapes[5 * *shape];	/* Rotate */
                /* Check if it fits, if not restore shape from backup */
                if (!fits_in(shape, pos)){
                    shape = backup;
                }
                else{		// fit update the board
                	// save the old pos
					old_pos = pos;
                	//clear the old sprite
					update_board(old_shape,pos,CMD_CLR_ONE);
					// clear old sprit for game logic
					place(shape, pos, 0);
                }
            }

            if (curr_key ==  keys[KEY_RIGHT]) {
                if (fits_in(shape, pos+1)){
                	// save the old pos
					old_pos = pos;
                    // clear old sprit for game logic
                    place(shape, pos, 0);
                    // change pos
                    ++pos;
                    s_new_pos = pos;
                	//clear the old sprite in GPU
                	update_board(shape[0],old_pos,CMD_CLR_ONE);
//                	// draw new sprite
//                	update_board(shape[0],new_pos,CMD_DRAW);
                }

            }

            if (curr_key ==  keys[KEY_DROP]) {
            	// save the old pos
				old_pos = pos;
                //clear the old sprite
                update_board(shape[0],pos,CMD_CLR_ONE);
                // clear old sprit for game logic
				place(shape, pos, 0);
                for (; fits_in(shape, pos + B_COLS); ++points){
                    pos += B_COLS;
                    s_new_pos = pos;
                }
            }

			place(shape, pos, color);
			// draw the new sprite at new pos
			update_board(shape[0],pos,CMD_DRAW);

            // pause here can only be ctrl_key instead of curr_key,
            // otherwise it will never breakout from the loop
            while (ctrl_key ==  keys[KEY_PAUSE])
			   ;

            // clear the flag, wait until next interrupt
            refresh_flag = 0;

            // save the old pos
//            old_pos = pos;

        	//clear the old sprite in GPU
//        	update_board(old_shape,old_pos,CMD_CLR_ONE);

            // clear old sprit for game logic
			place(shape, pos, 0);

        }
	}

    print("---Exiting main---\r\n");
    Xil_DCacheDisable();
    Xil_ICacheDisable();
    return 0;
}
