CP = copy
RM = rm -f
CC = sdcc
AS = sdasz80
LD = sdcc
MKBIN = makebin
H2B = hex2bin
MIF = srec_cat

SDIR = src
IDIR = inc
ODIR = obj

CFLAGS = -mz80 --opt-code-size --fomit-frame-pointer -I$(IDIR) -I..
LDFLAGS = -mz80 --code-loc 0x8100 --data-loc 0x7000 --no-std-crt0

_OBJS = crt0.rel mmc.rel pff.rel coleco.rel main.rel
OBJS = $(patsubst %,$(ODIR)/%,$(_OBJS))

all: MULTCART.ROM

MULTCART.ROM: MULTCART.ihx
	$(H2B) -e ROM $<
	fillfile $@ 16384
	$(CP) /y $@ f:\

multcart.ihx: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

.PHONY: clean

clean:
	$(RM) $(ODIR)/* *.map *.lk *.noi *.bin *.ihx *.mif

$(ODIR)/%.rel: $(SDIR)/%.s
	$(AS) -o $@ $<

$(ODIR)/%.rel: $(SDIR)/%.c
	$(CC) $(CFLAGS) -c -o $@ $<
