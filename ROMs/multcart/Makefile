CP = cp
RM = rm -f
CC = sdcc
AS = sdasz80
LD = sdcc
H2B = hex2bin

SDIR = src
IDIR = inc
ODIR = obj

CFLAGS = -mz80 --opt-code-size --fomit-frame-pointer -I$(IDIR) -I..
LDFLAGS = -mz80 --code-loc 0x8100 --data-loc 0x7000 --no-std-crt0

_OBJS = crt0.rel mmc.rel pff.rel coleco.rel main.rel
OBJS = $(patsubst %,$(ODIR)/%,$(_OBJS))

all:  MULTCART.ROM

MULTCART.ROM: MULTCART.ihx
	$(H2B) -l 4000 -e ROM $<

MULTCART.ihx: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

.PHONY: clean dir

clean:
	$(RM) $(ODIR)/* *.map *.lk *.noi *.bin *.ihx


$(ODIR)/%.rel: $(SDIR)/%.s
	$(AS) -o $@ $<

$(ODIR)/%.rel: $(SDIR)/%.c
	$(CC) $(CFLAGS) -c -o $@ $<
