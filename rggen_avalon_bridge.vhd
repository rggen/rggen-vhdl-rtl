library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_avalon_bridge is
    generic (
      ADDRESS_WIDTH:  positive  := 8;
      BUS_WIDTH:      positive  := 32;
      READ_STROBE:    boolean   := true
    );
    port (
      i_bus_valid:      in  std_logic;
      i_bus_access:     in  std_logic_vector(1 downto 0);
      i_bus_address:    in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
      i_bus_write_data: in  std_logic_vector(BUS_WIDTH - 1 downto 0);
      i_bus_strobe:     in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
      o_bus_ready:      out std_logic;
      o_bus_status:     out std_logic_vector(1 downto 0);
      o_bus_read_data:  out std_logic_vector(BUS_WIDTH - 1 downto 0);
      o_read:           out std_logic;
      o_write:          out std_logic;
      o_address:        out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
      o_byteenable:     out std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
      o_writedata:      out std_logic_vector(BUS_WIDTH - 1 downto 0);
      i_waitrequest:    in  std_logic;
      i_response:       in  std_logic_vector(1 downto 0);
      i_readdata:       in  std_logic_vector(BUS_WIDTH - 1 downto 0)
    );
end rggen_avalon_bridge;

architecture rtl of rggen_avalon_bridge is
begin
  o_read          <= i_bus_valid when i_bus_access = RGGEN_READ else '0';
  o_write         <= i_bus_valid when i_bus_access /= RGGEN_READ else '0';
  o_address       <= i_bus_address;
  o_byteenable    <= i_bus_strobe when (i_bus_access /= RGGEN_READ) or READ_STROBE else (others => '1');
  o_writedata     <= i_bus_write_data;
  o_bus_ready     <= i_bus_valid and (not i_waitrequest);
  o_bus_status    <= i_response;
  o_bus_read_data <= i_readdata;
end rtl;
