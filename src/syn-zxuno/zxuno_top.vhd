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
-- ZX-Uno board TOP
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity zxuno_top is
	port (
		-- Clocks
		clock_50_i			: in    std_logic;

		-- SRAM (AS7C34096)
		sram_addr_o			: out   std_logic_vector(18 downto 0)	:= (others => '0');
		sram_data_io		: inout std_logic_vector(7 downto 0)	:= (others => 'Z');
		sram_we_n_o			: out   std_logic								:= '1';

		-- PS2
		ps2_clk_io			: inout std_logic								:= 'Z';
		ps2_data_io			: inout std_logic								:= 'Z';
		ps2_mouse_clk_io  : inout std_logic								:= 'Z';
		ps2_mouse_data_io : inout std_logic								:= 'Z';

		-- SD Card
		sd_cs_n_o			: out   std_logic								:= '1';
		sd_sclk_o			: out   std_logic								:= '0';
		sd_mosi_o			: out   std_logic								:= '0';
		sd_miso_i			: in    std_logic;

		-- Flash
		flash_cs_n_o		: out   std_logic								:= '1';
		flash_sclk_o		: out   std_logic								:= '0';
		flash_mosi_o		: out   std_logic								:= '0';
		flash_miso_i		: in    std_logic;
		flash_wp_o			: out   std_logic								:= '0';
		flash_hold_o		: out   std_logic								:= '1';

		-- Joystick
		joy_up_i				: in    std_logic;
		joy_down_i			: in    std_logic;
		joy_left_i			: in    std_logic;
		joy_right_i			: in    std_logic;
		joy_fire1_i			: in    std_logic;
		joy_fire2_i			: in    std_logic;
--		joy_fire3_i			: in    std_logic;

		-- Audio
		dac_l_o				: out   std_logic								:= '0';
		dac_r_o				: out   std_logic								:= '0';
		ear_i					: in    std_logic;

		-- VGA
		vga_r_o				: out   std_logic_vector(2 downto 0)	:= (others => '0');
		vga_g_o				: out   std_logic_vector(2 downto 0)	:= (others => '0');
		vga_b_o				: out   std_logic_vector(2 downto 0)	:= (others => '0');
		vga_csync_n_o		: out   std_logic								:= '1';
		vga_vsync_n_o		: out   std_logic								:= '1';
		vga_ntsc_o			: out   std_logic								:= '1';
		vga_pal_o			: out   std_logic								:= '0';

		-- GPIO
--		gpio_io				: inout std_logic_vector(35 downto 6)	:= (others => 'Z');

		-- Debug
		led_o					: out   std_logic								:= '0'
	);
end entity;

use work.cv_keys_pack.all;
use work.vdp18_col_pack.all;

architecture behavior of zxuno_top is

	-- Clocks
	signal clock_master_s	: std_logic;
	signal clock_mem_s		: std_logic;
	signal clock_sdram_s		: std_logic;
	signal clk_cnt_q			: unsigned(1 downto 0);
	signal clk_en_10m7_q		: std_logic;
	signal clk_en_5m37_q		: std_logic;

	-- Resets
	signal por_cnt_s			: unsigned(7 downto 0)				:= (others => '1');
	signal por_n_s				: std_logic;
	signal reset_s				: std_logic;
	signal soft_reset_s		: std_logic;
	signal core_reload_s		: std_logic;

	-- SRAM
	signal sram_addr_s		: std_logic_vector(18 downto 0);		-- 512K
	signal sram_data_o_s		: std_logic_vector(7 downto 0);
	signal sram_ce_s			: std_logic;
	signal sram_oe_s			: std_logic;
	signal sram_we_s			: std_logic;

	-- ROM bios and loader
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
	signal audio_signed_s	: signed(7 downto 0);
	signal audio_s				: std_logic_vector(7 downto 0);
	signal audio_dac_s		: std_logic;

	-- Video
	signal rgb_col_s			: std_logic_vector( 3 downto 0);		-- 15KHz
	signal rgb_hsync_n_s		: std_logic;								-- 15KHz
	signal rgb_vsync_n_s		: std_logic;								-- 15KHz

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
	signal sd_cs_n_s			: std_logic;

begin

	-- PLL
	pll_1: entity work.pll1
	port map (
		CLK_IN1	=> clock_50_i,					-- 50.000
		CLK_OUT1	=> clock_master_s,			-- 21.429 (21,47727 MHz)
		CLK_OUT2	=> clock_mem_s					-- 42.857
	);

	-- The Colecovision
	vg: entity work.colecovision
	generic map (
		num_maq_g			=> 7,
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
		audio_o				=> open,
		audio_signed_o		=> audio_signed_s,
		-- RGB Video Interface
		col_o					=> rgb_col_s,
		rgb_r_o				=> open,
		rgb_g_o				=> open,
		rgb_b_o				=> open,
		hsync_n_o			=> rgb_hsync_n_s,
		vsync_n_o			=> rgb_vsync_n_s,
		comp_sync_n_o		=> open,
		-- SPI
		spi_miso_i			=> sd_miso_i,
		spi_mosi_o			=> sd_mosi_o,
		spi_sclk_o			=> sd_sclk_o,
		spi_cs_n_o			=> sd_cs_n_s,
		-- DEBUG
		D_cpu_addr			=> open--D_cpu_addr
	 );

	-- SRAM
	sram0: entity work.dpSRAM_5128
	port map (
		clk_i				=> clock_mem_s,
		-- Port 0
		porta0_addr_i	=> sram_addr_s,
		porta0_ce_i		=> sram_ce_s,
		porta0_oe_i		=> sram_oe_s,
		porta0_we_i		=> sram_we_s,
		porta0_data_i	=> ram_di_s,
		porta0_data_o	=> sram_data_o_s,
		-- Port 1
		porta1_addr_i	=> "11111" & vram_addr_s,
		porta1_ce_i		=> vram_ce_s,
		porta1_oe_i		=> vram_oe_s,
		porta1_we_i		=> vram_we_s,
		porta1_data_i	=> vram_di_s,
		porta1_data_o	=> vram_do_s,
		-- SRAM in board
		sram_addr_o		=> sram_addr_o,
		sram_data_io	=> sram_data_io,
		sram_ce_n_o		=> open,
		sram_oe_n_o		=> open,
		sram_we_n_o		=> sram_we_n_o
	);

	-- Audio
	audioout: entity work.dac
	generic map (
		msbi_g		=> 7
	)
	port map (
		clk_i		=> clock_master_s,
		res_i		=> reset_s,
		dac_i		=> audio_s,
		dac_o		=> audio_dac_s
	);

	-- Loader
	lr: entity work.loaderrom
	port map (
		clk		=> clock_master_s,
		addr		=> bios_addr_s,
		data		=> loader_data_s
	);

	-- PS/2 keyboard interface
	ps2if_inst : entity work.colecoKeyboard
	port map (
		clk				=> clock_master_s,
		reset				=> reset_s,
		-- inputs from PS/2 port
		ps2_clk			=> ps2_clk_io,
		ps2_data			=> ps2_data_io,
		-- user outputs
		keys				=> ps2_keys_s,
		joy				=> ps2_joy_s,
		core_reload_o	=> core_reload_s
	);

	-- Multiboot
	mb: entity work.multiboot
	port map (
		reset_i		=> reset_s,
		clock_i		=> clock_master_s,
		start_i		=> core_reload_s
	);

	-- Glue logic
	process(clock_master_s)
	begin
		if rising_edge(clock_master_s) then
			if por_cnt_s /= 0 then
				por_cnt_s <= por_cnt_s - 1;
			end if;
		end if;
	end process;

	por_n_s		<= '0' when por_cnt_s /= 0		else '1';
	reset_s		<= not por_n_s or soft_reset_s;

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

	audio_s		<= std_logic_vector(unsigned(audio_signed_s + 128));
	dac_l_o		<= audio_dac_s;
	dac_r_o		<= audio_dac_s;

	sd_cs_n_o	<= sd_cs_n_s;
	led_o			<= not sd_cs_n_s;

	-----------------------------------------------------------------------------
	-- VGA/RGB Output
	-----------------------------------------------------------------------------
	process (clock_master_s)
		variable rgb_col_v	: natural range 0 to 15;
		variable rgb_r_v,
					rgb_g_v,
					rgb_b_v		: rgb_val_t;
		variable vga_r_v,
					vga_g_v,
					vga_b_v		: std_logic_vector(7 downto 0);
	begin
		if rising_edge(clock_master_s) then
			rgb_col_v := to_integer(unsigned(rgb_col_s));
			rgb_r_v	:= full_rgb_table_c(rgb_col_v)(r_c);
			rgb_g_v	:= full_rgb_table_c(rgb_col_v)(g_c);
			rgb_b_v	:= full_rgb_table_c(rgb_col_v)(b_c);
			vga_r_v	:= std_logic_vector(to_unsigned(rgb_r_v, 8));
			vga_g_v	:= std_logic_vector(to_unsigned(rgb_g_v, 8));
			vga_b_v	:= std_logic_vector(to_unsigned(rgb_b_v, 8));
			vga_r_o	<= vga_r_v(7 downto 5);
			vga_g_o	<= vga_g_v(7 downto 5);
			vga_b_o	<= vga_b_v(7 downto 5);
		end if;
	end process vga_col;

	vga_csync_n_o	<= rgb_hsync_n_s and rgb_vsync_n_s;
	vga_vsync_n_o	<= '1';
	vga_ntsc_o		<= '1';
	vga_pal_o		<= '0';

	-- Controller
	-----------------------------------------------------------------------------
	-- Process pad_ctrl
	--
	-- Purpose:
	--   Maps the gamepad signals to the controller buses of the console.
	--
	pad_ctrl: process (ctrl_p5_s, ctrl_p8_s, ps2_keys_s, ps2_joy_s, joy_up_i,
				joy_down_i, joy_left_i, joy_right_i, joy_fire1_i, joy_fire2_i)
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
				ctrl_p1_s(idx) <= not ps2_joy_s(0) and joy_up_i;		-- up
				ctrl_p2_s(idx) <= not ps2_joy_s(1) and joy_down_i;		-- down
				ctrl_p3_s(idx) <= not ps2_joy_s(2) and joy_left_i;		-- left
				ctrl_p4_s(idx) <= not ps2_joy_s(3) and joy_right_i;	-- right
		  
				if (idx = 1) then
					ctrl_p6_s(idx) <= not ps2_joy_s(4) and joy_fire1_i; -- button left (4)
				else
					ctrl_p6_s(idx) <= not ps2_keys_s(0) and joy_fire2_i; -- button right(0)
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

end architecture;