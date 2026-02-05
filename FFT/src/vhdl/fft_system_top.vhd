library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fft_system_top is
    generic (
        FFT_SIZE   : integer := 256;
        DATA_WIDTH : integer := 16
    );
    port (
        clk50     : in  std_logic; -- 50MHz
        rst_n     : in  std_logic;

        uart_rx   : in  std_logic;
        uart_tx   : out std_logic;

        led_status: out std_logic_vector(7 downto 0)
    );
end fft_system_top;

architecture rtl of fft_system_top is
    constant FFT_N      : integer := 256;
    constant DATA_W     : integer := 16;
    signal clk25 : std_logic := '0';

    -- UART link
    signal rx_b    : std_logic_vector(7 downto 0);
    signal rx_v    : std_logic;
    signal tx_b    : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_v    : std_logic := '0';
    signal tx_rdy  : std_logic;

    -- packet parser
    type pstate_t is (
        WAIT_H1, WAIT_H2,
        WAIT_LEN0, WAIT_LEN1,
        RECV_PAYLOAD,
        SEND_H1, SEND_H2,
        SEND_LEN0, SEND_LEN1,
        SEND_PAYLOAD
    );
    signal ps : pstate_t := WAIT_H1;

    constant RX_HEADER_H1 : std_logic_vector(7 downto 0) := x"AA";
    constant RX_HEADER_H2 : std_logic_vector(7 downto 0) := x"55";
    constant TX_HEADER_H1 : std_logic_vector(7 downto 0) := x"55";
    constant TX_HEADER_H2 : std_logic_vector(7 downto 0) := x"AA";

    signal len0, len1 : std_logic_vector(7 downto 0) := (others => '0');
    signal sample_idx : integer range 0 to FFT_N := 0;
    signal byte_in_sample : integer range 0 to 3 := 0;

    type mem_t is array (0 to FFT_N-1) of signed(DATA_W-1 downto 0);
    signal in_re_mem, in_im_mem : mem_t;
    signal out_re_mem, out_im_mem : mem_t;

    signal re_lo, re_hi, im_lo, im_hi : std_logic_vector(7 downto 0) := (others => '0');

    -- fft stub
    signal fft_start : std_logic := '0';
    signal fft_in_re, fft_in_im : signed(DATA_W-1 downto 0) := (others => '0');
    signal fft_in_valid : std_logic := '0';
    signal fft_out_re, fft_out_im : signed(DATA_W-1 downto 0);
    signal fft_out_valid : std_logic;
    signal fft_busy, fft_done : std_logic;

    -- send side
    signal out_idx : integer range 0 to FFT_N := 0;
    signal out_byte_sel : integer range 0 to 3 := 0;
    signal tx_busy : std_logic := '0';
    
    -- 启动保护：只有接收到完整封包后才允许发送
    signal rx_packet_received : std_logic := '0';
    
    -- Power-on延迟：防止FPGA配置完成后立即误发送
    signal startup_delay_counter : integer range 0 to 12500000 := 0;  -- 500ms @ 25MHz
    signal system_stable : std_logic := '0';

    constant FFT_SIZE_U16 : unsigned(15 downto 0) := to_unsigned(FFT_N, 16);

    -- helper
    subtype s16_t is signed(15 downto 0);
    function to_s16(lo_b, hi_b : std_logic_vector(7 downto 0)) return s16_t is
        variable tmp : std_logic_vector(15 downto 0);
    begin
        tmp := hi_b & lo_b;
        return signed(tmp);
    end function;

begin
    -- clock /2
    process(clk50, rst_n)
    begin
        if rst_n = '0' then
            clk25 <= '0';
        elsif rising_edge(clk50) then
            clk25 <= not clk25;
        end if;
    end process;

    -- 使用全新简化UART模块 (专为TTL设计)
    u_tx: entity work.uart_tx_simple
        generic map(
            CLK_FREQ  => 25000000,
            BAUD_RATE => 38400
        )
        port map(
            clk      => clk25,
            rst_n    => rst_n,
            tx_data  => tx_b,
            tx_valid => tx_v,
            tx_ready => tx_rdy,
            tx       => uart_tx
        );
    
    u_rx: entity work.uart_rx_simple
        generic map(
            CLK_FREQ  => 25000000,
            BAUD_RATE => 38400
        )
        port map(
            clk      => clk25,
            rst_n    => rst_n,
            rx_data  => rx_b,
            rx_valid => rx_v,
            rx       => uart_rx
        );
    
    u_fft: entity work.fft_core_stub
        generic map(
            FFT_SIZE => FFT_N,
            DATA_WIDTH => DATA_W
        )
        port map(
            clk       => clk25,
            rst_n     => rst_n,
            start     => fft_start,
            in_re     => fft_in_re,
            in_im     => fft_in_im,
            in_valid  => fft_in_valid,
            out_re    => fft_out_re,
            out_im    => fft_out_im,
            out_valid => fft_out_valid,
            busy      => fft_busy,
            done      => fft_done
        );

    -- LED: 簡易狀態指示
    led_status(0) <= system_stable;  -- 系统稳定指示灯
    led_status(1) <= '1' when ps = RECV_PAYLOAD else '0';
    led_status(2) <= '1' when ps = SEND_H1 or ps = SEND_H2 else '0';
    led_status(3) <= '1' when ps = SEND_PAYLOAD else '0';
    led_status(4) <= tx_rdy;
    led_status(5) <= tx_v;
    led_status(6) <= '1' when sample_idx = FFT_N-1 else '0';
    led_status(7) <= '1' when out_idx = FFT_N-1 else '0';

    -- Power-on启动延迟
    process(clk25, rst_n)
    begin
        if rst_n = '0' then
            startup_delay_counter <= 0;
            system_stable <= '0';
        elsif rising_edge(clk25) then
            if startup_delay_counter < 12500000 then  -- 500ms延迟
                startup_delay_counter <= startup_delay_counter + 1;
                system_stable <= '0';
            else
                system_stable <= '1';
            end if;
        end if;
    end process;

    -- 主FSM
    process(clk25, rst_n)
        variable length_val : integer;
    begin
        if rst_n = '0' then
            ps <= WAIT_H1;
            len0 <= (others => '0');
            len1 <= (others => '0');
            sample_idx <= 0;
            byte_in_sample <= 0;
            re_lo <= (others => '0');
            re_hi <= (others => '0');
            im_lo <= (others => '0');
            im_hi <= (others => '0');
            fft_start <= '0';
            fft_in_valid <= '0';
            tx_v <= '0';
            tx_b <= (others => '0');
            out_idx <= 0;
            out_byte_sel <= 0;
            tx_busy <= '0';
            rx_packet_received <= '0';  -- 启动时未接收封包
        elsif rising_edge(clk25) then
            -- defaults
            fft_start <= '0';
            fft_in_valid <= '0';
            tx_v <= '0';

            case ps is
                when WAIT_H1 =>
                    if system_stable = '1' and rx_v = '1' and rx_b = RX_HEADER_H1 then
                        ps <= WAIT_H2;
                    end if;

                when WAIT_H2 =>
                    if rx_v = '1' then
                        if rx_b = RX_HEADER_H2 then
                            ps <= WAIT_LEN0;
                        else
                            ps <= WAIT_H1;
                        end if;
                    end if;

                when WAIT_LEN0 =>
                    if rx_v = '1' then
                        len0 <= rx_b;
                        ps <= WAIT_LEN1;
                    end if;

                when WAIT_LEN1 =>
                    if rx_v = '1' then
                        len1 <= rx_b;
                        length_val := to_integer(unsigned(rx_b & len0));
                        if length_val = FFT_N then
                            sample_idx <= 0;
                            byte_in_sample <= 0;
                            ps <= RECV_PAYLOAD;
                        else
                            ps <= WAIT_H1;
                        end if;
                    end if;

                when RECV_PAYLOAD =>
                    if rx_v = '1' then
                        case byte_in_sample is
                            when 0 => re_lo <= rx_b;
                            when 1 => re_hi <= rx_b;
                            when 2 => im_lo <= rx_b;
                            when others =>
                                im_hi <= rx_b;
                                in_re_mem(sample_idx) <= to_s16(re_lo, re_hi);
                                in_im_mem(sample_idx) <= to_s16(im_lo, rx_b);
                                out_re_mem(sample_idx) <= to_s16(re_lo, re_hi);
                                out_im_mem(sample_idx) <= to_s16(im_lo, rx_b);

                                if sample_idx = FFT_N-1 then
                                    rx_packet_received <= '1';  -- 标记已接收完整封包
                                    ps <= SEND_H1;
                                else
                                    sample_idx <= sample_idx + 1;
                                end if;
                        end case;

                        if byte_in_sample = 3 then
                            byte_in_sample <= 0;
                        else
                            byte_in_sample <= byte_in_sample + 1;
                        end if;
                    end if;

                when SEND_H1 =>
                    tx_b <= TX_HEADER_H1;
                    -- 双重保护：系统必须稳定 且 已接收封包
                    if system_stable = '1' and rx_packet_received = '1' then
                        if tx_busy = '0' then
                            if tx_rdy = '1' then
                                tx_v <= '1';
                                tx_busy <= '1';
                            end if;
                        else
                            if tx_rdy = '0' then
                                tx_busy <= '0';
                                ps <= SEND_H2;
                            end if;
                        end if;
                    else
                        ps <= WAIT_H1;  -- 未接收封包，返回等待
                    end if;

                when SEND_H2 =>
                    tx_b <= TX_HEADER_H2;
                    if tx_busy = '0' then
                        if tx_rdy = '1' then
                            tx_v <= '1';
                            tx_busy <= '1';
                        end if;
                    else
                        if tx_rdy = '0' then
                            tx_busy <= '0';
                            ps <= SEND_LEN0;
                        end if;
                    end if;

                when SEND_LEN0 =>
                    tx_b <= std_logic_vector(FFT_SIZE_U16(7 downto 0));
                    if tx_busy = '0' then
                        if tx_rdy = '1' then
                            tx_v <= '1';
                            tx_busy <= '1';
                        end if;
                    else
                        if tx_rdy = '0' then
                            tx_busy <= '0';
                            ps <= SEND_LEN1;
                        end if;
                    end if;

                when SEND_LEN1 =>
                    tx_b <= std_logic_vector(FFT_SIZE_U16(15 downto 8));
                    if tx_busy = '0' then
                        if tx_rdy = '1' then
                            tx_v <= '1';
                            tx_busy <= '1';
                        end if;
                    else
                        if tx_rdy = '0' then
                            tx_busy <= '0';
                            out_idx <= 0;
                            out_byte_sel <= 0;
                            ps <= SEND_PAYLOAD;
                        end if;
                    end if;

                when SEND_PAYLOAD =>
                    case out_byte_sel is
                        when 0 => tx_b <= std_logic_vector(out_re_mem(out_idx)(7 downto 0));
                        when 1 => tx_b <= std_logic_vector(out_re_mem(out_idx)(15 downto 8));
                        when 2 => tx_b <= std_logic_vector(out_im_mem(out_idx)(7 downto 0));
                        when others => tx_b <= std_logic_vector(out_im_mem(out_idx)(15 downto 8));
                    end case;
                    
                    if tx_busy = '0' then
                        if tx_rdy = '1' then
                            tx_v <= '1';
                            tx_busy <= '1';
                        end if;
                    else
                        if tx_rdy = '0' then
                            tx_busy <= '0';
                            if out_byte_sel = 3 then
                                out_byte_sel <= 0;
                                if out_idx = FFT_N-1 then
                                    ps <= WAIT_H1;
                                else
                                    out_idx <= out_idx + 1;
                                end if;
                            else
                                out_byte_sel <= out_byte_sel + 1;
                            end if;
                        end if;
                    end if;
            end case;
        end if;
    end process;

end rtl;
