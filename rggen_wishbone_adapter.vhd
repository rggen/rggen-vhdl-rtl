library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_wishbone_adapter is
  generic (
    ADDRESS_WIDTH:        positive  := 8;
    LOCAL_ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:            positive  := 32;
    REGISTERS:            positive  := 1;
    PRE_DECODE:           boolean   := false;
    BASE_ADDRESS:         unsigned  := x"0";
    BYTE_SIZE:            positive  := 256;
    ERROR_STATUS:         boolean   := false;
    USE_STALL:            boolean   := true
  );
  port (
    i_clk:                  in  std_logic;
    i_rst_n:                in  std_logic;
    i_wb_cyc:               in  std_logic;
    i_wb_stb:               in  std_logic;
    o_wb_stall:             out std_logic;
    i_wb_adr:               in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_wb_we:                in  std_logic;
    i_wb_dat:               in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    i_wb_sel:               in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    o_wb_ack:               out std_logic;
    o_wb_err:               out std_logic;
    o_wb_rty:               out std_logic;
    o_wb_dat:               out std_logic_vector(BUS_WIDTH - 1 downto 0);
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
end rggen_wishbone_adapter;

architecture rtl of rggen_wishbone_adapter is
  signal  bus_valid:      std_logic;
  signal  bus_access:     std_logic_vector(1 downto 0);
  signal  bus_address:    std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  bus_write_data: std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_strobe:     std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  bus_ready:      std_logic;
  signal  bus_status:     std_logic_vector(1 downto 0);
  signal  bus_read_data:  std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_ack:        std_logic;
  signal  request_valid:  std_logic_vector(1 downto 0);
  signal  wb_adr:         std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  wb_we:          std_logic;
  signal  wb_dat:         std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  wb_sel:         std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  response_valid: std_logic_vector(1 downto 0);
  signal  response_data:  std_logic_vector(BUS_WIDTH - 1 downto 0);
begin
  o_wb_stall  <= request_valid(1);
  o_wb_ack    <= response_valid(0);
  o_wb_err    <= response_valid(1);
  o_wb_rty    <= '0';
  o_wb_dat    <= response_data;

  bus_valid       <= '1' when (request_valid /= "00") and (response_valid = "00") else '0';
  bus_access(1)   <= '1';
  bus_access(0)   <= wb_we  when request_valid(1) = '1' else i_wb_we;
  bus_address     <= wb_adr when request_valid(1) = '1' else i_wb_adr;
  bus_write_data  <= wb_dat when request_valid(1) = '1' else i_wb_dat;
  bus_strobe      <= wb_sel when request_valid(1) = '1' else i_wb_sel;
  bus_ack         <= bus_valid and bus_ready;

  request_valid(0)  <= i_wb_cyc and i_wb_stb;
  g_stall: if (USE_STALL) generate
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        request_valid(1)  <= '0';
      elsif (rising_edge(i_clk)) then
        if (response_valid /= "00") then
          request_valid(1)  <= '0';
        elsif (request_valid = "01") then
          request_valid(1)  <= '1';
        end if;
      end if;
    end process;

    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        wb_adr  <= (others => '0');
        wb_we   <= '0';
        wb_dat  <= (others => '0');
        wb_sel  <= (others => '0');
      elsif (rising_edge(i_clk)) then
        if (request_valid = "01") then
          wb_adr  <= i_wb_adr;
          wb_we   <= i_wb_we;
          wb_dat  <= i_wb_dat;
          wb_sel  <= i_wb_sel;
        end if;
      end if;
    end process;
  end generate;

  g_no_stall: if (not USE_STALL) generate
    request_valid(1)  <= '0';
    wb_adr            <= (others => '0');
    wb_we             <= '0';
    wb_dat            <= (others => '0');
    wb_sel            <= (others => '0');
  end generate;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      response_valid  <= "00";
    elsif (rising_edge(i_clk)) then
      if (response_valid /= "00") then
        response_valid  <= "00";
      elsif (bus_ack = '1') then
        if (bus_status(1) = '1') then
          response_valid  <= "10";
        else
          response_valid  <= "01";
        end if;
      end if;
    end if;
  end process;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      response_data <= (others => '0');
    elsif (rising_edge(i_clk)) then
      if (bus_ack = '1') then
        response_data <= bus_read_data;
      end if;
    end if;
  end process;

  u_adapter_common: entity work.rggen_adapter_common
    generic map (
      ADDRESS_WIDTH       => ADDRESS_WIDTH,
      LOCAL_ADDRESS_WIDTH => LOCAL_ADDRESS_WIDTH,
      BUS_WIDTH           => BUS_WIDTH,
      REGISTERS           => REGISTERS,
      PRE_DECODE          => PRE_DECODE,
      BASE_ADDRESS        => BASE_ADDRESS,
      BYTE_SIZE           => BYTE_SIZE,
      ERROR_STATUS        => ERROR_STATUS
    )
    port map (
      i_clk                 => i_clk,
      i_rst_n               => i_rst_n,
      i_bus_valid           => bus_valid,
      i_bus_access          => bus_access,
      i_bus_address         => bus_address,
      i_bus_write_data      => bus_write_data,
      i_bus_strobe          => bus_strobe,
      o_bus_ready           => bus_ready,
      o_bus_status          => bus_status,
      o_bus_read_data       => bus_read_data,
      o_register_valid      => o_register_valid,
      o_register_access     => o_register_access,
      o_register_address    => o_register_address,
      o_register_write_data => o_register_write_data,
      o_register_strobe     => o_register_strobe,
      i_register_active     => i_register_active,
      i_register_ready      => i_register_ready,
      i_register_status     => i_register_status,
      i_register_read_data  => i_register_read_data
    );
end rtl;
