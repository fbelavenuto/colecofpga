
library ieee;
use ieee.std_logic_1164.all;

entity genesispad is
	generic (
		clocks_per_14us_g : integer		:= 2	-- number of clock_i periods during 14us
	);
	port (
		clock_i			: in  std_logic;
		reset_i			: in  std_logic;
		-- Gamepad interface
		pad_p1_i			: in  std_logic;
		pad_p2_i			: in  std_logic;
		pad_p3_i			: in  std_logic;
		pad_p4_i			: in  std_logic;
		pad_p6_i			: in  std_logic;
		pad_p7_o			: out std_logic;
		pad_p9_i			: in  std_logic;
		-- Buttons
		but_a_o			: out std_logic;
		but_b_o			: out std_logic;
		but_c_o			: out std_logic;
		but_x_o			: out std_logic;
		but_y_o			: out std_logic;
		but_z_o			: out std_logic;
		but_start_o		: out std_logic;
		but_mode_o		: out std_logic
	);
end entity;

architecture Behavior of genesispad is

	type state_t is (IDLE, PULSE1L, PULSE1H, PULSE2L, PULSE2H, PULSE3L, PULSE3H, PULSE4L, PULSE4H);
	signal state_q, state_s : state_t;

	signal pass_14u_s	: std_logic;
	signal cnt_14u_q	: integer range 0 to clocks_per_14us_g;
	signal cnt_idle_q	: integer range 0 to 720;

begin

	-- pragma translate_off
	-----------------------------------------------------------------------------
	-- Check generics
	-----------------------------------------------------------------------------
	assert clocks_per_14us_g > 1
		report "clocks_per_14us_g must be at least 2!"
		severity failure;
	-- pragma translate_on

	-- counters
	process (reset_i, clock_i)
	begin
		if reset_i = '1' then
			cnt_14u_q <= 0;
		elsif rising_edge(clock_i) then
			cnt_14u_q <= cnt_14u_q + 1;
		end if;
	end process;

	pass_14u_s <= '1' when cnt_14u_q = clocks_per_14us_g-1		else '0';

	--
	process (reset_i, clock_i)
	begin
		if reset_i = '1' then
			state_q <= IDLE;
			cnt_idle_q <= 0;
		elsif rising_edge(clock_i) then
			if pass_14u_s = '1' then
				state_s <= state_q;
			end if;
			if state_q = IDLE then
				cnt_idle_q <= cnt_idle_q + 1;
			end if;
		end if;
	end process;

	process (state_q)
	begin
		state_s	<= IDLE;
		case state_q is
			when IDLE =>
				
			when PULSE1L =>
			when PULSE1H =>
			when PULSE2L =>
			when PULSE2H =>
			when PULSE3L =>
			when PULSE3H =>
			when PULSE4L =>
			when PULSE4H =>
		end case;
	end process;
	
end architecture;