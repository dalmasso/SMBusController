----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/19/2024 03:57:42 PM
-- Design Name: 
-- Module Name: Testbench_SMBusPec - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


entity Testbench_SMBusPec is
end Testbench_SMBusPec;

architecture Behavioral of Testbench_SMBusPec is

COMPONENT SMBusPec is

PORT(
	i_clock: IN STD_LOGIC;
    i_reset: IN STD_LOGIC;
	i_enable: IN STD_LOGIC;
	i_data: IN STD_LOGIC_VECTOR(7 downto 0);
    o_pec: OUT STD_LOGIC_VECTOR(7 downto 0)
);

END COMPONENT;

signal clock_12M: STD_LOGIC := '1';
signal reset: STD_LOGIC := '0';
signal enable: STD_LOGIC := '0';
signal data: UNSIGNED(7 downto 0):= (others => '0');
signal pec: STD_LOGIC_VECTOR(7 downto 0):= (others => '0');

begin

-- Clock 12 MHz
clock_12M <= not(clock_12M) after 41.6667 ns;

-- Reset (CRC-8 Single Byte)
process
begin
    reset <= '1';
    wait for 1*83.3334 ns;
    reset <= '0';
    wait for 3*83.3334 ns;
end process;

-- Reset (CRC-8 Multiple Bytes)
--reset <= '1', '0' after 3*83.3334 ns;

-- Enable
process
begin
    enable <= '0';
    wait for 2*83.3334 ns;
    enable <= '1';
    wait for 83.3334 ns;
    enable <= '0';
    wait for 83.3334 ns;
end process;

-- Data input
process
begin
    wait for 4*83.3334 ns;
    data <= data +1;
end process;

uut: SMBusPec    
    PORT map(
        i_clock => clock_12M,
        i_reset => reset,
        i_enable => enable,
        i_data => STD_LOGIC_VECTOR(data),
        o_pec => pec);

end Behavioral;
