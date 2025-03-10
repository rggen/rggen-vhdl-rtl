library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_adapter_common is
  generic (
    ADDRESS_WIDTH:        positive  := 8;
    LOCAL_ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:            positive  := 32;
    STROBE_WIDTH:         positive  := 4;
    REGISTERS:            positive  := 1;
    PRE_DECODE:           boolean   := false;
    BASE_ADDRESS:         unsigned  := x"0";
    BYTE_SIZE:            positive  := 256;
    USE_READ_STROBE:      boolean   := false;
    ERROR_STATUS:         boolean   := false;
    INSERT_SLICER:        boolean   := false
  );
  port (
    i_clk:                  in  std_logic;
    i_rst_n:                in  std_logic;
    i_bus_valid:            in  std_logic;
    i_bus_access:           in  std_logic_vector(1 downto 0);
    i_bus_address:          in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_bus_write_data:       in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    i_bus_strobe:           in  std_logic_vector(STROBE_WIDTH - 1 downto 0);
    o_bus_ready:            out std_logic;
    o_bus_status:           out std_logic_vector(1 downto 0);
    o_bus_read_data:        out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_register_valid:       out std_logic;
    o_register_access:      out std_logic_vector(1 downto 0);
    o_register_address:     out std_logic_vector(LOCAL_ADDRESS_WIDTH - 1 downto 0);
    o_register_write_data:  out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_register_strobe:      out std_logic_vector(BUS_WIDTH - 1 downto 0);
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

  function get_local_address (
    bus_address:  std_logic_vector
  ) return std_logic_vector is
    variable  begin_address:  unsigned(ADDRESS_WIDTH - 1 downto 0);
    variable  local_address:  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  begin
    begin_address := resize(BASE_ADDRESS, ADDRESS_WIDTH);
    if (begin_address(LOCAL_ADDRESS_WIDTH - 1 downto 0) = 0) then
      local_address := bus_address;
    else
      local_address := std_logic_vector(unsigned(bus_address) - begin_address);
    end if;

    return local_address(LOCAL_ADDRESS_WIDTH - 1 downto 0);
  end get_local_address;

  function get_register_strobe (
    bus_access: std_logic_vector;
    bus_strobe: std_logic_vector
  ) return std_logic_vector is
    variable  register_strobe: std_logic_vector(BUS_WIDTH - 1 downto 0);
  begin
    if (bus_access = RGGEN_READ) and (not USE_READ_STROBE) then
      register_strobe := (others => '1');
    elsif bus_strobe'length = BUS_WIDTH then
      register_strobe(STROBE_WIDTH - 1 downto 0)  := bus_strobe;
    else
      for i in 0 to STROBE_WIDTH - 1 loop
        register_strobe(8 * i + 7 downto 8 * i) := (others => bus_strobe(i));
      end loop;
    end if;
    return register_strobe;
  end get_register_strobe;

  function get_bus_ready (
    bus_busy:       std_logic;
    decode_error:   std_logic;
    register_ready: std_logic_vector
  ) return std_logic is
  begin
    if (INSERT_SLICER and (bus_busy = '0')) then
      return '0';
    elsif (decode_error = '1') then
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
  g_request_slicer: if (INSERT_SLICER) generate
    g: block
      signal  bus_valid:      std_logic;
      signal  bus_access:     std_logic_vector(1 downto 0);
      signal  bus_address:    std_logic_vector(LOCAL_ADDRESS_WIDTH - 1 downto 0);
      signal  bus_write_data: std_logic_vector(BUS_WIDTH - 1 downto 0);
      signal  bus_strobe:     std_logic_vector(STROBE_WIDTH - 1 downto 0);
    begin
      o_register_valid      <= bus_valid;
      o_register_access     <= bus_access;
      o_register_address    <= bus_address;
      o_register_write_data <= bus_write_data;
      o_register_strobe     <= get_register_strobe(bus_access, bus_strobe);

      process (i_clk, i_rst_n) begin
        if (i_rst_n = '0') then
          bus_valid <= '0';
        elsif (rising_edge(i_clk)) then
          if (busy = '0') then
            bus_valid <= i_bus_valid and inside_range;
          else
            bus_valid <= '0';
          end if;
        end if;
      end process;

      process (i_clk, i_rst_n) begin
        if (i_rst_n = '0') then
          bus_access      <= "00";
          bus_address     <= (others => '0');
          bus_write_data  <= (others => '0');
          bus_strobe      <= (others => '0');
        elsif (rising_edge(i_clk)) then
          if ((i_bus_valid = '1') and (busy = '0')) then
            bus_access      <= i_bus_access;
            bus_address     <= get_local_address(i_bus_address);
            bus_write_data  <= i_bus_write_data;
            bus_strobe      <= i_bus_strobe;
          end if;
        end if;
      end process;
    end block;
  end generate;

  g_no_request_slicer: if (not INSERT_SLICER) generate
    o_register_valid      <= i_bus_valid and inside_range and (not busy);
    o_register_access     <= i_bus_access;
    o_register_address    <= get_local_address(i_bus_address);
    o_register_write_data <= i_bus_write_data;
    o_register_strobe     <= get_register_strobe(i_bus_access, i_bus_strobe);
  end generate;

  --  response
  o_bus_ready     <= bus_ready;
  o_bus_status    <= get_status(decode_error, i_register_active, i_register_status);
  o_bus_read_data <= mux(i_register_active, i_register_read_data);

  active        <= i_register_active when inside_range = '1' else (others => '0');
  decode_error  <= '1' when unsigned(active) = 0 else '0';
  bus_ready     <= get_bus_ready(busy, decode_error, i_register_ready);
end rtl;
