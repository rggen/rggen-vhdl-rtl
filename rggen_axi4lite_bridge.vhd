library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_axi4lite_bridge is
  generic (
    ID_WIDTH:       natural   := 0;
    ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:      positive  := 32
  );
  port (
    i_clk:            in  std_logic;
    i_rst_n:          in  std_logic;
    i_bus_valid:      in  std_logic;
    i_bus_access:     in  std_logic_vector(1 downto 0);
    i_bus_address:    in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_bus_write_data: in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    i_bus_strobe:     in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    o_bus_ready:      out std_logic;
    o_bus_status:     out std_logic_vector(1 downto 0);
    o_bus_read_data:  out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_awvalid:        out std_logic;
    i_awready:        in  std_logic;
    o_awid:           out std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    o_awaddr:         out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    o_awprot:         out std_logic_vector(2 downto 0);
    o_wvalid:         out std_logic;
    i_wready:         in  std_logic;
    o_wdata:          out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_wstrb:          out std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    i_bvalid:         in  std_logic;
    o_bready:         out std_logic;
    i_bid:            in  std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    i_bresp:          in  std_logic_vector(1 downto 0);
    o_arvalid:        out std_logic;
    i_arready:        in  std_logic;
    o_arid:           out std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    o_araddr:         out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    o_arprot:         out std_logic_vector(2 downto 0);
    i_rvalid:         in  std_logic;
    o_rready:         out std_logic;
    i_rid:            in  std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    i_rresp:          in  std_logic_vector(1 downto 0);
    i_rdata:          in  std_logic_vector(BUS_WIDTH - 1 downto 0)
  );
end rggen_axi4lite_bridge;

architecture rtl of rggen_axi4lite_bridge is
  constant  RGGEN_WRITE:  std_logic_vector(1 downto 0)  := "11";
  constant  RGGEN_READ:   std_logic_vector(1 downto 0)  := "10";

  signal  request_valid:  std_logic_vector(2 downto 0);
  signal  request_ack:    std_logic_vector(2 downto 0);
  signal  request_done:   std_logic_vector(2 downto 0);
  signal  response_ready: std_logic_vector(1 downto 0);
  signal  bus_ready:      std_logic;
  signal  bus_status:     std_logic_vector(1 downto 0);
  signal  write_access:   std_logic;
  signal  read_access:    std_logic;
begin
  --  Request
  o_awvalid <= request_valid(0);
  o_awid    <= (others => '0');
  o_awaddr  <= i_bus_address;
  o_awprot  <= (others => '0');
  o_wvalid  <= request_valid(1);
  o_wdata   <= i_bus_write_data;
  o_wstrb   <= i_bus_strobe;
  o_arvalid <= request_valid(2);
  o_arid    <= (others => '0');
  o_araddr  <= i_bus_address;
  o_arprot  <= (others => '0');

  request_valid(0)  <= i_bus_valid and (not request_done(0)) and write_access;
  request_valid(1)  <= i_bus_valid and (not request_done(1)) and write_access;
  request_valid(2)  <= i_bus_valid and (not request_done(2)) and read_access;
  request_ack(0)    <= request_valid(0) and i_awready;
  request_ack(1)    <= request_valid(1) and i_wready;
  request_ack(2)    <= request_valid(2) and i_arready;

  write_access  <= '1' when i_bus_access = RGGEN_WRITE else '0';
  read_access   <= '1' when i_bus_access = RGGEN_READ  else '0';

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      request_done  <= "000";
    elsif (rising_edge(i_clk)) then
      if (bus_ready = '1') then
        request_done  <= "000";
      else
        if (request_ack(0) = '1') then
          request_done(0) <= '1';
        end if;
        if (request_ack(1) = '1') then
          request_done(1) <= '1';
        end if;
        if (request_ack(2) = '1') then
          request_done(2) <= '1';
        end if;
      end if;
    end if;
  end process;

  --  Response
  o_bready  <= response_ready(0);
  o_rready  <= response_ready(1);

  o_bus_ready     <= bus_ready;
  o_bus_status    <= bus_status;
  o_bus_read_data <= i_rdata;

  response_ready(0) <= request_done(0) and request_done(1);
  response_ready(1) <= request_done(2);

  bus_ready <=
    (i_bvalid and response_ready(0)) or
    (i_rvalid and response_ready(1));
  bus_status  <=
    i_bresp when response_ready(0) = '1' else
    i_rresp when response_ready(1) = '1' else
    "00";
end rtl;
