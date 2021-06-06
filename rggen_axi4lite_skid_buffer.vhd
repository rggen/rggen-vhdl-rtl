library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_axi4lite_skid_buffer is
  generic (
    ID_WIDTH:       natural   := 0;
    ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:      positive  := 32
  );
  port (
    i_clk:      in  std_logic;
    i_rst_n:    in  std_logic;
    i_awvalid:  in  std_logic;
    o_awready:  out std_logic;
    i_awid:     in  std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    i_awaddr:   in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_awprot:   in  std_logic_vector(2 downto 0);
    i_wvalid:   in  std_logic;
    o_wready:   out std_logic;
    i_wdata:    in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    i_wstrb:    in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    o_bvalid:   out std_logic;
    i_bready:   in  std_logic;
    o_bid:      out std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    o_bresp:    out std_logic_vector(1 downto 0);
    i_arvalid:  in  std_logic;
    o_arready:  out std_logic;
    i_arid:     in  std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    i_araddr:   in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_arprot:   in  std_logic_vector(2 downto 0);
    o_rvalid:   out std_logic;
    i_rready:   in  std_logic;
    o_rid:      out std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    o_rresp:    out std_logic_vector(1 downto 0);
    o_rdata:    out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_awvalid:  out std_logic;
    i_awready:  in  std_logic;
    o_awid:     out std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    o_awaddr:   out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    o_awprot:   out std_logic_vector(2 downto 0);
    o_wvalid:   out std_logic;
    i_wready:   in  std_logic;
    o_wdata:    out std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_wstrb:    out std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    i_bvalid:   in  std_logic;
    o_bready:   out std_logic;
    i_bid:      in  std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    i_bresp:    in  std_logic_vector(1 downto 0);
    o_arvalid:  out std_logic;
    i_arready:  in  std_logic;
    o_arid:     out std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    o_araddr:   out std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    o_arprot:   out std_logic_vector(2 downto 0);
    i_rvalid:   in  std_logic;
    o_rready:   out std_logic;
    i_rid:      in  std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
    i_rresp:    in  std_logic_vector(1 downto 0);
    i_rdata:    in  std_logic_vector(BUS_WIDTH - 1 downto 0)
  );
end rggen_axi4lite_skid_buffer;

architecture rtl of rggen_axi4lite_skid_buffer is
  signal  awbusy:   std_logic;
  signal  awvalid:  std_logic;
  signal  awready:  std_logic;
  signal  awid:     std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
  signal  awaddr:   std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  awprot:   std_logic_vector(2 downto 0);
  signal  wbusy:    std_logic;
  signal  wvalid:   std_logic;
  signal  wready:   std_logic;
  signal  wdata:    std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  wstrb:    std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  arbusy:   std_logic;
  signal  arvalid:  std_logic;
  signal  arready:  std_logic;
  signal  arid:     std_logic_vector(clip_id_width(ID_WIDTH) - 1 downto 0);
  signal  araddr:   std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  arprot:   std_logic_vector(2 downto 0);
begin
  --  Write address channel
  o_awready <= awready;
  o_awvalid <= awvalid;
  o_awid    <= awid   when (awbusy = '1') else i_awid;
  o_awaddr  <= awaddr when (awbusy = '1') else i_awaddr;
  o_awprot  <= awprot when (awbusy = '1') else i_awprot;

  awvalid <= i_awvalid or awbusy;
  awready <= not awbusy;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      awbusy  <= '0';
    elsif (rising_edge(i_clk)) then
      if ((awvalid and i_awready) = '1') then
        awbusy  <= '0';
      elsif ((i_awvalid and awready) = '1') then
        awbusy  <= '1';
      end if;
    end if;
  end process;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      awid    <= (others => '0');
      awaddr  <= (others => '0');
      awprot  <= (others => '0');
    elsif (rising_edge(i_clk)) then
      if ((i_awvalid and awready) = '1') then
        awid    <= i_awid;
        awaddr  <= i_awaddr;
        awprot  <= i_awprot;
      end if;
    end if;
  end process;

  --  Write data channel
  o_wready  <= wready;
  o_wvalid  <= wvalid;
  o_wdata   <= wdata when (wbusy = '1') else i_wdata;
  o_wstrb   <= wstrb when (wbusy = '1') else i_wstrb;

  wvalid  <= i_wvalid or wbusy;
  wready  <= not wbusy;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      wbusy  <= '0';
    elsif (rising_edge(i_clk)) then
      if ((wvalid and i_wready) = '1') then
        wbusy  <= '0';
      elsif ((i_wvalid and wready) = '1') then
        wbusy  <= '1';
      end if;
    end if;
  end process;

  process (i_clk) begin
    if (rising_edge(i_clk)) then
      if ((i_wvalid and wready) = '1') then
        wdata <= i_wdata;
        wstrb <= i_wstrb;
      end if;
    end if;
  end process;

  --  Write response channel
  o_bready  <= i_bready;
  o_bvalid  <= i_bvalid;
  o_bid     <= i_bid;
  o_bresp   <= i_bresp;

  --  Read address channel
  o_arready <= arready;
  o_arvalid <= arvalid;
  o_arid    <= arid   when (arbusy = '1') else i_arid;
  o_araddr  <= araddr when (arbusy = '1') else i_araddr;
  o_arprot  <= arprot when (arbusy = '1') else i_arprot;

  arvalid <= i_arvalid or arbusy;
  arready <= not arbusy;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      arbusy  <= '0';
    elsif (rising_edge(i_clk)) then
      if ((arvalid and i_arready) = '1') then
        arbusy  <= '0';
      elsif ((i_arvalid and arready) = '1') then
        arbusy  <= '1';
      end if;
    end if;
  end process;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      arid    <= (others => '0');
      araddr  <= (others => '0');
      arprot  <= (others => '0');
    elsif (rising_edge(i_clk)) then
      if ((i_arvalid and arready) = '1') then
        arid    <= i_arid;
        araddr  <= i_araddr;
        arprot  <= i_arprot;
      end if;
    end if;
  end process;

  --  Read response channel
  o_rready  <= i_rready;
  o_rvalid  <= i_rvalid;
  o_rid     <= i_rid;
  o_rresp   <= i_rresp;
  o_rdata   <= i_rdata;
end rtl;
