------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 18/11/2024
-- Module Name: SMBusController
-- Description:
--      System Management Bus (SMBus) Controller, compatible with all 15 commands (from SMBus Speficiation 3.3.1)
--		Features:
--          - Controller-Transmitter with Read/Write Operations
--			- Controller-Receiver Auto-Dectection (act as Slave/Target)
--			- Command Byte activation/deactivation
--			- PEC (Packet Error Code) activation/deactivation
--			- Configurable Read/Write Data length
--          - Bus Busy Detection
--          - Bus Timeout Detection
--			- Clock Stretching Detection
--			- Multimaster (arbitration)
--
-- WARNING: /!\ Require Pull-Up on SMBCLK and SMBDAT pins /!\
--
-- Usage:
--      ...
--
-- Generics
--		INPUT_CLOCK_FREQ: Module Input Clock Frequency
--		SMBUS_CLOCK_FREQ: SMBus Serial Clock Frequency
--		SMBUS_CLASS: SMBus Class (100kHz, 400kHz, 1MHz)
--		MAX_BUS_LENGTH: Maximum Length of the SMBus Address/Data in bits
--		CONTROLLER_ADDR: Address of this SMBus Controller-Receiver
--
-- Ports
--		Input 	-	i_clock: Module Input Clock
--		Input 	-	i_reset: Reset ('0': No Reset, '1': Reset)
--		Input 	-	i_start: Start SMBus Transmission ('0': No Start, '1': Start)
--		Input 	-	i_mode: Operation Mode ("00": Write-Only, "11": Read-Only, "01": Write-then-Read)
--		Input 	-	i_slave_addr: Slave Address (7 bits)
--		Input 	-	i_cmd_enable: Command Byte Enable ('0': Disable, '1': Enable)
--		Input 	-	i_pec_enable: Packet Error Code Enable ('0': Disable, '1': Enable)
--		Input 	-	i_data_write_length: Data Length to Write in bytes
--		Input 	-	i_data_read_length: Data Length to Read in bytes
--		Input 	-	i_cmd: Command Value to Write
--		Input 	-	i_data_write: Data Value to Write
--		Output 	-	o_data_read: Read Data Value
--		Output 	-	o_data_read_valid: Validity of the Read Data Value ('0': Not Valid, '1': Valid)
--		Output 	-	o_ready: Ready State of SMBus Controller ('0': Not Ready, '1': Ready)
--		Output 	-	o_error: Error State of SMBus Controller ('0': No Error, '1': Error)
--		Output 	-	o_busy: Busy State of SMBus Controller ('0': Not Busy, '1': Busy)
--		In/Out 	-	io_smbclk: SMBus Serial Clock ('0'-'Z'(as '1') values, working with Pull-Up)
--		In/Out 	-	io_smbdat: SMBus Serial Data ('0'-'Z'(as '1') values, working with Pull-Up)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity Testbench_SMBusController is
end Testbench_SMBusController;

architecture Behavioral of Testbench_SMBusController is

COMPONENT SMBusController is

GENERIC(
	INPUT_CLOCK_FREQ: INTEGER := 12_000_000;
	SMBUS_CLOCK_FREQ: INTEGER := 100_000;
	SMBUS_CLASS: INTEGER := 100_000;
	MAX_DATA_BIT_LENGTH: INTEGER := 8
);

PORT(
	i_clock: IN STD_LOGIC;
    i_reset: IN STD_LOGIC;
	i_start: IN STD_LOGIC;
	i_mode: IN STD_LOGIC_VECTOR(1 downto 0);
	i_slave_addr: IN STD_LOGIC_VECTOR(6 downto 0);
	i_cmd_enable: IN STD_LOGIC;
	i_pec_enable: IN STD_LOGIC;
	i_data_write_byte_number: IN INTEGER range 0 to MAX_DATA_BIT_LENGTH/8;
	i_data_read_byte_number: IN INTEGER range 0 to MAX_DATA_BIT_LENGTH/8;
	i_cmd: IN STD_LOGIC_VECTOR(7 downto 0);
	i_data_write: IN STD_LOGIC_VECTOR(MAX_DATA_BIT_LENGTH-1 downto 0);
	o_data_read: OUT STD_LOGIC_VECTOR(MAX_DATA_BIT_LENGTH-1 downto 0);
	o_data_read_valid: OUT STD_LOGIC;
	o_ready: OUT STD_LOGIC;
	o_error: OUT STD_LOGIC;
	o_busy: OUT STD_LOGIC;
	io_smbclk: INOUT STD_LOGIC;
	io_smbdat: INOUT STD_LOGIC
);

END COMPONENT;

signal clock_12M: STD_LOGIC := '1';
signal reset: STD_LOGIC := '0';
signal start: STD_LOGIC := '0';
signal mode: STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
signal slave_addr: STD_LOGIC_VECTOR(6 downto 0) := (others => '0');
signal cmd_enable: STD_LOGIC := '0';
signal pec_enable: STD_LOGIC := '0';
signal cmd: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
signal data_read: STD_LOGIC_VECTOR(8-1 downto 0) := (others => '0');
signal data_read_valid: STD_LOGIC := '0';
signal ready: STD_LOGIC := '0';
signal error: STD_LOGIC := '0';
signal busy: STD_LOGIC := '0';
signal smbclk: STD_LOGIC := '0';
signal smbdat: STD_LOGIC := '0';


begin

-- Clock 12 MHz
clock_12M <= not(clock_12M) after 41.6667 ns;
    
-- Reset
reset <= '1', '0' after 250 ns;

-- Mode
mode <= "00", "11" after 601 us, "01" after 1201 us;

-- Start
start <= '0', '1' after 1 us, '0' after 12 us, '1' after 600 us, '0' after 602 us, '1' after 1200 us, '0' after 1202 us;

-- SMBCLK
smbclk <= 'Z';

-- SMBDAT
smbdat <= 
        -- Write Mode
        'Z',
        -- Write Slave Addr W ACK
        '0' after 100.250802 us,
        'Z' after 110.250882 us,
        -- Write CMD ACK
        '0' after 190.251522 us,
        'Z' after 200.251602 us,
        -- Write Reg ACK
        '0' after 280.252242 us,
        'Z' after 290.252322 us,
         -- Write PEC ACK
        '0' after 370.252962 us,
        'Z' after 380.253042 us,
        
        -- Read Mode
        -- Write Slave Addr R ACK
        '0' after 690.255522 us,
        -- Read Reg Value
        '0' after 700.255602 us,
        '0' after 710.255682 us,
        '1' after 720.255762 us,
        '1' after 730.255842 us,
        '0' after 740.255922 us,
        '0' after 750.256002 us,
        '1' after 760.256082 us,
        '0' after 770.256162 us,
        'Z' after 780.256242 us,
        -- Read PEC Value
        '0' after 790.256322 us,
        '0' after 800.256402 us,
        '0' after 810.256482 us,
        '1' after 820.256562 us,
        '1' after 830.256642 us,
        '0' after 840.256722 us,
        '1' after 850.256802 us,
        '1' after 860.256882 us,
        'Z' after 870.256962 us,

        -- Write-then-Read Mode
        -- Write Slave Addr W ACK
        '0' after 1290.260322 us,
        'Z' after 1300.260402 us,
        -- Write CMD ACK
        '0' after 1380.261042 us,
        'Z' after 1390.261122 us,
        -- Write Reg ACK
        '0' after 1470.261762 us,
        'Z' after 1480.261842 us,
         -- Write Slave Addr R ACK
        '0' after 1570.262562 us,        
         -- Read Reg Value
        '1' after 1580.262642 us,
        '1' after 1590.262722 us,
        '0' after 1600.262802 us,
        '1' after 1610.262882 us,
        '0' after 1620.262962 us,
        '1' after 1630.263042 us,
        '1' after 1640.263122 us,
        '0' after 1650.263202 us,
        'Z' after 1660.263282 us,
        -- Read PEC Value
        '1' after 1670.263362 us,
        '1' after 1680.263442 us,
        '1' after 1690.263522 us,
        '0' after 1700.263602 us,
        '1' after 1710.263682 us,
        '1' after 1720.263762 us,
        '0' after 1730.263842 us,
        '1' after 1740.263922 us,
        'Z' after 1750.264002 us;
        

uut: SMBusController
        
    PORT map(
	i_clock => clock_12M,
    i_reset => reset, 
	i_start => start,
	i_mode => mode,
	i_slave_addr => "1101001",
	i_cmd_enable => '1',
	i_pec_enable => '1',
	i_data_write_byte_number => 1,
	i_data_read_byte_number => 1,
	i_cmd => X"FF",
	i_data_write => "10110010",
	o_data_read => data_read,
	o_data_read_valid => data_read_valid,
	o_ready => ready,
	o_error => error,
	o_busy => busy,
	io_smbclk => smbclk,
	io_smbdat => smbdat);

end Behavioral;
