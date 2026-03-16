library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rs232_link is
    generic (
        -- 注意：匯入的 RS232_T1/RS232_R2 driver 目前 F_Set=3-bit，
        -- 對應表內最高只到 38400（F_Set="111"）。
        F_SET : std_logic_vector(2 downto 0) := "111";
        DL    : std_logic_vector(1 downto 0) := "11";  -- 8-bit
        PARITY: std_logic_vector(2 downto 0) := "000"; -- None
        STOPN : std_logic_vector(1 downto 0) := "00"   -- 1 stop bit
    );
    port (
        clk        : in  std_logic; -- 建議 25MHz（50MHz 除2）
        rst_n      : in  std_logic; -- active-low

        rx         : in  std_logic;
        tx         : out std_logic;

        -- RX byte output
        rx_data    : out std_logic_vector(7 downto 0);
        rx_valid   : out std_logic; -- 1-cycle pulse

        -- TX byte input
        tx_data    : in  std_logic_vector(7 downto 0);
        tx_valid   : in  std_logic; -- request to send 1 byte
        tx_ready   : out std_logic  -- high when driver can accept a new byte
    );
end rs232_link;

architecture rtl of rs232_link is
    signal status_t : std_logic_vector(1 downto 0);
    signal status_r : std_logic_vector(2 downto 0);

    signal tx_w     : std_logic := '0';
    signal rx_r     : std_logic := '0';

    signal rx_data_i : std_logic_vector(7 downto 0);

    signal tx_ready_i : std_logic;

    signal rx_seen_full : std_logic := '0';
    signal tx_pulse     : std_logic := '0';
begin

    -- 匯入的 driver 使用 Reset='0' 表示 reset
    u_tx: entity work.RS232_T1
        port map(
            Clk      => clk,
            Reset    => rst_n,
            DL       => DL,
            ParityN  => PARITY,
            StopN    => STOPN,
            F_Set    => F_SET,
            Status_s => status_t,
            TX_W     => tx_w,
            TXData   => tx_data,
            TX       => tx
        );

    u_rx: entity work.RS232_R2
        port map(
            Clk      => clk,
            Reset    => rst_n,
            DL       => DL,
            ParityN  => PARITY,
            StopN    => STOPN,
            F_Set    => F_SET,
            Status_s => status_r,
            Rx_R     => rx_r,
            RD       => rx,
            RxDs     => rx_data_i
        );

    -- status_t(1)=Tx_B_Empty：0 表示可寫入新資料
    tx_ready_i <= not status_t(1);
    tx_ready   <= tx_ready_i;

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            tx_w   <= '0';
            tx_pulse <= '0';
        elsif rising_edge(clk) then
            -- default
            tx_w <= '0';

            if (tx_valid = '1') and (tx_ready_i = '1') then
                -- 單拍載入 TXData
                tx_w <= '1';
            end if;
        end if;
    end process;

    rx_data <= rx_data_i;

    -- status_r(2)=Rx_B_Empty：1 表示接收 buffer 有新資料
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            rx_r <= '0';
            rx_seen_full <= '0';
            rx_valid <= '0';
        elsif rising_edge(clk) then
            rx_valid <= '0';

            if status_r(2) = '1' then
                -- buffer full：只在第一次看到 full 時發出 valid 並拉高 Rx_R
                if rx_seen_full = '0' then
                    rx_seen_full <= '1';
                    rx_valid <= '1';
                    rx_r <= '1';
                end if;
            else
                -- buffer cleared
                rx_seen_full <= '0';
                rx_r <= '0';
            end if;
        end if;
    end process;

    end rtl;
