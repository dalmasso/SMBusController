------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 30/10/2024
-- Module Name: SMBusAnalyzer
-- Description:
--      SMBus Analyzer in charge to detect:
--          - Bus Busy Detection
--          - Bus Inactivity
--          - Bus Timeout
--          - Bus Arbitration
--          - Clock Stretching
--
-- WARNING: /!\ Require Pull-Up on SMBCLK and SMBDAT pins /!\
--
-- Generics
--		INPUT_CLOCK_FREQ: Module Input Clock Frequency
--		SMBUS_CLASS: SMBus Class (100kHz, 400kHz, 1MHz)
--
-- Ports
--		Input 	-	i_clock: Module Input Clock
--		Input 	-	i_reset: Module Reset ('0': No Reset, '1': Reset)
--		Input 	-	i_smbclk_controller: SMBus Serial Clock from Controller
--		Input 	-	i_smbclk_line: SMBus Serial Clock bus line
--		Input 	-	i_smbdat_controller: SMBus Serial Data from Controller
--		Input 	-	i_smbdat_line: SMBus Serial Data bus line
--		Output 	-	o_smbus_busy: SMBus Busy detection ('0': Not Busy, '1': Busy)
--		Output 	-	o_smbus_timeout: SMBus Timeout detection ('0': No Timeout, '1': Timeout)
--		Output 	-	o_smbus_arbitration: SMBus Arbitration detection ('0': Lost Arbitration, '1': Win Arbitration)
--		Output 	-	o_smbclk_stretching: SMBus Clock Stretching detection ('0': Not Stretching, '1': Stretching)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL."ceil";

ENTITY SMBusAnalyzer is

GENERIC(
    INPUT_CLOCK_FREQ: INTEGER := 12_000_000;
	SMBUS_CLASS: INTEGER := 100_000
);

PORT(
	i_clock: IN STD_LOGIC;
	i_reset: IN STD_LOGIC;
    i_smbclk_controller: IN STD_LOGIC;
	i_smbclk_line: IN STD_LOGIC;
	i_smbdat_controller: IN STD_LOGIC;
    i_smbdat_line: IN STD_LOGIC;
    o_smbus_busy: OUT STD_LOGIC;
    o_smbus_timeout: OUT STD_LOGIC;
    o_smbus_arbitration: OUT STD_LOGIC;
	o_smbclk_stretching: OUT STD_LOGIC
);

END SMBusAnalyzer;

ARCHITECTURE Behavioral of SMBusAnalyzer is
	
------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- SMBus Classes (100kHz, 400kHz, 1MHz)
constant SMBUS_100K_CLASS: INTEGER := 100_000;
constant SMBUS_400K_CLASS: INTEGER := 400_000;
constant SMBUS_1M_CLASS: INTEGER := 1_000_000;

-- SMBus Minimum Free Time (only after Stop condition)
-- SMBus 100kHz Class: 4.7 µs
-- SMBus 400kHz Class: 1.3 µs
-- SMBus 1MHz Class: 0.5 µs
constant SMBUS_100K_MIN_FREE_TIME_NS: INTEGER := 4700;
constant SMBUS_400K_MIN_FREE_TIME_NS: INTEGER := 1300;
constant SMBUS_1M_MIN_FREE_TIME_NS: INTEGER := 500;

-- SMBus Minimum Free Time Cycles ('/1_000_000_000' -> SMBus Minimum Free Time in ns)
constant SMBUS_100K_MIN_FREE_TIME_CYCLES: INTEGER := INTEGER(CEIL(REAL(SMBUS_100K_MIN_FREE_TIME_NS * INPUT_CLOCK_FREQ) / REAL(1_000_000_000)));
constant SMBUS_400K_MIN_FREE_TIME_CYCLES: INTEGER := INTEGER(CEIL(REAL(SMBUS_400K_MIN_FREE_TIME_NS * INPUT_CLOCK_FREQ) / REAL(1_000_000_000)));
constant SMBUS_1M_MIN_FREE_TIME_CYCLES: INTEGER := INTEGER(CEIL(REAL(SMBUS_1M_MIN_FREE_TIME_NS * INPUT_CLOCK_FREQ) / REAL(1_000_000_000)));

-- SMBus Inactivity (50 µs)
constant SMBUS_INACTIVITY_US: INTEGER := 50;

-- SMBus Inactivity Cycles ('/1_000_000' -> SMBus Inactivity in µs)
constant SMBUS_INACTIVITY_CYCLES: INTEGER := INTEGER(CEIL(REAL(SMBUS_INACTIVITY_US * INPUT_CLOCK_FREQ) / REAL(1_000_000)));

-- SMBus Timeout (35 ms)
constant SMBUS_TIMEOUT_MS: INTEGER := 35;

-- SMBus Timeout Cycles ('/1_000' -> SMBus Timeout in ms)
constant SMBUS_TIMEOUT_CYCLES: INTEGER := INTEGER(CEIL(REAL(SMBUS_TIMEOUT_MS * INPUT_CLOCK_FREQ) / REAL(1_000)));

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- SMBus SMBCLK / SMBDAT Line Levels
signal smbclk_line_level: STD_LOGIC := '0';
signal smbdat_line_level: STD_LOGIC := '0';
signal smbdat_line_level_reg: STD_LOGIC := '0';

-- SMBus Start & Stop Conditions
signal smbus_start_cond: STD_LOGIC := '0';
signal smbus_stop_cond: STD_LOGIC := '0';

-- SMBus Busy & Timing Counter
signal smbus_busy: STD_LOGIC := '0';
signal busy_timing_counter: INTEGER range 0 to SMBUS_INACTIVITY_CYCLES := 0;
signal busy_timing_counter_end: STD_LOGIC := '0';

-- SMBus Timeout
signal timeout_counter: INTEGER range 0 to SMBUS_TIMEOUT_CYCLES := 0;

-- SMBus Arbitration
signal smbus_arbitration: STD_LOGIC := '0';

-- SMBus Clock Stretching
signal smbclk_stretching: STD_LOGIC := '0';

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin
	---------------------------------------
	-- SMBus SMBCLK Line Level Converter --
	---------------------------------------
	-- Convert 'Z' into '1' level
	smbclk_line_level <= '0' when i_smbclk_line = '0' else '1';

	---------------------------------------
	-- SMBus SMBDAT Line Level Converter --
	---------------------------------------
	-- Convert 'Z' into '1' level
	smbdat_line_level <= '0' when i_smbdat_line = '0' else '1';
    
	-- SMBDAT Line Level Register
	process(i_clock)
	begin
		if rising_edge(i_clock) then
			smbdat_line_level_reg <= smbdat_line_level;
		end if;
	end process;

	-------------------------------------
	-- SMBus Start Condition Detection --
	-------------------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Start Condition (SMBCLK High while SDA High to Low)
			if (smbclk_line_level = '1') and (smbdat_line_level_reg = '1') and (smbdat_line_level = '0') then
				smbus_start_cond <= '1';
			else
				smbus_start_cond <= '0';
			end if;
		end if;
	end process;

	------------------------------------
	-- SMBus Stop Condition Detection --
	------------------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Stop Condition Detection while SMBus Busy
			if (smbus_busy = '1') then

				-- Stop Condition (SMBCLK High while SDA Low to High)
				if (smbclk_line_level = '1') and (smbdat_line_level_reg = '0') and (smbdat_line_level = '1') then
					smbus_stop_cond <= '1';
				end if;
			
			-- Disable Stop Condition (SMBus NOT Busy)
			else
				smbus_stop_cond <= '0';
			
			end if;
		end if;
	end process;

	-------------------------------
	-- SMBus Busy Timing Counter --
	-------------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Reset Counter when Reset or SMBCLK / SMBDAT toggle
			if (i_reset = '1') or (smbclk_line_level = '0') or (smbdat_line_level = '0') then
				busy_timing_counter <= 0;

			-- Increment Counter (SMBCLK & SMBDAT High)
			else
				busy_timing_counter <= busy_timing_counter +1;
			end if;
		end if;
	end process;

	-- Busy Timing Counter End
	busy_timing_counter_end <= 	'1' when smbus_stop_cond = '1' and busy_timing_counter = SMBUS_100K_MIN_FREE_TIME_CYCLES and SMBUS_CLASS = SMBUS_100K_CLASS else
								'1' when smbus_stop_cond = '1' and busy_timing_counter = SMBUS_400K_MIN_FREE_TIME_CYCLES and SMBUS_CLASS = SMBUS_400K_CLASS else
								'1' when smbus_stop_cond = '1' and busy_timing_counter = SMBUS_1M_MIN_FREE_TIME_CYCLES and SMBUS_CLASS = SMBUS_1M_CLASS else
								'1' when busy_timing_counter = SMBUS_INACTIVITY_CYCLES else
								'0';

	--------------------------
	-- SMBus Busy Detection --
	--------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then
			
			-- Bus IDLE when Reset / Stop Condition then Minimum Free Time or after Inactivity Period
			if (i_reset = '1') or (busy_timing_counter_end = '1') then
				smbus_busy <= '0';
			
			-- Bus BUSY when Start Condition (SMBCLK High while SDA High to Low)
			elsif (smbus_start_cond = '1') then
				smbus_busy <= '1';

			end if;
		end if;
	end process;
	o_smbus_busy <= smbus_busy;

	---------------------------
	-- SMBus Timeout Counter --
	---------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Reset Counter when Reset or SMBCLK is High
			if (i_reset = '1') or (smbclk_line_level = '1') then
				timeout_counter <= 0;

			-- Increment Counter
			else
				timeout_counter <= timeout_counter +1;
			end if;
		end if;
	end process;

	-- SMBus Timeout
	o_smbus_timeout <= 	'1' when timeout_counter = SMBUS_TIMEOUT_CYCLES else '0';

	---------------------------
	-- SMBus Bus Arbitration --
	---------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then
			
			-- SMBDAT from Controller = SMBDAT Line (when SMBCLK is High)
			if (smbclk_line_level = '1') then
				smbus_arbitration <= i_smbdat_controller xnor smbdat_line_level;
			end if;

		end if;
	end process;
    o_smbus_arbitration <= smbus_arbitration;

    -----------------------------
	-- SMBus SMBCLK Stretching --
	-----------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then
			
			-- SMBus Controller release SMBCLK ('Z') while SMBus Target pull-down SMBCLK
			smbclk_stretching <= i_smbclk_controller and not(smbclk_line_level);

		end if;
	end process;
	o_smbclk_stretching <= smbclk_stretching;

end Behavioral;