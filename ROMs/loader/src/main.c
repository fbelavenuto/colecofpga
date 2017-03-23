
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "joy.h"
#include "vdp.h"
#include "mmc.h"
#include "fat.h"

static const char biosfiles[3][12] = {
	"COLECO  BIO",
	"ONYX    BIO",
	"SPLICE  BIO"
};
static const char * mcfile    = "MULTCARTROM";

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
	DisableCard();
	vdp_setcolor(COLOR_RED, COLOR_BLACK, COLOR_WHITE);
	printCenter(12, erro);
	for(;;);
}

/*******************************************************************************/
void main()
{
	unsigned char *pbios = (unsigned char *)0x0000;
	unsigned char *pcart = (unsigned char *)0x8000;
	unsigned char *cp    = (unsigned char *)0x7100;
	unsigned char i, joybtns, bi;
	char *biosfile       = NULL;
	char msg[32];
	fileTYPE file;

	vdp_init();
	vdp_setcolor(COLOR_BLACK, COLOR_BLACK, COLOR_WHITE);
	vdp_putstring(TITULO);
//	vdp_gotoxy(10, 10);
//	vdp_putstring("Loading... ");
	joybtns = ReadJoy();
	if ((joybtns & JOY_UP) != 0) {
		bi = 1;
	} else if ((joybtns & JOY_DOWN) != 0) {
		bi = 2;
	} else {
		bi = 0;
	}
	biosfile = (char *)biosfiles[bi];
	strcpy(msg, "Loading ");
	strcat(msg, biosfile);
	printCenter(9, msg);

	if (!MMC_Init()) {										// Inicializar cartão
		erro("Error on SD card initialization!");
	}
	if (!FindDrive()) {										// Abrir partição
		erro("Error monting SD card!");
	}
	if (!FileOpen(&file, biosfile)) {						// Abrir arquivo
		erro("BIOS file not found!");
	}
	if (file.size != 8192) {
		erro("BIOS file size is not 8192!");
	}
	for (i = 0; i < 16; i++) {								// Ler 16 blocos de 512 bytes (8192 bytes)
		if (!FileRead(&file, pbios)) {
			erro("Error reading BIOS file!");
		}
		pbios += 512;
	}
	strcpy(msg, "Loading MULTCART ROM");
	printCenter(10, msg);

	if (!FileOpen(&file, mcfile)) {							// Abrir arquivo
		erro("MULTCART.ROM file not found!");
	}
	if (file.size != 16384) {
		erro("MULTCART.ROM file size wrong!");
	}
	for (i = 0; i < 32; i++) {								// Ler 32 blocos de 512 bytes (16384 bytes)
		if (!FileRead(&file, pcart)) {
			erro("Error reading file MULTCART.ROM");
		}
		pcart += 512;
	}
	vdp_putstring("OK");
	// Disable loader and start BIOS
	*cp++=0x3e;		// LD A, 2
	*cp++=0x02;
	*cp++=0xd3;		// OUT (0x52), A
	*cp++=0x52;
	*cp++=0xc3;		// JP 0
	*cp++=0x00;
	*cp++=0x00;
	__asm__("jp 0x7100");
}
