-- Abstracao do audio para chip WM8731

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Audio_WM8731 is
	port (
		clock_i			: in    std_logic;							-- Clock 24 MHz
		reset_i			: in    std_logic;							-- Reset geral
		psg_i				: in    std_logic_vector(7 downto 0);

		i2s_xck_o		: out   std_logic;							-- Ligar nos pinos do TOP
		i2s_bclk_o		: out   std_logic;
		i2s_adclrck_o	: out   std_logic;
		i2s_adcdat_i	: in    std_logic;
		i2s_daclrck_o	: out   std_logic;
		i2s_dacdat_o	: out   std_logic;
		
		i2c_sda_io		: inout std_logic;							-- Ligar no pino I2C SDA
		i2c_scl_io		: inout std_logic								-- Ligar no pino I2C SCL
	);
end entity;

architecture Behavior of Audio_WM8731 is

	signal pcm_lrclk_s		: std_logic;
	signal pcm_outl_s			: std_logic_vector(15 downto 0);
	signal pcm_outr_s			: std_logic_vector(15 downto 0);

	signal psg_s				: std_logic_vector(15 downto 0);

begin

	i2s: entity work.i2s_intf
	generic map (
		mclk_rate	=> 12000000,
		sample_rate	=> 48000,
		preamble		=>  1, -- I2S
		word_length	=> 16
	)
	port map (
		-- 2x MCLK in (e.g. 24 MHz for WM8731 USB mode)
		clock_i			=> clock_i,
		reset_i			=> reset_i,
		-- Parallel IO
		pcm_inl_o		=> open,
		pcm_inr_o		=> open,
		pcm_outl_i		=> pcm_outl_s,
		pcm_outr_i		=> pcm_outr_s,
		-- Codec interface (right justified mode)
		-- MCLK is generated at half of the CLK input
		i2s_mclk_o		=> i2s_xck_o,
		-- LRCLK is equal to the sample rate and is synchronous to
		-- MCLK.  It must be related to MCLK by the oversampling ratio
		-- given in the codec datasheet.
		i2s_lrclk_o		=> pcm_lrclk_s,
		-- Data is shifted out on the falling edge of BCLK, sampled
		-- on the rising edge.  The bit rate is determined such that
		-- it is fast enough to fit preamble + word_length bits into
		-- each LRCLK half cycle.  The last cycle of each word may be 
		-- stretched to fit to LRCLK.  This is OK at least for the 
		-- WM8731 codec.
		-- The first falling edge of each timeslot is always synchronised
		-- with the LRCLK edge.
		i2s_bclk_o		=> i2s_bclk_o,
		-- Output bitstream
		i2s_d_o			=> i2s_dacdat_o,
		-- Input bitstream
		i2s_d_i			=> i2s_adcdat_i
	);
	i2s_adclrck_o <= pcm_lrclk_s;
	i2s_daclrck_o <= pcm_lrclk_s;
	 

	i2c: entity work.i2c_loader 
	generic map (
		device_address	=> 16#1a#,		-- Address of slave to be loaded
		num_retries		=> 0,				-- Number of retries to allow before stopping
		-- Length of clock divider in bits.  Resulting bus frequency is
		-- CLK/2^(log2_divider + 2)
		log2_divider	=> 7
	)
	port map (
		clock_i			=> clock_i,
		reset_i			=> reset_i,
		i2c_scl_io		=> i2c_scl_io,
		i2c_sda_io		=> i2c_sda_io,
		is_done_o		=> open,
		is_error_o		=> open
	);

	psg_s <= psg_i & "00000000";

	pcm_outl_s <= psg_s;
	pcm_outr_s <= psg_s;

end architecture;