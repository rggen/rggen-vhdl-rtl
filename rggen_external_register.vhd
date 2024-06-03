library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_external_register is
  generic (
    ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:      positive  := 32;
    STROBE_WIDTH:   positive  := 4;
    START_ADDRESS:  unsigned  := x"0";
    BYTE_SIZE:      positive  := 1
  );
  port (
    i_clk:                  in  std_logic;
    i_rst_n:                in  std_logic;
    i_register_valid:       in  std_logic;
    i_register_access:      in  std_logic_vector(1 downto 0);
    i_register_address:     in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_register_write_data:  in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    i_register_strobe:      in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_register_active:      out std_logic;
    o_register_ready:       out std_logic;
    o_register_status:      out std_logic_vector(1 downto 0);
    o_register_read_data:   out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_register_value:       out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_external_valid:       out std_logic;
    o_external_access:      out std_logic_vector(1 downto 0);
    o_external_address:     out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    o_external_data:        out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_external_strobe:      out std_logic_vector(STROBE_WIDTH - 1 downto 0);
    i_external_ready:       in  std_logic;
    i_external_status:      in  std_logic_vector(1 downto 0);
    i_external_data:        in  std_logic_vector(BUS_WIDTH - 1 downto 0)
  );
end rggen_external_register;

architecture rtl of rggen_external_register is
  constant  END_ADDRESS:  unsigned(START_ADDRESS'range) := START_ADDRESS + BYTE_SIZE - 1;

  function get_external_address (
    register_address: std_logic_vector
  ) return std_logic_vector is
    variable  base:     unsigned(ADDRESS_WIDTH - 1 downto 0);
    variable  address:  std_logic_vector(register_address'range);
  begin
    base    := resize(START_ADDRESS, ADDRESS_WIDTH);
    address := std_logic_vector(unsigned(register_address) - base);
    return address;
  end get_external_address;

  function get_bus_strobe (
    strobe: std_logic_vector
  ) return std_logic_vector is
    variable  bus_strobe: std_logic_vector(STROBE_WIDTH - 1 downto 0);
  begin
    if STROBE_WIDTH = BUS_WIDTH then
      bus_strobe  := strobe(STROBE_WIDTH - 1 downto 0);
    else
      for i in 0 to STROBE_WIDTH - 1 loop
        if strobe(8 * i + 7 downto 8 * i) = x"00" then
          bus_strobe(i) := '0';
        else
          bus_strobe(i) := '1';
        end if;
      end loop;
    end if;

    return bus_strobe;
  end get_bus_strobe;

  signal  address_match:        std_logic;
  signal  external_start:       std_logic;
  signal  external_ack:         std_logic;
  signal  external_valid:       std_logic;
  signal  external_access:      std_logic_vector(1 downto 0);
  signal  external_address:     std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  external_write_data:  std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  external_strobe:      std_logic_vector(STROBE_WIDTH - 1 downto 0);
begin
  --  Decode address
  u_decoder: entity work.rggen_address_decoder
    generic map (
      READABLE      => true,
      WRITABLE      => true,
      ADDRESS_WIDTH => ADDRESS_WIDTH,
      BUS_WIDTH     => BUS_WIDTH,
      START_ADDRESS => START_ADDRESS,
      END_ADDRESS   => END_ADDRESS
    )
    port map (
      i_address           => i_register_address,
      i_access            => i_register_access,
      i_additional_match  => '1',
      o_match             => address_match
    );

  -- Request
  o_external_valid    <= external_valid;
  o_external_access   <= external_access;
  o_external_address  <= external_address;
  o_external_data     <= external_write_data;
  o_external_strobe   <= external_strobe;

  external_start  <= (not external_valid) and i_register_valid and address_match;
  external_ack    <= external_valid and i_external_ready;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      external_valid  <= '0';
    elsif (rising_edge(i_clk)) then
      if (external_ack = '1') then
        external_valid  <= '0';
      elsif (external_start = '1') then
        external_valid  <= '1';
      end if;
    end if;
  end process;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      external_access   <= (others => '0');
      external_address  <= (others => '0');
    elsif (rising_edge(i_clk)) then
      if (external_start = '1') then
        external_access   <= i_register_access;
        external_address  <= get_external_address(i_register_address);
      end if;
    end if;
  end process;

  process (i_clk) begin
    if (rising_edge(i_clk)) then
      if (external_start = '1') then
        external_write_data <= i_register_write_data;
        external_strobe     <= get_bus_strobe(i_register_strobe);
      end if;
    end if;
  end process;

  --  Response
  o_register_active     <= address_match;
  o_register_ready      <= external_ack;
  o_register_status     <= i_external_status;
  o_register_read_data  <= i_external_data;
  o_register_value      <= i_external_data;
end rtl;
