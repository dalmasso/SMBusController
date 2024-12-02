# SMBusController

This module implements System Management Bus (SMBus) Controller, compatible with all 15 commands (from SMBus Speficiation 3.3.1). Module supports:
- Controller-Transmitter with Read/Write Operations
- Command Byte activation/deactivation
- PEC (Packet Error Code) activation/deactivation
- Configurable Read/Write Data length
- Bus Busy Detection
- Bus Timeout Detection
- Clock Stretching Detection
- Multimaster (arbitration)

SMBus Controller module is composed of 2 sub-modules:

- SMBus Analyzer: in charge to detect busy status, bus inactivity and timeout, arbitration and clock stretching
- SMBus PEC: in charge to generate Package Error Code (PEC)

**/!\ Require Pull-Up on SMBCLK and SMBDAT pins /!\ **

<img width="1103" alt="Screenshot 2024-12-02 at 17 02 33" src="https://github.com/user-attachments/assets/5533d472-f676-4652-8209-b33d8fb2857e">

## Architecture Overview

<img width="1256" alt="Screenshot 2024-12-02 at 17 07 47" src="https://github.com/user-attachments/assets/65c868b9-3c1d-4eea-be4d-4ed167743b18">

## Usage

The Ready signal indicates no operation is on going and the SMBus Controller is waiting operation.
The Busy signal indicates operation is on going. Reset input can be trigger at any time to reset the SMBus Controller to the IDLE state.

1. Set all necessary inputs
     - Mode (Write only, Read only or Write-then-Read)
     - SMBus Slave Address Delay
     - Enable/Disable SMBus Command to Write
     - Enable/Disable SMBus PEC (Packet Error Code)
     - Set the number of byte to Write (in Write-only and  Write-then-Read modes)
     - Set the number of byte to Read (in Read-only and  Write-then-Read modes)
     - Set SMBus Command Value (SMBus Commande enable)
     - Set SMBus Data to Write
2. Asserts Start input. The Ready signal is de-asserted and the Busy signal is asserted.
3. SMBus Controller re-asserts the Ready signal at the end of transmission (Controller is ready for a new transmission)
4. The Data Read value is available when its validity signal is asserted
5. If an Error occur during transmission, the Error signal is asserterd

## SMBus Controller Pin Description

### Generics

| Name | Description |
| ---- | ----------- |
| INPUT_CLOCK_FREQ | Module Input Clock Frequency |
| SMBUS_CLOCK_FREQ | SMBus Serial Clock Frequency |
| SMBUS_CLASS | SMBus Class (100kHz, 400kHz, 1MHz) |
| MAX_DATA_BIT_LENGTH | Maximum Length of the SMBus Data in bits |

### Ports

| Name | Type | Description |
| ---- | ---- | ----------- |
| i_clock | Input | Module Input Clock |
| i_reset | Input | Reset ('0': No Reset, '1': Reset) |
| i_start | Input | Start SMBus Transmission ('0': No Start, '1': Start) |
| i_mode | Input | Operation Mode ("00": Write-Only, "11": Read-Only, "01": Write-then-Read) |
| i_slave_addr | Input | SMBus Slave Address (7 bits) |
| i_cmd_enable | Input | Command Byte Enable ('0': Disable, '1': Enable) |
| i_pec_enable | Input | Packet Error Code Enable ('0': Disable, '1': Enable) |
| i_data_write_byte_number | Input | Number of Data Bytes to Write |
| i_data_read_byte_number | Input | Number of Data Bytes to Read |
| i_cmd | Input | Command Value to Write |
| i_data_write | Input | Data Value to Write |
| o_data_read | Output | Read Data Value |
| o_data_read_valid | Output | Validity of the Read Data Value ('0': Not Valid, '1': Valid) |
| o_ready | Output | Ready State of SMBus Controller ('0': Not Ready, '1': Ready) |
| o_error | Output | Error State of SMBus Controller ('0': No Error, '1': Error) |
| o_busy | Output | Busy State of SMBus Controller ('0': Not Busy, '1': Busy) |
| io_smbclk | In/Out | SMBus Serial Clock ('0'-'Z'(as '1') values, working with Pull-Up) |
| io_smbdat | In/Out | SMBus Serial Data ('0'-'Z'(as '1') values, working with Pull-Up) |
