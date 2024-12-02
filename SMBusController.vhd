------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 18/11/2024
-- Module Name: SMBusController
-- Description:
--      System Management Bus (SMBus) Controller, compatible with all 15 commands (from SMBus Speficiation 3.3.1)
--		Features:
--			- Controller-Transmitter with Read/Write Operations
--			- Command Byte activation/deactivation
--			- PEC (Packet Error Code) activation/deactivation
--			- Configurable Read/Write Data length
--			- Bus Busy Detection
--			- Bus Timeout Detection
--			- Clock Stretching Detection
--			- Multimaster (arbitration)
--			- SMBus Classes (100kHz, 400kHz, 1MHz)
--
-- WARNING: /!\ Require Pull-Up on SMBCLK and SMBDAT pins /!\
--
-- Usage:
--      The Ready signal indicates no operation is on going and the SMBus Controller is waiting operation.
--		The Busy signal indicates operation is on going.
--      Reset input can be trigger at any time to reset the SMBus Controller to the IDLE state.
--		1. Set all necessary inputs
--			* Mode (Write only, Read only or Write-then-Read)
--			* SMBus Slave Address Delay
--			* Enable/Disable SMBus Command to Write
--			* Enable/Disable SMBus PEC (Packet Error Code)
--			* Set the number of byte to Write (in Write-only and  Write-then-Read modes)
--			* Set the number of byte to Read (in Read-only and  Write-then-Read modes)
--			* Set SMBus Command Value (SMBus Commande enable)
--			* Set SMBus Data to Write
--      2. Asserts Start input. The Ready signal is de-asserted and the Busy signal is asserted.
--		3. SMBus Controller re-asserts the Ready signal at the end of transmission (Controller is ready for a new transmission)
--		4. The Data Read value is available when its validity signal is asserted
--		5. If an Error occur during transmission, the Error signal is asserterd
--
-- Generics
--		INPUT_CLOCK_FREQ: Module Input Clock Frequency
--		SMBUS_CLOCK_FREQ: SMBus Serial Clock Frequency
--		SMBUS_CLASS: SMBus Class (100kHz, 400kHz, 1MHz)
--		MAX_DATA_BIT_LENGTH: Maximum Length of the SMBus Data in bits
--
-- Ports
--		Input 	-	i_clock: Module Input Clock
--		Input 	-	i_reset: Reset ('0': No Reset, '1': Reset)
--		Input 	-	i_start: Start SMBus Transmission ('0': No Start, '1': Start)
--		Input 	-	i_mode: Operation Mode ("00": Write-Only, "11": Read-Only, "01": Write-then-Read)
--		Input 	-	i_slave_addr: SMBus Slave Address (7 bits)
--		Input 	-	i_cmd_enable: Command Byte Enable ('0': Disable, '1': Enable)
--		Input 	-	i_pec_enable: Packet Error Code Enable ('0': Disable, '1': Enable)
--		Input 	-	i_data_write_byte_number: Number of Data Bytes to Write
--		Input 	-	i_data_read_byte_number: Number of Data Bytes to Read
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

ENTITY SMBusController is

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

END SMBusController;

ARCHITECTURE Behavioral of SMBusController is

------------------------------------------------------------------------
-- Component Declarations
------------------------------------------------------------------------
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

COMPONENT SMBusPec is

	PORT(
		i_clock: IN STD_LOGIC;
		i_reset: IN STD_LOGIC;
		i_enable: IN STD_LOGIC;
		i_data: IN STD_LOGIC_VECTOR(7 downto 0);
		o_pec: OUT STD_LOGIC_VECTOR(7 downto 0)
	);
	
END COMPONENT;

------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- SMBus Clock Dividers
constant CLOCK_DIV: INTEGER := INPUT_CLOCK_FREQ / SMBUS_CLOCK_FREQ;
constant CLOCK_DIV_1_4: INTEGER := CLOCK_DIV /4;
constant CLOCK_DIV_3_4: INTEGER := CLOCK_DIV - CLOCK_DIV_1_4;

-- SMBus Controller Modes ("00": Write-Only, "11": Read-Only, "01": Write-then-Read)
constant SMBUS_WRITE_ONLY_MODE: STD_LOGIC_VECTOR(1 downto 0) := "00";
constant SMBUS_READ_ONLY_MODE: STD_LOGIC_VECTOR(1 downto 0) := "11";
constant SMBUS_WRITE_THEN_READ_MODE: STD_LOGIC_VECTOR(1 downto 0) := "01";

-- SMBus Modes ('0': Write, '1': Read)
constant SMBUS_WRITE_MODE: STD_LOGIC := '0';
constant SMBUS_READ_MODE: STD_LOGIC := '1';

-- SMBus Bit Counter End (8-bit per cycle)
constant SMBUS_BIT_COUNTER_END: UNSIGNED(3 downto 0) := "0111";

-- SMBus SMBDAT Left Shift Value
constant LEFT_SHIFT_EMPTY_VALUE: STD_LOGIC := '0';

-- SMBus IDLE ('Z' with Pull-Up)
constant TRANSMISSION_IDLE: STD_LOGIC := 'Z';

-- SMBus Transmission Don't Care Bit
constant TRANSMISSION_DONT_CARE_BIT: STD_LOGIC := '1';

-- SMBus Transmission Start Bit
constant TRANSMISSION_START_BIT: STD_LOGIC := '0';

-- SMBus Transmission ACK Bit
constant TRANSMISSION_ACK_BIT: STD_LOGIC := '0';

-- SMBus Transmission NACK Bit
constant TRANSMISSION_NACK_BIT: STD_LOGIC := '1';

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- SMBus Controller States
TYPE smbusState is (IDLE, START_TX,
					WRITE_SLAVE_ADDR_W, WRITE_CMD_VALUE, WRITE_REG_VALUE, WRITE_PEC_VALUE,
					RE_START_TX,
					WRITE_SLAVE_ADDR_R, READ_REG_VALUE, READ_PEC_VALUE,
					STOP_TX);
signal state: smbusState := IDLE;
signal next_state: smbusState;

-- SMBus Clock Management
signal clock_divider: INTEGER range 0 to CLOCK_DIV-1 := 0;
signal clock_enable: STD_LOGIC := '0';
signal clock_enable_1_4: STD_LOGIC := '0';
signal clock_enable_3_4: STD_LOGIC := '0';

-- SMBus Bit Counter (8 bits per phass + 1 bit ACK/ACK)
signal bit_counter: UNSIGNED(3 downto 0) := (others => '0');
signal bit_counter_end: STD_LOGIC := '0';

-- SMBus Bit/Byte Counter
signal byte_counter: INTEGER range 0 to MAX_DATA_BIT_LENGTH/8 := 0;
signal byte_counter_end: STD_LOGIC := '0';

-- SMBus SMBCLK & SMBDAT IOs
signal smbclk_in: STD_LOGIC := '0';
signal smbclk_out: STD_LOGIC := '0';
signal smbclk_out_reg: STD_LOGIC := '0';
signal smbdat_in: STD_LOGIC := '0';
signal smbdat_in_reg: STD_LOGIC_VECTOR(MAX_DATA_BIT_LENGTH-1 downto 0) := (others => '0');
signal smbdat_in_valid: STD_LOGIC := '0';
signal smbdat_out: STD_LOGIC := '0';
signal smbdat_out_reg: STD_LOGIC_VECTOR(MAX_DATA_BIT_LENGTH-1 downto 0) := (others => '0');

-- SMBus PEC Signals
signal smbus_pec_reset: STD_LOGIC := '0';
signal smbus_pec_enable: STD_LOGIC := '0';
signal smbus_pec_input: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
signal smbus_pec_value: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
signal smbus_pec_received: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

-- SMBus Analyzer Signals
signal smbus_busy: STD_LOGIC := '0';
signal smbus_timeout: STD_LOGIC := '0';
signal smbus_arbitration: STD_LOGIC := '0';
signal smbclk_stretching: STD_LOGIC := '0';

-- SMBus Error
signal smbus_error: STD_LOGIC := '0';

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

	-------------------------
	-- SMBus Clock Divider --
	-------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Reset Clock Divider
			if (i_reset = '1') or (clock_divider = CLOCK_DIV-1) then
				clock_divider <= 0;

			-- Increment Clock Divider (Waiting no SMBCLK Stretching)
			elsif (smbclk_stretching = '0') then
				clock_divider <= clock_divider +1;
			end if;
		end if;
	end process;

	-------------------------
	-- SMBus Clock Enables --
	-------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- SMBCLK Stretching (Waiting no SMBCLK Stretching)
			if (smbclk_stretching = '0') then

				-- Clock Enable
				if (clock_divider = CLOCK_DIV-1) then
					clock_enable <= '1';
				else
					clock_enable <= '0';
				end if;

				-- Clock Enable (1/4)
				if (clock_divider = CLOCK_DIV_1_4-1) then
					clock_enable_1_4 <= '1';
				else
					clock_enable_1_4 <= '0';
				end if;

				-- Clock Enable (3/4)
				if (clock_divider = CLOCK_DIV_3_4-1) then
					clock_enable_3_4 <= '1';
				else
					clock_enable_3_4 <= '0';
				end if;
			
			-- SMBCLK Stretching (Disable all Clock Enables)
			else
				clock_enable <= '0';
				clock_enable_1_4 <= '0';
				clock_enable_3_4 <= '0';

			end if;
		end if;
	end process;

	-------------------------
	-- SMBus State Machine --
	-------------------------
    -- SMBus State
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Reset State
			if (i_reset = '1') then
				state <= IDLE;
				
			-- Next State (when Clock Enable)
			elsif (clock_enable = '1') then
				state <= next_state;
			end if;
		end if;
	end process;

    -- SMBus Next State
	process(state, i_start, i_mode, i_cmd_enable, i_pec_enable, i_data_write_byte_number, i_data_read_byte_number, smbus_busy, smbus_error, smbus_arbitration, bit_counter_end, byte_counter_end)
	begin

		case state is
			when IDLE => 	if (i_start = '1') and (smbus_busy = '0') then
								next_state <= START_TX;
							else
								next_state <= IDLE;
							end if;

			-- Start Transmission
			when START_TX =>
							-- Read-Only Mode
							if (i_mode = SMBUS_READ_ONLY_MODE) then
								next_state <= WRITE_SLAVE_ADDR_R;

							-- Write-Only or Write-then-Read Modes
							else
								next_state <= WRITE_SLAVE_ADDR_W;
							end if;

			-- Write Slave Address (Write Mode)
			when WRITE_SLAVE_ADDR_W =>
							-- Error
							if (smbus_error = '1') then
								next_state <= STOP_TX;

							-- End of Write Slave Addr Cycle
							elsif (bit_counter_end = '1') then

								-- Write Command
								if (i_cmd_enable = '1') then
									next_state <= WRITE_CMD_VALUE;

								-- No Byte to Write
								elsif (i_data_write_byte_number = 0) then
									next_state <= STOP_TX;

								-- Write Value
								else
									next_state <= WRITE_REG_VALUE;
								end if;

							-- Master Loses Arbitration (during Write Cycle)
							elsif (smbus_arbitration = '0') then
								next_state <= IDLE;

							else
								next_state <= WRITE_SLAVE_ADDR_W;
							end if;

			-- Write Command Value (Write Mode)
			when WRITE_CMD_VALUE =>
							-- Error
							if (smbus_error = '1') then
								next_state <= STOP_TX;

							-- End of Write Command Value Cycle
							elsif (bit_counter_end = '1') then

								-- At least 1 Byte to Write
								if (i_data_write_byte_number /= 0) then
									next_state <= WRITE_REG_VALUE;

								-- Write-then-Read Mode
								elsif (i_mode = SMBUS_WRITE_THEN_READ_MODE) then
									next_state <= RE_START_TX;
							
								-- End of Transmission (Should NOT Happen)
								else
									next_state <= STOP_TX;
								end if;

							-- Master Loses Arbitration (during Write Cycle)
							elsif (smbus_arbitration = '0') then
								next_state <= IDLE;

							else
								next_state <= WRITE_CMD_VALUE;
							end if;

			-- Write Register Value (Write Mode)
			when WRITE_REG_VALUE =>
							-- Error
							if (smbus_error = '1') then
								next_state <= STOP_TX;

							-- End of Write Value Cycle
							elsif (byte_counter_end = '1') then

								-- Write-then-Read Mode
								if (i_mode = SMBUS_WRITE_THEN_READ_MODE) then
									next_state <= RE_START_TX;

								-- Write PEC Value
								elsif (i_pec_enable = '1') then
									next_state <= WRITE_PEC_VALUE;

								-- Stop Transmission
								else
									next_state <= STOP_TX;
								end if;

							-- Master Loses Arbitration (during Write Cycle)
							elsif (bit_counter_end = '0') and (smbus_arbitration = '0') then
								next_state <= IDLE;

							else
								next_state <= WRITE_REG_VALUE;
							end if;

			-- Write PEC Value (Write Mode)
			when WRITE_PEC_VALUE =>
							-- End of Write PEC Value Cycle (Stop Transmission)
							if (bit_counter_end = '1') then
								next_state <= STOP_TX;

							-- Master Loses Arbitration (during Write Cycle)
							elsif (smbus_arbitration = '0') then
								next_state <= IDLE;

							else
								next_state <= WRITE_PEC_VALUE;
							end if;

			-- Re-Start Transmission
			when RE_START_TX => next_state <= WRITE_SLAVE_ADDR_R;

			-- Write Slave Address (Read Mode)
			when WRITE_SLAVE_ADDR_R =>
							-- Error
							if (smbus_error = '1') then
								next_state <= STOP_TX;

							-- End of Write Slave Addr Cycle
							elsif (bit_counter_end = '1') then

								-- No Byte to Write
								if (i_data_read_byte_number = 0) then
									next_state <= STOP_TX;
								else
									next_state <= READ_REG_VALUE;
								end if;

							-- Master Loses Arbitration (during Write Cycle)
							elsif (smbus_arbitration = '0') then
								next_state <= IDLE;

							else
								next_state <= WRITE_SLAVE_ADDR_R;
							end if;

			-- Read Register Value (Read Mode)
			when READ_REG_VALUE =>
							-- End of Read Value Cycle
							if (byte_counter_end = '1') then

								-- Read PEC Value
								if (i_pec_enable = '1') then
									next_state <= READ_PEC_VALUE;

								-- Stop Transmission
								else
									next_state <= STOP_TX;
								end if;

							else
								next_state <= READ_REG_VALUE;
							end if;

			-- Read PEC Value (Read Mode)
			when READ_PEC_VALUE =>
							-- End of Read PEC Value Cycle
							if (bit_counter_end = '1') then
								next_state <= STOP_TX;
							else
								next_state <= READ_PEC_VALUE;
							end if;

			-- Stop Transmission
			when others => next_state <= IDLE;
		end case;
	end process;

	-----------------------
	-- SMBus Bit Counter --
	-----------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Clock Enable
			if (clock_enable = '1') then

				-- Reset Counter
				if (state = IDLE) or (state = START_TX) or (state = RE_START_TX) or (state = STOP_TX) or (bit_counter_end = '1') then
					bit_counter <= (others => '0');

				-- Increment Counter
				else
					bit_counter <= bit_counter +1;
				end if;
			end if;
		end if;
    end process;

	-- Bit Counter End
	bit_counter_end <= bit_counter(3);

	------------------------
	-- SMBus Byte Counter --
	------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then
			
			-- Clock Enable
			if (clock_enable = '1') then

				-- Reset Byte Counter
				if (state = START_TX) or (state = RE_START_TX) then
					byte_counter <= 0;

				-- Increment Byte Counter (bii counter to 7 for anticipation)
				elsif ((state = WRITE_REG_VALUE) or (state = READ_REG_VALUE)) and (bit_counter = SMBUS_BIT_COUNTER_END) then
					byte_counter <= byte_counter +1;
				end if;
			end if;
		end if;
	end process;

	-- Byte Counter End
	byte_counter_end <= '1' when (state = WRITE_REG_VALUE) and (byte_counter = i_data_write_byte_number) else
						'1' when (state = READ_REG_VALUE) and (byte_counter = i_data_read_byte_number) else
						'0';

	----------------------------------
	-- SMBus SMBCLK Output Register --
	----------------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- SMBCLK High ('Z')
			if (clock_enable_1_4 = '1') or (state = IDLE) then
				smbclk_out_reg <= '1';
			
			-- SMBCLK Low ('0')
			elsif (clock_enable_3_4 = '1') and (state /= RE_START_TX) and (state /= STOP_TX) then
				smbclk_out_reg <= '0';
			end if;
		end if;
	end process;
	smbclk_out <= smbclk_out_reg;

	---------------------------------
	-- SMBus SMBDAT Write Register --
	---------------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Clock Enable
			if (clock_enable = '1') then

				-- Load Slave Address (Write/Read Mode)
				if (state = START_TX) then

					if (i_mode = SMBUS_READ_ONLY_MODE) then
						-- Load Slave Address (Read Mode)
						smbdat_out_reg(MAX_DATA_BIT_LENGTH-1 downto MAX_DATA_BIT_LENGTH-8) <= i_slave_addr & SMBUS_READ_MODE;
					else
						-- Load Slave Address (Write Mode)
						smbdat_out_reg(MAX_DATA_BIT_LENGTH-1 downto MAX_DATA_BIT_LENGTH-8) <= i_slave_addr & SMBUS_WRITE_MODE;
					end if;
				
				-- Load Slave Address (Read Mode)
				elsif (state = RE_START_TX) then
					smbdat_out_reg(MAX_DATA_BIT_LENGTH-1 downto MAX_DATA_BIT_LENGTH-8) <= i_slave_addr & SMBUS_READ_MODE;

				-- Load Write Command value / Write Register Value
				elsif (state = WRITE_SLAVE_ADDR_W) and (bit_counter_end = '1') then
					
					-- Load Write Command value
					if (i_cmd_enable = '1') then
						smbdat_out_reg(MAX_DATA_BIT_LENGTH-1 downto MAX_DATA_BIT_LENGTH-8) <= i_cmd;

					-- Load Write Register Value
					else
						smbdat_out_reg <= i_data_write;
					end if;
				
				-- Load Write Register Value
				elsif (state = WRITE_CMD_VALUE) and (bit_counter_end = '1') then
					smbdat_out_reg <= i_data_write;

				-- Load Write PEC Value
				elsif (state = WRITE_REG_VALUE) and (i_pec_enable = '1') and (byte_counter_end = '1') then
					smbdat_out_reg(MAX_DATA_BIT_LENGTH-1 downto MAX_DATA_BIT_LENGTH-8) <= smbus_pec_value;
				
				-- Left-Shift
				else
					smbdat_out_reg <= smbdat_out_reg(MAX_DATA_BIT_LENGTH-2 downto 0) & LEFT_SHIFT_EMPTY_VALUE;
				end if;
			end if;
		end if;
	end process;

	-------------------------------
	-- SMBus SMBDAT Output Value --
	-------------------------------
	process(state, bit_counter_end, byte_counter_end, smbdat_out_reg)
	begin
		-- Start & Stop Transmission
		if (state = START_TX) or (state = STOP_TX) then
			smbdat_out <= TRANSMISSION_START_BIT;

		-- Read Cycles
		elsif (state = READ_REG_VALUE) or (state = READ_PEC_VALUE) then

			-- Last Read Cycle
			if (byte_counter_end = '1') then
				smbdat_out <= TRANSMISSION_NACK_BIT;

			-- End of Read Phase
			elsif (bit_counter_end = '1') then
				smbdat_out <= TRANSMISSION_ACK_BIT;

			-- Read In-Progress
			else
				smbdat_out <= TRANSMISSION_DONT_CARE_BIT;
			end if;

		-- IDLE / Re-Start Cycles / End of Write Cycles
		elsif (state = IDLE) or (state = RE_START_TX) or (bit_counter_end = '1') then
			smbdat_out <= TRANSMISSION_DONT_CARE_BIT;

		-- Write Cycles
		else
			smbdat_out <= smbdat_out_reg(7);
		end if;
	end process;

	-------------------------------
	-- SMBus SMBCLK & SMBDAT IOs --
	-------------------------------
	-- SMBus SMBCLK Input (for Simulation only: '0' when io_smbclk = '0' else '1')
	smbclk_in <= io_smbclk;

	-- SMBus SMBCLK Output ('0' or 'Z' values)
	io_smbclk <= '0' when smbclk_out = '0' else TRANSMISSION_IDLE;

	-- SMBus SMBDAT Input (for Simulation only: '0' when io_smbdat = '0' else '1')
	smbdat_in <= '0' when io_smbdat = '0' else '1';

	-- SMBus SMBDAT Output ('0' or 'Z' values)
	io_smbdat <= '0' when smbdat_out = '0' else TRANSMISSION_IDLE;

	--------------------
	-- SMBus Analyzer --
	--------------------
	inst_smbusAnalyzer: SMBusAnalyzer
		generic map (
			INPUT_CLOCK_FREQ => INPUT_CLOCK_FREQ,
			SMBUS_CLASS => SMBUS_CLASS)

		port map (
			i_clock => i_clock,
			i_reset => i_reset,
			i_smbclk_controller => smbclk_out,
			i_smbclk_line => smbclk_in,
			i_smbdat_controller => smbdat_out,
			i_smbdat_line => smbdat_in,
			o_smbus_busy => smbus_busy,
			o_smbus_timeout => smbus_timeout,
			o_smbus_arbitration => smbus_arbitration,
			o_smbclk_stretching => smbclk_stretching);

	----------------------
	-- SMBus Read Value --
	----------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Clock Enable
			if (clock_enable = '1') then
				
				-- Not End of Read Register Value Phase
				if (state = READ_REG_VALUE) and (bit_counter_end = '0') then
					smbdat_in_reg <= smbdat_in_reg(MAX_DATA_BIT_LENGTH-2 downto 0) & smbdat_in;
				end if;
			end if;
		end if;
	end process;
	o_data_read <= smbdat_in_reg;

	----------------------------
	-- SMBus Read Value Valid --
	----------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- End of Transmission
			if (state = STOP_TX) then

				-- Read Value with PEC
				if (i_pec_enable = '1') then

					-- Verify PEC (Read Value Valid only if PEC OK)
					if (smbus_pec_value = smbus_pec_received) then
						smbdat_in_valid <= '1';
					else
						smbdat_in_valid <= '0';
					end if;

				-- Read Value without PEC
				else
					smbdat_in_valid <= '1';
				end if;

			-- Disable Read Value Valid (New cycle)
			elsif (state /= IDLE) then
				smbdat_in_valid <= '0';
			end if;

		end if;
	end process;
	o_data_read_valid <= smbdat_in_valid;

	--------------------------
	-- SMBus PEC Controller --
	--------------------------
	-- SMBus PEC Reset (when Start Transmission)
	smbus_pec_reset <= '1' when state = START_TX else '0';

	-- SMBus PEC Enable Handler
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Clock Enable & PEC Enable & Write / Read Cycles
			if (clock_enable_1_4 = '1') and (i_pec_enable = '1') and (
				(state = WRITE_SLAVE_ADDR_W) or (state = WRITE_CMD_VALUE) or (state = WRITE_REG_VALUE) or 
				(state = WRITE_SLAVE_ADDR_R) or (state = READ_REG_VALUE)) and (bit_counter_end = '1') then

				smbus_pec_enable <= '1'; 
			else
				smbus_pec_enable <= '0';
			end if;
		end if;
	end process;

	-- SMBus PEC Input Handler
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Clock Enable
			if (clock_enable = '1') then

				-- Write Cycles
				if (state = WRITE_SLAVE_ADDR_W) or (state = WRITE_CMD_VALUE) or (state = WRITE_REG_VALUE) or (state = WRITE_SLAVE_ADDR_R) then
					smbus_pec_input <= smbus_pec_input(6 downto 0) & smbdat_out;

				-- Read Cycles
				elsif (state = READ_REG_VALUE) then
					smbus_pec_input <= smbus_pec_input(6 downto 0) & smbdat_in;
				end if;
			end if;
		end if;
	end process;

	-- SMBus Received PEC Handler
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Clock Enable
			if (clock_enable = '1') then
				
				-- Not End of Read PEC Value Phase
				if (i_pec_enable = '1') and (bit_counter_end = '0') then
					smbus_pec_received <= smbus_pec_received(6 downto 0) & smbdat_in;
				end if;
			end if;
		end if;
	end process;

	------------------------
	-- SMBus PEC Instance --
	------------------------
	inst_smbusPec: SMBusPec
		port map (
			i_clock => i_clock,
			i_reset => smbus_pec_reset,
			i_enable => smbus_pec_enable,
			i_data => smbus_pec_input,
			o_pec => smbus_pec_value);

	------------------------
	-- SMBus Ready Status --
	------------------------
	o_ready <= '1' when state = IDLE and smbus_busy = '0' else '0';

	------------------------
	-- SMBus Busy Status --
	------------------------
	o_busy <= smbus_busy;

	------------------------
	-- SMBus Error Status --
	------------------------
	process(i_clock)
	begin
		if rising_edge(i_clock) then

			-- Disable Error Flag (New cycle)
			if (state = START_TX) then
				smbus_error <= '0';
	
			-- Timeout
			elsif (smbus_timeout = '1') then
				smbus_error <= '1';

			-- Write Cycles
			elsif (state = WRITE_SLAVE_ADDR_W) or (state = WRITE_CMD_VALUE) or (state = WRITE_REG_VALUE) or (state = WRITE_PEC_VALUE) or (state = WRITE_SLAVE_ADDR_R) then

				-- No ACK at the End of Write Cycle
				if (bit_counter_end = '1') and (smbdat_in /= TRANSMISSION_ACK_BIT) then
					smbus_error <= '1';
				end if;
				
			-- Received PEC Error (only in Read or Write-then-Read modes)
			elsif (state = STOP_TX) and (i_pec_enable = '1') and (smbus_pec_value /= smbus_pec_received) then
				smbus_error <= '1';
			end if;
		end if;
	end process;
	o_error <= smbus_error;

end Behavioral;