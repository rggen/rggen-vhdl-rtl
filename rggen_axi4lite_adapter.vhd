library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_axi4lite_adapter is
  generic (
    ID_WIDTH:             natural   := 0;
    ADDRESS_WIDTH:        positive  := 8;
    LOCAL_ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:            positive  := 32;
    REGISTERS:            positive  := 1;
    PRE_DECODE:           boolean   := false;
    BASE_ADDRESS:         unsigned  := x"0";
    BYTE_SIZE:            positive  := 256;
    ERROR_STATUS:         boolean   := false;
    INSERT_SLICER:        boolean   := false;
    WRITE_FIRST:          boolean   := true
  );
  port (
    i_clk:                  in  std_logic;
    i_rst_n:                in  std_logic;
    i_awvalid:              in  std_logic;
    o_awready:              out std_logic;
    i_awid:                 in  std_logic_vector(clip_width(ID_WIDTH) - 1 downto 0);
    i_awaddr:               in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_awprot:               in  std_logic_vector(2 downto 0);
    i_wvalid:               in  std_logic;
    o_wready:               out std_logic;
    i_wdata:                in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    i_wstrb:                in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    o_bvalid:               out std_logic;
    i_bready:               in  std_logic;
    o_bid:                  out std_logic_vector(clip_width(ID_WIDTH) - 1 downto 0);
    o_bresp:                out std_logic_vector(1 downto 0);
    i_arvalid:              in  std_logic;
    o_arready:              out std_logic;
    i_arid:                 in  std_logic_vector(clip_width(ID_WIDTH) - 1 downto 0);
    i_araddr:               in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_arprot:               in  std_logic_vector(2 downto 0);
    o_rvalid:               out std_logic;
    i_rready:               in  std_logic;
    o_rid:                  out std_logic_vector(clip_width(ID_WIDTH) - 1 downto 0);
    o_rresp:                out std_logic_vector(1 downto 0);
    o_rdata:                out std_logic_vector(BUS_WIDTH - 1 downto 0);
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
end rggen_axi4lite_adapter;

architecture rtl of rggen_axi4lite_adapter is
  constant  RGGEN_WRITE:  std_logic_vector(1 downto 0)  := "11";
  constant  RGGEN_READ:   std_logic_vector(1 downto 0)  := "10";

  function get_request_valid (
    awvalid:  std_logic;
    wvalid:   std_logic;
    arvalid:  std_logic
  ) return std_logic_vector is
    variable  valid:  std_logic_vector(1 downto 0);
  begin
    if (WRITE_FIRST) then
      valid(0)  := awvalid and wvalid;
      valid(1)  := arvalid and (not valid(0));
    else
      valid(0)  := awvalid and wvalid and (not arvalid);
      valid(1)  := arvalid;
    end if;

    return valid;
  end get_request_valid;

  signal  awvalid:                std_logic;
  signal  awready:                std_logic;
  signal  awid:                   std_logic_vector(clip_width(ID_WIDTH) - 1 downto 0);
  signal  awaddr:                 std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  awprot:                 std_logic_vector(2 downto 0);
  signal  wvalid:                 std_logic;
  signal  wready:                 std_logic;
  signal  wdata:                  std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  wstrb:                  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  bvalid:                 std_logic;
  signal  bready:                 std_logic;
  signal  bid:                    std_logic_vector(clip_width(ID_WIDTH) - 1 downto 0);
  signal  bresp:                  std_logic_vector(1 downto 0);
  signal  arvalid:                std_logic;
  signal  arready:                std_logic;
  signal  arid:                   std_logic_vector(clip_width(ID_WIDTH) - 1 downto 0);
  signal  araddr:                 std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  arprot:                 std_logic_vector(2 downto 0);
  signal  rvalid:                 std_logic;
  signal  rready:                 std_logic;
  signal  rid:                    std_logic_vector(clip_width(ID_WIDTH) - 1 downto 0);
  signal  rresp:                  std_logic_vector(1 downto 0);
  signal  rdata:                  std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_valid:              std_logic;
  signal  bus_access:             std_logic_vector(1 downto 0);
  signal  bus_address:            std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  bus_write_data:         std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_strobe:             std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  bus_ready:              std_logic;
  signal  bus_status:             std_logic_vector(1 downto 0);
  signal  bus_read_data:          std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_ack:                std_logic;
  signal  request_valid:          std_logic_vector(1 downto 0);
  signal  request_valid_lathced:  std_logic_vector(1 downto 0);
  signal  response_valid:         std_logic_vector(1 downto 0);
  signal  response_ack:           std_logic;
  signal  response_id:            std_logic_vector(clip_width(ID_WIDTH) - 1 downto 0);
  signal  response_data:          std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  response_status:        std_logic_vector(1 downto 0);
begin
  --  Buffer
  u_buffer: entity work.rggen_axi4lite_skid_buffer
    generic map (
      ID_WIDTH      => ID_WIDTH,
      ADDRESS_WIDTH => ADDRESS_WIDTH,
      BUS_WIDTH     => BUS_WIDTH
    )
    port map (
      i_clk     => i_clk,
      i_rst_n   => i_rst_n,
      i_awvalid => i_awvalid,
      o_awready => o_awready,
      i_awid    => i_awid,
      i_awaddr  => i_awaddr,
      i_awprot  => i_awprot,
      i_wvalid  => i_wvalid,
      o_wready  => o_wready,
      i_wdata   => i_wdata,
      i_wstrb   => i_wstrb,
      o_bvalid  => o_bvalid,
      i_bready  => i_bready,
      o_bid     => o_bid,
      o_bresp   => o_bresp,
      i_arvalid => i_arvalid,
      o_arready => o_arready,
      i_arid    => i_arid,
      i_araddr  => i_araddr,
      i_arprot  => i_arprot,
      o_rvalid  => o_rvalid,
      i_rready  => i_rready,
      o_rid     => o_rid,
      o_rresp   => o_rresp,
      o_rdata   => o_rdata,
      o_awvalid => awvalid,
      i_awready => awready,
      o_awid    => awid,
      o_awaddr  => awaddr,
      o_awprot  => awprot,
      o_wvalid  => wvalid,
      i_wready  => wready,
      o_wdata   => wdata,
      o_wstrb   => wstrb,
      i_bvalid  => bvalid,
      o_bready  => bready,
      i_bid     => bid,
      i_bresp   => bresp,
      o_arvalid => arvalid,
      i_arready => arready,
      o_arid    => arid,
      o_araddr  => araddr,
      o_arprot  => arprot,
      i_rvalid  => rvalid,
      o_rready  => rready,
      i_rid     => rid,
      i_rresp   => rresp,
      i_rdata   => rdata
    );

  --  Request
  awready <= '1' when (bus_ready = '1') and (request_valid(0) = '1') and (response_valid = "00") else '0';
  wready  <= '1' when (bus_ready = '1') and (request_valid(0) = '1') and (response_valid = "00") else '0';
  arready <= '1' when (bus_ready = '1') and (request_valid(1) = '1') and (response_valid = "00") else '0';

  bus_valid       <= '1' when (request_valid /= "00") and (response_valid = "00") else '0';
  bus_access      <= RGGEN_WRITE when (request_valid(0) = '1') else RGGEN_READ;
  bus_address     <= awaddr      when (request_valid(0) = '1') else araddr;
  bus_write_data  <= wdata;
  bus_strobe      <= wstrb;
  bus_ack         <= bus_valid and bus_ready;

  request_valid <=
    request_valid_lathced when (request_valid_lathced /= "00") else
    get_request_valid(awvalid, wvalid, arvalid);

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      request_valid_lathced <= "00";
    elsif (rising_edge(i_clk)) then
      if (bus_ready = '1') then
        request_valid_lathced <= "00";
      elsif (bus_valid = '1') then
        request_valid_lathced <= request_valid;
      end if;
    end if;
  end process;

  -- Response
  bvalid  <= response_valid(0);
  bid     <= response_id;
  bresp   <= response_status;
  rvalid  <= response_valid(1);
  rid     <= response_id;
  rresp   <= response_status;
  rdata   <= response_data;

  response_ack  <=
    (response_valid(0) and bready) or
    (response_valid(1) and rready);
  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      response_valid  <= "00";
    elsif (rising_edge(i_clk)) then
      if (response_ack = '1') then
        response_valid  <= "00";
      elsif (bus_ack = '1') then
        if (bus_access = RGGEN_WRITE) then
          response_valid  <= "01";
        else
          response_valid  <= "10";
        end if;
      end if;
    end if;
  end process;

  g_id: if (ID_WIDTH /= 0) generate
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        response_id <= (others => '0');
      elsif (rising_edge(i_clk)) then
        if ((awvalid and awready) = '1') then
          response_id <= awid;
        elsif ((arvalid and arready) = '1') then
          response_id <= arid;
        end if;
      end if;
    end process;
  end generate;

  g_no_id: if (ID_WIDTH = 0) generate
    response_id <= (others => '0');
  end generate;

  process (i_clk) begin
    if (rising_edge(i_clk)) then
      if (bus_ack = '1') then
        response_status <= bus_status;
        response_data   <= bus_read_data;
      end if;
    end if;
  end process;

  -- Common
  u_adapter_common: entity work.rggen_adapter_common
    generic map (
      ADDRESS_WIDTH       => ADDRESS_WIDTH,
      LOCAL_ADDRESS_WIDTH => LOCAL_ADDRESS_WIDTH,
      BUS_WIDTH           => BUS_WIDTH,
      STROBE_WIDTH        => BUS_WIDTH / 8,
      REGISTERS           => REGISTERS,
      PRE_DECODE          => PRE_DECODE,
      BASE_ADDRESS        => BASE_ADDRESS,
      BYTE_SIZE           => BYTE_SIZE,
      ERROR_STATUS        => ERROR_STATUS,
      INSERT_SLICER       => INSERT_SLICER
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
