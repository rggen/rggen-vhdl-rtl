library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rggen_rtl.all;

entity rggen_bit_field is
  generic (
    WIDTH:                    positive            := 8;
    INITIAL_VALUE:            unsigned            := x"0";
    PRECEDENCE_ACCESS:        rggen_sw_hw_access  := RGGEN_HW_ACCESS;
    SW_READ_ACTION:           rggen_sw_action     := RGGEN_READ_DEFAULT;
    SW_WRITE_ACTION:          rggen_sw_action     := RGGEN_WRITE_DEFAULT;
    SW_WRITE_CONTROL:         boolean             := false;
    SW_WRITE_ONCE:            boolean             := false;
    SW_WRITE_ENABLE_POLARITY: rggen_polarity      := RGGEN_ACTIVE_HIGH;
    HW_WRITE:                 boolean             := false;
    HW_WRITE_ENABLE_POLARITY: rggen_polarity      := RGGEN_ACTIVE_HIGH;
    HW_SET:                   boolean             := false;
    HW_SET_WIDTH:             positive            := 1;
    HW_CLEAR:                 boolean             := false;
    HW_CLEAR_WIDTH:           positive            := 1;
    STORAGE:                  boolean             := true;
    EXTERNAL_READ_DATA:       boolean             := false;
    EXTERNAL_MASK:            boolean             := false;
    TRIGGER:                  boolean             := false
  );
  port (
    i_clk:              in  std_logic;
    i_rst_n:            in  std_logic;
    i_sw_read_valid:    in  std_logic;
    i_sw_write_valid:   in  std_logic;
    i_sw_write_enable:  in  std_logic_vector(0 downto 0);
    i_sw_mask:          in  std_logic_vector(WIDTH - 1 downto 0);
    i_sw_write_data:    in  std_logic_vector(WIDTH - 1 downto 0);
    o_sw_read_data:     out std_logic_vector(WIDTH - 1 downto 0);
    o_sw_value:         out std_logic_vector(WIDTH - 1 downto 0);
    o_write_trigger:    out std_logic_vector(0 downto 0);
    o_read_trigger:     out std_logic_vector(0 downto 0);
    i_hw_write_enable:  in  std_logic_vector(0 downto 0);
    i_hw_write_data:    in  std_logic_vector(WIDTH - 1 downto 0);
    i_hw_set:           in  std_logic_vector(HW_SET_WIDTH - 1 downto 0);
    i_hw_clear:         in  std_logic_vector(HW_CLEAR_WIDTH - 1 downto 0);
    i_value:            in  std_logic_vector(WIDTH - 1 downto 0);
    i_mask:             in  std_logic_vector(WIDTH - 1 downto 0);
    o_value:            out std_logic_vector(WIDTH - 1 downto 0);
    o_value_unmasked:   out std_logic_vector(WIDTH - 1 downto 0)
  );
end rggen_bit_field;

architecture rtl of rggen_bit_field is
  constant  SW_WRITABLE:          boolean := SW_WRITE_ACTION /= RGGEN_WRITE_NONE;
  constant  SW_READABLE:          boolean := SW_READ_ACTION  /= RGGEN_READ_NONE;
  constant  SW_READ_UPDATE:       boolean := SW_READABLE and (SW_READ_ACTION /= RGGEN_READ_DEFAULT);
  constant  ENABLE_WRITE_TRIGGER: boolean := SW_WRITABLE and TRIGGER;
  constant  ENABLE_READ_TRIGGER:  boolean := SW_READABLE and TRIGGER;
  constant  HW_ACCESS:            boolean := HW_WRITE or HW_SET or HW_CLEAR;

  function get_sw_read_update(
    read_valid: std_logic
  ) return std_logic is
  begin
    if (SW_READ_UPDATE) then
      return read_valid;
    else
      return '0';
    end if;
  end get_sw_read_update;

  function get_sw_write_update(
    write_valid:  std_logic;
    write_enable: std_logic;
    write_done:   std_logic
  ) return std_logic is
    variable  enable_value: std_logic;
  begin
    if (SW_WRITE_ENABLE_POLARITY = RGGEN_ACTIVE_HIGH) then
      enable_value  := '1';
    else
      enable_value  := '0';
    end if;

    if not SW_WRITABLE then
      return '0';
    elsif SW_WRITE_ONCE and (write_done = '1') then
      return '0';
    elsif SW_WRITE_CONTROL and (write_enable /= enable_value) then
      return '0';
    else
      return write_valid;
    end if;
  end get_sw_write_update;

  function get_sw_update (
    read_valid:   std_logic;
    write_valid:  std_logic;
    write_enable: std_logic;
    write_done:   std_logic
  ) return std_logic_vector is
    variable  read_action:      boolean;
    variable  write_no_action:  boolean;
    variable  read_access:      boolean;
    variable  write_access:     boolean;
    variable  sw_update:        std_logic_vector(1 downto 0);
  begin
    sw_update(0)  := get_sw_read_update(read_valid);
    sw_update(1)  := get_sw_write_update(write_valid, write_enable, write_done);
    return sw_update;
  end get_sw_update;

  function get_hw_update (
    write_enable: std_logic;
    set:          std_logic_vector;
    clear:        std_logic_vector
  ) return std_logic is
  begin
    if (HW_WRITE and (write_enable = '1')) then
      return '1';
    elsif (HW_SET and (unsigned(set) /= 0)) then
      return '1';
    elsif (HW_CLEAR and (unsigned(clear) /= 0)) then
      return '1';
    else
      return '0';
    end if;
  end get_hw_update;

  function get_sw_read_next_value(
    current_value:  std_logic_vector;
    mask:           std_logic_vector
  ) return std_logic_vector is
    variable  value:  std_logic_vector(current_value'range);
  begin
    if ((unsigned(mask) = 0) or (not SW_READ_UPDATE)) then
      value := current_value;
    elsif (SW_READ_ACTION = RGGEN_READ_CLEAR) then
      value := (others => '0');
    else
      value := (others => '1');
    end if;
    return value;
  end get_sw_read_next_value;

  function get_sw_write_next_value(
    current_value:  std_logic_vector;
    mask:           std_logic_vector;
    write_data:     std_logic_vector
  ) return std_logic_vector is
    variable  value: std_logic_vector(current_value'range);
  begin
    value := current_value;
    if (SW_WRITE_ACTION = RGGEN_WRITE_DEFAULT) then
      value := write_data;
    elsif (SW_WRITE_ACTION = RGGEN_WRITE_0_CLEAR) then
      for i in 0 to WIDTH - 1 loop
        if ((mask(i) = '1') and (write_data(i) = '0')) then
          value(i)  := '0';
        end if;
      end loop;
    elsif (SW_WRITE_ACTION = RGGEN_WRITE_1_CLEAR) then
      for i in 0 to WIDTH - 1 loop
        if ((mask(i) = '1') and (write_data(i) = '1')) then
          value(i)  := '0';
        end if;
      end loop;
    elsif (SW_WRITE_ACTION = RGGEN_WRITE_CLEAR) then
      if (unsigned(mask) /= 0) then
        value := (others => '0');
      end if;
    elsif (SW_WRITE_ACTION = RGGEN_WRITE_0_SET) then
      for i in 0 to WIDTH - 1 loop
        if ((mask(i) = '1') and (write_data(i) = '0')) then
          value(i)  := '1';
        end if;
      end loop;
    elsif (SW_WRITE_ACTION = RGGEN_WRITE_1_SET) then
      for i in 0 to WIDTH - 1 loop
        if ((mask(i) = '1') and (write_data(i) = '1')) then
          value(i)  := '1';
        end if;
      end loop;
    elsif (SW_WRITE_ACTION = RGGEN_WRITE_SET) then
      if (unsigned(mask) /= 0) then
        value := (others => '1');
      end if;
    elsif (SW_WRITE_ACTION = RGGEN_WRITE_0_TOGGLE) then
      for i in 0 to WIDTH - 1 loop
        if ((mask(i) = '1') and (write_data(i) = '0')) then
          value(i)  := not current_value(i);
        end if;
      end loop;
    elsif (SW_WRITE_ACTION = RGGEN_WRITE_1_TOGGLE) then
      for i in 0 to WIDTH - 1 loop
        if ((mask(i) = '1') and (write_data(i) = '1')) then
          value(i)  := not current_value(i);
        end if;
      end loop;
    end if;

    return value;
  end get_sw_write_next_value;

  function get_hw_next_value (
    current_value:  std_logic_vector;
    write_enable:   std_logic;
    write_data:     std_logic_vector;
    set:            std_logic_vector;
    clear:          std_logic_vector
  ) return std_logic_vector is
    variable  set_actual:   std_logic_vector(current_value'range);
    variable  clear_actual: std_logic_vector(current_value'range);
    variable  enable_value: std_logic;
    variable  value:        std_logic_vector(current_value'range);
  begin
    if (not HW_SET) then
      set_actual  := (others => '0');
    elsif (HW_SET_WIDTH = WIDTH) then
      set_actual(HW_SET_WIDTH - 1 downto 0) := set;
    else
      set_actual  := (others => set(0));
    end if;

    if (not HW_CLEAR) then
      clear_actual  := (others => '0');
    elsif (HW_CLEAR_WIDTH = WIDTH) then
      clear_actual(HW_CLEAR_WIDTH - 1 downto 0) := clear;
    else
      clear_actual  := (others => clear(0));
    end if;

    if (HW_WRITE_ENABLE_POLARITY = RGGEN_ACTIVE_HIGH) then
      enable_value  := '1';
    else
      enable_value  := '0';
    end if;

    for i in 0 to WIDTH - 1 loop
      if (set_actual(i) = '1') then
        value(i)  := '1';
      elsif (clear_actual(i) = '1') then
        value(i)  := '0';
      elsif (HW_WRITE and (write_enable = enable_value)) then
        value(i)  := write_data(i);
      else
        value(i)  := current_value(i);
      end if;
    end loop;

    return value;
  end get_hw_next_value;

  signal  sw_update:        std_logic_vector(1 downto 0);
  signal  sw_write_done:    std_logic;
  signal  hw_update:        std_logic;
  signal  write_trigger:    std_logic;
  signal  read_trigger:     std_logic;
  signal  value:            std_logic_vector(WIDTH - 1 downto 0);
  signal  value_masked:     std_logic_vector(WIDTH - 1 downto 0);
  signal  read_data:        std_logic_vector(WIDTH - 1 downto 0);
begin
  o_sw_read_data      <= (read_data and i_mask) when EXTERNAL_MASK else read_data;
  o_sw_value          <= value;
  o_write_trigger(0)  <= write_trigger;
  o_read_trigger(0)   <= read_trigger;
  o_value             <= (value and i_mask) when EXTERNAL_MASK else value;
  o_value_unmasked    <= value;

  process (i_sw_read_valid, i_sw_write_valid, i_sw_write_enable, sw_write_done) begin
    if (SW_READ_UPDATE) then
      sw_update(0)  <= i_sw_read_valid;
    else
      sw_update(0)  <= '0';
    end if;
    
    if (SW_WRITABLE) then
      sw_update(1)  <= get_sw_write_update(i_sw_write_valid, i_sw_write_enable(0), sw_write_done);
    else
      sw_update(1)  <= '0';
    end if;
  end process;
  
  process (i_hw_write_enable, i_hw_set, i_hw_clear) begin
    if (HW_ACCESS) then
      hw_update <= get_hw_update(i_hw_write_enable(0), i_hw_set, i_hw_clear);
    else
      hw_update <= '0';
    end if;
  end process;

  g_sw_write_onece: if (SW_WRITE_ONCE) generate
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        sw_write_done <= '0';
      elsif (rising_edge(i_clk)) then
        if ((sw_update(1) = '1') and (unsigned(i_sw_mask) /= 0)) then
          sw_write_done <= '1';
        end if;
      end if;
    end process;
  end generate;

  g_sw_write_anytime: if (not SW_WRITE_ONCE) generate
    sw_write_done <= '0';
  end generate;

  g_write_trigger: if (ENABLE_WRITE_TRIGGER) generate
  begin
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        write_trigger <= '0';
      elsif (rising_edge(i_clk)) then
        if (i_sw_write_valid = '1' and unsigned(i_sw_mask) /= 0) then
          write_trigger <= '1';
        else
          write_trigger <= '0';
        end if;
      end if;
    end process;
  end generate;

  g_no_write_trigger: if (not ENABLE_WRITE_TRIGGER) generate
  begin
    write_trigger <= '0';
  end generate;

  g_read_trigger: if (ENABLE_READ_TRIGGER) generate
  begin
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        read_trigger  <= '0';
      elsif (rising_edge(i_clk)) then
        if (i_sw_read_valid = '1' and unsigned(i_sw_mask) /= 0) then
          read_trigger  <= '1';
        else
          read_trigger  <= '0';
        end if;
      end if;
    end process;
  end generate;

  g_no_read_trigger: if (not ENABLE_READ_TRIGGER) generate
  begin
    read_trigger  <= '0';
  end generate;

  g_storage_hw_first: if (STORAGE and (PRECEDENCE_ACCESS = RGGEN_HW_ACCESS)) generate
  begin
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        value <= std_logic_vector(INITIAL_VALUE);
      elsif (rising_edge(i_clk)) then
        if (HW_ACCESS and (hw_update = '1')) then
          value <=
            get_hw_next_value(
              value, i_hw_write_enable(0), i_hw_write_data,
              i_hw_set, i_hw_clear
            );
        elsif (SW_READ_UPDATE and (sw_update(0) = '1')) then
          value <=
            get_sw_read_next_value(
              value, i_sw_mask
            );
        elsif (SW_WRITABLE and (sw_update(1) = '1')) then
          value <=
            get_sw_write_next_value(
              value, i_sw_mask, i_sw_write_data
            );
        end if;
      end if;
    end process;
  end generate;

  g_storage_sw_first: if (STORAGE and (PRECEDENCE_ACCESS = RGGEN_SW_ACCESS)) generate
  begin
    process (i_clk, i_rst_n) begin
      if (i_rst_n = '0') then
        value <= std_logic_vector(INITIAL_VALUE);
      elsif (rising_edge(i_clk)) then
        if (SW_READ_UPDATE and (sw_update(0) = '1')) then
          value <=
            get_sw_read_next_value(
              value, i_sw_mask
            );
        elsif (SW_WRITABLE and (sw_update(1) = '1')) then
          value <=
            get_sw_write_next_value(
              value, i_sw_mask, i_sw_write_data
            );
        elsif (HW_ACCESS and (hw_update = '1')) then
          value <=
            get_hw_next_value(
              value, i_hw_write_enable(0), i_hw_write_data,
              i_hw_set, i_hw_clear
            );
        end if;
      end if;
    end process;
  end generate;

  g_through: if (not STORAGE) generate
    value <= i_value;
  end generate;

  g_internal_read_data: if (SW_READABLE and (not EXTERNAL_READ_DATA)) generate
    read_data <= value;
  end generate;

  g_external_read_data: if (SW_READABLE and EXTERNAL_READ_DATA) generate
    read_data <= i_value;
  end generate;

  g_no_read_data: if (not SW_READABLE) generate
    read_data <= (others => '0');
  end generate;
end rtl;
