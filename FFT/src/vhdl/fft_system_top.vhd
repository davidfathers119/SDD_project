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
    -- Quartus 13.1 對「generic 用在 array/range bounds」偶爾會在 elaborate/map 階段崩潰。
    -- 這個專案目前目標固定 256-point / 16-bit，因此內部統一用常數做 bounds，提升相容性。
    constant FFT_N      : integer := 256;
    constant DATA_W     : integer := 16;
    -- 50MHz -> 25MHz (driver 內部 divisor 表以 25MHz 設計)
    signal clk25 : std_logic := '0';

    -- UART link
    signal rx_b    : std_logic_vector(7 downto 0);
    signal rx_v    : std_logic;
    signal tx_b    : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_v    : std_logic := '0';
    signal tx_rdy  : std_logic;
    
    -- UART 實際連接信號（加入 system_ready 控制）
    signal uart_tx_b : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_tx_v : std_logic := '0';
    signal uart_rst_n : std_logic;  -- 受控的 UART reset

    -- packet parser
    type pstate_t is (
        WAIT_H1, WAIT_H2,
        WAIT_LEN0, WAIT_LEN1,
        RECV_PAYLOAD,
        START_FFT,
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
    signal sample_idx : integer range 0 to FFT_N := 0;  -- 擴展到 FFT_N 避免 START_FFT 溢出
    signal byte_in_sample : integer range 0 to 3 := 0;

    type mem_t is array (0 to FFT_N-1) of signed(DATA_W-1 downto 0);
    signal in_re_mem, in_im_mem : mem_t;
    signal out_re_mem, out_im_mem : mem_t;  -- 輸出緩衝區

    signal re_lo, re_hi, im_lo, im_hi : std_logic_vector(7 downto 0) := (others => '0');

    -- fft stub
    signal fft_start : std_logic := '0';
    signal fft_in_re, fft_in_im : signed(DATA_W-1 downto 0) := (others => '0');
    signal fft_in_valid : std_logic := '0';

    signal fft_out_re, fft_out_im : signed(DATA_W-1 downto 0);
    signal fft_out_valid : std_logic;
    signal fft_busy, fft_done : std_logic;

    -- send side
    signal out_idx : integer range 0 to FFT_N := 0;  -- 擴展範圍避免邊界檢查時溢出
    signal out_byte_sel : integer range 0 to 3 := 0;
    signal data_ready : std_logic := '0';  -- 標記輸出資料是否已準備好
    signal tx_busy : std_logic := '0';  -- 標記當前byte正在發送
    signal tx_enabled : std_logic := '0';  -- 標記是否允許發送（只在SEND狀態為'1'）
    
    -- 啟動延遲：防止 power-on 時信號不穩定
    signal startup_counter : integer range 0 to 15000000 := 0;  -- 擴展範圍支援更長延遲
    signal system_ready : std_logic := '0';
    
    -- LED latch：延長顯示時間
    signal led_send_header_latch : std_logic := '0';
    signal led_send_payload_latch : std_logic := '0';

    constant FFT_SIZE_U16 : unsigned(15 downto 0) := to_unsigned(FFT_N, 16);

    -- helper
    subtype s16_t is signed(15 downto 0);
    function to_s16(lo_b, hi_b : std_logic_vector(7 downto 0)) return s16_t is
        variable tmp : std_logic_vector(15 downto 0);
    begin
        tmp := hi_b & lo_b; -- little-endian: lo first, then hi
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

    u_link: entity work.rs232_link
        port map(
            clk      => clk25,
            rst_n    => uart_rst_n,  -- 使用受控的 reset
            rx       => uart_rx,
            tx       => uart_tx,
            rx_data  => rx_b,
            rx_valid => rx_v,
            tx_data  => uart_tx_b,
            tx_valid => uart_tx_v,
            tx_ready => tx_rdy
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

    -- LED: 簡易狀態 + FSM 除錯
    led_status(0) <= system_ready;            -- 系統準備好（40ms 延遲後）
    led_status(1) <= tx_rdy;                  -- TX 準備好（關鍵！）
    led_status(2) <= '1' when sample_idx = FFT_N-1 else '0';  -- sample_idx = 255（最後一個樣本）
    led_status(3) <= '1' when ps = SEND_H1 else '0';  -- 在 SEND_H1 狀態
    -- 新增：FSM 狀態除錯
    led_status(4) <= '1' when ps = WAIT_H1 else '0';  -- 在 WAIT_H1 狀態
    led_status(5) <= led_send_header_latch;   -- 曾經發送 header（latch）
    led_status(6) <= led_send_payload_latch;  -- 曾經發送 payload（latch）
    led_status(7) <= '1' when ps = RECV_PAYLOAD else '0'; -- 是否在接收 payload

    -- packet FSM + FFT feed + TX
    -- 啟動延遲計數器
    process(clk25, rst_n)
    begin
        if rst_n = '0' then
            startup_counter <= 0;
            system_ready <= '0';
            uart_rst_n <= '0';  -- 同步生成 UART reset
        elsif rising_edge(clk25) then
            if startup_counter < 12500000 then  -- 500ms @ 25MHz (930 bytes @ 38400 需 242ms，留雙倍餘裕)
                startup_counter <= startup_counter + 1;
                system_ready <= '0';
                uart_rst_n <= '0';  -- 保持 UART reset
            else
                system_ready <= '1';
                uart_rst_n <= '1';  -- 釋放 UART reset
            end if;
        end if;
    end process;
    
    -- 主 FSM
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
            data_ready <= '0';  -- reset 時標記資料未準備好
            tx_busy <= '0';  -- reset 時清除發送忙碌標誌
            tx_enabled <= '0';  -- reset 時禁止發送
            uart_tx_b <= (others => '0');  -- reset UART TX buffer
            uart_tx_v <= '0';  -- reset UART TX valid
            led_send_header_latch <= '0';
            led_send_payload_latch <= '0';
        elsif rising_edge(clk25) then
            -- defaults
            fft_start <= '0';
            fft_in_valid <= '0';
            tx_v <= '0';  -- 預設不發送，由 FSM 各狀態控制
            tx_b <= (others => '0');  -- 預設清空發送buffer，避免latch推斷
            -- 寄存器化UART TX接口（只在system_ready且tx_enabled時轉發）
            if system_ready = '1' and tx_enabled = '1' then
                uart_tx_b <= tx_b;
                uart_tx_v <= tx_v;
            else
                uart_tx_b <= (others => '0');
                uart_tx_v <= '0';
            end if;

            case ps is
                when WAIT_H1 =>
                    tx_enabled <= '0';  -- 禁止發送
                    -- 只有系統準備好才開始接收
                    if system_ready = '1' and rx_v = '1' then
                        if rx_b = RX_HEADER_H1 then
                            ps <= WAIT_H2;
                        end if;
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
                        sample_idx <= 0;
                        byte_in_sample <= 0;

                        length_val := to_integer(unsigned(rx_b & len0));
                        if length_val = FFT_N then
                            ps <= RECV_PAYLOAD;
                        else
                            -- 長度不符：丟棄，重新等 header
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
                                -- commit one sample (同時寫入輸入和輸出緩衝區)
                                in_re_mem(sample_idx) <= to_s16(re_lo, re_hi);
                                in_im_mem(sample_idx) <= to_s16(im_lo, rx_b);
                                out_re_mem(sample_idx) <= to_s16(re_lo, re_hi);  -- 直接複製到輸出
                                out_im_mem(sample_idx) <= to_s16(im_lo, rx_b);   -- 直接複製到輸出

                                if sample_idx = FFT_N-1 then
                                    -- 接收完成，直接跳到發送（跳過 FFT 處理）
                                    sample_idx <= 0;  -- 重置 sample_idx 準備發送
                                    data_ready <= '1';
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

                when START_FFT =>
                    -- 暫時跳過 FFT 處理，直接發送
                    -- (此狀態目前不會被進入)
                    data_ready <= '1';
                    ps <= SEND_H1;

                when SEND_H1 =>
                    tx_enabled <= '1';  -- 啟用發送
                    led_send_header_latch <= '1';  -- 設置 latch
                    tx_b <= TX_HEADER_H1;
                    if tx_busy = '0' then
                        -- 尚未發送，等待 UART 準備好
                        if tx_rdy = '1' and data_ready = '1' then
                            tx_v <= '1';
                            tx_busy <= '1';  -- 標記已發送
                        end if;
                    else
                        -- 已發送，等待 UART 開始處理（tx_rdy 變 0）
                        if tx_rdy = '0' then
                            tx_busy <= '0';  -- 清除標誌
                            ps <= SEND_H2;   -- 轉換狀態
                        end if;
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
                    led_send_payload_latch <= '1';  -- 設置 latch
                    -- 準備要發送的資料
                    case out_byte_sel is
                        when 0 => tx_b <= std_logic_vector(out_re_mem(out_idx)(7 downto 0));
                        when 1 => tx_b <= std_logic_vector(out_re_mem(out_idx)(15 downto 8));
                        when 2 => tx_b <= std_logic_vector(out_im_mem(out_idx)(7 downto 0));
                        when others => tx_b <= std_logic_vector(out_im_mem(out_idx)(15 downto 8));
                    end case;
                    
                    if tx_busy = '0' then
                        -- 尚未發送當前 byte
                        if tx_rdy = '1' then
                            tx_v <= '1';
                            tx_busy <= '1';
                        end if;
                    else
                        -- 已發送，等待 UART 接收（tx_rdy 變 0）
                        if tx_rdy = '0' then
                            tx_busy <= '0';
                            -- 更新索引
                            if out_byte_sel = 3 then
                                out_byte_sel <= 0;
                                if out_idx = FFT_N-1 then
                                    -- 發送完成
                                    data_ready <= '0';
                                    tx_enabled <= '0';  -- 禁止發送
                                    led_send_header_latch <= '0';
                                    led_send_payload_latch <= '0';
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
