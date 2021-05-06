library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_adapter_common is
  generic (
    ADDRESS_WIDTH:        positive  := 8;
    LOCAL_ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:            positive  := 32;
    REGISTERS:            positive  := 1;
    PRE_DECODE:           boolean   := false;
    BASE_ADDRESS:         unsigned  := x"0";
    BYTE_SIZE:            positive  := 256;
    ERROR_STATUS:         boolean   := false
  );
  port (
    i_clk:                  in  std_logic;
    i_rst_n:                in  std_logic;
    i_bus_valid:            in  std_logic;
    i_bus_access:           in  std_logic_vector(1 downto 0);
    i_bus_address:          in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_bus_write_data:       in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    i_bus_strobe:           in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    o_bus_ready:            out std_logic;
    o_bus_status:           out std_logic_vector(1 downto 0);
    o_bus_read_data:        out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_register_valid:       out std_logic;
    o_register_access:      out std_logic_vector(1 downto 0);
    o_register_address:     out std_logic_vector(LOCAL_ADDRESS_WIDTH - 1 downto 0);
    o_register_write_data:  out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_register_strobe:      out std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    i_register_active:      in  std_logic_vector(1 * REGISTERS - 1 downto 0);
    i_register_ready:       in  std_logic_vector(1 * REGISTERS - 1 downto 0);
    i_register_status:      in  std_logic_vector(2 * REGISTERS - 1 downto 0);
    i_register_read_data:   in  std_logic_vector(BUS_WIDTH * REGISTERS - 1 downto 0)
  );
end rggen_adapter_common;

architecture rtl of rggen_adapter_common is
  function decode_address (
    bus_address:  std_logic_vector
  ) return std_logic is
    variable  begin_address:  unsigned(ADDRESS_WIDTH - 1 downto 0);
    variable  end_address:    unsigned(ADDRESS_WIDTH - 1 downto 0);
    variable  result_0:       boolean;
    variable  result_1:       boolean;
  begin
    if (PRE_DECODE) then
      begin_address := resize(BASE_ADDRESS, ADDRESS_WIDTH);
      end_address   := begin_address + BYTE_SIZE - 1;
      result_0      := unsigned(bus_address) >= begin_address;
      result_1      := unsigned(bus_address) <= end_address;
    else
      result_0  := true;
      result_1  := true;
    end if;

    if (result_0 and result_1) then
      return '1';
    else
      return '0';
    end if;
  end decode_address;

  function get_bus_ready (
    decode_error:   std_logic;
    register_ready: std_logic_vector
  ) return std_logic is
  begin
    if (decode_error = '1') then
      return '1';
    elsif (unsigned(register_ready) /= 0) then
      return '1';
    else
      return '0';
    end if;
  end get_bus_ready;

  function get_status (
    decode_error:     std_logic;
    register_active:  std_logic_vector;
    register_status:  std_logic_vector
  ) return std_logic_vector is
    variable  result: std_logic_vector(1 downto 0);
  begin
    if (ERROR_STATUS and (decode_error = '1')) then
      result  := "10";
    else
      result  := mux(register_active, register_status);
    end if;
    return result;
  end get_status;

  signal  busy:         std_logic;
  signal  inside_range: std_logic;
  signal  bus_ready:    std_logic;
  signal  active:       std_logic_vector(REGISTERS - 1 downto 0);
  signal  decode_error: std_logic;
begin
  --  state
  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      busy  <= '0';
    elsif (rising_edge(i_clk)) then
      if (bus_ready = '1') then
        busy  <= '0';
      elsif (i_bus_valid = '1') then
        busy  <= '1';
      end if;
    end if;
  end process;

  --  pre decode
  inside_range  <= decode_address(i_bus_address);

  --  request
  o_register_valid      <= i_bus_valid and inside_range and (not busy);
  o_register_access     <= i_bus_access;
  o_register_address    <= i_bus_address(LOCAL_ADDRESS_WIDTH - 1 downto 0);
  o_register_write_data <= i_bus_write_data;
  o_register_strobe     <= i_bus_strobe;

  --  response
  o_bus_ready     <= bus_ready;
  o_bus_status    <= get_status(decode_error, i_register_active, i_register_status);
  o_bus_read_data <= mux(i_register_active, i_register_read_data);

  active        <= i_register_active when inside_range = '1' else (others => '0');
  decode_error  <= '1' when unsigned(active) = 0 else '0';
  bus_ready     <= get_bus_ready(decode_error, i_register_ready);
end rtl;
