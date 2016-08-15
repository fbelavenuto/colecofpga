-------------------------------------------------------------------------------
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity colecovision is

	generic (
		num_maq_g		: integer := 0;
		is_pal_g			: integer := 0;
		compat_rgb_g	: integer := 0
	);
	port (
		clock_i				: in  std_logic;
		clk_en_10m7_i	: in  std_logic;
		reset_i			: in  std_logic;			-- Reset, tbem acionado quando por_n_i for 0
		por_n_i			: in  std_logic;			-- Power-on Reset
		-- Controller Interface ---------------------------------------------------
		ctrl_p1_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p2_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p3_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p4_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p5_o		: out std_logic_vector( 1 downto 0);
		ctrl_p6_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p7_i		: in  std_logic_vector( 1 downto 0);
		ctrl_p8_o		: out std_logic_vector( 1 downto 0);
		ctrl_p9_i		: in  std_logic_vector( 1 downto 0);
		-- BIOS ROM Interface -----------------------------------------------------
		bios_loader_o	: out std_logic;
		bios_addr_o		: out std_logic_vector(12 downto 0);	-- 8K
		bios_ce_o		: out std_logic;
		bios_oe_o		: out std_logic;
		bios_we_o		: out std_logic;
		bios_data_i		: in  std_logic_vector( 7 downto 0);
		-- CPU RAM Interface ------------------------------------------------------
		ram_addr_o		: out std_logic_vector(12 downto 0);	-- 8K
		ram_ce_o			: out std_logic;
		ram_oe_o			: out std_logic;
		ram_we_o			: out std_logic;
		ram_data_i		: in  std_logic_vector( 7 downto 0);
		ram_data_o		: out std_logic_vector( 7 downto 0);
		-- Video RAM Interface ----------------------------------------------------
		vram_addr_o		: out std_logic_vector(13 downto 0);	-- 16K
		vram_ce_o		: out std_logic;
		vram_oe_o		: out std_logic;
		vram_we_o		: out std_logic;
		vram_data_i		: in  std_logic_vector( 7 downto 0);
		vram_data_o		: out std_logic_vector( 7 downto 0);
		-- Cartridge ROM Interface ------------------------------------------------
		cart_multcart_o: out std_logic;
		cart_addr_o		: out std_logic_vector(14 downto 0);	-- 32K
		cart_en_80_n_o	: out std_logic;
		cart_en_a0_n_o	: out std_logic;
		cart_en_c0_n_o	: out std_logic;
		cart_en_e0_n_o	: out std_logic;
		cart_ce_o		: out std_logic;
		cart_oe_o		: out std_logic;
		cart_we_o		: out std_logic;
		cart_data_i		: in  std_logic_vector( 7 downto 0);
		-- Audio Interface --------------------------------------------------------
		audio_o			: out std_logic_vector(7 downto 0);
		audio_signed_o	: out signed(7 downto 0);
		-- RGB Video Interface ----------------------------------------------------
		col_o				: out std_logic_vector( 3 downto 0);
		rgb_r_o			: out std_logic_vector( 7 downto 0);
		rgb_g_o			: out std_logic_vector( 7 downto 0);
		rgb_b_o			: out std_logic_vector( 7 downto 0);
		hsync_n_o		: out std_logic;
		vsync_n_o		: out std_logic;
		comp_sync_n_o	: out std_logic;
		-- SPI
		spi_miso_i		: in  std_logic;
		spi_mosi_o		: out std_logic;
		spi_sclk_o		: out std_logic;
		spi_cs_n_o		: out std_logic;
		-- DEBUG
		D_cpu_addr		: out std_logic_vector(15 downto 0)
	);

end entity;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

architecture behave of colecovision is

	-- Clock
	signal clk_cnt_q			: unsigned(1 downto 0);
	signal clk_en_3m58_s		: std_logic;

	-- Reset
	signal reset_n_s			: std_logic;

	-- CPU signals
	signal clk_en_cpu_s		: std_logic;
	signal nmi_n_s				: std_logic;
	signal iorq_n_s			: std_logic;
	signal m1_n_s           : std_logic;
	signal m1_wait_q        : std_logic;
	signal rd_n_s				: std_logic;
	signal wr_n_s				: std_logic;
	signal mreq_n_s			: std_logic;
	signal rfsh_n_s			: std_logic;
	signal cpu_addr_s			: std_logic_vector(15 downto 0);
	signal d_to_cpu_s			: std_logic_vector( 7 downto 0);
	signal d_from_cpu_s		: std_logic_vector( 7 downto 0);

	-- Address Decoder
	signal mem_access_s		: std_logic;
	signal io_access_s		: std_logic;
	signal io_read_s			: std_logic;
	signal io_write_s			: std_logic;

	-- machine id
	signal machine_id_cs_s	: std_logic;
	constant machine_id_c	: std_logic_vector(7 downto 0)		:= std_logic_vector(to_unsigned(num_maq_g, 8));

	-- Config port
	signal cfg_port_cs_s		: std_logic;
	signal cfg_page_cs_s		: std_logic;
	signal cfg_page_r			: std_logic_vector(7 downto 0);

	-- BIOS
	signal loader_q			: std_logic;
	signal multcart_q			: std_logic;
	signal bios_ce_n_s		: std_logic;

	-- RAM
	signal ram_ce_n_s			: std_logic;

	-- VDP18 signal
	signal d_from_vdp_s     : std_logic_vector( 7 downto 0);
	signal vdp_r_n_s			: std_logic;
	signal vdp_w_n_s			: std_logic;

	-- SN76489 signal
	signal audio_s				: signed(7 downto 0);
	signal psg_ready_s      : std_logic;
	signal psg_we_n_s			: std_logic;

	-- Controller signals
	signal d_from_ctrl_s    : std_logic_vector( 7 downto 0);
	signal ctrl_r_n_s       : std_logic;
	signal ctrl_en_key_n_s	: std_logic;
	signal ctrl_en_joy_n_s	: std_logic;

	-- SPI
	signal d_from_spi_s		: std_logic_vector( 7 downto 0);
	signal spi_cs_s			: std_logic;
	signal spi_wr_s			: std_logic;
	signal spi_rd_s			: std_logic;

	-- Cartridge
	signal cart_en_80_n_s	: std_logic;
	signal cart_en_a0_n_s	: std_logic;
	signal cart_en_c0_n_s	: std_logic;
	signal cart_en_e0_n_s	: std_logic;
	signal cart_ce_s			: std_logic;

begin

	-- CPU
	cpu: entity work.T80a
	generic map (
		Mode			=> 0
	)
	port map (
		CLK_n			=> clock_i,
		CLK_EN_SYS	=> clk_en_cpu_s,
		RESET_n		=> reset_n_s,
		A				=> cpu_addr_s,
		Din			=> d_to_cpu_s,
		Dout			=> d_from_cpu_s,
		WAIT_n		=> '1',
		INT_n			=> '1',
		NMI_n			=> nmi_n_s,
		BUSRQ_n		=> '1',
		M1_n			=> m1_n_s,
		MREQ_n		=> mreq_n_s,
		IORQ_n		=> iorq_n_s,
		RD_n			=> rd_n_s,
		WR_n			=> wr_n_s,
		RFSH_n		=> rfsh_n_s,
		HALT_n		=> open,
		BUSAK_n		=> open
	);

	-----------------------------------------------------------------------------
	-- TMS9928A Video Display Processor
	-----------------------------------------------------------------------------
	vdp18_b : entity work.vdp18_core
	generic map (
		is_pal_g			=> is_pal_g,
		compat_rgb_g	=> compat_rgb_g
	)
	port map (
		clock_i			=> clock_i,
		clk_en_10m7_i	=> clk_en_10m7_i,
		reset_n_i		=> por_n_i,
		csr_n_i			=> vdp_r_n_s,
		csw_n_i			=> vdp_w_n_s,
		mode_i			=> cpu_addr_s(0),
		int_n_o			=> nmi_n_s,
		cd_i				=> d_from_cpu_s,
		cd_o				=> d_from_vdp_s,
		vram_ce_o		=> vram_ce_o,
		vram_oe_o		=> vram_oe_o,
		vram_we_o		=> vram_we_o,
		vram_a_o			=> vram_addr_o,
		vram_d_o			=> vram_data_o,
		vram_d_i			=> vram_data_i,
		col_o				=> col_o,
		rgb_r_o			=> rgb_r_o,
		rgb_g_o			=> rgb_g_o,
		rgb_b_o			=> rgb_b_o,
		hsync_n_o		=> hsync_n_o,
		vsync_n_o		=> vsync_n_o,
		comp_sync_n_o	=> comp_sync_n_o
	);

	-----------------------------------------------------------------------------
	-- SN76489 Programmable Sound Generator
	-----------------------------------------------------------------------------
	psg_b : entity work.sn76489_top
	generic map (
		clock_div_16_g	=> 1
	)
	port map (
		clock_i		=> clock_i,
		clock_en_i	=> clk_en_3m58_s,
		res_n_i		=> reset_n_s,
		ce_n_i		=> psg_we_n_s,
		we_n_i		=> psg_we_n_s,
		ready_o		=> psg_ready_s,
		d_i			=> d_from_cpu_s,
		aout_o		=> audio_s
	);

	audio_o			<= std_logic_vector(audio_s);
	audio_signed_o	<= audio_s;

	-----------------------------------------------------------------------------
	-- Controller ports
	-----------------------------------------------------------------------------
	ctrl_b : entity work.cv_ctrl
	port map (
		clock_i					=> clock_i,
		clk_en_3m58_i		=> clk_en_3m58_s,
		reset_n_i			=> reset_n_s,
		ctrl_en_key_n_i	=> ctrl_en_key_n_s,
		ctrl_en_joy_n_i	=> ctrl_en_joy_n_s,
		a1_i					=> cpu_addr_s(1),
		ctrl_p1_i			=> ctrl_p1_i,
		ctrl_p2_i			=> ctrl_p2_i,
		ctrl_p3_i			=> ctrl_p3_i,
		ctrl_p4_i			=> ctrl_p4_i,
		ctrl_p5_o			=> ctrl_p5_o,
		ctrl_p6_i			=> ctrl_p6_i,
		ctrl_p7_i			=> ctrl_p7_i,
		ctrl_p8_o			=> ctrl_p8_o,
		ctrl_p9_i			=> ctrl_p9_i,
		d_o					=> d_from_ctrl_s
	);

	-- SPI
	sd: entity work.spi
	port map (
		clock_i			=> clk_en_3m58_s,
		reset_i			=> reset_i,
		addr_i			=> cpu_addr_s(0),
		cs_i				=> spi_cs_s,
		wr_i				=> spi_wr_s,
		rd_i				=> spi_rd_s,
		data_i			=> d_from_cpu_s,
		data_o			=> d_from_spi_s,
		-- SD card interface
		spi_cs_o			=> spi_cs_n_o,
		spi_sclk_o		=> spi_sclk_o,
		spi_mosi_o		=> spi_mosi_o,
		spi_miso_i		=> spi_miso_i
	);

	spi_wr_s		<= not wr_n_s;
	spi_rd_s		<= not rd_n_s;

	-- Glue
	reset_n_s		<= not reset_i;
	clk_en_cpu_s	<= clk_en_3m58_s and psg_ready_s and not m1_wait_q;

	-----------------------------------------------------------------------------
	-- Process clk_cnt
	--
	-- Purpose:
	--   Implements the counter which is used to generate the clock enable
	--   for the 3.58 MHz clock.
	--
	clk_cnt: process (por_n_i, clock_i)
	begin
		if por_n_i = '0' then
			clk_cnt_q     <= (others => '0');
		elsif rising_edge(clock_i) then
			if clk_en_10m7_i = '1' then
				if clk_cnt_q = 0 then
					clk_cnt_q <= "10";
				else
					clk_cnt_q <= clk_cnt_q - 1;
				end if;
			end if;
		end if;
	end process clk_cnt;

	clk_en_3m58_s <= clk_en_10m7_i	when	clk_cnt_q = 0	else	'0';

	-----------------------------------------------------------------------------
	-- Process m1_wait
	--
	-- Purpose:
	--   Implements flip-flop U8A which asserts a wait states controlled by M1.
	--
	m1_wait: process (clock_i, reset_n_s, m1_n_s)
	begin
		if reset_n_s = '0' or m1_n_s = '1' then
			m1_wait_q   <= '0';
		elsif rising_edge(clock_i) then
			if clk_en_3m58_s = '1' then
				m1_wait_q <= not m1_wait_q;
			end if;
		end if;
	end process m1_wait;

	-----------------------------------------------------------------------------
	-- Misc outputs
	-----------------------------------------------------------------------------
	bios_addr_o		<= cpu_addr_s(12 downto 0);
	bios_ce_o		<= not bios_ce_n_s;
	bios_we_o		<= not (wr_n_s or bios_ce_n_s)	when loader_q = '1'	else '0';
	bios_oe_o		<= not (rd_n_s or bios_ce_n_s);

	ram_addr_o		<= cpu_addr_s(12 downto 0);
	ram_data_o		<= d_from_cpu_s;
	ram_ce_o			<= not ram_ce_n_s;
	ram_we_o			<= not (wr_n_s or ram_ce_n_s);
	ram_oe_o			<= not (rd_n_s or ram_ce_n_s);

	cart_addr_o		<= cpu_addr_s(14 downto 0);
	cart_en_80_n_o	<= cart_en_80_n_s;
	cart_en_a0_n_o	<= cart_en_A0_n_s;
	cart_en_c0_n_o	<= cart_en_C0_n_s;
	cart_en_e0_n_o	<= cart_en_E0_n_s;
	cart_ce_s		<= not (cart_en_80_n_s and cart_en_A0_n_s and cart_en_C0_n_s and cart_en_E0_n_s);
	cart_ce_o		<= cart_ce_s;
	cart_oe_o		<= (not rd_n_s) and cart_ce_s;
	cart_we_o		<= (not wr_n_s) and cart_ce_s		when multcart_q = '1'	else '0';


	-- Address decoding
	mem_access_s	<= '1'	when mreq_n_s = '0' and rfsh_n_s = '1'							else '0';
	io_access_s		<= '1'	when iorq_n_s = '0' and m1_n_s = '1'							else '0';
	io_read_s		<= '1'	when iorq_n_s = '0' and m1_n_s = '1' and rd_n_s = '0'		else '0';
	io_write_s		<= '1'	when iorq_n_s = '0' and m1_n_s = '1' and wr_n_s = '0'		else '0';

	-- memory
	bios_ce_n_s		<= '0'	when mem_access_s = '1' and cpu_addr_s(15 downto 13) = "000"		else '1';	-- BIOS         => 0000 to 1FFF
	ram_ce_n_s		<= '0'	when mem_access_s = '1' and cpu_addr_s(15 downto 13) = "011"		else '1';	-- RAM          => 6000 to 7FFF
	cart_en_80_n_s	<= '0'	when mem_access_s = '1' and cpu_addr_s(15 downto 13) = "100"		else '1';	-- Cartridge 80 => 8000 to 9FFF
	cart_en_a0_n_s	<= '0'	when mem_access_s = '1' and cpu_addr_s(15 downto 13) = "101"		else '1';	-- Cartridge A0 => A000 to BFFF
	cart_en_c0_n_s	<= '0'	when mem_access_s = '1' and cpu_addr_s(15 downto 13) = "110"		else '1';	-- Cartridge C0 => C000 to DFFF
	cart_en_e0_n_s	<= '0'	when mem_access_s = '1' and cpu_addr_s(15 downto 13) = "111"		else '1';	-- Cartridge E0 => E000 to FFFF

	-- I/O
	spi_cs_s				<= '1'	when io_access_s = '1' and cpu_addr_s(7 downto 1) = "0101000"	else '0';	-- SPI (R/W)          => 50 to 51
	cfg_port_cs_s		<= '1'	when io_write_s = '1'  and cpu_addr_s(7 downto 0) = X"52"		else '0';	-- Config Port        => 52
	machine_id_cs_s	<= '1'	when io_read_s = '1'   and cpu_addr_s(7 downto 0) = X"53"		else '0';	-- Machine ID read    => 53
	cfg_page_cs_s		<= '1'	when io_access_s = '1' and cpu_addr_s(7 downto 0) = X"54"		else '0';	-- Page port          => 54
	ctrl_en_key_n_s	<= '0'	when io_write_s = '1'  and cpu_addr_s(7 downto 5) = "100"		else '1';	-- Controller key set => 80 to 9F
	vdp_w_n_s			<= '0'	when io_write_s = '1'  and cpu_addr_s(7 downto 5) = "101"		else '1';	-- VDP write          => A0 to BF
	vdp_r_n_s			<= '0'	when io_read_s = '1'   and cpu_addr_s(7 downto 5) = "101"		else '1';	-- VDP read           => A0 to BF
	ctrl_en_joy_n_s	<= '0'	when io_write_s = '1'  and cpu_addr_s(7 downto 5) = "110"		else '1';	-- Controller joy set => C0 to DF
	psg_we_n_s			<= '0'	when io_write_s = '1'  and cpu_addr_s(7 downto 5) = "111"		else '1';	-- PSG write          => E0 to FF
	ctrl_r_n_s			<= '0'	when io_read_s = '1'   and cpu_addr_s(7 downto 5) = "111"		else '1';	-- Controller read    => E0 to FF

	-- Write I/O port 52
	process (por_n_i, reset_i, clk_en_3m58_s)
	begin
		if por_n_i = '0' then
			multcart_q <= '1';
			loader_q	  <= '1';
		elsif reset_i = '1' then
			multcart_q <= '1';
		elsif rising_edge(clk_en_3m58_s) then
			if cfg_port_cs_s = '1' then
				multcart_q <= d_from_cpu_s(1);
				loader_q	  <= d_from_cpu_s(0);
			end if;
		end if;
	end process;

	-- Write I/O port 54
	process (por_n_i, clk_en_3m58_s)
	begin
		if por_n_i = '0' then
			cfg_page_r <= (others => '0');
		elsif rising_edge(clk_en_3m58_s) then
			if cfg_page_cs_s = '1' and wr_n_s = '0' then
				cfg_page_r <= d_from_cpu_s;
			end if;
		end if;
	end process;

	bios_loader_o		<= loader_q;
	cart_multcart_o	<= multcart_q;

	-- MUX data CPU
	d_to_cpu_s		<= bios_data_i						when bios_ce_n_s = '0'		else
							ram_data_i						when ram_ce_n_s  = '0'		else
							d_from_vdp_s					when vdp_r_n_s = '0'			else
							d_from_ctrl_s					when ctrl_r_n_s = '0'		else
							cart_data_i						when cart_ce_s = '1'			else
							d_from_spi_s					when spi_cs_s = '1'			else
							machine_id_c					when machine_id_cs_s = '1'	else
							cfg_page_r						when cfg_page_cs_s = '1'	else
							(others => '1');

	-- Debug
	D_cpu_addr	<= cpu_addr_s;
	

end architecture;
