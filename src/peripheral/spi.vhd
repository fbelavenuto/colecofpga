---
---   Portas SPI
---	50 - CS do cartao
---	51 - interface SPI
---

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi is
	port (
		clock_i			: in    std_logic;
		reset_i			: in    std_logic;
		addr_i			: in    std_logic;
		cs_i				: in    std_logic;
		wr_i				: in    std_logic;
		rd_i				: in    std_logic;
		data_i			: in    std_logic_vector(7 downto 0);
		data_o			: out   std_logic_vector(7 downto 0);
		-- SD card interface
		spi_cs_o			: out   std_logic;
		spi_sclk_o		: out   std_logic;
		spi_mosi_o		: out   std_logic;
		spi_miso_i		: in    std_logic
	);
end entity;

architecture rtl of spi is

	signal sck_delayed_s	: std_logic;
	signal counter_s		: unsigned(3 downto 0);
	-- Shift register has an extra bit because we write on the
	-- falling edge and read on the rising edge
	signal shift_r			: std_logic_vector(8 downto 0);
	signal port51_r		: std_logic_vector(7 downto 0);
	signal enable_s		: std_logic;

begin

	enable_s <= '1'	when cs_i = '1' and (wr_i = '1' or rd_i = '1')	else '0';

	-- Leitura das portas
	data_o	<=
				   port51_r			when enable_s = '1' and addr_i = '1' and rd_i = '1'  else
				   (others => '1');
		

	--------------------------------------------------
	-- Essa parte lida com a porta SPI por hardware --
	--      Implementa um SPI Master Mode 0         --
	--------------------------------------------------

	process(clock_i, reset_i)
	begin
		if reset_i = '1' then
			spi_cs_o <= '1';
		elsif rising_edge(clock_i) then
			if enable_s = '1' and addr_i = '0' and wr_i = '1'  then
				spi_cs_o	<= data_i(0);
			end if;
		end if;
	end process;

	-- SD card outputs from clock divider and shift register
	spi_sclk_o  <= sck_delayed_s;
	spi_mosi_o  <= shift_r(8);

	-- Atrasa SCK para dar tempo do bit mais significativo mudar de estado e acertar MOSI antes do SCK
	process (clock_i, reset_i)
	begin
		if reset_i = '1' then
			sck_delayed_s <= '0';
		elsif rising_edge(clock_i) then
			sck_delayed_s <= not counter_s(0);
		end if;
	end process;

	-- SPI write
	process(clock_i, reset_i)
	begin		
		if reset_i = '1' then
			shift_r		<= (others => '1');
			port51_r		<= (others => '1');
			counter_s	<= "1111"; -- Idle
		elsif rising_edge(clock_i) then
			if counter_s = "1111" then
				port51_r		<= shift_r(7 downto 0);		-- Store previous shift register value in input register
				shift_r(8)	<= '1';							-- MOSI repousa em '1'

				-- Idle - check for a bus access
				if enable_s = '1' and addr_i = '1'  then
					-- Write loads shift register with data
					-- Read loads it with all 1s
					if rd_i = '1' then
						shift_r <= (others => '1');								-- Uma leitura seta 0xFF para enviar e dispara a transmissão
					else
						shift_r <= data_i & '1';									-- Uma escrita seta o valor a enviar e dispara a transmissão
					end if;
					counter_s <= "0000"; -- Initiates transfer
				end if;
			else
				counter_s <= counter_s + 1;										-- Transfer in progress

				if sck_delayed_s = '0' then
					shift_r(0)	<= spi_miso_i;										-- Input next bit on rising edge
				else
					shift_r		<= shift_r(7 downto 0) & '1';					-- Output next bit on falling edge
				end if;
			end if;
		end if;
	end process;
end architecture;
