--
--  v9938.vhd
--
--        copyright (c) 2000 kunihiko ohnaka
--                   all rights reserved.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity v9938 is
	port (
		clock_i					: in    std_logic;					-- VDP clock ... 21.477MHz
		reset_n_i				: in    std_logic;
		dac_clock_o				: out   std_logic;					-- video dac(mb40988) clock
		-- msx slot signals
		bus_clock_i				: in    std_logic;
		bus_cs_n_i				: in    std_logic;
		bus_rd_n_i				: in    std_logic;
		bus_wr_n_i				: in    std_logic;
		bus_addr_i				: in    std_logic_vector( 1 downto 0);
		bus_data_i				: in    std_logic_vector( 7 downto 0);
		bus_data_o				: out   std_logic_vector( 7 downto 0);
		-- sram (as vram) access signals
		vram_ce_n_o				: out   std_logic;
		vram_oe_n_o				: out   std_logic;
		vram_we_n_o				: out   std_logic;
		vram_addr_o				: out   std_logic_vector(16 downto 0);
		vram_data_i				: in    std_logic_vector( 7 downto 0);
		vram_data_o				: out   std_logic_vector( 7 downto 0);
		-- video output
		video_r_o				: out   std_logic_vector( 2 downto 0);
		video_g_o				: out   std_logic_vector( 2 downto 0);
		video_b_o				: out   std_logic_vector( 2 downto 0);
		video_hs_n_o			: out   std_logic;
		video_vs_n_o			: out   std_logic;
		video_cs_n_o			: out   std_logic;
		video_dhclk_o			: out   std_logic;
		video_dlclk_o			: out   std_logic;
		-- cxa1645(rgb->ntsc encoder) signals
		video_subcarrier_o	: out   std_logic;
		video_sync_o			: out   std_logic
	);
end v9938;


architecture rtl of v9938 is

	-- 3.58mhz clock
	signal bus_clock_s			: std_logic;

	-- slot control
	signal ioPaCs					: std_logic;
	signal ioPaCs0					: std_logic;
	signal ioPaCs1					: std_logic;

	-- h counter
	signal h_counter				: std_logic_vector(10 downto 0);
	-- v counter
	signal v_counter				: std_logic_vector(10 downto 0);

	-- display start position ( when adjust=(0,0) )
	constant offset_x				: std_logic_vector := "0110110";		-- = 220/4;
	constant offset_y				: std_logic_vector := "0101110";		-- = 3+3+13+26+1 = 46
	constant offset_y_212		: std_logic_vector := "0100100";		-- = 3+3+13+16+1 = 36

	signal adjust_x				: std_logic_vector( 6 downto 0);
	signal adjust_y				: std_logic_vector( 6 downto 0);

	-- dot state register
	signal dotState				: std_logic_vector( 1 downto 0);
	signal dotResetState			: std_logic_vector( 1 downto 0);

	-- display field signal
	signal field					: std_logic;

	-- sync state register
	signal sstate					: std_logic_vector( 1 downto 0);

	constant sstate_a				: std_logic_vector := "00";
	constant sstate_b				: std_logic_vector := "01";
	constant sstate_c				: std_logic_vector := "10";
	constant sstate_d				: std_logic_vector := "11";

	signal videohs_n				: std_logic;
	signal videovs_n				: std_logic;

	-- display area flags
	signal window_x				: std_logic;
	signal window_y				: std_logic;
	signal window					: std_logic;
	signal prewindow_x			: std_logic;
	signal prewindow_y			: std_logic;
	signal prewindow				: std_logic;
	-- for sprites
	signal spwindow_ec			: std_logic;
	signal spwindow				: std_logic;
	signal spwindow_x				: std_logic;
	signal spwindow_y				: std_logic;
	signal spwindow_ecx			: std_logic;
	-- for text mode
	signal twindow					: std_logic;
	signal twindow_y				: std_logic;
	signal twindow_x				: std_logic;
	-- for graphic mode 1,2,3
	signal g123window				: std_logic;
	signal g123window_y			: std_logic;
	signal g123window_x			: std_logic;
	-- for frame zone
	signal bwindow_x				: std_logic;
	signal bwindow_y				: std_logic;
	signal bwindow					: std_logic;

	-- dot counter
	signal dotcounter_x			: std_logic_vector( 8 downto 0);
	signal dotcounter_y			: std_logic_vector( 7 downto 0);
	-- dot counter - 8 ( fifo read addr )
	signal predotcounter_x		: std_logic_vector( 8 downto 0);
	signal predotcounter_y		: std_logic_vector( 7 downto 0);

	signal vramReadFreeFlag		: std_logic;

	-- 3.58mhz generator
	signal cpuClockCounter		: std_logic_vector( 2 downto 0);

	-- vdp register access
	signal vdpP1Is1StByte		: std_logic;
	signal vdpP2Is1StByte		: std_logic;
	signal vdpP0Data				: std_logic_vector( 7 downto 0);
	signal vdpP1Data				: std_logic_vector( 7 downto 0);
	signal vdpRegPtr				: std_logic_vector( 5 downto 0);
	signal vdpRegWrPulse			: std_logic;
	signal vdpVramAccessAddr	: std_logic_vector( 16 downto 0);
	signal vdpVramAccessData	: std_logic_vector( 7 downto 0);
	signal vdpVramAccessAddrTmp	: std_logic_vector( 16 downto 0);
	signal vdpVramAddrSetReq		: std_logic;
	signal vdpVramAddrSetAck		: std_logic;
	signal vdpVramAccessRw			: std_logic;
	signal vdpVramWrReqPd			: std_logic;
	signal vdpVramWrReqP				: std_logic;
	signal vdpVramWrAckP				: std_logic;
	signal vdpVramWrReq				: std_logic;
	signal vdpVramWrAck				: std_logic;
	signal vdpVramAccessing			: std_logic;
	signal vdpR0DispNum				: std_logic_vector(3 downto 1);
	signal vdpR1DispMode				: std_logic_vector(1 downto 0);
	signal vdpR1SpSize				: std_logic;
	signal vdpR1SpZoom				: std_logic;
	signal vdpR1DispOn					: std_logic;
	signal vdpR2PtnNameTblBaseAddr	: std_logic_vector( 6 downto 0);
	signal vdpR4PtnGeneTblBaseAddr	: std_logic_vector( 5 downto 0);
	signal vdpR10R3ColorTblBaseAddr	: std_logic_vector( 10 downto 0);
	signal vdpR11R5SpAttrTblBaseAddr	: std_logic_vector( 6 downto 0);
	signal vdpR6SpPtnGeneTblBaseAddr	: std_logic_vector( 5 downto 0);
	signal vdpR7FrameColor				: std_logic_vector( 7 downto 0);
	signal vdpR8SpOff						: std_logic;
	signal vdpR8Color0On					: std_logic;
	signal vdpR9InterlaceMode			: std_logic;
	signal vdpR9TwoPageMode				: std_logic;
	signal vdpR9YDots						: std_logic;
	signal vdpR16PalNum					: std_logic_vector( 3 downto 0);
	signal vdpR17RegNum					: std_logic_vector( 5 downto 0);
	signal vdpR17IncRegNum				: std_logic;
	signal vdpR23VStartLine				: std_logic_vector( 7 downto 0);
--	signal vdpR18Adjust					: std_logic;
	signal vdpModeText1					: std_logic;			-- text mode 1    (screen0)
	signal vdpModeText2					: std_logic;			-- text mode 2    (screen0 width 80)
	signal vdpModeGraphic1				: std_logic;			-- graphic mode 1 (screen1)
	signal vdpModeGraphic2				: std_logic;			-- graphic mode 2 (screen2)
	signal vdpModeGraphic3				: std_logic;			-- graphic mode 2 (screen4)
	signal vdpModeGraphic4				: std_logic;			-- graphic mode 4 (screen5)
	signal vdpModeGraphic5				: std_logic;			-- graphic mode 5 (screen6)
	signal vdpModeGraphic6				: std_logic;			-- graphic mode 6 (screen7)
	signal vdpModeGraphic7				: std_logic;			-- graphic mode 7 (screen8)

	-- color code
	signal colorCode						: std_logic_vector( 7 downto 0);
--	signal colorR							: std_logic_vector( 2 downto 0);
--	signal colorG							: std_logic_vector( 2 downto 0);
--	signal colorB							: std_logic_vector( 2 downto 0);

	-- for text 1
	signal t1DotCounter_x				: std_logic_vector( 2 downto 0);
	signal t1CharCounter_x				: std_logic_vector( 9 downto 0);
	signal t1CharCounter_y				: std_logic_vector( 9 downto 0);
	signal t1PtnNum						: std_logic_vector( 7 downto 0);
	signal t1Pattern						: std_logic_vector( 7 downto 0);
	signal t1ColorCode					: std_logic_vector( 3 downto 0);

	-- for graphic 1,2,3
	signal g1PtnNum						: std_logic_vector( 7 downto 0);
	signal g1PPattern						: std_logic_vector( 7 downto 0);
	signal g1Pattern						: std_logic_vector( 7 downto 0);
	signal g1Color							: std_logic_vector( 7 downto 0);
	signal g1ColorCode					: std_logic_vector( 3 downto 0);

	-- for graphic 4
	signal g4ColorCode					: std_logic_vector( 3 downto 0);
	-- for graphic 7
	signal g7ColorCode					: std_logic_vector( 7 downto 0);

	-- sprite
	signal spPreReading					: std_logic;
	signal spPreReadState				: std_logic_vector( 2 downto 0);
	constant spState_idle				: std_logic_vector := "000";
	constant spState_yread				: std_logic_vector := "001";
	constant spState_xread				: std_logic_vector := "010";
	constant spState_ptnnumread		: std_logic_vector := "011";
	constant spState_ptnread1			: std_logic_vector := "111";
	constant spState_ptnread2			: std_logic_vector := "110";
	constant spState_colorRead			: std_logic_vector := "100";

	signal spmode2							: std_logic;
	signal spprereadcounter				: std_logic_vector( 4 downto 0);
	signal spprereadcounter2			: std_logic_vector( 3 downto 0);
	signal spprereadptnnum				: std_logic_vector( 7 downto 0);
	signal spy								: std_logic_vector( 7 downto 0);
	signal sppreready						: std_logic_vector( 7 downto 0);
	signal spcolorCode					: std_logic_vector( 3 downto 0);
	signal spccis0							: std_logic;
	signal spdispend						: std_logic;

	constant spmode2_nsprites			: integer := 4;

	type spbitvec is 			array( 0 to spmode2_nsprites-1 ) of std_logic;
	type sppatternvec is		array( 0 to spmode2_nsprites-1 ) of std_logic_vector(16 downto 0);
	type spxvec is				array( 0 to spmode2_nsprites-1 ) of std_logic_vector(8 downto 0);
	type spcolorvec is		array( 0 to spmode2_nsprites-1 ) of std_logic_vector(3 downto 0);

	signal spcolorin						: spbitvec;
	signal sppattern						: sppatternvec;
	signal spx								: spxvec;
	signal spcolor							: spcolorvec;
	signal spcc								: spbitvec;
	signal spec								: spbitvec;
	signal spic								: spbitvec;

	signal fifoaddr						: std_logic_vector( 3 downto 0);
	signal fifoaddr_in					: std_logic_vector( 3 downto 0);
	signal fifoaddr_out					: std_logic_vector( 3 downto 0);
	signal fifowe							: std_logic;
	signal fifoin							: std_logic;
	signal fifodata_in					: std_logic_vector( 7 downto 0);
	signal fifodata_out					: std_logic_vector( 7 downto 0);

	-- palette registers
	signal paletteaddr					: std_logic_vector( 3 downto 0);
	signal paletteaddr_out				: std_logic_vector( 3 downto 0);
	signal palettewerb					: std_logic;
	signal paletteweg						: std_logic;
	signal paletteinrb					: std_logic;
	signal paletteing						: std_logic;
	signal palettedata_in				: std_logic_vector( 7 downto 0);
	signal palettedatarb_out			: std_logic_vector( 7 downto 0);
	signal palettedatag_out				: std_logic_vector( 7 downto 0);

	signal palettewrtemp					: std_logic_vector( 7 downto 0);
	signal palettewrnum					: std_logic_vector( 3 downto 0);
	signal palettewrreqrb				: std_logic;
	signal palettewrreqg					: std_logic;
	signal palettewrreqrb_d				: std_logic;
	signal palettewrreqg_d				: std_logic;
	signal palettewrackrb				: std_logic;
	signal palettewrackg					: std_logic;

--	type palettevec is		array( 0 to 15 ) of std_logic_vector(2 downto 0);
--	signal paletter						: palettevec;
--	signal paletteg						: palettevec;
--	signal paletteb						: palettevec;

begin

	----------------------------------------------------------------
	-- 16byte fifo control
	----------------------------------------------------------------
	fifoaddr <= fifoaddr_in	when fifoin = '1'	else	fifoaddr_out;
	fifodata_in <= vram_data_i;
	fifowe   <= '1' when fifoin = '1' else '0';

--	fifomem : ram
--	port map(
--		address		=> fifoaddr,
--		inclock		=> clock_i,
--		we				=> fifowe,
--		data			=> fifodata_in,
--		q				=> fifodata_out
--	);
	fifomem : entity work.spram
	generic map (
		addr_width_g => 4,
		data_width_g => 8
	)
	port map (
		clk_i		=> clock_i,
		we_i		=> fifowe,
		addr_i	=> fifoaddr,
		data_i	=> fifodata_in,
		data_o	=> fifodata_out
	);

  ----------------------------------------------------------------
  -- palette register control r and b
  ----------------------------------------------------------------
  paletteaddr <= palettewrnum when paletteinrb = '1' or paletteing = '1' else paletteaddr_out;
  palettedata_in <= palettewrtemp;
  palettewerb  <= '1' when paletteinrb = '1' else '0';
  paletteweg   <= '1' when paletteing  = '1' else '0';

--  palettememrb : ram port map(paletteaddr, clock_i, palettewerb, palettedata_in, palettedatarb_out);
--  palettememg  : ram port map(paletteaddr, clock_i, paletteweg,  palettedata_in, palettedatag_out);
	palettememrb : entity work.spram
	generic map (
		addr_width_g => 4,
		data_width_g => 8
	)
	port map (
		clk_i		=> clock_i,
		we_i		=> palettewerb,
		addr_i	=> paletteaddr,
		data_i	=> palettedata_in,
		data_o	=> palettedatarb_out
	);

	palettememg : entity work.spram
	generic map (
		addr_width_g => 4,
		data_width_g => 8
	)
	port map (
		clk_i		=> clock_i,
		we_i		=> paletteweg,
		addr_i	=> paletteaddr,
		data_i	=> palettedata_in,
		data_o	=> palettedatag_out
	);

  ----------------------------------------------------------------
  -- dummy pin
  ----------------------------------------------------------------
  bus_clock_s  <= bus_clock_i;

  -- composit sync signal
  video_cs_n_o <= not (videohs_n xor videovs_n);
  -- h sync signal
  video_hs_n_o <= videohs_n;
  -- v sync signal
  video_vs_n_o <= videovs_n;

  -- video dac clock
  -- dotState changes as         00->01->11->10
  -- dotState(0) xor dotState(1)  0-> 1-> 0-> 1
  -- video_r_o(g,b)                <======><====>
  dac_clock_o <= dotState(0) xor dotState(1);


-- to cxa1645
  video_sync_o <= not (videohs_n xor videovs_n);
  video_subcarrier_o <= cpuClockCounter(2);

  process( clock_i, reset_n_i )
  begin
    if (reset_n_i = '0') then
      h_counter <= (others => '0');
      v_counter <= (others => '0');
      videohs_n <= '1';
      videovs_n <= '1';
      cpuClockCounter <= (others => '0');
      sstate <= (others => '0' );
      field <= '0';
    elsif (clock_i'event and clock_i = '1') then
-- 3.58mhz generator
      case cpuClockCounter is
        when "000" => cpuClockCounter <= "001";
        when "001" => cpuClockCounter <= "011";
        when "011" => cpuClockCounter <= "111";
        when "111" => cpuClockCounter <= "110";
        when "110" => cpuClockCounter <= "100";
        when "100" => cpuClockCounter <= "000";
        when others => cpuClockCounter <= "000";
      end case;

      if( h_counter = 1363 ) then
        h_counter <= (others => '0' );
      else
        h_counter <= h_counter + 1;
      end if;

      if( (h_counter = 681) or (h_counter = 1363) ) then
        -- 525 lines * 2 = 1050
        if( v_counter = 1049 ) then
          if(h_counter = 1363) then
            v_counter <= (others => '0');
          end if;
        else
          v_counter <= v_counter + 1;
        end if;
      end if;

      if( (v_counter = 0) or
          (v_counter = 12) or
          ((v_counter = 525) and vdpR9InterlaceMode = '1') or
          ((v_counter = 526) and vdpR9InterlaceMode = '0') or
          ((v_counter = 537) and vdpR9InterlaceMode = '1') or
          ((v_counter = 538) and vdpR9InterlaceMode = '0') )then
        sstate <= sstate_a;
      elsif( (v_counter = 6) or
             ((v_counter = 531) and vdpR9InterlaceMode = '1') or
             ((v_counter = 532) and vdpR9InterlaceMode = '0') )then
        sstate <= sstate_b;
      elsif( (v_counter = 18) or
             ((v_counter = 543) and vdpR9InterlaceMode = '1') or
             ((v_counter = 544) and vdpR9InterlaceMode = '0') )then
        sstate <= sstate_c;
      end if;

-- generate field signal
      if( v_counter = 525 ) then
        field <= '1';
      elsif( v_counter = 0 ) then
        field <= '0';
      end if;

-- generate h sync pulse
      if( sstate = sstate_a ) then
        if( (h_counter = 1) or (h_counter = 1+682) ) then
          videohs_n <= '0';		-- pulse on
        elsif( (h_counter = 51) or (h_counter = 51+682) ) then
          videohs_n <= '1';		-- pulse off
        end if;
      elsif( sstate = sstate_b ) then
        if( (h_counter = 1364-100+1) or (h_counter = 682-100+1) ) then
          videohs_n <= '0';		-- pulse on
        elsif( (h_counter = 1) or (h_counter = 1+682) ) then
          videohs_n <= '1';		-- pulse off
        end if;
      elsif( sstate = sstate_c ) then
        if( h_counter = 1 ) then
          videohs_n <= '0';		-- pulse on
        elsif( h_counter = 101 ) then
          videohs_n <= '1';		-- pulse off
        end if;
      end if;

-- generate v sync pulse
      if( sstate = sstate_b ) then
        videovs_n <= '0';
      else
        videovs_n <= '1';
      end if;
    end if;
  end process;

-- generate prewindow, window, g123window, spwindow
  prewindow <= (prewindow_x and prewindow_y);
  window <= (window_x and window_y);
  g123window <= (g123window_x and g123window_y);
  twindow <= (twindow_x and twindow_y);


  spwindow_ec <= spwindow_ecx and spwindow_y;
  spwindow <= spwindow_x and spwindow_y;

  process( clock_i, reset_n_i )
  begin
    if (reset_n_i = '0') then
      dotcounter_x <= (others =>'0');
      dotcounter_y <= (others =>'0');
      predotcounter_x <= (others =>'0');
      predotcounter_y <= (others =>'0');
      window_x <= '0';
      window_y <= '0';
      prewindow_x <= '0';
      prewindow_y <= '0';
      bwindow <= '0';
      bwindow_x <= '0';
      bwindow_y <= '0';
      spwindow_x <= '0';
      spwindow_y <= '0';
      spwindow_ecx <= '0';
      g123window_y <= '0';
      g123window_x <= '0';
      twindow_y <= '0';
      twindow_x <= '0';
      vramReadFreeFlag <= '0';
      t1CharCounter_x <= (others => '0');
      t1CharCounter_y <= (others => '0');
      t1DotCounter_x <= (others => '0');
    elsif (clock_i'event and clock_i = '1') then
      if( h_counter = ("00" & adjust_x & "10" ) ) then
        prewindow_x <= '1';
        g123window_x <= '1';
      elsif( (h_counter( 1 downto 0) = "10") and ( predotcounter_x = "011111111" ) ) then
        prewindow_x <= '0';
        g123window_x <= '0';
      end if;

      if( (v_counter = ("0000" & (adjust_y+1) & '0') ) or (v_counter = 526+("0000" & (adjust_y+1) & '0')) ) then
        prewindow_y <= '1';
        window_y <= '1';
        g123window_y <= '1';
        twindow_y <= '1';
      elsif( (vdpR9YDots = '1' and ( (vdpModeGraphic7 = '1') or (vdpModeGraphic4='1') ) ) and
             ( (v_counter = ("0000" & (adjust_y+1) & '0')+212*2) or (v_counter = 526+("0000" & (adjust_y+1) & '0')+212*2) ) ) then
        prewindow_y <= '0';
        window_y <= '0';
        g123window_y <= '0';
        twindow_y <= '0';
      elsif( ((vdpR9YDots = '0') or (vdpR9YDots = '1' and not ( (vdpModeGraphic7 = '1') or (vdpModeGraphic4='1') ) ) ) and
	     ( (v_counter = ("0000" & (adjust_y+1) & '0')+192*2) or (v_counter = 526+("0000" & (adjust_y+1) & '0')+192*2) ) ) then
        prewindow_y <= '0';
        window_y <= '0';
        g123window_y <= '0';
        twindow_y <= '0';
      end if;

      if( (v_counter = ("0000" & adjust_y & '0') ) or (v_counter = 526+("0000" & adjust_y & '0')) ) then
        spwindow_y <= '1';
      elsif( (v_counter = ("0000" & adjust_y & '0')+212*2) or (v_counter = 526+("0000" & adjust_y & '0')+212*2) ) then
        spwindow_y <= '0';
      end if;

-- main window
      if( (h_counter( 1 downto 0) = "10") and ( dotcounter_x = "111111111" ) ) then
	-- when dotcounter_x = -1
	window_x <= '1';
      elsif( (h_counter( 1 downto 0) = "10") and ( dotcounter_x ="011111111" ) ) then
	-- when dotcounter_x = 255
        window_x <= '0';
      end if;

--      if( (h_counter( 1 downto 0) = "10") and ( predotcounter_x = 7- ) and (window_y = '1') ) then
--      elsif( (h_counter( 1 downto 0) = "10") and ( predotcounter_x = 255 ) ) then
--      end if;

      if( h_counter = ("00" & ( adjust_x - 24 -2) & "10" ) ) then
        spwindow_ecx <= '1';
      elsif( h_counter = ("00" & ( adjust_x + 8 -2) & "10" ) ) then
        spwindow_x <= '1';
      elsif( (h_counter( 1 downto 0) = "10") and ( predotcounter_x = "011111111" ) ) then
        spwindow_x <= '0';
        spwindow_ecx <= '0';
      end if;

      -- 32???? 1?? vram ?a?n?z?x?p?? vram?o?x???j??
      if( h_counter = ("00" & adjust_x & "10") ) then
        predotcounter_x <= (others =>'0');
        vramReadFreeFlag <= '0';
        if( v_counter = ("000" & adjust_y & '0') ) then
          dotcounter_y <= (vdpR23VStartLine - 1);
        elsif( v_counter = ("000" & adjust_y & '0')+526 ) then
          dotcounter_y <= (vdpR23VStartLine - 1);
        else
          dotcounter_y <= dotcounter_y + 1;
        end if;
      elsif( (h_counter( 1 downto 0) = "10") and (vramReadFreeFlag = '0') ) then
        predotcounter_x <= predotcounter_x + 1;
        if( predotcounter_x( 4 downto 0 ) = "11111" ) then
          vramReadFreeFlag <= '1';
        end if;
      elsif( (h_counter( 1 downto 0) = "10") and (vramReadFreeFlag = '1') ) then
        vramReadFreeFlag <= '0';
      end if;

      if( h_counter = ("00" & adjust_x & "10") ) then
        dotcounter_x <= "111111000";      -- -8
      elsif( h_counter( 1 downto 0) = "10") then
        dotcounter_x <= dotcounter_x + 1;
      end if;

      if( h_counter = 1363 ) then
	if( v_counter = ("0000" & adjust_y & '1') ) then
          predotcounter_y <= vdpR23VStartLine;
        elsif( v_counter = ("0000" & adjust_y & '1')+526 ) then
          predotcounter_y <= vdpR23VStartLine;
        else
--          predotcounter_y <= dotcounter_y + 1;
--	2000/10/12?c??
          predotcounter_y <= predotcounter_y + 1;
        end if;
      end if;

-- counter for text 1
      if( (h_counter( 1 downto 0) = "10") and ( dotcounter_x = "111111111" ) ) then
        t1DotCounter_x <= "100";          --  4
	t1CharCounter_x <= "1111111111";  -- -1
	if( dotcounter_y = "00000000" ) then
	  t1CharCounter_y <= (others => '0');
	elsif( dotcounter_y( 2 downto 0) = "000" ) then
	  t1CharCounter_y <= t1CharCounter_y + 40;
	end if;
      elsif( h_counter( 1 downto 0) = "10") then
	if( t1DotCounter_x = "101" ) then
	  t1DotCounter_x <= "000";
	  t1CharCounter_x <= t1CharCounter_x + 1;
	else
	  t1DotCounter_x <= t1DotCounter_x + 1;
	end if;
      end if;

-- text1 window
      if( (h_counter( 1 downto 0) = "10") and ( dotcounter_x = "000000111" ) ) then
        twindow_x <= '1';
      elsif( (h_counter( 1 downto 0) = "10") and ( dotcounter_x = "011110111" ) ) then
        twindow_x <= '0';
      end if;

-- generate bwindow
      if( h_counter = 200-1 ) then
        bwindow_x <= '1';
      elsif( h_counter = 1363-1 ) then
        bwindow_x <= '0';
      end if;

      if( (v_counter = 10*2-1) or (v_counter = 525+10*2-1) ) then
        bwindow_y <= '1';
      elsif( (v_counter = 524-1) or (v_counter = 525+524-1) ) then
        bwindow_y <= '0';
      end if;

      if( (bwindow_x = '1') and (bwindow_y = '1') )then
        bwindow <= '1';
      else
        bwindow <= '0';
      end if;

    end if;
  end process;


	-- color generator
	process( clock_i, reset_n_i )
	begin
		if (reset_n_i = '0') then
			dotState <= (others => '0' );
			colorCode <= (others => '0' );
--			colorR <= (others => '0' );
--			colorG <= (others => '0' );
--			colorB <= (others => '0' );
			video_r_o <= "000";
			video_g_o <= "000";
			video_b_o <= "000";
			video_dhclk_o <= '0';
			video_dlclk_o <= '0';
			vdpVramWrAckP <= '0';
			vdpVramWrAck <= '0';
			vdpVramWrReq <= '0';

			palettewrreqrb_d <= '0';
			palettewrreqg_d <= '0';
			palettewrackrb <= '0';
			palettewrackg <= '0';
			paletteaddr_out <= (others => '0');
			paletteinrb <= '0';
			paletteing <= '0';

			vram_addr_o <= (others => '0');
--			pramadry <= (others => '0');
			vram_data_o <= (others => 'Z');
--			pramdaty <= (others => 'z');
			vram_oe_n_o <= '1';
			vram_we_n_o <= '1';
--			pramoey_n <= '1';
--			pramwey_n <= '1';
			vdpVramAccessing <= '0';
			spPreReading <= '0';
			vdpVramWrReqPd <= '0';
		elsif (clock_i'event and clock_i = '1') then
			if( h_counter = 1363) then
				dotState <= "00";
			else
				case dotState is
					when "00" =>
						dotState <= "01";
						video_dhclk_o <= '1';
						video_dlclk_o <= '0';
					when "01" =>
						dotState <= "11";
						video_dhclk_o <= '0';
						video_dlclk_o <= '0';
					when "11" =>
						dotState <= "10";
						video_dhclk_o <= '1';
						video_dlclk_o <= '1';
					when "10" =>
						dotState <= "00";
						video_dhclk_o <= '0';
						video_dlclk_o <= '1';
					when others => 
						null;
				end case;
			end if;

			vdpVramWrReqPd <= vdpVramWrReqP;

			palettewrreqrb_d <= palettewrreqrb;
			palettewrreqg_d <= palettewrreqg;

			if ( vdpVramWrReqPd /= vdpVramWrAckP ) then
				-- vram write
				vdpVramWrAckP	<= not vdpVramWrAckP;
				vdpVramWrReq	<= not vdpVramWrAck;
			end if;

			--
			-- dotState     10 00 01 11 10 00 01 11 10
			--                |           |
			-- dhclk           00000/11111\
			-- vram_oe_n_o       00000000/111
			-- vram_we_n_o       11111111111100
			-- vram_addr_o      <     >-----<     >
			-- vram_data_io       >zzzzzz
			--                       |
			--

			-- main state
			case dotState is
				when "10" =>
					vram_ce_n_o <= '0';
					if( (vdpModeGraphic7 = '1') and (prewindow = '1') and (vramReadFreeFlag = '0' ) and (vdpR1DispOn='1') ) then
						vram_addr_o <= (vdpR2PtnNameTblBaseAddr(5) & predotcounter_y & predotcounter_x(7 downto 0));
						vram_data_o <= (others => 'Z' );
						vram_oe_n_o <= '0';
						vram_we_n_o <= '1';
					elsif( (vdpModeGraphic4 = '1') and (prewindow = '1') and (vramReadFreeFlag = '0' ) and (dotcounter_x(0) = '1') and (vdpR1DispOn='1') ) then
						vram_addr_o <= (vdpR2PtnNameTblBaseAddr(6 downto 5) & predotcounter_y & predotcounter_x( 7 downto 1));
						vram_data_o <= (others => 'Z' );
						vram_oe_n_o <= '0';
						vram_we_n_o <= '1';
					elsif( (vdpModeGraphic1 = '1') and (g123window = '1') and (dotcounter_x(0) = '1') and (vdpR1DispOn='1') ) then
						-- screen 1
						vram_data_o <= (others => 'Z' );
						vram_oe_n_o <= '0';
						vram_we_n_o <= '1';
						case dotcounter_x(2 downto 0) is
							when "011" =>
								-- read pattern name table
								vram_addr_o <= (vdpR2PtnNameTblBaseAddr & dotcounter_y(7 downto 3) & (dotcounter_x(7 downto 3)+1) );
							when "101" =>
								-- read pattern generator table
								vram_addr_o <= (vdpR4PtnGeneTblBaseAddr & g1PtnNum & dotcounter_y(2 downto 0) );
							when "111" =>
								-- read color table
								vram_addr_o <= (vdpR10R3ColorTblBaseAddr & '0' & g1PtnNum( 7 downto 3 ) );
							when others =>
								null;
						end case;
					elsif( (vdpModeGraphic2 = '1' or vdpModeGraphic3 = '1') and (g123window = '1') and (dotcounter_x(0) = '1') and (vdpR1DispOn='1') ) then
						-- screen 2, 4
						vram_data_o <= (others => 'Z');
						vram_oe_n_o <= '0';
						vram_we_n_o <= '1';
						case dotcounter_x(2 downto 0) is
							when "011" =>
								-- read pattern name table
								vram_addr_o <= (vdpR2PtnNameTblBaseAddr & dotcounter_y(7 downto 3) & (dotcounter_x(7 downto 3)+1) );
							when "101" =>
								-- read pattern generator table
								vram_addr_o <= (vdpR4PtnGeneTblBaseAddr(5 downto 2) &
								               dotcounter_y(7 downto 6) & g1PtnNum & dotcounter_y(2 downto 0) ) and
								               ("1111" & vdpR4PtnGeneTblBaseAddr(1 downto 0) & "11111111" & "111");
							when "111" =>
								-- read color table
								vram_addr_o <= (vdpR10R3ColorTblBaseAddr(10 downto 7) &
								               dotcounter_y(7 downto 6) & g1PtnNum & dotcounter_y(2 downto 0) ) and
								              ("1111" & vdpR10R3ColorTblBaseAddr(6 downto 0) & "111111" );
							when others =>
								null;
						end case;
					elsif( (vdpModeText1 = '1') and (window = '1') and (t1DotCounter_x(0) = '1') and (vdpR1DispOn='1') ) then
						-- text 1 (screen 0)
						vram_data_o <= (others => 'Z' );
						vram_oe_n_o <= '0';
						vram_we_n_o <= '1';
						case t1DotCounter_x is
							when "001" =>
								-- read pattern name table
								vram_addr_o <= (vdpR2PtnNameTblBaseAddr & (t1CharCounter_y+t1CharCounter_x) );
							when "011" =>
								null;
							when "101" =>
								-- read pattern generator table
								vram_addr_o <= (vdpR4PtnGeneTblBaseAddr & t1PtnNum & dotcounter_y(2 downto 0) );
							when others =>
								null;
						end case;
					elsif( vdpVramWrReq /= vdpVramWrAck ) then
						vdpVramAccessing <= '1';
						vdpVramWrAck <= not vdpVramWrAck;
						vram_addr_o <= (vdpVramAccessAddr(16 downto 0));
--						if( vdpVramAccessRw = '0' ) then
							vram_data_o <= vdpVramAccessData;
							vram_oe_n_o <= '1';
							vram_we_n_o <= '0';
--						else
--							vram_data_o <= (others => 'Z' );
--							vram_oe_n_o <= '0';
--							vram_we_n_o <= '1';
--						end if;
--					elsif( vdpvramrdreq /= vdpvramrdack ) then
--						vram_addr_o <= vdpVramAccessAddrTmp(16 downto 0);
					elsif( (spPreReadState /= spState_idle) and (vdpR8SpOff='0') and ( vramReadFreeFlag = '0')  )then
						spPreReading <= '1';
						vram_data_o <= (others => 'Z' );
						vram_oe_n_o <= '0';
						vram_we_n_o <= '1';
						case spPreReadState is
							when spState_yread =>
								vram_addr_o <= (vdpR11R5SpAttrTblBaseAddr & '1' & not spmode2 & '0' & spprereadcounter & "00");
							when spState_xread =>
								vram_addr_o <= (vdpR11R5SpAttrTblBaseAddr & '1' & not spmode2 & '0' & spprereadcounter & "01");
							when spState_ptnnumread =>
								vram_addr_o <= (vdpR11R5SpAttrTblBaseAddr & '1' & not spmode2 & '0' & spprereadcounter & "10");
							when spState_colorRead =>
								if( spmode2 = '0' ) then
									vram_addr_o <= (vdpR11R5SpAttrTblBaseAddr & '1' & not spmode2 & '0' & spprereadcounter & "11");
								else
									-- sprite color table
									vram_addr_o <= (vdpR11R5SpAttrTblBaseAddr & "0" & spprereadcounter & sppreready( 3 downto 0));
								end if;
							when spState_ptnread1 =>
								if( vdpR1SpSize = '0' ) then
									-- 8x8 mode
									vram_addr_o <= (vdpR6SpPtnGeneTblBaseAddr & spprereadptnnum( 7 downto 0) & sppreready( 2 downto 0) );
								else
									-- 16x16 mode
									vram_addr_o <= (vdpR6SpPtnGeneTblBaseAddr & spprereadptnnum( 7 downto 2) & '0' & sppreready( 3 downto 0) );
								end if;
							when spState_ptnread2 =>
								if( vdpR1SpSize = '0' ) then
									-- 8x8 mode
									null;
								else
									-- 16x16 mode
									vram_addr_o <= (vdpR6SpPtnGeneTblBaseAddr & spprereadptnnum( 7 downto 2) & '1' & sppreready( 3 downto 0) );
								end if;
							when others =>
								null;
						end case;
					end if;
					if( bwindow = '1' ) then
						if( vdpModeGraphic7 = '1' ) then
							video_r_o <= colorCode(4 downto 2);
							video_g_o <= colorCode(7 downto 5);
							video_b_o <= colorCode(1 downto 0) & colorCode(1);
						else
							video_r_o <= palettedatarb_out(6 downto 4);
							video_b_o <= palettedatarb_out(2 downto 0);
							video_g_o <= palettedatag_out(2 downto 0);
						end if;
					else
						video_r_o <= (others => '0');
						video_g_o <= (others => '0');
						video_b_o <= (others => '0');
						video_b_o <= (others => '0');
					end if;
				when "00" =>
					if( palettewrreqrb_d /= palettewrackrb ) then
--						paletteaddr_in <= palettewrnum;
						paletteinrb <= '1';
						palettewrackrb <= not palettewrackrb;
					elsif( palettewrreqg_d /= palettewrackg ) then
--						paletteaddr_in <= palettewrnum;
						paletteing <= '1';
						palettewrackg <= not palettewrackg;
					end if;
				when "01" =>
					vram_we_n_o <= '1';
					vram_oe_n_o <= '1';
					vram_data_o <= (others => 'Z');
					vram_addr_o <= (others => 'Z');
					paletteinrb <= '0';
					paletteing <= '0';
					if( (window = '1') and (vdpR1DispOn = '1') ) then
						if (  (sppattern(0)(16) = '1') or (sppattern(1)(16) = '1') or
						   (sppattern(2)(16) = '1') or (sppattern(3)(16) = '1')
--						   (sppattern(4)(16) = '1') or (sppattern(5)(16) = '1') or
--						   (sppattern(6)(16) = '1') or (sppattern(7)(16) = '1')
						) then
							colorCode <= "0000" & spcolorCode;
						elsif( vdpModeGraphic1 = '1' ) then
							if( (vdpR8Color0On = '0') and (g1ColorCode = "0000") ) then
								colorCode <= vdpR7FrameColor;
							else
								colorCode <= "0000" & g1ColorCode;
							end if;
						elsif( vdpModeGraphic2 = '1' or vdpModeGraphic3 = '1' ) then
							if( (vdpR8Color0On = '0') and (g1ColorCode = "0000") ) then
								colorCode <= vdpR7FrameColor;
							else
								colorCode <= "0000" & g1ColorCode;
							end if;
						elsif( vdpModeGraphic4 = '1' ) then
							if( (vdpR8Color0On = '0') and (g4ColorCode = "0000") ) then
								colorCode <= vdpR7FrameColor;
							else
								colorCode <= "0000" & g4ColorCode;
							end if;
						elsif( vdpModeGraphic7 = '1' ) then
							if( (vdpR8Color0On = '0') and (g7ColorCode = "00000000") ) then
								colorCode <= vdpR7FrameColor;
							else
								colorCode <= g7ColorCode;
							end if;
						elsif( vdpModeText1 = '1' ) then
							if( twindow = '0' ) then
								colorCode <= vdpR7FrameColor;
							elsif( (vdpR8Color0On = '0') and (t1ColorCode = "0000") ) then
								colorCode <= vdpR7FrameColor;
							else
								colorCode <= "0000" & t1ColorCode;
							end if;
						end if;
					else
						colorCode <= vdpR7FrameColor;
					end if;
				when "11" =>
					vdpVramAccessing <= '0';
					spPreReading <= '0';

					-- palette decoding
					paletteaddr_out <= colorCode( 3 downto 0);

--					if( vdpModeGraphic7 = '1' ) then
--						colorR <= colorCode( 4 downto 2 );
--						colorG <= colorCode( 7 downto 5 );
--						colorB <= colorCode( 1 downto 0 ) & colorCode(1);
--					else
--						colorR <= paletter( conv_integer( colorCode( 3 downto 0) ) );
--						colorG <= paletteg( conv_integer( colorCode( 3 downto 0) ) );
--						colorB <= paletteb( conv_integer( colorCode( 3 downto 0) ) );
--					end if;

				when others =>
					null;
			end case;
		end if;
	end process;

	-- FIFO control
	process( clock_i, reset_n_i )
	begin
		if reset_n_i = '0' then
			t1ColorCode		<= (others => '0');
			t1PtnNum			<= (others => '0');
			t1Pattern		<= (others => '0');
			g1ColorCode		<= (others => '0');
			g1PtnNum			<= (others => '0');
			g1Pattern		<= (others => '0');
			g1PPattern		<= (others => '0');
			g1Color			<= (others => '0');
			g4ColorCode		<= (others => '0');
			g7ColorCode		<= (others => '0');
			fifoaddr_in		<= (others => '0');
			fifoaddr_out	<= (others => '0');
			fifoin			<= '0';
		elsif (clock_i'event and clock_i = '1') then
			-- text 1 state
			case dotState is
				when "10" =>
					null;
				when "00" =>
					if( t1Pattern(7) = '1' ) then
						t1ColorCode <= vdpR7FrameColor(7 downto 4);
					else
						t1ColorCode <= vdpR7FrameColor(3 downto 0);
					end if;
					t1Pattern <= t1Pattern(6 downto 0) & '0';
				when "01" =>
					case t1DotCounter_x is
						when "001" =>
							-- read pattern name table
							t1PtnNum <= vram_data_i;
						when "011" =>
							null;
						when "101" =>
							-- read pattern generator table
							t1Pattern <= vram_data_i;
						when others =>
							null;
					end case;
				when "11" =>
					null;
				when others =>
					null;
			end case;
	
			-- graphic 1,2,3 state
			case dotState is
				when "10" =>
					null;
				when "00" =>
					if( g1Pattern(7) = '1' ) then
						g1ColorCode <= g1Color(7 downto 4);
					else
						g1ColorCode <= g1Color(3 downto 0);
					end if;
					g1Pattern <= g1Pattern(6 downto 0) & '0';
				when "01" =>
					case dotcounter_x(2 downto 0) is
						when "011" =>
							-- read pattern name table
							g1PtnNum <= vram_data_i;
						when "101" =>
							-- read pattern generator table
							g1PPattern <= vram_data_i;
						when "111" =>
							-- read color table
							g1Color <= vram_data_i;
							g1Pattern <= g1PPattern;
						when others =>
							null;
					end case;
				when "11" =>
					null;
				when others =>
					null;
			end case;
	
			-- graphic 4 state
			case dotState is
				when "10" =>
					null;
				when "00" =>
					if( window = '1' ) then
						if( dotcounter_x(0) = '0' ) then
							g4ColorCode <= fifodata_out(7 downto 4);
						else
							fifoaddr_out <= fifoaddr_out + 1;
							g4ColorCode <= fifodata_out(3 downto 0);
						end if;
					end if;
					if( (prewindow = '1') and (vramReadFreeFlag = '0' ) and (dotcounter_x(0) = '1') ) then
						fifoin <= '1';
					end if;
				when "01" =>
					if( (prewindow = '1') and (vramReadFreeFlag = '0' ) and (dotcounter_x(0) = '1') ) then
						fifoin <= '0';
						fifoaddr_in <= fifoaddr_in + 1;
					end if;
				when "11" =>
					if( predotcounter_x = "011111111" ) then
						fifoaddr_in <= (others => '0');
						fifoaddr_out <= (others => '0');
					end if;
				when others =>
					null;
			end case;
	
			-- graphic 7 state
			case dotState is
				when "10" =>
					null;
				when "00" =>
					if( window = '1' ) then
						fifoaddr_out <= fifoaddr_out + 1;
						g7ColorCode <= fifodata_out;
					end if;
					if( (prewindow = '1') and (vramReadFreeFlag = '0' ) ) then
						fifoin <= '1';
					end if;
				when "01" =>
					if( (prewindow = '1') and (vramReadFreeFlag = '0' ) ) then
						fifoin <= '0';
						fifoaddr_in <= fifoaddr_in + 1;
					end if;
				when "11" =>
					if( predotcounter_x = "011111111" ) then
						fifoaddr_in <= (others => '0');
						fifoaddr_out <= (others => '0');
					end if;
				when others =>
					null;
			end case;
		end if;
	end process;

	-- sprite generator
	process( sppattern, spcc, spmode2, spcolorin )
	begin
		if( spmode2 = '0' ) then
			spcolorCode(3) <= (spcolorin(0) and sppattern(0)(16)) or
			                  ( not sppattern(0)(16) and
			                  (spcolorin(1) and sppattern(1)(16)) ) or
			                  ( not sppattern(0)(16) and not sppattern(1)(16) and
			                  (spcolorin(2) and sppattern(2)(16)) ) or
			                  ( not sppattern(0)(16) and not sppattern(1)(16) and not sppattern(2)(16) and
			                  (spcolorin(3) and sppattern(3)(16)) );
		else
			spcolorCode(3) <= (
			                  (spcolorin(0) and sppattern(0)(16)) or
			                  (spcolorin(1) and sppattern(1)(16) and spcc(1) )
--			                  (spcolorin2 and sppattern2(16) and spcc1 and spcc2 )
--			                  (spcolorin3 and sppattern3(16) and spcc1 and spcc2 and spcc3 ) or
--			                  (spcolorin4 and sppattern4(16) and spcc1 and spcc2 and spcc3 and spcc4 ) or
--			                  (spcolorin5 and sppattern5(16) and spcc1 and spcc2 and spcc3 and spcc4 and spcc5 ) or
--			                  (spcolorin6 and sppattern6(16) and spcc1 and spcc2 and spcc3 and spcc4 and spcc5 and spcc6 ) or
--			                  (spcolorin7 and sppattern7(16) and spcc1 and spcc2 and spcc3 and spcc4 and spcc5 and spcc6 and spcc7 )
			) or (
			                  ( not sppattern(0)(16) and not spcc(1) ) and (
			                  (spcolorin(1) and sppattern(1)(16) ) or
			                  (spcolorin(2) and sppattern(2)(16) and spcc(2) )
--			                  (spcolorin3 and sppattern3(16) and spcc2 and spcc3 ) or
--			                  (spcolorin4 and sppattern4(16) and spcc2 and spcc3 and spcc4 ) or
--			                  (spcolorin5 and sppattern5(16) and spcc2 and spcc3 and spcc4 and spcc5 ) or
--			                  (spcolorin6 and sppattern6(16) and spcc2 and spcc3 and spcc4 and spcc5 and spcc6 ) or
--			                  (spcolorin7 and sppattern7(16) and spcc2 and spcc3 and spcc4 and spcc5 and spcc6 and spcc7 )
			                  )
			) or (
			                  ( not sppattern(0)(16) and not sppattern(1)(16) and not spcc(2) ) and (
			                  (spcolorin(2) and sppattern(2)(16) ) or
			                  (spcolorin(3) and sppattern(3)(16) and spcc(3) )
--			                  (spcolorin4 and sppattern4(16) and spcc3 and spcc4 ) or
--			                  (spcolorin5 and sppattern5(16) and spcc3 and spcc4 and spcc5 ) or
--			                  (spcolorin6 and sppattern6(16) and spcc3 and spcc4 and spcc5 and spcc6 ) or
--			                  (spcolorin7 and sppattern7(16) and spcc3 and spcc4 and spcc5 and spcc6 and spcc7 )
			                  )
			) or (
			                  ( not sppattern(0)(16) and not sppattern(1)(16) and not sppattern(2)(16) and not spcc(3) ) and (
			                  (spcolorin(3) and sppattern(3)(16) )
--			                  (spcolorin(4) and sppattern(4)(16) and spcc(4) ) or
--			                  (spcolorin5 and sppattern5(16) and spcc4 and spcc5 ) or
--			                  (spcolorin6 and sppattern6(16) and spcc4 and spcc5 and spcc6 ) or
--			                  (spcolorin7 and sppattern7(16) and spcc4 and spcc5 and spcc6 and spcc7 )
			                  )
--			) or (
--			                  ( not sppattern(0)(16) and not sppattern(1)(16) and not sppattern(2)(16) and not sppattern(3)(16) and not spcc(4) ) and (
--			                  (spcolorin(4) and sppattern(4)(16) ) or
--			                  (spcolorin(5) and sppattern(5)(16) and spcc(5) )
--			                  (spcolorin6 and sppattern6(16) and spcc5 and spcc6 ) or
--			                  (spcolorin7 and sppattern7(16) and spcc5 and spcc6 and spcc7 )
--			                  )
--			) or (
--			                  ( not sppattern(0)(16) and not sppattern(1)(16) and not sppattern(2)(16) and not sppattern(3)(16) and
--			                  not sppattern(4)(16) and not spcc(5) ) and (
--			                  (spcolorin(5) and sppattern(5)(16) )
--			                  (spcolorin6 and sppattern6(16) and spcc6 ) or
--			                  (spcolorin7 and sppattern7(16) and spcc6 and spcc7 )
--			                  )
--			) or (
--			                  ( not sppattern0(16) and not sppattern1(16) and not sppattern2(16) and not sppattern3(16) and
--			                  not sppattern4(16) and not sppattern5(16) and not spcc6 ) and (
--			                  (spcolorin6 and sppattern6(16) ) or
--			                  (spcolorin7 and sppattern7(16) and spcc7 )
--			                  )
--			) or (
--			                  ( not sppattern0(16) and not sppattern1(16) and not sppattern2(16) and not sppattern3(16) and
--			                  not sppattern4(16) and not sppattern5(16) and not sppattern6(16) and not spcc7 ) and (
--			                  (spcolorin7 and sppattern7(16) )
--			                  )
			);
		end if;
	end process;

  process( clock_i, reset_n_i )
  begin
    if (reset_n_i = '0') then
      for i in 0 to spmode2_nsprites -1 loop
	sppattern(i) <= (others => '0');
	spcolor(i) <= (others => '0');
	spcolorin(i) <= '0';
	spx(i) <= (others => '0');
	spic(i) <= '0';
	spec(i) <= '0';
	spcc(i) <= '0';
      end loop;
      spdispend <= '0';
      spccis0 <= '0';
      spcolorCode(2 downto 0) <= (others => '0' );
      spprereadptnnum <= (others => '0' );
      sppreready <= (others => '0' );
      spPreReadState <= (others => '0' );
      spprereadcounter <= (others => '0' );
      spprereadcounter2 <= (others => '0' );
    elsif (clock_i'event and clock_i = '1') then
      case dotState is
        when "10" =>
          for i in 0 to spmode2_nsprites-1 loop
	    spcolorin(i) <= spcolor(i)(2);
	  end loop;
          spcolorCode(1) <= spcolorCode(3);
          if( (predotcounter_x = "011111111") and (spwindow_y = '1') ) then
            spPreReadState <= spState_idle;
            spprereadcounter <= (others => '0');
            spprereadcounter2 <= (others => '0');
            spy <= dotcounter_y;
          end if;
        when "00" =>
          for i in 0 to spmode2_nsprites-1 loop
	    spcolorin(i) <= spcolor(i)(3);
	  end loop;
          spcolorCode(2) <= spcolorCode(3);
        when "01" =>
          for i in 0 to spmode2_nsprites-1 loop
	    spcolorin(i) <= spcolor(i)(0);
	  end loop;
          if( spPreReading = '1' ) then
            case spPreReadState is
              when spState_yread =>
                sppreready <= spy - vram_data_i;
                if( vram_data_i = "11010000" ) then -- y=208
                  spdispend <= '1';
                end if;
              when spState_xread =>
                spx(conv_integer(spprereadcounter2)) <= '0' & vram_data_i;
              when spState_ptnnumread =>
                spprereadptnnum <= vram_data_i;
              when spState_colorRead =>
		if( vram_data_i(6) = '0' ) then
		  spccis0 <= '1';
		end if;
		spcolor(conv_integer(spprereadcounter2)) <= vram_data_i( 3 downto 0);
		spec(conv_integer(spprereadcounter2)) <= vram_data_i(7);
		spcc(conv_integer(spprereadcounter2)) <= vram_data_i(6);
		spic(conv_integer(spprereadcounter2)) <= vram_data_i(5);
              when spState_ptnread1 =>
                if( (spmode2 = '1' and spccis0 = '1') or (spmode2 = '0') ) then
		  sppattern(conv_integer(spprereadcounter2))(16 downto 8) <= '0' & vram_data_i;
                 end if;
              when spState_ptnread2 =>
                if( vdpR1SpSize = '0' ) then
                                        -- 8x8 mode
		  sppattern(conv_integer(spprereadcounter2))(7 downto 0) <= (others => '0');
                else
                                        -- 16x16 mode
                  if( (spmode2 = '1' and spccis0 = '1') or (spmode2 = '0') ) then
		    sppattern(conv_integer(spprereadcounter2))(7 downto 0) <= vram_data_i;
                  end if;
                end if;
              when others =>
                null;
            end case;
          else
            for i in 0 to spmode2_nsprites - 1 loop
	      if( spx(i)(8) = '1') then
		if( (vdpR1SpZoom='0') or (vdpR1SpZoom='1' and (spx(i)(0)='0')) ) then
		  sppattern(i) <= sppattern(i)(15 downto 0) & '0';
		end if;
	      end if;
	      if( spwindow = '1' ) then
		spx(i) <= spx(i) - 1;
	      elsif( spwindow_ec = '1' ) then
		if( spec(i)='1' ) then
		  spx(i) <= spx(i) - 1;
		end if;
	      end if;
	    end loop;
          end if;
        when "11" =>
	  for i in 0 to spmode2_nsprites - 1 loop
	    spcolorin(i) <= spcolor(i)(1);
	  end loop;
          spcolorCode(0) <= spcolorCode(3);
          if( spPreReadState = spState_idle ) then
             if( spprereadcounter = "00000" ) then
                spPreReadState <= spState_yread;
                spccis0 <= '0';
                spdispend <= '0';
		for i in 0 to spmode2_nsprites - 1 loop
		  sppattern(i) <= (others =>'0');
		end loop;
             end if;
          elsif( spPreReading = '1' ) then
            case spPreReadState is
              when spState_yread =>
                if( spdispend = '1' ) then
                    spPreReadState <= spState_idle;
                elsif( (sppreready( 7 downto 3) = "00000") and (vdpR1SpSize = '0' ) and (vdpR1SpZoom='0') )then
                  spPreReadState <= spState_xread;
                elsif( (sppreready( 7 downto 4) = "0000") and (vdpR1SpSize = '1' ) and (vdpR1SpZoom='0') )then
                  spPreReadState <= spState_xread;
                elsif( (sppreready( 7 downto 4) = "0000") and (vdpR1SpSize = '0' ) and (vdpR1SpZoom='1') )then
                  spPreReadState <= spState_xread;
                  sppreready <= '0' & sppreready(7 downto 1);
                elsif( (sppreready( 7 downto 5) = "000") and (vdpR1SpSize = '1' ) and (vdpR1SpZoom='1') )then
                  spPreReadState <= spState_xread;
                  sppreready <= '0' & sppreready(7 downto 1);
                else
                  if( spprereadcounter = "11111" ) then
                    spPreReadState <= spState_idle;
                  else
                    spPreReadState <= spState_yread;
                    spprereadcounter <= spprereadcounter + 1;
                    -- ?a???????x?v???c?g?v???[?????\????????????aspccis0 ???n???a
                    spccis0 <= '0';
                  end if;
                end if;
              when spState_xread =>
                spPreReadState <= spState_ptnnumread;
              when spState_ptnnumread =>
                spPreReadState <= spState_colorRead;
              when spState_colorRead =>
                spPreReadState <= spState_ptnread1;
              when spState_ptnread1 =>
                spPreReadState <= spState_ptnread2;
              when spState_ptnread2 =>
                if( (spmode2='0') and (spprereadcounter2 = "0011") ) then
                                        -- ???s????~x?v???c?g???????
                  spPreReadState <= spState_idle;
--                elsif( (spmode2='1' and spprereadcounter2 = "0111") ) then
                elsif( (spmode2='1') and (spprereadcounter2 = spmode2_nsprites-1) ) then
                                        -- ???w????~x?v???c?g???????
                  spPreReadState <= spState_idle;
                elsif( spprereadcounter = "11111" ) then
                    spPreReadState <= spState_idle;
		else
		  spprereadcounter <= spprereadcounter + 1;
		  spprereadcounter2 <= spprereadcounter2 + 1;
                  spPreReadState <= spState_yread;
                end if;
              when others =>
                null;
            end case;
          end if;
        when others =>
          null;
      end case;

    end if;
  end process;

	bus_data_o   <= (others => 'Z');

	-- msx slot access
	ioPaCs0   <= '1' when bus_cs_n_i = '0' and (bus_rd_n_i = '0' or bus_wr_n_i = '0')	else '0';
	ioPaCs    <= '1' when ioPaCs0 = '1'    and ioPaCs1 = '0'										else '0';

	process(bus_clock_s, reset_n_i)
	begin
		if (reset_n_i = '0') then
			ioPaCs1 <= '0';
		elsif rising_edge(bus_clock_s) then
			ioPaCs1 <= ioPaCs0;
		end if;
	end process;

	-- vdp mode
	vdpModeText1		<= '1' when (vdpR0DispNum = "000" and vdpR1DispMode = "10") else '0';
--	vdpModeText2		<= '1' when (vdpR0DispNum = "010" and vdpR1DispMode = "10") else '0';
	vdpModeGraphic1	<= '1' when (vdpR0DispNum = "000" and vdpR1DispMode = "00") else '0';
	vdpModeGraphic2	<= '1' when (vdpR0DispNum = "001" and vdpR1DispMode = "00") else '0';
	vdpModeGraphic3	<= '1' when (vdpR0DispNum = "010" and vdpR1DispMode = "00") else '0';
	vdpModeGraphic4	<= '1' when (vdpR0DispNum = "011" and vdpR1DispMode = "00") else '0';
	vdpModeGraphic5	<= '1' when (vdpR0DispNum = "100" and vdpR1DispMode = "00") else '0';
	vdpModeGraphic6	<= '1' when (vdpR0DispNum = "101" and vdpR1DispMode = "00") else '0';
	vdpModeGraphic7	<= '1' when (vdpR0DispNum = "111" and vdpR1DispMode = "00") else '0';
	spmode2				<= '1' when (vdpModeGraphic3 = '1' or vdpModeGraphic4 = '1' or vdpModeGraphic7 = '1' ) else '0';

	-- vdp register access
	process( bus_clock_s, reset_n_i )
	begin
		if (reset_n_i = '0') then
			vdpP1Data						<= (others => '0');
			vdpP1Is1StByte					<= '1';
			vdpP2Is1StByte					<= '1';
			vdpRegWrPulse					<= '0';
			vdpRegPtr						<= (others => '0');
			vdpVramAddrSetReq				<= '0';
			vdpVramWrReqP					<= '0';
			vdpVramAddrSetAck				<= '0';
			vdpVramAccessRw				<= '0';
			vdpVramAccessAddr				<= (others => '0');
			vdpVramAccessAddrTmp			<= (others => '0');
			vdpVramAccessData				<= (others => '0');
			vdpR0DispNum					<= (others => '0');
			vdpR1DispMode					<= (others => '0');
			vdpR1SpSize						<= '0';
			vdpR1SpZoom						<= '0';
			vdpR1DispOn						<= '0';
			vdpR2PtnNameTblBaseAddr		<= (others => '0');
			vdpR4PtnGeneTblBaseAddr		<= (others => '0');
			vdpR10R3ColorTblBaseAddr	<= (others => '0');
			vdpR11R5SpAttrTblBaseAddr	<= (others => '0');
			vdpR6SpPtnGeneTblBaseAddr	<= (others => '0');
			vdpR7FrameColor				<= (others => '0');
			vdpR8SpOff						<= '0';
			vdpR8Color0On					<= '0';
			vdpR9TwoPageMode				<= '0';
			vdpR9InterlaceMode			<= '0';
			vdpR9YDots						<= '0';
			vdpR16PalNum					<= (others => '0');
			vdpR17RegNum					<= (others => '0');
			vdpR17IncRegNum				<= '0';
			vdpR23VStartLine				<= (others => '0');
			-- adjust
			adjust_x							<= offset_x;
			adjust_y							<= offset_y;
			-- palette
			palettewrtemp					<= (others => '0');
			palettewrreqrb					<= '0';
			palettewrreqg					<= '0';
		elsif rising_edge(bus_clock_s) then
			if ioPaCs = '1' and bus_wr_n_i = '0' and bus_addr_i = "00" then			-- port#0 write
				vdpVramWrReqP		<= not vdpVramWrAckP;
				vdpVramAccessData	<= bus_data_i( 7 downto 0);
				if( vdpVramAddrSetReq /= vdpVramAddrSetAck ) then
					vdpVramAccessAddr	<= vdpVramAccessAddrTmp;
					vdpVramAddrSetAck	<= not vdpVramAddrSetAck;
				else
					vdpVramAccessAddr <= vdpVramAccessAddr + 1;
				end if;
			elsif( ioPaCs = '1' and bus_rd_n_i = '0' and bus_addr_i = "00") then		-- port#0 read
				null;
			elsif( ioPaCs = '1' and bus_wr_n_i = '0' and bus_addr_i = "01") then		-- port#1 write
				case vdpP1Is1StByte is
					when '1' =>
						vdpP1Data <= bus_data_i( 7 downto 0);
						vdpP1Is1StByte <= '0';
					when '0' =>
						case bus_data_i( 7 downto 6 ) is
							when "01" =>  -- set vram access address(write)
								vdpVramAccessAddrTmp( 7 downto 0 ) <= vdpP1Data( 7 downto 0);
								vdpVramAccessAddrTmp(13 downto 8 ) <= bus_data_i( 5 downto 0);
								vdpVramAddrSetReq <= not vdpVramAddrSetAck;
								vdpVramAccessRw <= '0';
							when "00" =>  -- set vram access address(read)
								vdpVramAccessAddrTmp( 7 downto 0 ) <= vdpP1Data( 7 downto 0);
								vdpVramAccessAddrTmp(13 downto 8 ) <= bus_data_i( 5 downto 0);
								vdpVramAddrSetReq <= not vdpVramAddrSetAck;
								vdpVramAccessRw <= '1';
							when "10" =>  -- chokusetsu register shitei
								vdpRegPtr <= bus_data_i( 5 downto 0);
								vdpRegWrPulse <= '1';
							when others =>
								null;
						end case;
						vdpP1Is1StByte <= '1';
					when others =>
						null;
				end case;
			elsif( ioPaCs = '1' and bus_rd_n_i = '0' and bus_addr_i = "01") then		-- port#1 read
				vdpP1Is1StByte <= '1';
			elsif( ioPaCs = '1' and bus_wr_n_i = '0' and bus_addr_i = "10") then		-- port#2 write
				case vdpP2Is1StByte is
					when '1' =>
						palettewrtemp	<= bus_data_i;
						palettewrnum	<= vdpR16PalNum;
						palettewrreqrb	<= not palettewrackrb;
--						paletter(conv_integer(vdpR16PalNum)) <= bus_data_io(6 downto 4);
--						paletteb(conv_integer(vdpR16PalNum)) <= bus_data_io(2 downto 0);
						vdpP2Is1StByte <= '0';
					when '0' =>
						palettewrtemp	<= bus_data_i;
						palettewrnum	<= vdpR16PalNum;
						palettewrreqg	<= not palettewrackg;
--						paletteg(conv_integer(vdpR16PalNum)) <= bus_data_i(2 downto 0);
						vdpP2Is1StByte <= '1';
					when others =>
						null;
				end case;
			elsif( ioPaCs = '1' and bus_rd_n_i = '0' and bus_addr_i = "10") then		-- port#2 read
				null;
			elsif( ioPaCs = '1' and bus_wr_n_i = '0' and bus_addr_i = "11") then		-- port#3 write
				if( vdpR17RegNum /= "010001" ) then
					vdpRegWrPulse <= '1';
				end if;
				vdpP1Data <= bus_data_i( 7 downto 0);
				vdpRegPtr <= vdpR17RegNum;
				if( vdpR17IncRegNum = '1' ) then
					vdpR17RegNum <= vdpR17RegNum + 1;
				end if;
			elsif( ioPaCs = '1' and bus_rd_n_i = '0' and bus_addr_i = "11") then		-- port#3 read
				null;
			elsif( vdpRegWrPulse = '1' ) then
				-- register write
				vdpRegWrPulse <= '0';
				case vdpRegPtr is
					when "000000" =>   -- #00
						vdpR0DispNum <= vdpP1Data(3 downto 1);
					when "000001" =>   -- #01
						vdpR1SpZoom <= vdpP1Data(0);
						vdpR1SpSize <= vdpP1Data(1);
						vdpR1DispMode <= vdpP1Data(4 downto 3);
						vdpR1DispOn <= vdpP1Data(6);
					when "000010" =>   -- #02
						vdpR2PtnNameTblBaseAddr <= vdpP1Data( 6 downto 0);
					when "000011" =>   -- #03
						vdpR10R3ColorTblBaseAddr(7 downto 0) <= vdpP1Data( 7 downto 0);
					when "000100" =>   -- #04
						vdpR4PtnGeneTblBaseAddr <= vdpP1Data( 5 downto 0);
					when "000101" =>   -- #05
						vdpR11R5SpAttrTblBaseAddr( 4 downto 0) <= vdpP1Data( 7 downto 3);
					when "000110" =>   -- #06
						vdpR6SpPtnGeneTblBaseAddr <= vdpP1Data( 5 downto 0);
					when "000111" =>   -- #07
						vdpR7FrameColor <= vdpP1Data( 7 downto 0 );
					when "001000" =>   -- #08
						vdpR8SpOff <= vdpP1Data(1);
						vdpR8Color0On <= vdpP1Data(5);
					when "001001" =>   -- #09
						vdpR9TwoPageMode <= vdpP1Data(2);
						vdpR9InterlaceMode <= vdpP1Data(3);
						vdpR9YDots <= vdpP1Data(7);
					when "001010" =>   -- #10
						vdpR10R3ColorTblBaseAddr(10 downto 8) <= vdpP1Data( 2 downto 0);
					when "001011" =>   -- #11
						vdpR11R5SpAttrTblBaseAddr( 6 downto 5) <= vdpP1Data( 1 downto 0);
					when "001110" =>   -- #14
						vdpVramAccessAddrTmp( 16 downto 14 ) <= vdpP1Data( 2 downto 0);
						vdpVramAddrSetReq <= not vdpVramAddrSetAck;
					when "010000" =>   -- #16
						vdpR16PalNum <= vdpP1Data( 3 downto 0 );
					when "010001" =>   -- #17
						vdpR17RegNum <= vdpP1Data( 5 downto 0 );
						vdpR17IncRegNum <= not vdpP1Data(7);
					when "010010" =>   -- #18
						adjust_x <= offset_x - (vdpP1Data(3) & vdpP1Data(3) & vdpP1Data(3) & vdpP1Data(3 downto 0) );
						adjust_y <= offset_y - (vdpP1Data(7) & vdpP1Data(7) & vdpP1Data(7) & vdpP1Data(7 downto 4) );
					when "010111" =>              -- #23
						vdpR23VStartLine <= vdpP1Data;
						null;
					when others =>
						null;
				end case;
			end if;
		end if;
	end process;

end rtl;
