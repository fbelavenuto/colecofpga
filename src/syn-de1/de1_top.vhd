-------------------------------------------------------------------------------
--
-- Copyright (c) 2016, Fabio Belavenuto (belavenuto@gmail.com)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-------------------------------------------------------------------------------

--
-- Terasic DE1 top-level
--

-- altera message_off 10540 10541

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Generic top-level for Altera DE1 board
entity de1_top is
	generic (
		usar_sdram		: boolean	:= FALSE
	);
	port (
		-- Clocks
		CLOCK_24       : in    std_logic_vector(1 downto 0);
		CLOCK_27       : in    std_logic_vector(1 downto 0);
		CLOCK_50       : in    std_logic;
		EXT_CLOCK      : in    std_logic;

		-- Switches
		SW             : in    std_logic_vector(9 downto 0);
		-- Buttons
		KEY            : in    std_logic_vector(3 downto 0);

		-- 7 segment displays
		HEX0           : out   std_logic_vector(6 downto 0)		:= (others => '1');
		HEX1           : out   std_logic_vector(6 downto 0)		:= (others => '1');
		HEX2           : out   std_logic_vector(6 downto 0)		:= (others => '1');
		HEX3           : out   std_logic_vector(6 downto 0)		:= (others => '1');
		-- Red LEDs
		LEDR           : out   std_logic_vector(9 downto 0)		:= (others => '0');
		-- Green LEDs
		LEDG           : out   std_logic_vector(7 downto 0)		:= (others => '0');

		-- VGA
		VGA_R          : out   std_logic_vector(3 downto 0)		:= (others => '0');
		VGA_G          : out   std_logic_vector(3 downto 0)		:= (others => '0');
		VGA_B          : out   std_logic_vector(3 downto 0)		:= (others => '0');
		VGA_HS         : out   std_logic									:= '0';
		VGA_VS         : out   std_logic									:= '0';

		-- Serial
		UART_RXD       : in    std_logic;
		UART_TXD       : out   std_logic									:= '0';

		-- PS/2 Keyboard
		PS2_CLK        : inout std_logic									:= '1';
		PS2_DAT        : inout std_logic									:= '1';

		-- I2C
		I2C_SCLK       : inout std_logic									:= '1';
		I2C_SDAT       : inout std_logic									:= '1';

		-- Audio
		AUD_XCK        : out   std_logic									:= '0';
		AUD_BCLK       : out   std_logic									:= '0';
		AUD_ADCLRCK    : out   std_logic									:= '0';
		AUD_ADCDAT     : in    std_logic;
		AUD_DACLRCK    : out   std_logic									:= '0';
		AUD_DACDAT     : out   std_logic									:= '0';

		-- SRAM
		SRAM_ADDR      : out   std_logic_vector(17 downto 0)		:= (others => '0');
		SRAM_DQ        : inout std_logic_vector(15 downto 0)		:= (others => '0');
		SRAM_CE_N      : out   std_logic									:= '1';
		SRAM_OE_N      : out   std_logic									:= '1';
		SRAM_WE_N      : out   std_logic									:= '1';
		SRAM_UB_N      : out   std_logic									:= '1';
		SRAM_LB_N      : out   std_logic									:= '1';

		-- SDRAM
		DRAM_ADDR      : out   std_logic_vector(11 downto 0)		:= (others => '0');
		DRAM_DQ        : inout std_logic_vector(15 downto 0)		:= (others => '0');
		DRAM_BA_0      : out   std_logic									:= '1';
		DRAM_BA_1      : out   std_logic									:= '1';
		DRAM_CAS_N     : out   std_logic									:= '1';
		DRAM_CKE       : out   std_logic									:= '1';
		DRAM_CLK       : out   std_logic									:= '1';
		DRAM_CS_N      : out   std_logic									:= '1';
		DRAM_LDQM      : out   std_logic									:= '1';
		DRAM_RAS_N     : out   std_logic									:= '1';
		DRAM_UDQM      : out   std_logic									:= '1';
		DRAM_WE_N      : out   std_logic									:= '1';

		-- Flash
		FL_ADDR        : out   std_logic_vector(21 downto 0)		:= (others => '0');
		FL_DQ          : inout std_logic_vector(7 downto 0)		:= (others => '0');
		FL_RST_N       : out   std_logic									:= '1';
		FL_OE_N        : out   std_logic									:= '1';
		FL_WE_N        : out   std_logic									:= '1';
		FL_CE_N        : out   std_logic									:= '1';

		-- SD card (SPI mode)
		SD_nCS         : out   std_logic									:= '1';
		SD_MOSI        : out   std_logic									:= '1';
		SD_SCLK        : out   std_logic									:= '1';
		SD_MISO        : in    std_logic;

		-- GPIO
		GPIO_0         : inout std_logic_vector(35 downto 0)		:= (others => '0');
		GPIO_1         : inout std_logic_vector(35 downto 0)		:= (others => '0')
	);
end entity;

use work.cv_keys_pack.all;
use work.vdp18_col_pack.all;

architecture behavior of de1_top is

	-- Resets
	signal pll_locked_s		: std_logic;
	signal reset_s				: std_logic;
	signal soft_reset_s		: std_logic;
	signal por_n_s				: std_logic;

	-- Clocks
	signal clock_master_s	: std_logic;
	signal clock_mem_s		: std_logic;
	signal clock_sdram_s		: std_logic;
	signal clk_cnt_q			: unsigned(1 downto 0);
	signal clk_en_10m7_q		: std_logic;
	signal clk_en_5m37_q		: std_logic;

	-- SRAM
	signal sram_addr_s		: std_logic_vector(18 downto 0);		-- 512K
	signal sram_data_o_s		: std_logic_vector(7 downto 0);
	signal sram_ce_s			: std_logic;
	signal sram_oe_s			: std_logic;
	signal sram_we_s			: std_logic;

	-- ROM bios e loader
	signal bios_loader_s		: std_logic;
	signal bios_addr_s		: std_logic_vector(12 downto 0);		-- 8K
	signal bios_data_s		: std_logic_vector(7 downto 0);
	signal loader_data_s		: std_logic_vector(7 downto 0);
	signal bios_ce_s			: std_logic;
	signal bios_oe_s			: std_logic;
	signal bios_we_s			: std_logic;

	-- Cartridge
	signal cart_multcart_s	: std_logic;
	signal cart_addr_s		: std_logic_vector(14 downto 0);		-- 32K
	signal cart_do_s			: std_logic_vector(7 downto 0);
	signal cart_oe_s			: std_logic;
	signal cart_ce_s			: std_logic;
	signal cart_we_s			: std_logic;
	signal cart_en_80_n_s	: std_logic;
	signal cart_en_A0_n_s	: std_logic;
	signal cart_en_C0_n_s	: std_logic;
	signal cart_en_E0_n_s	: std_logic;

	-- RAM memory
	signal ram_addr_s			: std_logic_vector(12 downto 0);		-- 8K
	signal ram_mirr_addr_s	: std_logic_vector(9 downto 0);		-- 1K (mirrored)
	signal ram_do_s			: std_logic_vector(7 downto 0);
	signal ram_di_s			: std_logic_vector(7 downto 0);
	signal ram_ce_s			: std_logic;
	signal ram_oe_s			: std_logic;
	signal ram_we_s			: std_logic;

	-- VRAM memory
	signal vram_addr_s		: std_logic_vector(13 downto 0);		-- 16K
	signal vram_do_s			: std_logic_vector(7 downto 0);
	signal vram_di_s			: std_logic_vector(7 downto 0);
	signal vram_ce_s			: std_logic;
	signal vram_oe_s			: std_logic;
	signal vram_we_s			: std_logic;

	-- Audio
	signal audio_s				: std_logic_vector(7 downto 0);

	-- Video
	signal btn_dblscan_s		: std_logic;
	signal dblscan_en_s		: std_logic;
	signal rgb_col_s			: std_logic_vector( 3 downto 0);		-- 15KHz
	signal rgb_hsync_n_s		: std_logic;								-- 15KHz
	signal rgb_vsync_n_s		: std_logic;								-- 15KHz
	signal vga_col_s			: std_logic_vector( 3 downto 0);		-- 31KHz
	signal vga_hsync_n_s		: std_logic;								-- 31KHz
	signal vga_vsync_n_s		: std_logic;								-- 31KHz

	-- Keyboard
	signal ps2_keys_s			: std_logic_vector(15 downto 0);
	signal ps2_joy_s			: std_logic_vector(15 downto 0);

	-- Controller
	signal ctrl_p1_s			: std_logic_vector( 2 downto 1);
	signal ctrl_p2_s			: std_logic_vector( 2 downto 1);
	signal ctrl_p3_s			: std_logic_vector( 2 downto 1);
	signal ctrl_p4_s			: std_logic_vector( 2 downto 1);
	signal ctrl_p5_s			: std_logic_vector( 2 downto 1);
	signal ctrl_p6_s			: std_logic_vector( 2 downto 1);
	signal ctrl_p7_s			: std_logic_vector( 2 downto 1);
	signal ctrl_p8_s			: std_logic_vector( 2 downto 1);
	signal ctrl_p9_s			: std_logic_vector( 2 downto 1);
	signal but_a_s				: std_logic_vector( 1 downto 0);
	signal but_b_s				: std_logic_vector( 1 downto 0);
	signal but_x_s				: std_logic_vector( 1 downto 0);
	signal but_y_s				: std_logic_vector( 1 downto 0);
	signal but_start_s		: std_logic_vector( 1 downto 0);
	signal but_sel_s			: std_logic_vector( 1 downto 0);
	signal but_tl_s			: std_logic_vector( 1 downto 0);
	signal but_tr_s			: std_logic_vector( 1 downto 0);
	signal but_up_s			: std_logic_vector( 1 downto 0);
	signal but_down_s			: std_logic_vector( 1 downto 0);
	signal but_left_s			: std_logic_vector( 1 downto 0);
	signal but_right_s		: std_logic_vector( 1 downto 0);

	-- SD
	signal spi_cs_s			: std_logic;
	signal spi_data_in_s		: std_logic_vector(7 downto 0);
	signal spi_data_out_s	: std_logic_vector(7 downto 0);

	-- Debug
	signal D_display			: std_logic_vector(15 downto 0);
	signal D_cpu_addr			: std_logic_vector(15 downto 0);

begin

	-- PLL
	pll_1: entity work.pll1
	port map (
		inclk0	=> CLOCK_50,
		c0			=> clock_mem_s,			-- 42.857143 MHz
		c1			=> clock_master_s,		-- 21.428571 MHz
		locked	=> pll_locked_s
	);

	gp2: if usar_sdram = true generate
		pll_2: entity work.pll2
		port map (
			inclk0	=> CLOCK_24(0),
			c0			=> clock_sdram_s,			-- 100 MHz   0º
			c1			=> DRAM_CLK					-- 100 MHz -45º
		);
	end generate;

	-- Power-on reset
	por_b : entity work.cv_por
	port map (
		clock_i		=> clock_master_s,
		por_n_o		=> por_n_s
	);

	-- The colecovision
	vg: entity work.colecovision
	generic map (
		num_maq_g			=> 1,
		is_pal_g				=> 0,
		compat_rgb_g		=> 0
	)
	port map (
		clock_i				=> clock_master_s,
		clk_en_10m7_i		=> clk_en_10m7_q,
		clock_cpu_en_o		=> open,
		reset_i				=> reset_s,
		por_n_i				=> por_n_s,
		-- Controller Interface
		ctrl_p1_i			=> ctrl_p1_s,
		ctrl_p2_i			=> ctrl_p2_s,
		ctrl_p3_i			=> ctrl_p3_s,
		ctrl_p4_i			=> ctrl_p4_s,
		ctrl_p5_o			=> ctrl_p5_s,
		ctrl_p6_i			=> ctrl_p6_s,
		ctrl_p7_i			=> ctrl_p7_s,
		ctrl_p8_o			=> ctrl_p8_s,
		ctrl_p9_i			=> ctrl_p9_s,
		-- BIOS ROM Interface
		bios_loader_o		=> bios_loader_s,
      bios_addr_o			=> bios_addr_s,
      bios_ce_o			=> bios_ce_s,
		bios_oe_o			=> bios_oe_s,
		bios_we_o			=> bios_we_s,
      bios_data_i			=> bios_data_s,
		-- CPU RAM Interface
		ram_addr_o			=> ram_addr_s,
		ram_ce_o				=> ram_ce_s,
		ram_we_o				=> ram_we_s,
		ram_oe_o				=> ram_oe_s,
		ram_data_i			=> ram_do_s,
		ram_data_o			=> ram_di_s,
		-- Video RAM Interface
		vram_addr_o			=> vram_addr_s,
		vram_ce_o			=> vram_ce_s,
		vram_oe_o			=> vram_oe_s,
		vram_we_o			=> vram_we_s,
		vram_data_i			=> vram_do_s,
		vram_data_o			=> vram_di_s,
		-- Cartridge ROM Interface
		cart_multcart_o	=> cart_multcart_s,
		cart_addr_o			=> cart_addr_s,
		cart_en_80_n_o		=> cart_en_80_n_s,
		cart_en_a0_n_o		=> cart_en_A0_n_s,
		cart_en_c0_n_o		=> cart_en_C0_n_s,
		cart_en_e0_n_o		=> cart_en_E0_n_s,
		cart_ce_o			=> cart_ce_s,
		cart_oe_o			=> cart_oe_s,
		cart_we_o			=> cart_we_s,
		cart_data_i			=> cart_do_s,
		-- Audio Interface
		audio_o				=> audio_s,
		audio_signed_o		=> open,
		-- RGB Video Interface
		col_o					=> rgb_col_s, --open,
		rgb_r_o				=> open, --rgb_r_s,
		rgb_g_o				=> open, --rgb_g_s,
		rgb_b_o				=> open, --rgb_b_s,
		hsync_n_o			=> rgb_hsync_n_s,
		vsync_n_o			=> rgb_vsync_n_s,
		comp_sync_n_o		=> open,
		-- SPI
		spi_miso_i			=> SD_MISO,
		spi_mosi_o			=> SD_MOSI,
		spi_sclk_o			=> SD_SCLK,
		spi_cs_n_o			=> SD_nCS,
		-- DEBUG
		D_cpu_addr			=> D_cpu_addr
	 );

	-- SRAM IS61WV25616BLL
	usarsram: if usar_sdram = false generate
		sram0: entity work.dpSRAM_25616
		port map (
			clk_i				=> clock_mem_s,
			-- Port 0
			porta0_addr_i	=> sram_addr_s,
			porta0_ce_i		=> sram_ce_s,
			porta0_oe_i		=> sram_oe_s,
			porta0_we_i		=> sram_we_s,
			porta0_d_i		=> ram_di_s,
			porta0_d_o		=> sram_data_o_s,
			-- Port 1
			porta1_addr_i	=> "01000" & vram_addr_s,
			porta1_ce_i		=> vram_ce_s,
			porta1_oe_i		=> vram_oe_s,
			porta1_we_i		=> vram_we_s,
			porta1_d_i		=> vram_di_s,-- (others => '0'),
			porta1_d_o		=> vram_do_s,-- open,
			-- SRAM in board
			sram_addr_o		=> SRAM_ADDR,
			sram_data_io	=> SRAM_DQ,
			sram_ub_o		=> SRAM_UB_N,
			sram_lb_o		=> SRAM_LB_N,
			sram_ce_n_o		=> SRAM_CE_N,
			sram_oe_n_o		=> SRAM_OE_N,
			sram_we_n_o		=> SRAM_WE_N
		);
	end generate;

	-- SDRAM
	usarsdram: if usar_sdram = true generate
		sdram0: entity work.dpSDRAM64Mb
		generic map (
			freq_g			=> 100
		)
		port map (
			clock_i			=> clock_sdram_s,
			reset_i			=> reset_s,
			refresh_i		=> '1',
			-- Port 0
			port0_cs_i		=> vram_ce_s,
			port0_oe_i		=> vram_oe_s,
			port0_we_i		=> vram_we_s,
			port0_addr_i	=> "000001000" & vram_addr_s,
			port0_data_i	=> vram_di_s,
			port0_data_o	=> vram_do_s,
			-- Port 1
			port1_cs_i		=> sram_ce_s,
			port1_oe_i		=> sram_oe_s,
			port1_we_i		=> sram_we_s,
			port1_addr_i	=> "0000" & sram_addr_s,
			port1_data_i	=> ram_di_s,
			port1_data_o	=> sram_data_o_s,
			-- SDRAM in board
			mem_cke_o		=> DRAM_CKE,
			mem_cs_n_o		=> DRAM_CS_N,
			mem_ras_n_o		=> DRAM_RAS_N,
			mem_cas_n_o		=> DRAM_CAS_N,
			mem_we_n_o		=> DRAM_WE_N,
			mem_udq_o		=> DRAM_UDQM,
			mem_ldq_o		=> DRAM_LDQM,
			mem_ba_o(1)		=> DRAM_BA_1,
			mem_ba_o(0)		=> DRAM_BA_0,
			mem_addr_o		=> DRAM_ADDR,
			mem_data_io		=> DRAM_DQ
		);
	end generate;

	-- Audio
	audioout: entity work.Audio_WM8731
	port map (
		clock_i			=> CLOCK_24(0),
		reset_i			=> reset_s,
		psg_i				=> audio_s,

		i2s_xck_o		=> AUD_XCK,
		i2s_bclk_o		=> AUD_BCLK,
		i2s_adclrck_o	=> AUD_ADCLRCK,
		i2s_adcdat_i	=> AUD_ADCDAT,
		i2s_daclrck_o	=> AUD_DACLRCK,
		i2s_dacdat_o	=> AUD_DACDAT,

		i2c_sda_io		=> I2C_SDAT,
		i2c_scl_io		=> I2C_SCLK
	);

	-- Key debounce
	btndbl: entity work.debounce
	generic map (
		counter_size_g	=> 16
	)
	port map (
		clk_i				=> clock_master_s,
		button_i			=> KEY(1),
		result_o			=> btn_dblscan_s
	);

	-- VGA Scandoubler
	dblscan_b : entity work.dblscan
	port map (
		clk_6m_i			=> clock_master_s,
		clk_en_6m_i		=> clk_en_5m37_q,
		clk_12m_i		=> clock_master_s,
		clk_en_12m_i	=> clk_en_10m7_q,
		col_i				=> rgb_col_s,
		col_o				=> vga_col_s,
		hsync_n_i		=> rgb_hsync_n_s,
		vsync_n_i		=> rgb_vsync_n_s,
		hsync_n_o		=> vga_hsync_n_s,
		vsync_n_o		=> vga_vsync_n_s,
		blank_o			=> open
	);

	-- Controller
	-- PS/2 keyboard interface
	ps2if_inst : entity work.colecoKeyboard
	port map (
		clk		=> clock_master_s,
		reset		=> reset_s,
		-- inputs from PS/2 port
		ps2_clk	=> PS2_CLK,
		ps2_data	=> PS2_DAT,
		-- user outputs
		keys		=> ps2_keys_s,
		joy		=> ps2_joy_s
	);

	-- Glue logic
	reset_s		<= not pll_locked_s or not KEY(0) or soft_reset_s;

	-----------------------------------------------------------------------------
	-- Process clk_cnt
	--
	-- Purpose:
	--   Counts the base clock and derives the clock enables.
	--
	clk_cnt: process (clock_master_s, por_n_s)
	begin
		if por_n_s = '0' then
			clk_cnt_q		<= (others => '0');
			clk_en_10m7_q	<= '0';
			clk_en_5m37_q	<= '0';

		elsif rising_edge(clock_master_s) then
	 
			-- Clock counter --------------------------------------------------------
			if clk_cnt_q = 3 then
				clk_cnt_q <= (others => '0');
			else
				clk_cnt_q <= clk_cnt_q + 1;
			end if;

			-- 10.7 MHz clock enable ------------------------------------------------
			case clk_cnt_q is
				when "01" | "11" =>
					clk_en_10m7_q <= '1';
				when others =>
					clk_en_10m7_q <= '0';
			end case;

			-- 5.37 MHz clock enable ------------------------------------------------
			case clk_cnt_q is
				when "11" =>
					clk_en_5m37_q <= '1';
				when others =>
					clk_en_5m37_q <= '0';
			end case;
		end if;
	end process clk_cnt;

	-- Loader
	lr: entity work.loaderrom
	port map (
		clk		=> clock_master_s,
		addr		=> bios_addr_s,
		data		=> loader_data_s
	);

	-- RAM
	ram_mirr_addr_s	<= ram_addr_s(9 downto 0);

	sram_addr_s	<=
		"000000" & bios_addr_s			when bios_ce_s = '1'																	else
		"000011" & ram_addr_s			when ram_ce_s = '1'	and cart_multcart_s = '1'								else	-- 8K linear RAM
		"000011100" & ram_mirr_addr_s	when ram_ce_s = '1'	and cart_multcart_s = '0'								else	-- 1K mirrored RAM
		"0001"   & cart_addr_s			when cart_ce_s = '1' and bios_loader_s = '1'									else
		"0001"   & cart_addr_s			when cart_ce_s = '1' and cart_multcart_s = '1' and cart_oe_s = '1'	else
		"0010"   & cart_addr_s			when cart_ce_s = '1' and cart_multcart_s = '1' and cart_we_s = '1'	else
		"0010"   & cart_addr_s			when cart_ce_s = '1' and cart_multcart_s = '0'								else
		(others => '0');

	sram_ce_s	<= ram_ce_s or bios_ce_s or cart_ce_s;
	sram_oe_s	<= ram_oe_s or bios_oe_s or cart_oe_s;
	sram_we_s	<= ram_we_s or bios_we_s or cart_we_s;

	bios_data_s		<= loader_data_s					when bios_loader_s = '1'	else 	sram_data_o_s;
	ram_do_s			<= sram_data_o_s;
	cart_do_s		<= sram_data_o_s;

	-- scandoubler
	process (por_n_s, btn_dblscan_s)
	begin
		if por_n_s = '0' then
			dblscan_en_s <= '1';							-- Enabled by default
		elsif falling_edge(btn_dblscan_s) then
			dblscan_en_s <= not dblscan_en_s;
		end if;
	end process;

	-----------------------------------------------------------------------------
	-- VGA Output
	-----------------------------------------------------------------------------
	-- Process vga_col
	--
	-- Purpose:
	--   Converts the color information (doubled to VGA scan) to RGB values.
	--
	vga_col : process (clock_master_s, reset_s)
		variable vga_col_v : natural range 0 to 15;
		variable vga_r_v,
					vga_g_v,
					vga_b_v   : rgb_val_t;
	begin
		if reset_s = '1' then
			VGA_R		<= (others => '0');
			VGA_G		<= (others => '0');
			VGA_B		<= (others => '0');
		elsif rising_edge(clock_master_s) then
			if clk_en_10m7_q = '1' then
				if dblscan_en_s = '0' then
					vga_col_v := to_integer(unsigned(rgb_col_s));
				else
					vga_col_v := to_integer(unsigned(vga_col_s));
				end if;
				vga_r_v	:= full_rgb_table_c(vga_col_v)(r_c);
				vga_g_v	:= full_rgb_table_c(vga_col_v)(g_c);
				vga_b_v	:= full_rgb_table_c(vga_col_v)(b_c);
				VGA_R		<= std_logic_vector(to_unsigned(vga_r_v, 8))(7 downto 4);
				VGA_G		<= std_logic_vector(to_unsigned(vga_g_v, 8))(7 downto 4);
				VGA_B		<= std_logic_vector(to_unsigned(vga_b_v, 8))(7 downto 4);
			end if;
		end if;
	end process vga_col;

	VGA_HS	<= rgb_hsync_n_s	when dblscan_en_s = '0'		else vga_hsync_n_s;
	VGA_VS	<= rgb_vsync_n_s	when dblscan_en_s = '0'		else vga_vsync_n_s;

	-----------------------------------------------------------------------------
	-- Process pad_ctrl
	--
	-- Purpose:
	--   Maps the gamepad signals to the controller buses of the console.
	--
	pad_ctrl: process (ctrl_p5_s, ctrl_p8_s, ps2_keys_s, ps2_joy_s)
		variable key_v : natural range cv_keys_t'range;
	begin
		-- quadrature device not implemented
		ctrl_p7_s          <= "11";
		ctrl_p9_s          <= "11";

		--------------------------------------------------------------------
		-- soft reset to get to cart menu : use ps2 ESC key in keys(8)
		if ps2_keys_s(8) = '1' then
			soft_reset_s <= '1';
		else
			soft_reset_s <= '0';
		end if;
		------------------------------------------------------------------------

		for idx in 1 to 2 loop -- was 2
			if ctrl_p5_s(idx) = '0' and ctrl_p8_s(idx) = '1' then
				-- keys and right button enabled --------------------------------------
				-- keys not fully implemented

				key_v := cv_key_none_c;

				if ps2_keys_s(13) = '1' then
					-- KEY 1
					key_v := cv_key_1_c;
				elsif ps2_keys_s(7) = '1' then
					-- KEY 2
					key_v := cv_key_2_c;
				elsif ps2_keys_s(12) = '1' then
					-- KEY 3
					key_v := cv_key_3_c;
				elsif ps2_keys_s(2) = '1' then
					-- KEY 4
					key_v := cv_key_4_c;
				elsif ps2_keys_s(3) = '1' then
					-- KEY 5
					key_v := cv_key_5_c;	
				elsif ps2_keys_s(14) = '1' then
					-- KEY 6
					key_v := cv_key_6_c;
				elsif ps2_keys_s(5) = '1' then
					-- KEY 7
					key_v := cv_key_7_c;				
				elsif ps2_keys_s(1) = '1' then
					-- KEY 8
					key_v := cv_key_8_c;				
				elsif ps2_keys_s(11) = '1' then
					-- KEY 9
					key_v := cv_key_9_c;
				elsif ps2_keys_s(10) = '1' then
					-- KEY 0
					key_v := cv_key_0_c;
				elsif ps2_keys_s(6) = '1' then
					-- KEY *
					key_v := cv_key_asterisk_c;
				elsif ps2_keys_s(9) = '1' then
					-- KEY #
					key_v := cv_key_number_c;
				end if;

				ctrl_p1_s(idx) <= cv_keys_c(key_v)(1);
				ctrl_p2_s(idx) <= cv_keys_c(key_v)(2);
				ctrl_p3_s(idx) <= cv_keys_c(key_v)(3);
				ctrl_p4_s(idx) <= cv_keys_c(key_v)(4);

				if (idx = 1) then
					ctrl_p6_s(idx) <= not ps2_keys_s(0); -- button right (0)
				else
					ctrl_p6_s(idx) <= not ps2_joy_s(4);
				end if;
		  
			elsif ctrl_p5_s(idx) = '1' and ctrl_p8_s(idx) = '0' then
				-- joystick and left button enabled -----------------------------------
				ctrl_p1_s(idx) <= not ps2_joy_s(0);	-- up
				ctrl_p2_s(idx) <= not ps2_joy_s(1); -- down
				ctrl_p3_s(idx) <= not ps2_joy_s(2); -- left
				ctrl_p4_s(idx) <= not ps2_joy_s(3); -- right
		  
				if (idx = 1) then
					ctrl_p6_s(idx) <= not ps2_joy_s(4); -- button left (4)
				else
					ctrl_p6_s(idx) <= not ps2_keys_s(0); -- button right(0)
				end if;
			
			else
				-- nothing active -----------------------------------------------------
				ctrl_p1_s(idx) <= '1';
				ctrl_p2_s(idx) <= '1';
				ctrl_p3_s(idx) <= '1';
				ctrl_p4_s(idx) <= '1';
				ctrl_p6_s(idx) <= '1';
				ctrl_p7_s(idx) <= '1';
			end if;
		end loop;
	end process pad_ctrl;	 


	-- DEBUG

	LEDG(7) <= reset_s;

--	LEDG(1) <= bios_ce_n_s;
	LEDG(6) <= dblscan_en_s;


	--D_display		<= "00000000" & std_logic_vector(audio_s);
	D_display	<= D_cpu_addr;

	ld3: entity work.seg7
	port map(
		D		=> D_display(15 downto 12),
		Q		=> HEX3
	);

	ld2: entity work.seg7
	port map(
		D		=> D_display(11 downto 8),
		Q		=> HEX2
	);

	ld1: entity work.seg7
	port map(
		D		=> D_display(7 downto 4),
		Q		=> HEX1
	);

	ld0: entity work.seg7
	port map(
		D		=> D_display(3 downto 0),
		Q		=> HEX0
	);

end architecture;