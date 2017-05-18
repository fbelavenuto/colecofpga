
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "vdp.h"

__sfr __at 0x52 CONFIG;
#define peek16(A) (*(volatile unsigned int*)(A))
#define poke16(A,V) *(volatile unsigned int*)(A)=(V)

//                              11111111112222222222333
//                     12345678901234567890123456789012
const char TITULO[] = "      COLECOVISION LOADER       ";


/*******************************************************************************/
void printCenter(unsigned char y, unsigned char *msg)
{
	unsigned char x;

	x = 16 - strlen(msg)/2;
	vdp_gotoxy(x, y);
	vdp_putstring(msg);
}

/*******************************************************************************/
void erro(unsigned char *erro)
{
	vdp_setcolor(COLOR_RED, COLOR_BLACK, COLOR_WHITE);
	printCenter(12, erro);
	for(;;);
}

/*******************************************************************************/
void main()
{
	char *biosfile       = "COLECO  BIO";
	char msg[32];
	unsigned int  ext_cart_id = 0xFFFF;

	vdp_init();
	vdp_setcolor(COLOR_BLACK, COLOR_BLACK, COLOR_WHITE);
	vdp_putstring(TITULO);

	// Test if external cartridge exists
	ext_cart_id = peek16(0x8000);

	sprintf(msg, "%04X", ext_cart_id);
	printCenter(9, msg);
	for(;;);
}
