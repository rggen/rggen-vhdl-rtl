library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_avalon_adapter is
  generic (
    ADDRESS_WIDTH:        positive  := 8;
    LOCAL_ADDRESS_WIDTH:  positive  := 8;
    BUS_WIDTH:            positive  := 32;
    REGISTERS:            positive  := 1;
    PRE_DECODE:           boolean   := false;
    BASE_ADDRESS:         unsigned  := x"0";
    BYTE_SIZE:            positive  := 256;
    ERROR_STATUS:         boolean   := false;
    INSERT_SLICER:        boolean   := false
  );
  port (
    i_clk:                  in  std_logic;
    i_rst_n:                in  std_logic;
    i_read:                 in  std_logic;
    i_write:                in  std_logic;
    i_address:              in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_byteenable:           in  std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
    i_writedata:            in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    o_waitrequest:          out std_logic;
    o_readdatavalid:        out std_logic;
    o_writeresponsevalid:   out std_logic;
    o_response:             out std_logic_vector(1 downto 0);
    o_readdata:             out std_logic_vector(BUS_WIDTH - 1 downto 0);
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
end rggen_avalon_adapter;

architecture rtl of rggen_avalon_adapter is
  signal  request_valid:  std_logic_vector(1 downto 0);
  signal  request_read:   std_logic;
  signal  address:        std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  byteenable:     std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  writedata:      std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  response_valid: std_logic_vector(1 downto 0);
  signal  response:       std_logic_vector(1 downto 0);
  signal  readdata:       std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_valid:      std_logic;
  signal  bus_access:     std_logic_vector(1 downto 0);
  signal  bus_address:    std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
  signal  bus_write_data: std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal  bus_strobe:     std_logic_vector(BUS_WIDTH / 8 - 1 downto 0);
  signal  bus_ready:      std_logic;
  signal  bus_status:     std_logic_vector(1 downto 0);
  signal  bus_read_data:  std_logic_vector(BUS_WIDTH - 1 downto 0);
begin
  o_waitrequest         <= request_valid(1);
  o_readdatavalid       <= response_valid(0);
  o_writeresponsevalid  <= response_valid(1);
  o_response            <= response;
  o_readdata            <= readdata;

  bus_valid       <= '1' when (request_valid /= "00") else '0';
  bus_access      <= RGGEN_READ  when (request_valid(1) = '1') and (request_read = '1') else
                     RGGEN_WRITE when (request_valid(1) = '1') and (request_read = '0') else
                     RGGEN_READ  when (i_read           = '1') else
                     RGGEN_WRITE;
  bus_address     <= address    when (request_valid(1) = '1') else i_address;
  bus_write_data  <= writedata  when (request_valid(1) = '1') else i_writedata;
  bus_strobe      <= byteenable when (request_valid(1) = '1') else i_byteenable;

  request_valid(0)  <= i_read or i_write;
  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      request_valid(1)  <= '0';
    elsif (rising_edge(i_clk)) then
      if ((bus_valid and bus_ready) = '1') then
        request_valid(1)  <= '0';
      elsif (request_valid(1) = '0') then
        request_valid(1)  <= request_valid(0);
      end if;
    end if;
  end process;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      request_read  <= '0';
      address       <= (others => '0');
      byteenable    <= (others => '0');
      writedata     <= (others => '0');
    elsif (rising_edge(i_clk)) then
      if (request_valid = "01") then
        request_read  <= i_read;
        address       <= i_address;
        byteenable    <= i_byteenable;
        writedata     <= i_writedata;
      end if;
    end if;
  end process;

  process (i_clk, i_rst_n) begin
    if (i_rst_n = '0') then
      response_valid  <= "00";
    elsif (rising_edge(i_clk)) then
      if ((bus_valid and bus_ready) = '1') then
        if (bus_access = RGGEN_READ) then
          response_valid  <= "01";
        else
          response_valid  <= "10";
        end if;
      else
        response_valid  <= "00";
      end if;
    end if;
  end process;

  process (i_clk) begin
    if (rising_edge(i_clk)) then
      if ((bus_valid and bus_ready) = '1') then
        response  <= bus_status;
        readdata  <= bus_read_data;
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
      USE_READ_STROBE     => true,
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
