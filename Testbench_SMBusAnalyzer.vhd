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
-- Ports
--		Input 	-	i_clock: Module Input Clock
--		Input 	-	i_clock_enable: Module Input Clock Enable
--		Input 	-	i_smbclk_controller: SMBus Serial Clock from Controller
--		Input 	-	i_smbcllk_line: SMBus Serial Clock bus line
--		Input 	-	i_smbdat_controller: SMBus Serial Data from Controller
--		Input 	-	i_smbdat_line: SMBus Serial Data bus line
--		Output 	-	o_smbus_busy: SMBus Busy detection ('0': Not Busy, '1': Busy)
--		Output 	-	o_smbus_timeout: SMBus Timeout detection ('0': No Timeout, '1': Timeout)
--		Output 	-	o_smbus_arbitration: SMBus Arbitration detection ('0': Lost Arbitration, '1': Win Arbitration)
--		Output 	-	o_smbclk_stretching: SMBus Clock Stretching detection ('0': Not Stretching, '1': Stretching)
------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Testbench_SMBusAnalyzer is
end Testbench_SMBusAnalyzer;

architecture Behavioral of Testbench_SMBusAnalyzer is

COMPONENT SMBusAnalyzer is
    
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
    
END COMPONENT;

signal clock_12M: STD_LOGIC := '1';
signal reset: STD_LOGIC := '0';
signal smbclk_controller: STD_LOGIC := '0';
signal smbclk_line: STD_LOGIC := '0';
signal smbdat_controller: STD_LOGIC := '0';
signal smbdat_line: STD_LOGIC := '0';
signal smbus_busy: STD_LOGIC := '0';
signal smbus_timeout: STD_LOGIC := '0';
signal smbus_arbitration: STD_LOGIC := '0';
signal smbclk_stretching: STD_LOGIC := '0';

begin

-- Clock 12 MHz
clock_12M <= not(clock_12M) after 41.6667 ns;
    
-- Reset
reset <= '1', '0' after 3*83.3334 ns, '1' after 101.5 us, '0' after 103 us;

-- SMBus Clock
smbclk_controller <= '1', '0' after 625 ns, '1' after 725 ns, '0' after 1200 ns, '1' after 1500 ns, '0' after 7 us, '1' after 8 us;
smbclk_line <= '1','0' after 625 ns, '1' after 725 ns, '0' after 950 ns, '1' after 1050 ns, '0' after 1150 ns, '1' after 1200 ns, '0' after 1350 ns, '1' after 1500 ns, '0' after 7 us, '1' after 8 us,
                '0' after 200 us, '1' after 400 us, '0' after 500 us;

-- SMBus Data
smbdat_controller <= '1','0' after 500 ns, '1' after 800 ns, '0' after 950 ns, '1' after 1050 ns, '0' after 1150 ns, '1' after 1583.346 ns, '0' after 7 us, '1' after 8 us;
smbdat_line <= '1','0' after 500 ns, '1' after 800 ns, '1' after 950 ns, '0' after 1050 ns, '0' after 1150 ns, '1' after 1583.346 ns, '0' after 7 us, '1' after 8 us;
    
uut: SMBusAnalyzer
    GENERIC map(
     INPUT_CLOCK_FREQ => 12_000_000,
     SMBUS_CLASS => 100_000)
        
    PORT map(
	   i_clock => clock_12M,
	   i_reset => reset,
       i_smbclk_controller => smbclk_controller,
	   i_smbclk_line => smbclk_line,
	   i_smbdat_controller => smbdat_controller,
       i_smbdat_line => smbdat_line,
       o_smbus_busy => smbus_busy,
       o_smbus_timeout => smbus_timeout,
       o_smbus_arbitration => smbus_arbitration,
	   o_smbclk_stretching => smbclk_stretching);
    

end Behavioral;
