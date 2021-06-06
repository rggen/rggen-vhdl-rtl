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
    WRITE_FIRST:          boolean   := true
  );
  port (
    i_clk:                  in  std_logic;
    i_rst_n:                in  std_logic;
    i_awvalid:              in  std_logic;
    o_awready:              out std_logic;
    i_awid:                 in  std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    i_awaddr:               in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_awprot:               in  std_logic_vector(2 downto 0);
    i_wvalid:               in  std_logic;
    o_wready:               out std_logic;
    i_wdata:                in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    i_wstrb:                in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    o_bvalid:               out std_logic;
    i_bready:               in  std_logic;
    o_bid:                  out std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    o_bresp:                out std_logic_vector(1 downto 0);
    i_arvalid:              in  std_logic;
    o_arready:              out std_logic;
    i_arid:                 in  std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    i_araddr:               in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_arprot:               in  std_logic_vector(2 downto 0);
    o_rvalid:               out std_logic;
    i_rready:               in  std_logic;
    o_rid:                  out std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    o_rresp:                out std_logic_vector(1 downto 0);
    o_rdata:                out std_logic_vector(BUS_WIDTH - 1 downto 0);
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
end rggen_axi4lite_adapter;

architecture rtl of rggen_axi4lite_adapter is
  constant  RGGEN_WRITE:            std_logic_vector(1 downto 0)  := "11";
  constant  RGGEN_READ:             std_logic_vector(1 downto 0)  := "10";
  constant  IDLE:                   std_logic_vector(1 downto 0)  := "00";
  constant  BUS_ACCESS_BUSY:        std_logic_vector(1 downto 0)  := "01";
  constant  WAIT_FOR_RESPONSE_ACK:  std_logic_vector(1 downto 0)  := "10";

  function get_request_valid (
    awvalid:  std_logic;
    wvalid:   std_logic;
    arvalid:  std_logic
  ) return std_logic_vector is
    variable  write_valid:  std_logic;
    variable  read_valid:   std_logic;
    variable  valid:        std_logic_vector(1 downto 0);
  begin
    if (WRITE_FIRST) then
      write_valid := awvalid and wvalid;
      read_valid  := arvalid and (not write_valid);
    else
      read_valid  := arvalid;
      write_valid := awvalid and wvalid and (not read_valid);
    end if;

    valid(0)  := write_valid;
    valid(1)  := read_valid;

    return valid;
  end get_request_valid;

  function get_request_ready (
    state:    std_logic_vector;
    awvalid:  std_logic;
    wvalid:   std_logic;
    arvalid:  std_logic
  ) return std_logic_vector is
    variable  awready:  std_logic;
    variable  wready:   std_logic;
    variable  arready:  std_logic;
    variable  ready:    std_logic_vector(2 downto 0);
  begin
    if (WRITE_FIRST) then
      awready := wvalid;
      wready  := awvalid;
      arready := (not awvalid) and (not wvalid);
    else
      arready := '1';
      awready := (not arvalid) and wvalid;
      wready  := (not arvalid) and awvalid;
    end if;

    ready := "000";
    if (state = IDLE) then
      ready(0)  := awready;
      ready(1)  := wready;
      ready(2)  := arready;
    end if;

    return ready;
  end get_request_ready;

  signal  state:                  std_logic_vector(1 downto 0);
  signal  awvalid:                std_logic;
  signal  awready:                std_logic;
  signal  awid:                   std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
  signal  awaddr:                 std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  awprot:                 std_logic_vector(2 downto 0);
  signal  wvalid:                 std_logic;
  signal  wready:                 std_logic;
  signal  wdata:                  std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  wstrb:                  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  bvalid:                 std_logic;
  signal  bready:                 std_logic;
  signal  bid:                    std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
  signal  bresp:                  std_logic_vector(1 downto 0);
  signal  arvalid:                std_logic;
  signal  arready:                std_logic;
  signal  arid:                   std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
  signal  araddr:                 std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  arprot:                 std_logic_vector(2 downto 0);
  signal  rvalid:                 std_logic;
  signal  rready:                 std_logic;
  signal  rid:                    std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
  signal  rresp:                  std_logic_vector(1 downto 0);
  signal  rdata:                  std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_valid:              std_logic;
  signal  bus_access:             std_logic_vector(1 downto 0);
  signal  bus_access_latched:     std_logic_vector(1 downto 0);
  signal  bus_address:            std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  bus_address_latched:    std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  bus_write_data:         std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_write_data_latched: std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_strobe:             std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  bus_strobe_latched:     std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  bus_ready:              std_logic;
  signal  bus_status:             std_logic_vector(1 downto 0);
  signal  bus_read_data:          std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_ack:                std_logic;
  signal  request_valid:          std_logic_vector(1 downto 0);
  signal  request_ready:          std_logic_vector(2 downto 0);
  signal  response_valid:         std_logic_vector(1 downto 0);
  signal  response_ack:           std_logic;
  signal  response_id:            std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
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
  awready <= request_ready(0);
  wready  <= request_ready(1);
  arready <= request_ready(2);

  bus_valid <=
    '1' when (state = IDLE) and (request_valid /= "00") else
    '1' when (state = BUS_ACCESS_BUSY) else
    '0';
  bus_access  <=
    RGGEN_WRITE when (state = IDLE) and (request_valid(0) = '1') else
    RGGEN_READ  when (state = IDLE) and (request_valid(1) = '1') else
    bus_access_latched;
  bus_address <=
    awaddr when (state = IDLE) and (request_valid(0) = '1') else
    araddr when (state = IDLE) and (request_valid(1) = '1') else
    bus_address_latched;
  bus_write_data  <=
    wdata when (state = IDLE) and (request_valid(0) = '1') else
    bus_write_data_latched;
  bus_strobe  <=
    wstrb when (state = IDLE) and (request_valid(0) = '1') else
    bus_strobe_latched;
  bus_ack <= bus_valid and bus_ready;

  request_valid <= get_request_valid(awvalid, wvalid, arvalid);
  request_ready <= get_request_ready(state, awvalid, wvalid, arvalid);

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      bus_access_latched  <= (others => '0');
      bus_address_latched <= (others => '0');
    elsif (rising_edge(i_clk)) then
      if ((state = IDLE) and (request_valid /= "00")) then
        bus_access_latched  <= bus_access;
        bus_address_latched <= bus_address;
      end if;
    end if;
  end process;

  process (i_clk) begin
    if (rising_edge(i_clk)) then
      if ((state = IDLE) and (request_valid /= "00")) then
        bus_write_data_latched  <= bus_write_data;
        bus_strobe_latched      <= bus_strobe;
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
        if ((awvalid and request_ready(0)) = '1') then
          response_id <= i_awid;
        elsif ((arvalid and request_ready(2)) = '1') then
          response_id <= i_arid;
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

  -- FSM
  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      state <= IDLE;
    elsif (rising_edge(i_clk)) then
      if (state = IDLE) then
        if (bus_ack = '1') then
          state <= WAIT_FOR_RESPONSE_ACK;
        elsif (bus_valid = '1') then
          state <= BUS_ACCESS_BUSY;
        end if;
      elsif (state = BUS_ACCESS_BUSY) then
        if (bus_ready = '1') then
          state <= WAIT_FOR_RESPONSE_ACK;
        end if;
      elsif (state = WAIT_FOR_RESPONSE_ACK) then
        if (response_ack = '1') then
          state <= IDLE;
        end if;
      end if;
    end if;
  end process;

  -- Common
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
