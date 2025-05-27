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

  signal  busy:               std_logic;
  signal  inside_range:       std_logic;
  signal  register_active:    std_logic;
  signal  register_ready:     std_logic;
  signal  register_read_data: std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  register_status:    std_logic_vector(1 downto 0);
  signal  register_inactive:  std_logic;
  signal  bus_ready:          std_logic;
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
  g_response_with_error: if (ERROR_STATUS) generate
    constant  RESPONSE_WIDTH: positive  := 2 + BUS_WIDTH + 2;

    signal  response:           std_logic_vector(RESPONSE_WIDTH * REGISTERS - 1 downto 0);
    signal  register_response:  std_logic_vector(RESPONSE_WIDTH - 1 downto 0);
  begin
    process (i_register_ready, i_register_read_data, i_register_status) begin
      for i in 0 to REGISTERS - 1 loop
        response(                                                  RESPONSE_WIDTH * i + 0            )  <= '1';
        response(                                                  RESPONSE_WIDTH * i + 1            )  <= i_register_ready(i);
        response(RESPONSE_WIDTH * i + 2 + BUS_WIDTH     - 1 downto RESPONSE_WIDTH * i + 2            )  <= i_register_read_data(BUS_WIDTH * (i + 1) - 1 downto BUS_WIDTH * i);
        response(RESPONSE_WIDTH * i + 2 + BUS_WIDTH + 2 - 1 downto RESPONSE_WIDTH * i + 2 + BUS_WIDTH)  <= i_register_status(2 * (i + 1) - 1 downto 2 * i);
      end loop;
    end process;

    u_response_mux: entity work.rggen_mux
      generic map (
        WIDTH   => RESPONSE_WIDTH,
        ENTRIES => REGISTERS
      )
      port map (
        i_select  => i_register_active,
        i_data    => response,
        o_data    => register_response
      );

    register_active     <= register_response(0);
    register_ready      <= register_response(1);
    register_read_data  <= register_response(2 + BUS_WIDTH - 1 downto 2);
    register_status     <= register_response(2 + BUS_WIDTH + 2 - 1 downto 2 + BUS_WIDTH);
  end generate;

  g_response_without_error: if (not ERROR_STATUS) generate
    constant  RESPONSE_WIDTH: positive  := 2 + BUS_WIDTH;

    signal  response:           std_logic_vector(RESPONSE_WIDTH * REGISTERS - 1 downto 0);
    signal  register_response:  std_logic_vector(RESPONSE_WIDTH - 1 downto 0);
  begin
    process (i_register_ready, i_register_read_data) begin
      for i in 0 to REGISTERS - 1 loop
        response(                                              RESPONSE_WIDTH * i + 0)  <= '1';
        response(                                              RESPONSE_WIDTH * i + 1)  <= i_register_ready(i);
        response(RESPONSE_WIDTH * i + 2 + BUS_WIDTH - 1 downto RESPONSE_WIDTH * i + 2)  <= i_register_read_data(BUS_WIDTH * (i + 1) - 1 downto BUS_WIDTH * i);
      end loop;
    end process;

    u_response_mux: entity work.rggen_mux
      generic map (
        WIDTH   => RESPONSE_WIDTH,
        ENTRIES => REGISTERS
      )
      port map (
        i_select  => i_register_active,
        i_data    => response,
        o_data    => register_response
      );

    register_active     <= register_response(0);
    register_ready      <= register_response(1);
    register_read_data  <= register_response(2 + BUS_WIDTH - 1 downto 2);
    register_status     <= (others => '0');
  end generate;

  o_bus_ready     <= bus_ready;
  o_bus_status    <= "10" when ERROR_STATUS and (register_inactive = '1') else register_status;
  o_bus_read_data <= register_read_data;

  register_inactive <= (not register_active) or (not inside_range);

  g_bus_ready_with_slicer: if (INSERT_SLICER) generate
  begin
    bus_ready <= busy and (register_ready or register_inactive);
  end generate;

  g_bus_ready_without_slicer: if (not INSERT_SLICER) generate
  begin
    bus_ready <= register_ready or register_inactive;
  end generate;
end rtl;
