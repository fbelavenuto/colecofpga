
#include <stdio.h>
#include <string.h>
#include "coleco.h"
#include "pff.h"

__sfr __at 0x43 MACHINE_ID;
__sfr __at 0x44 CFG_PAGE;
__sfr __at 0x45 CART_PAGE_PORT;
__sfr __at 0x46 CART_TOTPAGE_PORT;
__sfr __at 0x50 PSG_ADDRESS; 
__sfr __at 0x51 PSG_VALUE;
__sfr __at 0xFF SN_PORT;  
//extern const sound_t *snd_table;

// Variables
BYTE buff[27];				// ? T80SOC error reading if buff > ~300?
char xp[] = "=>";

//-------------------------------------------------------------------------------
void nmi(void)
{
	//
}

//-------------------------------------------------------------------------------

void silence(void)
{
	BYTE old_address = PSG_ADDRESS;
	BYTE old_value = PSG_VALUE;
	BYTE cnt;

	for (cnt=0; cnt<14; cnt++){
		PSG_ADDRESS=cnt;
		PSG_VALUE=0x00;
	}
    
	SN_PORT=0x9F;
	SN_PORT=0xBF;
	SN_PORT=0xDF;
	SN_PORT=0xFF;
	
	PSG_ADDRESS=old_address;
	PSG_VALUE=old_value;

}

//-------------------------------------------------------------------------------
void die_sd(FRESULT rc)
{
	unsigned int dly1, dly2;
	print_at(12, 18, "Error sd..Reset");
	for (dly1=0; dly1 < 300; ) {
		for(dly2 = 0; dly2 < 1000 ; ) {
			dly2++;
			rc = rc;
		}
		dly1++;
	}
	__asm__("jp 0x0000");
}
void die_menu(FRESULT rc)
{
	unsigned int dly1, dly2;
	print_at(12, 18, "Error menu..Reset");
	for (dly1=0; dly1 < 300; ) {
		for(dly2 = 0; dly2 < 1000 ; ) {
			dly2++;
			rc = rc;
		}
		dly1++;
	}
	__asm__("jp 0x0000");
}
void die_cart(FRESULT rc)
{
	unsigned int dly1, dly2;
	print_at(12, 18, "Error cart..Reset");
	for (dly1=0; dly1 < 300; ) {
		for(dly2 = 0; dly2 < 1000 ; ) {
			dly2++;
			rc = rc;
		}
		dly1++;
	}
	__asm__("jp 0x0000");
}
//-------------------------------------------------------------------------------
void main(void)
{
	FATFS			fatfs;			/* File system object */
	WORD			br;
	BYTE			rc;
	unsigned char	*cp, macid;
	BYTE			snum, cpos;
	WORD			w, dly;
	char			*sp, *s;
	BYTE			fn[15];
	char			cart_name[25];
	char			* cartp;
	BYTE			maxln, page, rcount, select;
	BYTE            act_page = 0;
	long            page_address = 0x8000;

	macid = MACHINE_ID;
    silence();
	vdp_init();
	set_mode1();
	disable_nmi();
	fill_vram(0);
	set_color(0xF4);
	load_ascii();
	screen_on();

	rc = pf_mount(&fatfs);
	if (rc) {
		die_sd(rc);
	}
	rc = pf_open("MENU.TXT");
	if (rc) {
		die_menu(rc);
	}

	select = 0;
	if (macid == 4 || macid == 8) {
		maxln = 15;		// Prototype 2 or CVUNO
	} else {
		maxln = 13;		// Others
	}

	page = CFG_PAGE;
	pf_lseek(page * 27 * maxln);
	do {
		cls();
		if (macid == 4) {
		//                         11111111112222222222333
		//                12345678901234567890123456789012
			print_at(0,1," B:Load A:Return START+SEL:Reset");
		} else {
		//                         11111111112222222222333
		//                12345678901234567890123456789012
			print_at(0,1,"  L-Fire:Load  R-Fire:Restart");
		}
		//                         11111111112222222222333
		//                12345678901234567890123456789012
		print_at(0, 3,   "     U/D:Select   L/R:Page");
		if (macid != 4 && macid != 8) {
			print_at(1,21,"<ESC>Reset <U/D>Sel <L/R>Page");
			print_at(1,22,"<Q>* <W># <Z>L-Fire <X>R-Fire");
		}

		rcount = 0;
		for (;;) {
			rc = pf_read(buff, 27, &br);	/* Read a line of file */
			if (rc || !br) break;			/* Error or end of file */
			rcount++;
			s = strchr(buff, ';');
			*s='\0'; // terminate the cart name
			print_at(4, rcount + 4, buff);
			if (rcount == maxln) { break;}
		}
		cpos = 5; snum = 0;
		print_at(2, cpos, xp);
		// UP  0x0001; RIGHT 0002; DOWN 0x0004 LEFT 0x0008
		for(;;) {
			w = read_joy(0);
			if ((w & _DOWN) && (cpos < rcount+4)) {
				print_at(2, cpos, "  ");
				cpos++;
				print_at(2, cpos, xp);
				snum++;
			} else if ((w & _UP) && (cpos > 5)) {
				print_at(2, cpos, "  ");
				cpos--;
				print_at(2, cpos, xp);
				snum--;
			} else if (w & _LEFT) {
				if (page > 0) page--;
				select = 0;
				rc = pf_lseek(page * 27 * maxln);
				break;
			} else if (w & _RIGHT) {
				if (br > 0) page++;
				select = 0;
				rc = pf_lseek(page * 27 * maxln);
				break;
			}
			if (w & (_RFIRE|_LFIRE)) {
				select = 1;
				break;
			}
			for (dly = 0; dly < 2800; ) {
				dly++;
			}
		}
	} while (select == 0);

	CFG_PAGE = page;
	if (w ==_RFIRE) {
//		__asm__("jp 0x0000");
		goto LOAD;
	}
	rc = pf_lseek(page * 27 * maxln + snum * 27 + 17);
	rc = pf_read(buff, 13, &br);

	sp = strchr(buff, '\r');
	if (sp) *sp = '\0';
	sp = strchr(buff, ' ');
	if (sp) *sp = '\0';
	strcpy(fn, buff);
	strcat(fn, ".rom");
	print_at(4, maxln+6, "Loading");
	print_at(12, maxln+6, fn);

	strcpy(cart_name, "Coleco/");
	cartp = strcat(cart_name, fn);
	rc = pf_open(cartp);
	if (rc) die_cart(rc);
     
	

	act_page=0; 
	CART_TOTPAGE_PORT=0;
	CART_PAGE_PORT=0;
	for (;;) {
		cp = (unsigned char *) 0x8000;
		rc = pf_read(cp, 16384, &br);	/* Read a chunk of file */
	    if (rc || !br) break;			/* Error or end of file */
		act_page++;
		CART_PAGE_PORT=act_page;
	}
    if (rc) die_cart(rc);
	CART_TOTPAGE_PORT=act_page-1;

LOAD:
	cp = (unsigned char *)0x7100;

	*cp++=0x3e;		// LD A, 0
	*cp++=0x00;
	*cp++=0xd3;		// OUT (0x42), A
	*cp++=0x42;
	*cp++=0xc3;		// JP 0
	*cp++=0x00;
	*cp++=0x00;
	__asm__("jp 0x7100");
}
